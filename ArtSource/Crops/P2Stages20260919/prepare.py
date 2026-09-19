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
if config.get('remove_artifacts'):
    removed_triangles = 0
    for artifact in config['remove_artifacts']:
        removed_vertices = 0
        triangles = 0
        for obj in objects:
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            selected = {v for v in bm.verts if all(artifact['min'][i] <= v.co[i] <= artifact['max'][i] for i in range(3))}
            faces = {f for v in selected for f in v.link_faces}
            assert all(all(v in selected for v in f.verts) for f in faces), 'Artifact selection cuts a connected surface'
            removed_vertices += len(selected)
            triangles += sum(len(f.verts)-2 for f in faces)
            bmesh.ops.delete(bm, geom=list(selected), context='VERTS')
            bm.to_mesh(obj.data)
            bm.free()
        assert removed_vertices == artifact['vertices'] and triangles == artifact['triangles'], 'Reviewed artifact changed'
        removed_triangles += triangles
    report['removed_artifacts'] = config['remove_artifacts']
    report['removed_artifact_triangles'] = removed_triangles
if config.get('remove_degenerate_triangles', 0):
    removed = 0
    for obj in objects:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        degenerate = [f for f in bm.faces if len(f.verts) == 3 and f.calc_area() == 0.0]
        removed += len(degenerate)
        bmesh.ops.delete(bm, geom=degenerate, context='FACES_ONLY')
        bm.to_mesh(obj.data)
        bm.free()
    assert removed == config['remove_degenerate_triangles'], 'Reviewed degenerate face count changed'
    report['removed_degenerate_triangles'] = removed
if config.get('remove_loose_vertices', 0):
    removed = 0
    for obj in objects:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        loose = [v for v in bm.verts if not v.link_faces]
        removed += len(loose)
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
        bm.to_mesh(obj.data)
        bm.free()
    assert removed == config['remove_loose_vertices'], 'Source cleanup no longer matches reviewed defect'
    report['removed_loose_vertices'] = removed
if 'leaf_repose' in config:
    pose = config['leaf_repose']
    pivot = Vector(pose['pivot'])
    leaf_rotation = Euler(tuple(math.radians(v) for v in pose['rotation_degrees']), 'XYZ').to_matrix()
    selected_positions = set()
    for obj in objects:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
        remaining = set(bm.verts)
        # P2 stores the reviewed outer leaves and petioles as separate components.
        # Move each complete component rigidly; preserve its UVs and thin-leaf shape.
        while remaining:
            component = {remaining.pop()}
            pending = list(component)
            while pending:
                vertex = pending.pop()
                for edge in vertex.link_edges:
                    neighbour = edge.other_vert(vertex)
                    if neighbour in remaining:
                        remaining.remove(neighbour)
                        component.add(neighbour)
                        pending.append(neighbour)
            root_section = (min(v.co.x for v in component) > pose['root_min_x']
                            and min(v.co.y for v in component) > pose['root_min_y']
                            and max(v.co.y for v in component) < pose['root_max_y'])
            if (not root_section and max(v.co.x for v in component) < pose['max_x']
                    and min(v.co.z for v in component) < pose['min_z_below']
                    and max(v.co.z for v in component) < pose['max_z']):
                selected_positions.update(tuple(v.co) for v in component)
        bm.free()
        for vertex in obj.data.vertices:
            if tuple(vertex.co) in selected_positions:
                vertex.co = pivot + leaf_rotation @ (vertex.co - pivot)
        obj.data.update()
    report['reposed_leaf_positions'] = len(selected_positions)
    report['leaf_repose'] = pose
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
# Drooping outer leaves can cross the soil slice: use the reviewed root section,
# rather than letting those leaves shift the plant's anchor off its storage root.
if 'collar_center_xy' in config:
    center.x, center.y = config['collar_center_xy']
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
if 'soil_radius' in config:
    report['whole_mesh_soil_slice_radius'] = report['soil_radius']
    report['soil_radius'] = config['soil_radius']
print('P2_STAGE_GEOMETRY ' + json.dumps(report), flush=True)
assert all(m['zero_area_faces'] == 0 and m['loose_vertices'] == 0 and m['uv_layers'] > 0 for m in report['meshes'])
report['triangles'] = sum(m['triangles'] for m in report['meshes'])
assert report['triangles'] == sum(m['triangles'] for m in report['source']) - report.get('removed_degenerate_triangles', 0) - report.get('removed_artifact_triangles', 0), 'All unselected high geometry must survive'
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
