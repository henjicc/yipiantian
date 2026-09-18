"""Prepare P2 props without discarding native polygons. Run in Blender background."""
from pathlib import Path
import json
import bpy
from mathutils import Vector
ROOT = Path(__file__).resolve().parent
for kind, height in [('hoe', 1.25), ('chair', .82)]:
    folder = ROOT / kind
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(folder/'raw/model.fbx'))
    meshes = [o for o in bpy.context.scene.objects if o.type=='MESH']
    pts = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    low = Vector([min(p[i] for p in pts) for i in range(3)])
    high = Vector([max(p[i] for p in pts) for i in range(3)])
    factor = height / (high.z-low.z)
    pivot = Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    for obj in meshes:
        matrix = obj.matrix_world.copy()
        for v in obj.data.vertices: v.co = (matrix @ v.co-pivot)*factor
        obj.matrix_world.identity()
        obj.name = kind
        for material in obj.data.materials:
            for node in material.node_tree.nodes:
                if node.type=='BSDF_PRINCIPLED':
                    node.inputs['Roughness'].default_value=.95
                    node.inputs['Metallic'].default_value=0
                    node.inputs['Specular IOR Level'].default_value=.08
    bpy.context.view_layer.update()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/(kind+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(folder/(kind+'.glb')),export_format='GLB')
    for obj in meshes: obj.data.calc_loop_triangles()
    report={'height_m':height,'triangles':sum(len(o.data.loop_triangles) for o in meshes),
            'quads':sum(sum(len(p.vertices)==4 for p in o.data.polygons) for o in meshes),
            'dimensions':[list(o.dimensions) for o in meshes]}
    (folder/'audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
