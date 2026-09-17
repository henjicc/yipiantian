"""Prepare the original textured osmanthus with seam-continuous wind weights.
Blender 5.2.2 --background --python-exit-code 1 --python this_file.py
Semantic parts guide authoring; the original mesh/UV/4K image remain the source.
"""
from pathlib import Path
import bpy, bmesh, json, math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[3]
OUT=REPO/'Game/art/environment/osmanthus'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'osmanthus/segmented/model.glb'))
verts=[]; faces=[]; labels=[]
for o in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    o.data.calc_loop_triangles(); start=len(verts)
    verts.extend(o.matrix_world@v.co for v in o.data.vertices)
    for f in o.data.loop_triangles:
        faces.append(tuple(start+i for i in f.vertices)); labels.append(int(o.name.rsplit('_',1)[1]))
seg_min=Vector([min(p[i] for p in verts) for i in range(3)])
seg_max=Vector([max(p[i] for p in verts) for i in range(3)])
seg_centre=(seg_min+seg_max)*.5
seg_bvh=BVHTree.FromPolygons(verts,faces,all_triangles=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'osmanthus/raw/model.glb'))
tree=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=tree; tree.select_set(True)
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
mesh=tree.data
points=[v.co.copy() for v in mesh.vertices]
lo=Vector([min(p[i] for p in points) for i in range(3)])
hi=Vector([max(p[i] for p in points) for i in range(3)])
centre=(lo+hi)*.5; span=hi-lo; scale=3.6/span.z
image=next(n.image for n in mesh.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
pixels=np.array(image.pixels[:],dtype=np.float32).reshape(image.size[1],image.size[0],4)
leaf_sum=np.zeros(len(mesh.vertices)); count=np.zeros(len(mesh.vertices))
for loop in mesh.loops:
    uv=mesh.uv_layers.active.data[loop.index].uv
    r,g,b=pixels[min(image.size[1]-1,int(uv.y*image.size[1])),min(image.size[0]-1,int(uv.x*image.size[0])),:3]
    # Leaves are greener than the warm grey bark; flowers follow branch sway only.
    leaf_sum[loop.vertex_index]+=max(0,min(1,(float(g)/max(float(r),.001)-1.0)/.14))
    count[loop.vertex_index]+=1
leaf_sum/=np.maximum(count,1)
weights={}; groups={}
for i,p in enumerate(points):
    seg_p=(p-centre)/max(span)*max(seg_max-seg_min)+seg_centre
    _,_,face_index,_=seg_bvh.find_nearest(seg_p)
    part=labels[face_index]
    if part not in groups: groups[part]=tree.vertex_groups.new(name=f'TripoPart_{part:02}')
    groups[part].add([i],1.0,'REPLACE')
    h=(p.z-lo.z)/span.z
    bend=max(0,min(1,(h-.20)/.80))**1.65
    flutter=float(leaf_sum[i])*max(0,min(1,(h-.38)/.22))
    # Phase varies continuously in space, even at cuts between semantic parts.
    phase=(p.y-lo.y)/span.y
    key=tuple(round(float(x),6) for x in p)
    weights.setdefault(key,[]).append((bend,flutter,phase,1))
attribute=mesh.color_attributes.new(name='WindWeights',type='FLOAT_COLOR',domain='POINT')
mesh.color_attributes.active_color=attribute
for i,v in enumerate(mesh.vertices):
    key=tuple(round(float(x),6) for x in points[i])
    attribute.data[i].color=np.mean(weights[key],axis=0)
    p=(v.co-Vector((centre.x,centre.y,lo.z)))*scale
    # Broaden crown depth to make the generated shallow canopy readable in orbit.
    v.co=Vector((p.y,-p.x*1.50,p.z))
for mat in mesh.materials:
    bsdf=mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=.96
    bsdf.inputs['Specular IOR Level'].default_value=.08
    mat.use_backface_culling=False
for f in mesh.polygons:f.use_smooth=True
tree.name='osmanthus_high'
low=tree.copy();low.data=mesh.copy();low.name='osmanthus_low';bpy.context.collection.objects.link(low)
bpy.context.view_layer.objects.active=low
# glTF duplicates vertices along UV seams. Decimating those disconnected borders
# independently tears the surface. Weld only the working low copy; UVs stay on
# face corners and the original/high mesh stays untouched.
bm=bmesh.new();bm.from_mesh(low.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
bm.to_mesh(low.data);bm.free();low.data.update()
dec=low.modifiers.new('Preserve leaf silhouette','DECIMATE');dec.ratio=.57
bpy.ops.object.modifier_apply(modifier=dec.name)
report={'blender':bpy.app.version_string,'height':3.6,'depth_scale':1.5,'source':'osmanthus/raw/model.glb','semantic_source':'osmanthus/segmented/model.glb','wind_channels':{'R':'continuous branch bending, bottom 20% locked','G':'leaf flutter sampled from original texture','B':'continuous crown phase','A':'1'},'meshes':{}}
for obj in [tree,low]:
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    obj.data.calc_loop_triangles()
    report['meshes'][obj.name]={'triangles':len(obj.data.loop_triangles),'dimensions':list(obj.dimensions),'materials':len(obj.data.materials),'textures':[4096,4096]}
    bpy.ops.export_scene.gltf(filepath=str(OUT/(obj.name+'.glb')),export_format='GLB',use_selection=True,export_vertex_color='ACTIVE',export_skins=False)
low.hide_render=True;low.hide_set(True)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'osmanthus/osmanthus.blend'))
for name,stats in report['meshes'].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
    o=next(o for o in bpy.context.scene.objects if o.type=='MESH');o.data.calc_loop_triangles()
    assert len(o.data.loop_triangles)==stats['triangles']
    assert len(o.data.color_attributes)==1
    assert len(o.data.materials)==1
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    stats['boundary_edges_after_audit_weld']=sum(e.is_boundary for e in bm.edges)
    stats['overconnected_edges']=sum(len(e.link_faces)>2 for e in bm.edges)
    assert stats['boundary_edges_after_audit_weld']==0, 'LOD introduced open borders'
    assert stats['overconnected_edges']==0, 'LOD introduced nonmanifold edges'
    bm.free()
    stats['reimport_verified']=True
(ROOT/'osmanthus/asset-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('OSMANTHUS_READY',json.dumps(report))
