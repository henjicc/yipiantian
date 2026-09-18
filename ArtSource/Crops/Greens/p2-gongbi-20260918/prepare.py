"""Export the P2 gongbi sample without reducing the high-detail geometry.

Blender 5.2: --background --python-exit-code 1 --python <this file>
Raw FBX is immutable; the source retains native polygons and its embedded texture.
Only the low-detail working copy is simplified, then checked against the high tier.
"""
from pathlib import Path
import json
import bpy
import bmesh
from mathutils import Vector, Matrix
from math import radians

FOLDER = Path(__file__).resolve().parent
REPO = FOLDER.parents[3]
OUTPUT = REPO / 'Game/art/crops/greens'
WIDTH = .48
LOW_RATIO = .65  # Candidate checked in four views; not a universal performance budget.


def inspect(obj):
    obj.data.calc_loop_triangles()
    bpy.context.view_layer.update()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    stats = {
        'vertices': len(obj.data.vertices), 'faces': len(obj.data.polygons),
        'quads': sum(len(p.vertices) == 4 for p in obj.data.polygons),
        'triangles': len(obj.data.loop_triangles),
        'dimensions_godot_xyz': [obj.dimensions.x, obj.dimensions.z, obj.dimensions.y],
        'materials': len(obj.data.materials), 'uv_layers': len(obj.data.uv_layers),
        'boundary_edges': sum(e.is_boundary for e in bm.edges),
        'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
        'loose_vertices': sum(not v.link_faces for v in bm.verts),
        'zero_area_faces': sum(f.calc_area() < 1e-12 for f in bm.faces),
    }
    bm.free()
    return stats


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(FOLDER / 'raw/model.fbx'), use_image_search=False)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(meshes) == 1, 'Changed input structure requires inspection'
high = meshes[0]
bpy.context.view_layer.objects.active = high
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
report = {'source': 'raw/model.fbx', 'blender': bpy.app.version_string,
          'source_topology': inspect(high), 'meshes': {}}
points = [v.co.copy() for v in high.data.vertices]
lo = Vector([min(p[i] for p in points) for i in range(3)])
hi = Vector([max(p[i] for p in points) for i in range(3)])
# FBX import is Blender Z-up. The neutral four-view renders verify the root is down.
factor = WIDTH / max((hi - lo).x, (hi - lo).y)
pivot = Vector(((lo.x + hi.x)/2, (lo.y + hi.y)/2, lo.z))
for v in high.data.vertices:
    v.co = (v.co - pivot) * factor
# Authoring correction: dominant upright leaf axis leaned left by about 21 degrees.
# Bake the rigid correction into every reusable tier, never into gameplay placement.
rotation = Matrix.Rotation(radians(21.0), 4, 'Y')
root = Vector((-.02827, -.00473, 0.0))
transform = rotation @ Matrix.Translation(-root)
corrected = [transform @ v.co for v in high.data.vertices]
transform = Matrix.Translation(Vector((0,0,-min(p.z for p in corrected)))) @ transform
high.data.transform(transform)
(FOLDER / 'upright-transform.json').write_text(json.dumps({'blender_matrix':[list(row) for row in transform], 'rotation_y_degrees':21.0, 'reason':'Align dominant leaf axis; restore root to ground, preserve natural leaf spread'},indent=2),encoding='utf-8')
report['upright_rotation_y_degrees'] = 21.0
high.name = 'greens_mature'
for face in high.data.polygons:
    face.use_smooth = True
for material in high.data.materials:
    material.use_backface_culling = False
    for node in material.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            node.inputs['Roughness'].default_value = .97
            node.inputs['Metallic'].default_value = 0
            node.inputs['Specular IOR Level'].default_value = .08
for image in bpy.data.images:
    if image.type == 'IMAGE':
        assert min(image.size) > 0
        image.pack()  # Keep the service's native texture resolution and brushwork.

editable = high.copy()
editable.data = high.data.copy()
editable.name = 'greens_editable_quad'
bpy.context.collection.objects.link(editable)
editable.hide_render = True
editable.hide_set(True)

low = high.copy()
low.data = high.data.copy()
low.name = 'greens_mature_low'
bpy.context.collection.objects.link(low)
# Only weld geometrically coincident seams in the low working copy, not the source.
bm = bmesh.new()
bm.from_mesh(low.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
bm.to_mesh(low.data)
bm.free()
bpy.context.view_layer.objects.active = low
modifier = low.modifiers.new('Screen-size candidate', 'DECIMATE')
modifier.ratio = LOW_RATIO
bpy.ops.object.modifier_apply(modifier=modifier.name)

OUTPUT.mkdir(parents=True, exist_ok=True)
for obj in [high, low]:
    stats = inspect(obj)
    assert stats['zero_area_faces'] == 0 and stats['loose_vertices'] == 0
    report['meshes'][obj.name] = stats
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (obj.name + '.glb')),
                             export_format='GLB', use_selection=True)
assert report['meshes']['greens_mature']['triangles'] == report['source_topology']['triangles']
low.hide_render = True
low.hide_set(True)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(FOLDER / 'greens_gongbi.blend'))
for name, stats in report['meshes'].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUTPUT / (name + '.glb')))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert sum(inspect(o)['triangles'] for o in objects) == stats['triangles']
    stats['textures'] = [{'size': list(im.size)} for im in bpy.data.images if im.type == 'IMAGE']
    assert stats['textures'] and all(min(t['size']) > 0 for t in stats['textures'])
    stats['reimport_verified'] = True
report['high_detail_policy'] = 'Full generated geometry; no decimation or extra Godot LOD'
report['wind'] = 'Existing root-anchored bounds wind; no invented per-leaf segmentation'
(FOLDER / 'asset-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('GREENS_GONGBI_READY ' + json.dumps(report))
