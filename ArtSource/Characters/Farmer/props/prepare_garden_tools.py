"""Normalize the approved P2 seed basket / watering vessel, preserving native faces."""
from pathlib import Path
import json
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
GAME = ROOT.parents[3] / 'Game/art/characters/farmer'
for kind, height in [('seed_basket', .48), ('watering_can', .55)]:
    folder = ROOT / kind
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(next((folder/'raw').rglob('model.fbx'))))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    low = Vector([min(p[i] for p in pts) for i in range(3)])
    high = Vector([max(p[i] for p in pts) for i in range(3)])
    factor = height / (high.z-low.z)
    pivot = Vector(((low.x+high.x)/2, (low.y+high.y)/2, low.z))
    for obj in meshes:
        transform = obj.matrix_world.copy()
        for v in obj.data.vertices: v.co = (transform @ v.co-pivot)*factor
        obj.matrix_world.identity()
        obj.name = kind
        for mat in obj.data.materials:
            for node in mat.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    node.inputs['Roughness'].default_value = .95
                    node.inputs['Metallic'].default_value = 0
                    node.inputs['Specular IOR Level'].default_value = .08
        obj.data.calc_loop_triangles()
    bpy.context.view_layer.update()
    triangles = sum(len(o.data.loop_triangles) for o in meshes)
    dimensions = [list(o.dimensions) for o in meshes]
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/(kind+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(folder/(kind+'.glb')), export_format='GLB')
    import shutil
    shutil.copy2(folder/(kind+'.glb'), GAME/(kind+'.glb'))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(GAME/(kind+'.glb')))
    count = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    assert count == triangles, (kind, count, triangles)
    (folder/'audit.json').write_text(json.dumps({'height_m':height, 'triangles':triangles, 'dimensions':dimensions, 'reimport_verified':True},indent=2))
    print('GARDEN_TOOL_VERIFIED', kind, triangles, dimensions)
