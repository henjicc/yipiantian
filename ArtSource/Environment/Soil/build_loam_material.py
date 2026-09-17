"""Blender 5.2: bake one periodic procedural soil source into aligned game maps.

No generated image is edited. The imagegen reference guides this native material.
Run: blender --background --factory-startup --python this_file
"""
from pathlib import Path
import json
import bpy

SOURCE = Path(__file__).resolve().parent / "20260917-granular"
OUT = SOURCE / "maps"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for unused in list(bpy.data.materials):
    bpy.data.materials.remove(unused)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 1
scene.render.bake.margin = 0
scene.view_settings.view_transform = 'Standard'
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGB'
scene.render.image_settings.color_depth = '8'
bpy.ops.mesh.primitive_plane_add(size=.64)
plane = bpy.context.object
plane.name = 'Loam_Periodic_Source_64cm'
mat = bpy.data.materials.new('Loam_SameSource')
mat.use_nodes = True
plane.data.materials.append(mat)
n, links = mat.node_tree.nodes, mat.node_tree.links
n.clear()

def node(kind, name):
    x = n.new(kind)
    x.label = name
    return x

def math(op, a, b=None):
    x = node('ShaderNodeMath', op)
    x.operation = op
    for index, val in enumerate([a, b]):
        if val is None:
            continue
        if isinstance(val, (float, int)):
            x.inputs[index].default_value = val
        else:
            links.new(val, x.inputs[index])
    return x.outputs[0]

uv = node('ShaderNodeTexCoord', 'UV')
split = node('ShaderNodeSeparateXYZ', 'UV components')
links.new(uv.outputs['UV'], split.inputs[0])
u = math('MULTIPLY', split.outputs['X'], 6.28318530718)
v = math('MULTIPLY', split.outputs['Y'], 6.28318530718)
torus = node('ShaderNodeCombineXYZ', 'Periodic 4D torus XYZ')
for socket, value in zip(torus.inputs, [math('COSINE', u), math('SINE', u), math('COSINE', v)]):
    links.new(value, socket)
w = math('SINE', v)

def noise(scale, detail):
    x = node('ShaderNodeTexNoise', 'Periodic grain noise')
    x.noise_dimensions = '4D'
    x.inputs['Scale'].default_value = scale
    x.inputs['Detail'].default_value = detail
    x.inputs['Roughness'].default_value = .7
    links.new(torus.outputs[0], x.inputs['Vector'])
    links.new(w, x.inputs['W'])
    return x.outputs['Fac']

vor = node('ShaderNodeTexVoronoi', 'Angular soil aggregate')
vor.voronoi_dimensions = '4D'
vor.feature = 'F1'
vor.distance = 'CHEBYCHEV'
vor.inputs['Scale'].default_value = 7.5
links.new(torus.outputs[0], vor.inputs['Vector'])
links.new(w, vor.inputs['W'])
aggregate = math('POWER', math('MAXIMUM', math('SUBTRACT', 1.0, math('MULTIPLY', vor.outputs['Distance'], 1.35)), .0), 1.8)
fine = noise(55, 2.0)
medium = noise(19, 2.5)
macro = noise(1.4, 2.0)
height = math('ADD', math('MULTIPLY', aggregate, .67), math('ADD', math('MULTIPLY', medium, .23), math('MULTIPLY', fine, .10)))
roughness = math('ADD', .86, math('MULTIPLY', fine, .12))
cavity = math('ADD', .48, math('MULTIPLY', height, .52))
pigment = math('ADD', .46, math('ADD', math('MULTIPLY', macro, .25), math('ADD', math('MULTIPLY', medium, .30), math('MULTIPLY', aggregate, .60))))
color = node('ShaderNodeMixRGB', 'Unlit umber pigment')
color.blend_type = 'MULTIPLY'
color.inputs[0].default_value = 1
color.inputs[1].default_value = (.112, .071, .039, 1)
links.new(pigment, color.inputs[2])
bump = node('ShaderNodeBump', 'Physical 6mm detail over 64cm tile')
bump.inputs['Strength'].default_value = 1
bump.inputs['Distance'].default_value = .006
links.new(height, bump.inputs['Height'])
bsdf = node('ShaderNodeBsdfPrincipled', 'Soil preview')
links.new(color.outputs[0], bsdf.inputs['Base Color'])
links.new(roughness, bsdf.inputs['Roughness'])
links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
out = node('ShaderNodeOutputMaterial', 'Output')
emit = node('ShaderNodeEmission', 'Bake unlit data')
packed = node('ShaderNodeCombineColor', 'R cavity G roughness B height')
for value, socket in zip([cavity, roughness, height], list(packed.inputs)[:3]):
    links.new(value, socket)
target = node('ShaderNodeTexImage', 'Bake target')
for index, x in enumerate(n):
    x.location = (index % 8 * 240, -(index // 8) * 220)

def bake(name, source=None, normal=False):
    image = bpy.data.images.new(name, width=2048, height=2048, alpha=False)
    image.colorspace_settings.name = 'sRGB' if name == 'loam_albedo' else 'Non-Color'
    target.image = image
    n.active = target
    if normal:
        links.new(bsdf.outputs[0], out.inputs['Surface'])
        bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', normal_r='POS_X', normal_g='POS_Y', normal_b='POS_Z')
    else:
        links.new(source, emit.inputs['Color'])
        links.new(emit.outputs[0], out.inputs['Surface'])
        bpy.ops.object.bake(type='EMIT')
    image.filepath_raw = str(OUT / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    image.filepath = '//maps/' + name + '.png'
    return image

bake('loam_albedo', color.outputs[0])
bake('loam_normal', normal=True)
bake('loam_surface', packed.outputs[0])
links.new(bsdf.outputs[0], out.inputs['Surface'])
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'loam-material.blend'))
(SOURCE / 'material.json').write_text(json.dumps({
    'blender': bpy.app.version_string, 'tile_metres': .64,
    'resolution': [2048,2048], 'normal_convention': 'OpenGL +Y tangent',
    'height_amplitude_metres': .006,
    'surface_channels': {'R': 'authored cavity, not raytraced AO', 'G': 'roughness', 'B': 'height'},
    'source': 'one periodic 4D procedural Blender material; no albedo-to-height conversion',
    'physics': False,
}, ensure_ascii=False, indent=2), encoding='utf-8')
print('LOAM_MATERIAL_COMPLETE')
