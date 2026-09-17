"""Inspect the osmanthus whole/semantic sources without changing either GLB.
Blender 5.2.2: --background --python-exit-code 1 --python this_file.py
This is a segmentation feasibility study, not the runtime preparation pipeline.
"""
from pathlib import Path
import bpy, bmesh, json, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent / 'osmanthus'
report = {'blender': bpy.app.version_string, 'runtime_adopted': False}
source_bvh = None
source_centre = None
source_span = None
for variant in ['raw', 'segmented']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / variant / 'model.glb'))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    bottom = Vector([min(p[i] for p in points) for i in range(3)])
    top = Vector([max(p[i] for p in points) for i in range(3)])
    part_data = []
    all_vertices, all_faces = [], []
    for obj in objects:
        mesh = obj.data
        mesh.calc_loop_triangles()
        vertices = [obj.matrix_world @ v.co for v in mesh.vertices]
        base = len(all_vertices)
        all_vertices.extend(vertices)
        all_faces.extend(tuple(base + i for i in t.vertices) for t in mesh.loop_triangles)
        bm = bmesh.new(); bm.from_mesh(mesh)
        # glTF splits vertices at UV seams. Weld only this disposable audit copy.
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
        unseen = set(bm.verts); sizes = []
        while unseen:
            stack = [unseen.pop()]; size = 0
            while stack:
                v = stack.pop(); size += 1
                for e in v.link_edges:
                    other = e.other_vert(v)
                    if other in unseen:
                        unseen.remove(other); stack.append(other)
            sizes.append(size)
        part_data.append({'name':obj.name, 'triangles':len(mesh.loop_triangles),
            'vertices':len(vertices), 'connected_components':len(sizes),
            'boundary_edges':sum(e.is_boundary for e in bm.edges),
            'loose_vertices':sum(not v.link_faces for v in bm.verts),
            'materials':[m.name for m in mesh.materials],
            'uv_layers':len(mesh.uv_layers), 'dimensions':list(obj.dimensions)})
        bm.free()
    if variant == 'raw':
        source_bvh = BVHTree.FromPolygons(all_vertices, all_faces, all_triangles=True)
        source_centre = (bottom+top)*.5
        source_span = top-bottom
    distances = []
    restored_distances = []
    if variant == 'segmented':
        centre=(bottom+top)*.5
        scale=max(source_span)/max(top-bottom)
        for p in all_vertices:
            nearest = source_bvh.find_nearest(p)
            if nearest[0] is not None: distances.append(nearest[3])
            nearest = source_bvh.find_nearest((p-centre)*scale+source_centre)
            if nearest[0] is not None: restored_distances.append(nearest[3])
    report[variant] = {'mesh_count':len(objects), 'triangles':len(all_faces),
        'bounds_min':list(bottom), 'bounds_max':list(top), 'parts':part_data,
        'textures':[{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.type == 'IMAGE'],
        'armatures':sum(o.type == 'ARMATURE' for o in bpy.context.scene.objects),
        'actions':len(bpy.data.actions),
        'max_vertex_distance_to_raw':max(distances) if distances else None,
        'max_distance_after_uniform_bounds_alignment':max(restored_distances) if restored_distances else None,
        'topology_audit':'Positions welded at 1e-6 on a disposable copy to avoid counting UV seams as holes.'}
    for i,obj in enumerate(objects):
        if variant == 'segmented':
            mat=bpy.data.materials.new('Part display '+obj.name)
            mat.diffuse_color=(*__import__('colorsys').hsv_to_rgb((i*.618)%1,.60,.78),1)
            mat.use_nodes=True
            bsdf=mat.node_tree.nodes.get('Principled BSDF')
            bsdf.inputs['Base Color'].default_value=mat.diffuse_color
            bsdf.inputs['Roughness'].default_value=.85
            obj.data.materials.clear(); obj.data.materials.append(mat)
            for face in obj.data.polygons: face.material_index=0
    scene=bpy.context.scene
    scene.render.engine='CYCLES'; scene.cycles.samples=24
    scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.world=bpy.data.worlds.new('Neutral world'); scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.32,.32,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
    centre=(bottom+top)*.5; extent=max(top-bottom)
    camera_data=bpy.data.cameras.new('Inspection camera'); camera=bpy.data.objects.new('Inspection camera',camera_data)
    scene.collection.objects.link(camera); scene.camera=camera; camera_data.type='ORTHO'; camera_data.ortho_scale=extent*1.3
    for j,offset in enumerate([(2,-3,4),(-3,-1,2)]):
        data=bpy.data.lights.new('Soft light '+str(j),'AREA'); data.energy=90; data.shape='DISK'; data.size=extent*3
        light=bpy.data.objects.new(data.name,data); scene.collection.objects.link(light)
        light.location=centre+Vector(offset)*extent
        light.rotation_euler=(centre-light.location).to_track_quat('-Z','Y').to_euler()
    scene.view_settings.view_transform='AgX'
    for view,offset in [('front',(3,-1,1.0)),('back',(-3,1,1.0)),('side',(1,-3,1.0))]:
        camera.location=centre+Vector(offset)*extent
        camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(ROOT/(variant+'-'+view+'.png'))
        bpy.ops.render.render(write_still=True)
    if variant=='segmented':
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'segmentation-inspection.blend'))
(ROOT/'segmentation-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('SEGMENTATION_AUDIT',json.dumps(report,ensure_ascii=False))
