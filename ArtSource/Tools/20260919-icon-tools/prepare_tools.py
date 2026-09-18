"""Preserve P2 sources; normalize icon tools and audit the exported runtime meshes."""
from pathlib import Path
import json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

def remove_sickle_sprig(mesh):
    """Separate decorative grass from the inspected sickle; retain handle, blade and rivets.

    Connectivity is evaluated on a welded copy. Delete only corresponding original
    vertices so the actual asset retains its original UV seams and native faces.
    """
    probe = bmesh.new(); probe.from_mesh(mesh)
    bmesh.ops.remove_doubles(probe, verts=list(probe.verts), dist=.00001)
    pending = set(probe.verts); retained = []
    while pending:
        vertex = pending.pop(); part = {vertex}; todo = [vertex]
        while todo:
            vertex = todo.pop()
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other in pending:
                    pending.remove(other); part.add(other); todo.append(other)
        # Verified normalized components: handle and blade extend below .35 m;
        # the separate sprig components are entirely above .38 m.
        if min(v.co.z for v in part) < .35: retained.extend(v.co.copy() for v in part)
    probe.free()
    tree = KDTree(len(retained))
    for i, point in enumerate(retained): tree.insert(point, i)
    tree.balance()
    edit = bmesh.new(); edit.from_mesh(mesh)
    remove = [v for v in edit.verts if tree.find(v.co)[2] > .00002]
    count = len(remove)
    bmesh.ops.delete(edit, geom=remove, context='VERTS')
    edit.to_mesh(mesh); edit.free()
    return count

ROOT = Path(__file__).resolve().parent
GAME = ROOT.parents[2] / 'Game/art/tools'
GAME.mkdir(parents=True, exist_ok=True)
for kind, height in [('water', .53), ('harvest', .48), ('weed', .67), ('till', 1.30)]:
    folder = ROOT / kind
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(next((folder/'raw').rglob('model.fbx'))))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    source_polygons = sum(len(o.data.polygons) for o in meshes)
    source_quads = sum(len(p.vertices)==4 for o in meshes for p in o.data.polygons)
    for obj in meshes:
        obj.data.transform(obj.matrix_world)
        obj.matrix_world.identity()
    points = np.array([list(v.co) for o in meshes for v in o.data.vertices])
    rotation = Vector((0, 0, 1)).rotation_difference(Vector((0, 0, 1)))
    if kind in ['weed', 'till']:
        center = points.mean(axis=0)
        values, vectors = np.linalg.eigh(np.cov((points-center).T))
        axis = vectors[:, -1]
        if axis[2] < 0: axis = -axis
        # Original blade is above the handle in both approved icons. A hoe
        # rests blade-down; the smaller sickle rests handle-down.
        if kind == 'till': axis = -axis
        rotation = Vector(axis).rotation_difference(Vector((0, 0, 1)))
        for obj in meshes: obj.data.transform(rotation.to_matrix().to_4x4())
    pts = [v.co.copy() for o in meshes for v in o.data.vertices]
    low = Vector([min(p[i] for p in pts) for i in range(3)])
    high = Vector([max(p[i] for p in pts) for i in range(3)])
    scale = height / (high.z-low.z)
    pivot = Vector(((low.x+high.x)/2, (low.y+high.y)/2, low.z))
    removed_vertices = 0
    for obj in meshes:
        for vertex in obj.data.vertices: vertex.co = (vertex.co-pivot)*scale
        if kind == 'weed': removed_vertices += remove_sickle_sprig(obj.data)
        obj.name = kind
        for mat in obj.data.materials:
            for node in mat.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    node.inputs['Roughness'].default_value = .94
                    node.inputs['Metallic'].default_value = 0
                    node.inputs['Specular IOR Level'].default_value = .08
        obj.data.calc_loop_triangles()
    bpy.context.view_layer.update()
    audit = {'height_m':height, 'triangles':sum(len(o.data.loop_triangles) for o in meshes),
             'source_polygons':source_polygons, 'source_quads':source_quads,
             'prepared_polygons':sum(len(o.data.polygons) for o in meshes),
             'quads':sum(len(p.vertices)==4 for o in meshes for p in o.data.polygons),
             'dimensions_blender_xyz':[list(o.dimensions) for o in meshes],
             'rotation_quaternion_wxyz':list(rotation), 'scale':scale, 'decorative_grass_vertices_removed':removed_vertices,
             'textures':[{ 'name':im.name, 'size':list(im.size)} for im in bpy.data.images if im.size[0]]}
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/(kind+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(GAME/(kind+'.glb')), export_format='GLB')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(GAME/(kind+'.glb')))
    count = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    assert count == audit['triangles'], (kind, count, audit)
    audit['reimport_verified'] = True
    (folder/'audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    print('ICON_TOOL_VERIFIED',kind,json.dumps(audit))
