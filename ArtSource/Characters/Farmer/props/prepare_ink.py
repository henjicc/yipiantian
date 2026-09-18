"""Restore texture-only outputs to source scale and render comparable real meshes."""
from pathlib import Path
import json, math
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parent
for kind, height in [('hoe', 1.25), ('chair', .82)]:
    folder = ROOT/kind
    def load(path):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(path))
        return [o for o in bpy.context.scene.objects if o.type == 'MESH']
    originals = load(folder/(kind+'.glb'))
    original_points = [o.matrix_world@v.co for o in originals for v in o.data.vertices]
    tree = KDTree(len(original_points))
    for i,p in enumerate(original_points): tree.insert(p,i)
    tree.balance()
    original_triangles = sum(len(o.data.polygons) for o in originals)
    meshes = load(folder/'ink/raw/model.glb')
    points = [o.matrix_world@v.co for o in meshes for v in o.data.vertices]
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    pivot = Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    for obj in meshes:
        transform = obj.matrix_world.copy()
        for v in obj.data.vertices: v.co = (transform@v.co-pivot)*height/(high.z-low.z)
        obj.matrix_world.identity()
        obj.name = kind
        for material in obj.data.materials:
            for node in material.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    node.inputs['Metallic'].default_value = 0
                    node.inputs['Roughness'].default_value = .95
                    node.inputs['Specular IOR Level'].default_value = .08
    bpy.context.view_layer.update()
    deviation = max(tree.find(o.matrix_world@v.co)[2] for o in meshes for v in o.data.vertices)
    assert deviation < 1e-5, (kind,deviation)
    assert sum(len(o.data.polygons) for o in meshes) == original_triangles
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/'ink'/(kind+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(folder/'ink'/(kind+'.glb')),export_format='GLB')
    meshes = load(folder/'ink'/(kind+'.glb'))
    assert sum(len(o.data.polygons) for o in meshes) == original_triangles
    (folder/'ink/audit.json').write_text(json.dumps({'height':height,'triangles':original_triangles,'max_vertex_deviation_m':deviation,'reimport_verified':True},indent=2))
    # The same light, framing and materials for baseline and retexture.
    for version in ['original','ink']:
        meshes = load(folder/(kind+'.glb') if version=='original' else folder/'ink'/(kind+'.glb'))
        scene = bpy.context.scene
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 16
        scene.world = bpy.data.worlds.new('Neutral')
        scene.world.use_nodes = True
        scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.7,.68,.62,1)
        scene.world.node_tree.nodes['Background'].inputs[1].default_value = .8
        for p,power in [((3,-4,5),300),((-3,2,4),200)]:
            bpy.ops.object.light_add(type='AREA',location=p)
            obj=bpy.context.object;obj.data.energy=power;obj.data.size=4
            obj.rotation_euler=(Vector((0,0,height/2))-obj.location).to_track_quat('-Z','Y').to_euler()
        bpy.ops.object.camera_add()
        cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=height*1.55
        scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100
        scene.view_settings.view_transform='Standard'
        (folder/'previews').mkdir(exist_ok=True)
        for index,angle in enumerate([-.65,2.5]):
            cam.location=(3*math.sin(angle),-3*math.cos(angle),height*.85)
            cam.rotation_euler=(Vector((0,0,height*.5))-cam.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath=str(folder/'previews'/f'{version}-{index}.png')
            bpy.ops.render.render(write_still=True)
    print('PROP_VERIFIED',kind,deviation)
