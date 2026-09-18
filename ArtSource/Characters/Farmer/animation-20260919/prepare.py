"""Inspect Tripo skin and actions, retain editable source and real pose previews."""
from pathlib import Path
import bpy, json, math
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'raw/actions.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
actions=list(bpy.data.actions)
report={'actions':[{ 'name':a.name,'frames':list(a.frame_range)} for a in actions],'bones':len(arm.data.bones)}
print('ACTIONS',json.dumps(report))
for track in arm.animation_data.nla_tracks: track.mute=True
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=16
scene.world=bpy.data.worlds.new('Neutral');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.7,.68,.62,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
for p,power in [((3,-4,5),300),((-3,2,4),200)]:
    bpy.ops.object.light_add(type='AREA',location=p)
    o=bpy.context.object;o.data.energy=power;o.data.size=4
    o.rotation_euler=(Vector((0,0,.6))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam
cam.data.type='ORTHO';cam.data.ortho_scale=1.8
scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
(ROOT/'previews').mkdir(exist_ok=True)
report['samples']=[]
for action in actions:
    arm.animation_data.action=action
    name=action.name.split(':')[-1]
    for fraction in [0,.5,1]:
        frame=action.frame_range[0]+(action.frame_range[1]-action.frame_range[0])*fraction
        scene.frame_set(int(frame),subframe=frame-int(frame))
        graph=bpy.context.evaluated_depsgraph_get()
        pts=[]
        for obj in meshes:
            evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh()
            pts.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
            evaluated.to_mesh_clear()
        lo=[min(p[i] for p in pts) for i in range(3)];hi=[max(p[i] for p in pts) for i in range(3)]
        report['samples'].append({'action':name,'fraction':fraction,'min':lo,'max':hi})
        center=(Vector(lo)+Vector(hi))*.5
        cam.data.ortho_scale=1.35
        cam.location=center+Vector((3,-.7,.3))
        cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(ROOT/'previews'/f'{name}-{fraction}.png')
        bpy.ops.render.render(write_still=True)
arm.animation_data.action=None
for track in arm.animation_data.nla_tracks: track.mute=False
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'farmer_actions.blend'))
(ROOT/'audit.json').write_text(json.dumps(report,indent=2))
