"""Preserve P2 polygons, normalize height, export and independently reimport GLB.
Run in Blender background with --python-exit-code 1 --python this_file.
No crop-specific decimation, tilt, color correction or wind is applied.
"""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parent


def audit(obj):
    obj.data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Diagnose UV seam splits without modifying the production geometry.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    result = dict(vertices=len(obj.data.vertices), polygons=len(obj.data.polygons),
                  quads=sum(len(p.vertices) == 4 for p in obj.data.polygons),
                  triangles=len(obj.data.loop_triangles), uv_layers=len(obj.data.uv_layers),
                  boundary_edges=sum(e.is_boundary for e in bm.edges),
                  non_manifold_edges=sum(not e.is_manifold for e in bm.edges),
                  zero_area_faces=sum(f.calc_area() < 1e-12 for f in bm.faces),
                  materials=len(obj.data.materials), dimensions=list(obj.dimensions))
    bm.free()
    return result


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT / 'raw/model.fbx'), use_image_search=False)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert meshes, 'Missing source mesh'
report = {'blender': bpy.app.version_string, 'source': [audit(o) for o in meshes]}
points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector([min(p[i] for p in points) for i in range(3)])
hi = Vector([max(p[i] for p in points) for i in range(3)])
factor = 1.55 / (hi.z - lo.z)
pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for i, obj in enumerate(meshes):
    transform = obj.matrix_world.copy()
    for vertex in obj.data.vertices:
        vertex.co = (transform @ vertex.co - pivot) * factor
    obj.matrix_world.identity()
    obj.name = 'Farmer' if i == 0 else f'Farmer_{i}'
    for face in obj.data.polygons:
        face.use_smooth = True
    for material in obj.data.materials:
        for node in material.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED':
                node.inputs['Metallic'].default_value = 0
                node.inputs['Roughness'].default_value = .95
                node.inputs['Specular IOR Level'].default_value = .08
bpy.context.view_layer.update()
report['repairs'] = []
for obj in meshes:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    uv = bm.loops.layers.uv.active
    # Only close short boundary loops in the headcloth. Garment openings remain.
    head_edges = [e for e in bm.edges if e.is_boundary and min(v.co.z for v in e.verts) > 1.18]
    vertex_uv = {v: [loop[uv].uv.copy() for loop in v.link_loops] for v in bm.verts}
    filled = bmesh.ops.holes_fill(bm, edges=head_edges, sides=16)['faces']
    for face in filled:
        face.smooth = True
        for loop in face.loops:
            samples = vertex_uv[loop.vert]
            if samples:
                loop[uv].uv = sum(samples, Vector((0, 0))) / len(samples)
    report['repairs'].append({'headcloth_small_holes_filled': len(filled),
                              'weld_distance_m': 1e-6, 'degenerate_threshold_m': 1e-7})
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
report['prepared'] = [audit(o) for o in meshes]
report['height_m'] = 1.55
report['textures'] = [{'name': im.name, 'size': list(im.size)} for im in bpy.data.images if im.type == 'IMAGE']
assert report['textures'] and all(min(im['size']) > 0 for im in report['textures'])
assert all(o.data.uv_layers for o in meshes)
bpy.ops.file.pack_all()
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'farmer_gongbi.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'farmer_gongbi.glb'), export_format='GLB', use_selection=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'farmer_gongbi.glb'))
report['reimport'] = [audit(o) for o in bpy.context.scene.objects if o.type == 'MESH']
assert sum(o['triangles'] for o in report['prepared']) == sum(o['triangles'] for o in report['reimport'])
report['reimport_verified'] = True
(ROOT / 'asset-audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')

# Neutral views are rendered from the actual exported GLB, not from reference art.
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.world = bpy.data.worlds.new('Neutral')
scene.world.use_nodes = True
background = scene.world.node_tree.nodes.get('Background')
background.inputs[0].default_value = (.7, .68, .62, 1)
background.inputs[1].default_value = .8
for position, power in [((3,-4,5), 300), ((-3,2,4), 200)]:
    bpy.ops.object.light_add(type='AREA', location=position)
    lamp = bpy.context.object
    lamp.data.energy = power
    lamp.data.size = 4
    lamp.rotation_euler = (Vector((0,0,.8))-lamp.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add()
camera = bpy.context.object
scene.camera = camera
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 1.85
scene.render.resolution_x = 640
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Standard'
(ROOT / 'previews').mkdir(exist_ok=True)
for i in range(4):
    angle = math.radians(i * 90)
    camera.location = (3 * math.sin(angle), -3 * math.cos(angle), 1.05)
    camera.rotation_euler = (Vector((0,0,.78))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(ROOT / 'previews' / f'view-{i}.png')
    bpy.ops.render.render(write_still=True)
print('FARMER_VERIFIED ' + json.dumps(report))
