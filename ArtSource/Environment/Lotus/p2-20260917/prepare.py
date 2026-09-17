"""Prepare the adopted P2 lotus; preserve raw FBX/quads, export explicit two-tier GLB.

Run with Blender 5.2 from any directory. Replaces this version's prepared source,
audit and the two formal runtime GLBs, never the legacy source or raw generation.
"""
from pathlib import Path
import json
import bpy
import bmesh
from mathutils import Vector

folder = Path(__file__).resolve().parent
repo = folder.parents[3]
output = repo / 'Game/art/environment/lotus'


def clean(obj):
    obj.data.validate(clean_customdata=False)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate(clean_customdata=False)
    for face in obj.data.polygons:
        face.use_smooth = True
    obj.data.normals_split_custom_set([(0, 0, 0)] * len(obj.data.loops))


def inspect(obj):
    obj.data.calc_loop_triangles()
    bpy.context.view_layer.update()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    report = {
        'vertices': len(obj.data.vertices), 'faces': len(obj.data.polygons),
        'quads': sum(len(p.vertices) == 4 for p in obj.data.polygons),
        'triangles': len(obj.data.loop_triangles),
        'dimensions_godot_xyz': [obj.dimensions.x, obj.dimensions.z, obj.dimensions.y],
        'materials': len(obj.data.materials), 'uv_layers': len(obj.data.uv_layers),
        'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
        'loose_vertices': sum(not v.link_edges for v in bm.verts),
        'zero_area_faces': sum(f.calc_area() < 1e-12 for f in bm.faces),
    }
    bm.free()
    return report


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(folder / 'raw/model.fbx'), use_image_search=False)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(meshes) == 1, 'Reinspect a changed generation before preparing it'
high = meshes[0]
bpy.context.view_layer.objects.active = high
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
report = {'source': 'raw/model.fbx', 'blender': bpy.app.version_string,
          'source_topology': inspect(high), 'meshes': {}}
points = [v.co.copy() for v in high.data.vertices]
lo = Vector([min(p[i] for p in points) for i in range(3)])
hi = Vector([max(p[i] for p in points) for i in range(3)])
factor = .9 / max((hi - lo).x, (hi - lo).y)
pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for vertex in high.data.vertices:
    p = (vertex.co - pivot) * factor
    vertex.co = Vector((p.y, -p.x, p.z))
high.name = 'lotus_high'
quad = high.copy()
quad.data = high.data.copy()
quad.name = 'lotus_editable_quad'
bpy.context.collection.objects.link(quad)
quad.hide_render = True
quad.hide_set(True)
clean(high)
for material in high.data.materials:
    for node in material.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            node.inputs['Roughness'].default_value = .97
            node.inputs['Metallic'].default_value = 0
            node.inputs['Specular IOR Level'].default_value = .08
for image in bpy.data.images:
    if image.type == 'IMAGE':
        assert min(image.size) > 0, 'Missing embedded FBX texture'
        if max(image.size) > 2048:
            image.scale(2048, 2048)
        image.pack()
low = high.copy()
low.data = high.data.copy()
low.name = 'lotus_low'
bpy.context.collection.objects.link(low)
bpy.context.view_layer.objects.active = low
low.hide_set(False)
high.data.calc_loop_triangles()
decimate = low.modifiers.new('Verified distant silhouette', 'DECIMATE')
decimate.ratio = 3500 / len(high.data.loop_triangles)
bpy.ops.object.modifier_apply(modifier=decimate.name)
clean(low)
output.mkdir(parents=True, exist_ok=True)
for obj in [high, low]:
    report['meshes'][obj.name] = inspect(obj)
    assert report['meshes'][obj.name]['zero_area_faces'] == 0
    assert report['meshes'][obj.name]['loose_vertices'] == 0
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(output / (obj.name + '.glb')),
                              export_format='GLB', use_selection=True)
low.hide_set(True)
low.hide_render = True
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(folder / 'lotus.blend'))
for name, stats in report['meshes'].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(output / (name + '.glb')))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for obj in meshes:
        obj.data.calc_loop_triangles()
    assert sum(len(o.data.loop_triangles) for o in meshes) == stats['triangles']
    stats['textures'] = [{'name': im.name, 'size': list(im.size)}
                         for im in bpy.data.images if im.type == 'IMAGE']
    assert stats['textures'] and all(min(im['size']) > 0 for im in stats['textures'])
    stats['reimport_verified'] = True
report['godot_import'] = 'Disable automatic mesh LOD on both GLBs; use authored high/low only.'
(folder / 'asset-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('LOTUS_READY', json.dumps(report))
