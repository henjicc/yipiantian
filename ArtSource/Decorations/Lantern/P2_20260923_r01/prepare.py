"""Normalize the immutable P2 FBX and export same-source lantern detail tiers."""
from pathlib import Path
import bpy, json
from mathutils import Vector

BASE = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(BASE / 'model.fbx'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert meshes
points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lo = Vector([min(p[i] for p in points) for i in range(3)])
hi = Vector([max(p[i] for p in points) for i in range(3)])
pivot = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
factor = .57/(hi.z-lo.z)
for o in meshes:
    matrix = o.matrix_world.copy()
    o.parent = None
    o.matrix_world.identity()
    for v in o.data.vertices: v.co = (matrix @ v.co-pivot)*factor
    for mat in o.data.materials:
        mat.use_backface_culling = False
        for n in mat.node_tree.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                n.inputs['Specular IOR Level'].default_value = .08
                n.inputs['Metallic'].default_value = 0
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes)>1: bpy.ops.object.join()
high = bpy.context.object
high.name = 'lantern_high'
high.data.calc_loop_triangles()
report = {'task_id':'09a71540-5feb-48bb-bf4b-518d970d5267','geometry_model':'P2-20260801','texture_model':'v3.5-20260815','credits':130,'height':.57,'pivot':'bottom center; hanging attachment at local y=.57 in Godot','high_triangles':len(high.data.loop_triangles),'original_faces':len(high.data.polygons),'quad_faces':sum(len(p.vertices)==4 for p in high.data.polygons)}
low = high.copy(); low.data = high.data.copy(); low.name = 'lantern_low'
bpy.context.collection.objects.link(low)
bpy.context.view_layer.objects.active = low
mod = low.modifiers.new('Far view detail', 'DECIMATE')
mod.ratio = min(1,9000/report['high_triangles'])
bpy.ops.object.modifier_apply(modifier=mod.name)
low.data.calc_loop_triangles()
report['low_triangles'] = len(low.data.loop_triangles)
report['textures'] = [{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.type=='IMAGE']
for obj in [high,low]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(BASE/(obj.name+'.glb')),export_format='GLB',use_selection=True,export_animations=False)
low.hide_set(True); low.hide_render=True
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'lantern.blend'))
(BASE/'asset-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
for obj in [high,low]:
    bpy.ops.object.select_all(action='DESELECT')
    obj.hide_set(False); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    obj.location.z=-.57
    bpy.ops.export_scene.gltf(filepath=str(BASE/(obj.name+'_hanging.glb')),export_format='GLB',use_selection=True,export_animations=False)
