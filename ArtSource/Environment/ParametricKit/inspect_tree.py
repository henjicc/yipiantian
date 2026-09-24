"""Re-render prepared tree components for dimensional and back-face inspection."""
from pathlib import Path
import bpy
from mathutils import Vector
SOURCE=Path(__file__).resolve().parent
ROOT=SOURCE.parents[2]
OUT=ROOT/'.local/verification/component-tree'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'tree_modules.blend'))
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.render.resolution_x=1000; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('InspectionWorld'); scene.world.color=(.35,.35,.35)
bpy.ops.object.light_add(type='AREA',location=(2,-4,6))
light=bpy.context.object; light.data.energy=650; light.data.shape='DISK'; light.data.size=5
bpy.ops.object.camera_add()
camera=bpy.context.object; camera.data.type='ORTHO'; scene.camera=camera
meshes=[o for o in scene.objects if o.type=='MESH']
for name in ['Rootstock','OsmanthusCluster']:
    obj=bpy.data.objects[name]
    for other in meshes: other.hide_render=other!=obj
    points=[obj.matrix_world@v.co for v in obj.data.vertices]
    low=Vector([min(p[i] for p in points) for i in range(3)])
    high=Vector([max(p[i] for p in points) for i in range(3)])
    centre=(low+high)*.5
    camera.data.ortho_scale=max(high-low)*1.45
    for label,direction in [('front',Vector((6,-8,4))),('back',Vector((-6,8,4)))]:
        camera.location=centre+direction
        camera.rotation_euler=(centre-camera.location).to_track_quat('-Z','Y').to_euler()
        light.location=centre+Vector((2,-4,6))
        scene.render.filepath=str(OUT/(name+'-'+label+'.png'))
        bpy.ops.render.render(write_still=True)
