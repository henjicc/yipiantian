"""Prepare the adopted P2 greens (mature); preserve raw FBX/quads, export two-tier GLB.

Run with Blender 5.2 from any directory. Replaces this version's prepared source,
audit and the two formal runtime GLBs, never the legacy source or raw generation.

Wind weights live in the COLOR_0 vertex attribute: r = bend mask (0 at root),
g = leaf flutter strength (green, upper leaf blade), b = per-leaf phase variation.
The game shader reads them only when plant_wind marks the instance as authored.
"""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector

folder = Path(__file__).resolve().parent
repo = folder.parents[3]
output = repo / 'Game/art/crops/greens'

TARGET_WIDTH = 0.48       # metres, max horizontal span, matches the legacy greens
HIGH_TRIANGLES = 3400     # crop_assets_test budget is 3600 per stage tier
LOW_TRIANGLES = 1400


def smoothstep(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


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
        'color_attributes': len(obj.data.color_attributes),
        'non_manifold_edges': sum(not e.is_manifold for e in bm.edges),
        'loose_vertices': sum(not v.link_edges for v in bm.verts),
        'zero_area_faces': sum(f.calc_area() < 1e-12 for f in bm.faces),
    }
    bm.free()
    return report


def vertex_uvs(me):
    """Average loop UV per vertex."""
    acc = [(0.0, 0.0, 0)] * len(me.vertices)
    acc = [[0.0, 0.0, 0] for _ in range(len(me.vertices))]
    uv = me.uv_layers.active.data
    for loop in me.loops:
        entry = acc[loop.vertex_index]
        entry[0] += uv[loop.index].uv.x
        entry[1] += uv[loop.index].uv.y
        entry[2] += 1
    return [(e[0] / e[2], e[1] / e[2]) if e[2] else (0.5, 0.5) for e in acc]


def greenness_sampler(image):
    w, h = image.size
    px = list(image.pixels)

    def sample(u, v):
        x = min(w - 1, max(0, int(u * w)))
        y = min(h - 1, max(0, int(v * h)))
        i = (y * w + x) * 4
        r, g, b = px[i], px[i + 1], px[i + 2]
        return smoothstep(1.02, 1.13, g / max(r, 1e-3)) * smoothstep(1.02, 1.10, g / max(b, 1e-3))

    return sample


def paint_wind_colors(obj, image):
    me = obj.data
    bottom = min(v.co.z for v in me.vertices)
    top = max(v.co.z for v in me.vertices)
    height = max(top - bottom, 1e-6)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    max_radius = max(math.hypot(v.co.x - cx, v.co.y - cy) for v in me.vertices) or 1.0
    uvs = vertex_uvs(me)
    sample = greenness_sampler(image)
    attr = me.color_attributes.get('Color')
    if attr is None:
        attr = me.color_attributes.new('Color', 'FLOAT_COLOR', 'POINT')
    for v in me.vertices:
        rel_h = (v.co.z - bottom) / height
        radial = math.hypot(v.co.x - cx, v.co.y - cy) / max_radius
        bend = smoothstep(0.10, 0.80, rel_h)
        flutter = sample(*uvs[v.index]) * smoothstep(0.30, 1.0, rel_h)
        phase = (math.atan2(v.co.y - cy, v.co.x - cx) * 1.37 + rel_h * 0.61 + radial * 2.13) % 1.0
        attr.data[v.index].color = (bend, flutter, phase, 1.0)


def decimate_to(obj, target_triangles):
    obj.data.calc_loop_triangles()
    current = len(obj.data.loop_triangles)
    if current <= target_triangles:
        return
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('Verified silhouette budget', 'DECIMATE')
    mod.ratio = target_triangles / current
    bpy.ops.object.modifier_apply(modifier=mod.name)
    clean(obj)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(folder / 'raw/model.fbx'), use_image_search=False)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(meshes) == 1, 'Reinspect a changed generation before preparing it'
high = meshes[0]
bpy.context.view_layer.objects.active = high
high.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
report = {'source': 'raw/model.fbx', 'blender': bpy.app.version_string,
          'source_topology': inspect(high), 'meshes': {}}

# Scale the texture first; the wind painter samples it per vertex.
for image in bpy.data.images:
    if image.type == 'IMAGE':
        assert min(image.size) > 0, 'Missing embedded FBX texture'
        if max(image.size) > 2048:
            image.scale(2048, 2048)
        image.pack()
base_image = next(im for im in bpy.data.images if im.type == 'IMAGE')

# Determine the up axis from the texture: pale petiole sits at the root,
# green blades at the top. The generation is near-cubic, so bbox alone cannot tell.
uvs = vertex_uvs(high.data)
sample = greenness_sampler(base_image)
best_axis, best_score, green_at_max = -1, -1.0, True
points = [v.co.copy() for v in high.data.vertices]
for axis in range(3):
    values = sorted(p[axis] for p in points)
    median = values[len(values) // 2]
    low_g = [sample(*uvs[v.index]) for v in high.data.vertices if v.co[axis] <= median]
    high_g = [sample(*uvs[v.index]) for v in high.data.vertices if v.co[axis] > median]
    score = abs(sum(high_g) / len(high_g) - sum(low_g) / len(low_g))
    if score > best_score:
        best_score = score
        best_axis = axis
        green_at_max = sum(high_g) / len(high_g) >= sum(low_g) / len(low_g)
assert best_score > 0.05, 'Cannot tell root from crown by texture; inspect manually'

# Rotate so the detected up axis becomes Blender +Z with the pale root at the bottom.
for v in high.data.vertices:
    p = v.co.copy()
    up = p[best_axis] if green_at_max else -p[best_axis]
    if best_axis == 0:
        v.co = Vector((p.y, p.z, up))
    elif best_axis == 1:
        v.co = Vector((p.x, p.z, up))
    else:
        v.co = Vector((p.x, p.y, up))

points = [v.co.copy() for v in high.data.vertices]
lo = Vector([min(p[i] for p in points) for i in range(3)])
hi = Vector([max(p[i] for p in points) for i in range(3)])
factor = TARGET_WIDTH / max((hi - lo).x, (hi - lo).y)
pivot = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
for v in high.data.vertices:
    v.co = (v.co - pivot) * factor
report['up_axis_detected'] = {'axis': best_axis, 'green_at_max': green_at_max,
                              'greenness_gradient': round(best_score, 4)}

high.name = 'greens_mature'
quad = high.copy()
quad.data = high.data.copy()
quad.name = 'greens_editable_quad'
bpy.context.collection.objects.link(quad)
quad.hide_render = True
quad.hide_set(True)

clean(high)
for material in high.data.materials:
    for node in material.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            node.inputs['Roughness'].default_value = .93
            node.inputs['Metallic'].default_value = 0
            node.inputs['Specular IOR Level'].default_value = .12

decimate_to(high, HIGH_TRIANGLES)
low = high.copy()
low.data = high.data.copy()
low.name = 'greens_mature_low'
bpy.context.collection.objects.link(low)
bpy.context.view_layer.objects.active = low
decimate_to(low, LOW_TRIANGLES)

for obj in [high, low]:
    paint_wind_colors(obj, base_image)

output.mkdir(parents=True, exist_ok=True)
for obj in [high, low]:
    report['meshes'][obj.name] = inspect(obj)
    stats = report['meshes'][obj.name]
    assert stats['zero_area_faces'] == 0
    assert stats['loose_vertices'] == 0
    assert stats['color_attributes'] == 1
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(output / (obj.name + '.glb')),
                              export_format='GLB', use_selection=True,
                              export_vertex_color='ACTIVE')
low.hide_set(True)
low.hide_render = True
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(folder / 'greens_p2.blend'))
for name, stats in report['meshes'].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(output / (name + '.glb')))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for obj in meshes:
        obj.data.calc_loop_triangles()
    assert sum(len(o.data.loop_triangles) for o in meshes) == stats['triangles']
    assert any(len(o.data.color_attributes) for o in meshes), 'COLOR_0 lost on export: ' + name
    stats['textures'] = [{'name': im.name, 'size': list(im.size)}
                         for im in bpy.data.images if im.type == 'IMAGE']
    assert stats['textures'] and all(min(im['size']) > 0 for im in stats['textures'])
    stats['reimport_verified'] = True
report['godot_import'] = 'Disable automatic mesh LOD on both GLBs; use authored high/low only.'
(folder / 'asset-audit.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('GREENS_READY ' + json.dumps(report, ensure_ascii=False))
