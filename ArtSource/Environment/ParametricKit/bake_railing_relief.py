"""Bake the existing wood material's shallow relief with Cycles, in atlas UVs.

The colour atlas remains immutable. This is a material bake, not a replacement
painting: only softly filtered, shallow wood grain contributes relief.
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
    # Prefilter height in the offline material bake. Tiny albedo/JPEG marks
    # must not become steep normals; these nine samples add no runtime cost.
    height = None
    for x, wx in [(-1, .25), (0, .5), (1, .25)]:
        for y, wy in [(-1, .25), (0, .5), (1, .25)]:
            offset = nodes.new('ShaderNodeVectorMath'); offset.operation = 'ADD'
            offset.inputs[1].default_value = (x/1024, y/1024, 0)
            links.new(uv.outputs['UV'], offset.inputs[0])
            sample = nodes.new('ShaderNodeTexImage'); sample.image = colour.image
            sample.interpolation = 'Cubic'
            links.new(offset.outputs['Vector'], sample.inputs['Vector'])
            grey = nodes.new('ShaderNodeRGBToBW')
            links.new(sample.outputs['Color'], grey.inputs[0])
            weighted = nodes.new('ShaderNodeMath'); weighted.operation = 'MULTIPLY'
            weighted.inputs[1].default_value = wx*wy
            links.new(grey.outputs[0], weighted.inputs[0])
            if height is None: height = weighted.outputs[0]
            else:
                add = nodes.new('ShaderNodeMath'); add.operation = 'ADD'
                links.new(height, add.inputs[0]); links.new(weighted.outputs[0], add.inputs[1])
                height = add.outputs[0]
    grain = nodes.new('ShaderNodeBump')
    grain.inputs['Distance'].default_value = .010
    grain.inputs['Strength'].default_value = .65
    links.new(height, grain.inputs['Height'])
    links.new(grain.outputs['Normal'], shader.inputs['Normal'])
    roughness = nodes.new('ShaderNodeMapRange')
    roughness.inputs['From Min'].default_value = .05
    roughness.inputs['From Max'].default_value = .55
    roughness.inputs['To Min'].default_value = .96
    roughness.inputs['To Max'].default_value = .88
    links.new(height, roughness.inputs['Value'])
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
    for name, size, mode in [('fence_wood_normal', 1024, 'NORMAL'), ('fence_wood_orm', 512, 'EMIT')]:
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
    normal.inputs['Strength'].default_value = .65
    links.new(normal_texture.outputs['Color'], normal.inputs['Color'])
    links.new(normal.outputs['Normal'], shader.inputs['Normal'])
    orm = nodes.new('ShaderNodeTexImage'); orm.image = images['fence_wood_orm']
    channels = nodes.new('ShaderNodeSeparateColor')
    links.new(orm.outputs['Color'], channels.inputs['Color'])
    links.new(channels.outputs['Green'], shader.inputs['Roughness'])
    links.new(channels.outputs['Blue'], shader.inputs['Metallic'])
    return images
