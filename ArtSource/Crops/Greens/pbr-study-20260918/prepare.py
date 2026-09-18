"""Audit Tripo retexture geometry/maps and export the isolated Godot candidate."""
from pathlib import Path
import json
import bpy
from mathutils.kdtree import KDTree
from mathutils import Vector, Matrix

folder = Path(__file__).resolve().parent
repo = folder.parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / 'raw/input.glb'))
original = [o for o in bpy.context.scene.objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in original for v in o.data.vertices]
original_min = Vector([min(p[i] for p in points) for i in range(3)])
original_max = Vector([max(p[i] for p in points) for i in range(3)])
tree = KDTree(len(points))
for index, point in enumerate(points): tree.insert(point, index)
tree.balance()
uv_by_position = {}
for obj in original:
    for loop in obj.data.loops:
        p = obj.matrix_world @ obj.data.vertices[loop.vertex_index].co
        key = tuple(round(c,5) for c in p)
        uv_by_position.setdefault(key,[]).append(obj.data.uv_layers.active.data[loop.index].uv.copy())
triangles = sum(len(o.data.polygons) for o in original)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / 'raw/model.glb'))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
candidate_points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
candidate_min = Vector([min(p[i] for p in candidate_points) for i in range(3)])
candidate_max = Vector([max(p[i] for p in candidate_points) for i in range(3)])
print('BOUNDS',list(original_min),list(original_max),list(candidate_min),list(candidate_max))
factor = (original_max-original_min).length / (candidate_max-candidate_min).length
original_center = (original_min+original_max)*.5
candidate_center = (candidate_min+candidate_max)*.5
for obj in objects:
    matrix = obj.matrix_world.copy()
    for vertex in obj.data.vertices:
        vertex.co = (matrix @ vertex.co - candidate_center)*factor+original_center
    obj.matrix_world.identity()
candidate_points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
error = max(tree.find(p)[2] for p in candidate_points)
candidate_triangles = sum(len(o.data.polygons) for o in objects)
assert error < 1e-5, f'Retexture changed position or scale: {error}'
assert triangles == candidate_triangles, 'Retexture changed triangle count'
uv_error = 0.0
for obj in objects:
    for loop in obj.data.loops:
        p = obj.matrix_world @ obj.data.vertices[loop.vertex_index].co
        key = tuple(round(c,5) for c in p)
        if key not in uv_by_position:
            key = tuple(round(c,5) for c in tree.find(p)[0])
        uv = obj.data.uv_layers.active.data[loop.index].uv
        uv_error = max(uv_error,min((uv-old).length for old in uv_by_position[key]))
materials = []
for material in bpy.data.materials:
    if not material.use_nodes: continue
    bsdf = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    materials.append({'name':material.name,'normal_linked':bsdf.inputs['Normal'].is_linked,
                      'roughness_linked':bsdf.inputs['Roughness'].is_linked,
                      'images':[{'name':n.image.name,'size':list(n.image.size)} for n in material.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]})
assert materials and all(m['normal_linked'] and m['roughness_linked'] for m in materials), 'Expected PBR maps missing'
upright = json.loads((folder.parent / 'p2-gongbi-20260918/upright-transform.json').read_text(encoding='utf-8'))
transform = Matrix(upright['blender_matrix'])
for obj in objects:
    obj.data.transform(transform)
report = {'blender':bpy.app.version_string,'original_triangles':triangles,
          'upright_rotation_y_degrees':upright['rotation_y_degrees'],
          'restored_uniform_scale':factor,
          'max_uv_distance':uv_error,
          'candidate_triangles':candidate_triangles,'max_vertex_distance_m':error,'materials':materials}
(folder / 'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(folder / 'greens_pbr.blend'))
output = repo / 'Game/development/greens_pbr'
output.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output / 'greens_pbr.glb'),export_format='GLB',export_animations=False,export_yup=True)
print('PBR_AUDIT',json.dumps(report))
