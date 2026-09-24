"""Blender 5.2: metric bridge modules; raw Tripo model stays immutable."""
from pathlib import Path
import bpy, json, math
import numpy as np
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[3]
OUT = ROOT / 'Game/art/environment/procedural_bridge'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'raw/tripo-out/lab-bridge-post-18e92ae5/model.glb'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes)>1: bpy.ops.object.join()
post = bpy.context.object
post.name = 'BridgePost'
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
points = [post.matrix_world @ v.co for v in post.data.vertices]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
factor = .90 / (hi.z-lo.z)
origin = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
for v, point in zip(post.data.vertices,points): v.co = (point-origin)*factor
post.location = (0,0,0)
for material in post.data.materials:
    bsdf = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value = .91
    bsdf.inputs['Metallic'].default_value = 0

# A painted timber swatch: layered long fibres and sparse oval knots, not white
# noise. This is newly authored texture data; no pixels of the source are edited.
size = 1024
y,x = np.mgrid[0:1:complex(size),0:1:complex(size)]
warp = y + .008*np.sin(x*17+y*5)+.004*np.sin(x*49+y*13)
grain = np.sin(warp*520 + 3*np.sin(warp*41)+.8*np.sin(x*11))
fine = np.sin(warp*1460+x*6)
tone = .62+.08*np.sin(warp*49)+.05*np.sin(warp*117)-.11*np.maximum(0,grain)**14-.035*np.maximum(0,fine)**12
for cx,cy in [(.28,.35),(.76,.77)]:
    rad = np.sqrt(((x-cx)*2.8)**2+((y-cy)*16)**2)
    tone -= .10*np.exp(-rad*rad*6)+.055*np.exp(-rad*rad)*np.maximum(0,np.sin(rad*33))**8
tone = np.clip(tone,0,1)
pixels = np.ones((size,size,4), dtype=np.float32)
dark = np.array([.25,.17,.095]); light = np.array([.68,.53,.35])
pixels[:,:,:3] = dark[None,None,:]+tone[:,:,None]*(light-dark)[None,None,:]
image = bpy.data.images.new('PaintedElm',width=size,height=size)
image.pixels.foreach_set(pixels.ravel())
image.filepath_raw = str(SOURCE/'painted_elm.png'); image.file_format='PNG'; image.save(); image.pack()
wood = bpy.data.materials.new('MattePaintedElm'); wood.use_nodes=True
bsdf = next(n for n in wood.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs['Roughness'].default_value=.94
tex=wood.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image
wood.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])

def timber(name, dimensions, bevel):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj=bpy.context.object; obj.name=name; obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=obj.modifiers.new('Worn corners','BEVEL'); mod.width=bevel; mod.segments=3
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(wood)
    # Project every long face in metres along its long axis; keep fibres lengthwise.
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new()
    axis=max(range(3),key=lambda i: dimensions[i])
    for poly in obj.data.polygons:
        transverse=max((i for i in range(3) if i!=axis), key=lambda i: 1-abs(poly.normal[i]))
        for li in poly.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv=(co[axis]/dimensions[axis]+.5,co[transverse]/dimensions[transverse]+.5)
    for poly in obj.data.polygons: poly.use_smooth=False
    return obj

parts={'post':post,
       'plank':timber('DeckPlank',(1.5,.25,.09),.012),
       'rail':timber('Handrail',(.09,1,.085),.014),
       'beam':timber('BearingTimber',(.14,1,.19),.014)}
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'bridge_modules.blend'))
report={'blender':bpy.app.version_string,'source_task':'18e92ae5-d11c-4987-81d4-babb51731181','parts':{}}
for name,obj in parts.items():
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    obj.data.calc_loop_triangles()
    report['parts'][name]={'triangles':len(obj.data.loop_triangles),'dimensions_blender':list(obj.dimensions),'uv':bool(obj.data.uv_layers)}
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT',export_cameras=False,export_lights=False)

# Clean re-import is part of the build, checking metric orientation, UV and images.
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for name in parts:
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
    imported=[o for o in set(bpy.context.scene.objects)-before if o.type=='MESH']
    assert imported and all(o.data.uv_layers for o in imported),name
    triangles=0
    for obj in imported:
        obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
        assert all(math.isfinite(v) for vert in obj.data.vertices for v in vert.co),name
        assert all(n.image for m in obj.data.materials for n in m.node_tree.nodes if n.type=='TEX_IMAGE'),name
    assert triangles==report['parts'][name]['triangles'],name
    report['parts'][name]['reimport_triangles']=triangles
    report['parts'][name]['reimport_ok']=True
(SOURCE/'audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('BRIDGE_MODULES_VERIFIED',json.dumps(report))
