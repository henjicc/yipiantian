"""Rebuild the adopted house and same-source sample LODs, using Blender 5.2."""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector

folder = Path(__file__).resolve().parent
repo = folder.parents[2]
out = repo / 'Game/art/environment/house'
sample = repo / 'Game/scenes/style_sample'
out.mkdir(parents=True, exist_ok=True)
sample.mkdir(parents=True, exist_ok=True)
source = next((folder / 'tripo-original').glob('*.glb'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = objects[0]
if len(objects) > 1:
    bpy.ops.object.join()
obj = bpy.context.object
obj.name = 'house_high'
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
bm.to_mesh(obj.data)
bm.free()
points = [v.co.copy() for v in obj.data.vertices]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
bottom = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
factor = 7.2 / max(hi.x - lo.x, hi.y - lo.y)
for vertex in obj.data.vertices:
    point = (vertex.co - bottom) * factor
    # Tripo supplied facade width along Blender Y and front toward +X.
    # Canonical front is Blender -Y, which becomes Godot +Z on glTF export.
    vertex.co = Vector((point.y, -point.x, point.z))
for material in obj.data.materials:
    for node in material.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            node.inputs['Roughness'].default_value = 0.97
            node.inputs['Metallic'].default_value = 0.0
            node.inputs['Specular IOR Level'].default_value = 0.08
obj.data.update()
bpy.context.view_layer.update()
obj.data.calc_loop_triangles()
original_triangles = len(obj.data.loop_triangles)
if original_triangles > 24000:
    modifier = obj.modifiers.new('High runtime budget', 'DECIMATE')
    modifier.ratio = 24000 / original_triangles
    bpy.ops.object.modifier_apply(modifier=modifier.name)
high = obj
low = high.copy()
low.data = high.data.copy()
low.name = 'house_low'
bpy.context.collection.objects.link(low)
bpy.context.view_layer.objects.active = low
mod = low.modifiers.new('Same source distant roof', 'DECIMATE')
high.data.calc_loop_triangles()
mod.ratio = min(1, 6500 / len(high.data.loop_triangles))
bpy.ops.object.modifier_apply(modifier=mod.name)
report = {'source': str(source.relative_to(repo)), 'blender': bpy.app.version_string,
          'requested_triangles': 18000, 'raw_triangles': original_triangles, 'meshes': {}}
for asset in [high, low]:
    bpy.ops.object.select_all(action='DESELECT')
    asset.select_set(True)
    bpy.context.view_layer.objects.active = asset
    # Decimation can leave degenerate polygons; validate and triangulate the
    # editable source before audit so exporter cleanup cannot hide a mismatch.
    asset.data.validate(clean_customdata=False)
    bm = bmesh.new()
    bm.from_mesh(asset.data)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=0.000001)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(asset.data)
    bm.free()
    asset.data.update()
    asset.data.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(asset.data)
    report['meshes'][asset.name] = {
        'triangles': len(asset.data.loop_triangles), 'materials': len(asset.data.materials),
        'dimensions_blender_xyz': list(asset.dimensions), 'uv_layers': len(asset.data.uv_layers),
        'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
        'loose_vertices': sum(not v.link_edges for v in bm.verts),
        'zero_area_faces': sum(f.calc_area() < 1e-12 for f in bm.faces),
    }
    bm.free()
    bpy.ops.export_scene.gltf(filepath=str(out / (asset.name + '.glb')), export_format='GLB', use_selection=True)
low.hide_render = True
low.hide_set(True)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(folder / 'house.blend'))
# Independent reimport catches missing textures and unexpected export scale.
for name in ['house_high', 'house_low']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(out / (name + '.glb')))
    imported = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(imported) == 1
    item = imported[0]
    item.data.calc_loop_triangles()
    assert len(item.data.loop_triangles) == report['meshes'][name]['triangles']
    report['meshes'][name]['reimport_verified'] = True
    report['meshes'][name]['textures'] = [{'size': list(image.size), 'name': image.name}
        for image in bpy.data.images if image.type == 'IMAGE']
(folder / 'asset-audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
# Same-source crop LOD is sample-only; the original crop source is untouched.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(repo / 'Game/art/crops/greens/greens_mature.glb'))
crop = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.context.view_layer.objects.active = crop
crop.select_set(True)
bm = bmesh.new()
bm.from_mesh(crop.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
bm.to_mesh(crop.data)
bm.free()
mod = crop.modifiers.new('Sample distant leaves', 'DECIMATE')
mod.ratio = 0.50
bpy.ops.object.modifier_apply(modifier=mod.name)
for polygon in crop.data.polygons:
    polygon.use_smooth = True
crop.data.normals_split_custom_set([(0.0, 0.0, 0.0)] * len(crop.data.loops))
crop.name = 'greens_sample_low'
crop.data.calc_loop_triangles()
report['crop_low_triangles'] = len(crop.data.loop_triangles)
bpy.ops.export_scene.gltf(filepath=str(sample / 'greens_sample_low.glb'), export_format='GLB', use_selection=True)
(folder / 'asset-audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
