"""Blender 5.2 batch-stage authoring. Raw P2 FBX is immutable.

Usage: blender --background --python-exit-code 1 --python prepare.py -- spinach sprout
Exports beside the source for inspection; only --install copies a checked stage to Game.
Each stage has independently generated anatomy, authored size and optional rigid correction.
"""
from pathlib import Path
import json
import math
import sys
import shutil
import bpy
import bmesh
from mathutils import Vector, Euler, Matrix

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
argv = sys.argv[sys.argv.index('--') + 1:]
crop, stage = argv[:2]
folder = ROOT / crop / stage
config = json.loads((ROOT / crop / 'stages.json').read_text(encoding='utf-8'))['stages'][stage]


def bounds(objects):
    points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    return Vector([min(p[i] for p in points) for i in range(3)]), Vector([max(p[i] for p in points) for i in range(3)])


def inspect(obj):
    obj.data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Diagnose UV-split vertices without modifying the source or exported geometry.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
    result = dict(vertices=len(obj.data.vertices), polygons=len(obj.data.polygons),
                  quads=sum(len(f.vertices) == 4 for f in obj.data.polygons),
                  triangles=len(obj.data.loop_triangles), uv_layers=len(obj.data.uv_layers),
                  materials=len(obj.data.materials), boundary_edges=sum(e.is_boundary for e in bm.edges),
                  non_manifold_edges=sum(not e.is_manifold for e in bm.edges),
                  loose_vertices=sum(not v.link_faces for v in bm.verts),
                  zero_area_faces=sum(f.calc_area() < 1e-14 for f in bm.faces))
    bm.free()
    return result


bpy.ops.wm.read_factory_settings(use_empty=True)
raw_files = list((folder / 'raw').rglob('model.fbx'))
assert len(raw_files) == 1, 'Expected exactly one immutable FBX for this stage'
bpy.ops.import_scene.fbx(filepath=str(raw_files[0]), use_image_search=False)
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert objects
for obj in objects:
    obj.data.transform(obj.matrix_world)
    obj.matrix_world.identity()
report = dict(crop=crop, stage=stage, task=config['task_id'], blender=bpy.app.version_string,
              source=[inspect(o) for o in objects], rotation_degrees=config['rotation_degrees'])
rotation = Euler(tuple(math.radians(v) for v in config['rotation_degrees']), 'XYZ').to_matrix().to_4x4()
for obj in objects:
    obj.data.transform(rotation)
lo, hi = bounds(objects)
scale = min(config['height'] / (hi.z - lo.z), config['max_width'] / max(hi.x - lo.x, hi.y - lo.y))
# A bottom root-collar slice avoids centering an asymmetric leaf crown on the soil.
collar = lo.z + (hi.z - lo.z) * config.get('collar_fraction', 0.0)
root_points = [v.co for o in objects for v in o.data.vertices if abs(v.co.z - collar) < (hi.z - lo.z) * .012]
assert root_points, 'No root collar points; author the correct collar fraction'
center = Vector(((min(p.x for p in root_points) + max(p.x for p in root_points)) / 2,
                 (min(p.y for p in root_points) + max(p.y for p in root_points)) / 2, collar))
transform = Matrix.Scale(scale, 4) @ Matrix.Translation(-center)
for index, obj in enumerate(objects):
    obj.data.transform(transform)
    obj.name = f'{crop}_{stage}' + (f'_{index}' if index else '')
    for face in obj.data.polygons:
        face.use_smooth = True
    for material in obj.data.materials:
        material.use_backface_culling = False
        for node in material.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED':
                node.inputs['Roughness'].default_value = .94
                node.inputs['Metallic'].default_value = 0
                node.inputs['Specular IOR Level'].default_value = .08
for image in bpy.data.images:
    if image.type == 'IMAGE':
        assert min(image.size) > 0, 'Missing embedded texture'
        image.pack()
lo, hi = bounds(objects)
report.update(min_godot=[lo.x, lo.z, -hi.y], max_godot=[hi.x, hi.z, -lo.y],
              root_transform=[list(row) for row in transform @ rotation], meshes=[inspect(o) for o in objects])
contact = [v.co for o in objects for v in o.data.vertices if abs(v.co.z) < .012]
report['soil_radius'] = [max(.009, min(.11, max(abs(v[i]) for v in contact))) for i in range(2)]
print('P2_STAGE_GEOMETRY ' + json.dumps(report), flush=True)
assert all(m['zero_area_faces'] == 0 and m['loose_vertices'] == 0 and m['uv_layers'] > 0 for m in report['meshes'])
report['triangles'] = sum(m['triangles'] for m in report['meshes'])
assert report['triangles'] == sum(m['triangles'] for m in report['source']), 'Full high geometry must survive'
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = objects[0]
output = folder / f'{crop}_{stage}.glb'
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
                         export_animations=False, export_yup=True, export_tangents=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(folder / f'{crop}_{stage}.blend'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(output))
imported = [o for o in bpy.context.scene.objects if o.type == 'MESH']
a, b = bounds(imported)
assert (a-lo).length < 1e-5 and (b-hi).length < 1e-5, 'Roundtrip bounds changed'
assert sum(inspect(o)['triangles'] for o in imported) == report['triangles']
report['textures'] = [list(im.size) for im in bpy.data.images if im.type == 'IMAGE']
assert report['textures'] and all(min(size) > 0 for size in report['textures'])
report['reimport_verified'] = True
report['runtime_path'] = f'Game/art/crops/{crop}/{crop}_{stage}.glb'
(folder / 'asset-audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
if '--install' in argv:
    shutil.copy2(output, REPO / report['runtime_path'])
print('P2_STAGE_READY ' + json.dumps(report), flush=True)
