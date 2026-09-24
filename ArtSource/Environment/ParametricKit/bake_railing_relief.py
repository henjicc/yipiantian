"""Bake the existing wood material's shallow relief with Cycles, in atlas UVs.

The colour atlas remains immutable. This is a material bake, not a replacement
painting: broad colour changes stay shallow; stretched noise adds fine fibres.
"""
import bpy


def bake_relief(wood, output):
    authored = wood.copy()
    authored.name = 'WeatheredTimberReliefSource'
    authored.use_fake_user = True
    nodes, links = authored.node_tree.nodes, authored.node_tree.links
    shader = nodes.get('Principled BSDF')
    colour = next(node for node in nodes if node.type == 'TEX_IMAGE')
    uv = nodes.new('ShaderNodeTexCoord')
    links.new(uv.outputs['UV'], colour.inputs['Vector'])
    grey = nodes.new('ShaderNodeRGBToBW')
    links.new(colour.outputs['Color'], grey.inputs[0])
    # The selected atlas patch spans 0.82m along / 0.17m across the wood.
    scale = nodes.new('ShaderNodeVectorMath'); scale.operation = 'MULTIPLY'
    scale.inputs[1].default_value = (18, 780, 1)
    links.new(uv.outputs['UV'], scale.inputs[0])
    fibres = nodes.new('ShaderNodeTexNoise')
    fibres.inputs['Scale'].default_value = 1
    fibres.inputs['Detail'].default_value = 2
    fibres.inputs['Roughness'].default_value = .65
    links.new(scale.outputs['Vector'], fibres.inputs['Vector'])
    fine = nodes.new('ShaderNodeBump')
    fine.inputs['Distance'].default_value = .0012
    fine.inputs['Strength'].default_value = .35
    links.new(fibres.outputs['Fac'], fine.inputs['Height'])
    grain = nodes.new('ShaderNodeBump')
    grain.inputs['Distance'].default_value = .014
    grain.inputs['Strength'].default_value = .8
    links.new(grey.outputs[0], grain.inputs['Height'])
    links.new(fine.outputs['Normal'], grain.inputs['Normal'])
    links.new(grain.outputs['Normal'], shader.inputs['Normal'])
    roughness = nodes.new('ShaderNodeMapRange')
    roughness.inputs['From Min'].default_value = .05
    roughness.inputs['From Max'].default_value = .55
    roughness.inputs['To Min'].default_value = .96
    roughness.inputs['To Max'].default_value = .78
    links.new(grey.outputs[0], roughness.inputs['Value'])
    links.new(roughness.outputs[0], shader.inputs['Roughness'])

    bpy.ops.mesh.primitive_plane_add(size=1)
    plane = bpy.context.object
    plane.name = 'AtlasMaterialBakeSurface'
    plane.dimensions = (.82/.146, .17/.118, 0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    plane.data.materials.append(authored)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 8
    scene.render.bake.margin = 4
    scene.render.bake.normal_space = 'TANGENT'
    target = nodes.new('ShaderNodeTexImage')
    material_output = nodes.get('Material Output')
    emission = nodes.new('ShaderNodeEmission')
    packed = nodes.new('ShaderNodeCombineColor')
    packed.inputs['Red'].default_value = 1
    packed.inputs['Blue'].default_value = 0
    links.new(roughness.outputs[0], packed.inputs['Green'])
    links.new(packed.outputs[0], emission.inputs['Color'])
    images = {}
    for name, size, mode in [('fence_wood_normal', 2048, 'NORMAL'), ('fence_wood_orm', 1024, 'EMIT')]:
        image = bpy.data.images.new(name, width=size, height=size, alpha=False)
        image.colorspace_settings.name = 'Non-Color'
        target.image = image
        nodes.active = target
        if mode == 'EMIT': links.new(emission.outputs[0], material_output.inputs['Surface'])
        bpy.ops.object.bake(type=mode)
        image.filepath_raw = str(output/(name+'.png'))
        image.file_format = 'PNG'
        image.save()
        images[name] = image
    links.new(shader.outputs[0], material_output.inputs['Surface'])
    nodes.remove(target)
    bpy.data.objects.remove(plane, do_unlink=True)

    nodes, links = wood.node_tree.nodes, wood.node_tree.links
    shader = nodes.get('Principled BSDF')
    normal_texture = nodes.new('ShaderNodeTexImage')
    normal_texture.image = images['fence_wood_normal']
    normal = nodes.new('ShaderNodeNormalMap')
    normal.inputs['Strength'].default_value = 1.4
    links.new(normal_texture.outputs['Color'], normal.inputs['Color'])
    links.new(normal.outputs['Normal'], shader.inputs['Normal'])
    orm = nodes.new('ShaderNodeTexImage'); orm.image = images['fence_wood_orm']
    channels = nodes.new('ShaderNodeSeparateColor')
    links.new(orm.outputs['Color'], channels.inputs['Color'])
    links.new(channels.outputs['Green'], shader.inputs['Roughness'])
    links.new(channels.outputs['Blue'], shader.inputs['Metallic'])
    return images
