"""Normalize the approved P2 bucket without decimation; export and verify GLB."""
from pathlib import Path
import json
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
TARGET = ROOT.parents[2] / 'Game/art/tools/water.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(next((ROOT/'raw').rglob('model.fbx'))))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for obj in meshes:
    obj.data.transform(obj.matrix_world)
    obj.matrix_world.identity()
points = [v.co.copy() for o in meshes for v in o.data.vertices]
low = Vector([min(p[i] for p in points) for i in range(3)])
high = Vector([max(p[i] for p in points) for i in range(3)])
scale = .62 / (high.z-low.z)
pivot = Vector(((low.x+high.x)/2, (low.y+high.y)/2, low.z))
for obj in meshes:
    for vertex in obj.data.vertices:
        vertex.co = (vertex.co-pivot)*scale
    obj.name = 'WaterBucket'
    for mat in obj.data.materials:
        for node in mat.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED':
                node.inputs['Roughness'].default_value = .94
                node.inputs['Metallic'].default_value = 0
                node.inputs['Specular IOR Level'].default_value = .08
    obj.data.calc_loop_triangles()
bpy.context.view_layer.update()
audit = {
    'blender': bpy.app.version_string,
    'height_m': .62, 'scale': scale, 'source_pivot': list(pivot),
    'triangles': sum(len(o.data.loop_triangles) for o in meshes),
    'polygons': sum(len(o.data.polygons) for o in meshes),
    'quads': sum(len(p.vertices)==4 for o in meshes for p in o.data.polygons),
    'dimensions_xyz': [list(o.dimensions) for o in meshes],
    'materials': [m.name for m in bpy.data.materials],
    'textures': [{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.size[0]],
    'processing': 'Uniform scale, bottom-center pivot, matte material. No decimation, repainting, segmentation or animation.'
}
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'water-bucket.blend'))
bpy.ops.export_scene.gltf(filepath=str(TARGET), export_format='GLB')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(TARGET))
count = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
assert count == audit['triangles'], (count, audit)
audit['reimport_verified'] = True
(ROOT/'audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
print('BUCKET_VERIFIED',json.dumps(audit))
