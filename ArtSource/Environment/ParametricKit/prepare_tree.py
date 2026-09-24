"""Prepare continuous Tripo branch wood and reusable crown clusters with sockets."""
from pathlib import Path
import bpy, bmesh, json, math, importlib.util, heapq
import numpy as np
from mathutils import Vector

SOURCE=Path(__file__).resolve().parent
ROOT=SOURCE.parents[2]
OUT=ROOT/'Game/art/environment/parametric_kit'
RAW=SOURCE/'raw/tripo-out/parametric-osmanthus-branch-67c5df09/model.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)

def imported(path,name):
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects=[o for o in set(bpy.context.scene.objects)-before if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1: bpy.ops.object.join()
    obj=bpy.context.object; obj.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    return obj

def bounds(obj):
    pts=[v.co for v in obj.data.vertices]
    return Vector([min(p[i] for p in pts) for i in range(3)]),Vector([max(p[i] for p in pts) for i in range(3)])

framework=SOURCE/'raw/tripo-out/parametric-osmanthus-framework-4ff9958f/model.glb'
trunk=imported(framework,'Rootstock')
lo,hi=bounds(trunk); centre=(lo+hi)*.5
swap=(hi-lo).y>(hi-lo).x
for v in trunk.data.vertices:
    p=(v.co-Vector((centre.x,centre.y,lo.z)))*(2.6/(hi.z-lo.z))
    v.co=Vector((p.y,-p.x,p.z)) if swap else p
bm=bmesh.new(); bm.from_mesh(trunk.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
raw_trunk_open=sum(e.is_boundary for e in bm.edges)
# The P2 framework has small unintended bark holes (largest span 0.11 m).
# Close them in the editable copy, preserving neighbouring corner UV values.
layer=bm.loops.layers.uv.active
old_uv={v:next(iter(v.link_loops))[layer].uv.copy() for v in bm.verts if v.link_loops}
filled=bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)['faces']
for face in filled:
    for loop in face.loops: loop[layer].uv=old_uv[loop.vert]
bm.normal_update(); bm.to_mesh(trunk.data); bm.free()
# Endpoints follow the surface graph from the rooted base. Unlike world-height
# cuts, this finds the end of each curved limb without cutting branch junctions.
verts=[v.co.copy() for v in trunk.data.vertices]
graph=[[] for _ in verts]
for edge in trunk.data.edges:
    a,b=edge.vertices; length=(verts[a]-verts[b]).length
    graph[a].append((b,length)); graph[b].append((a,length))
def distances(start,limit=float('inf')):
    result={start:0.}; todo=[(0.,start)]
    while todo:
        cost,i=heapq.heappop(todo)
        if cost!=result[i]: continue
        for j,length in graph[i]:
            new=cost+length
            if new<result.get(j,float('inf')) and new<=limit:
                result[j]=new; heapq.heappush(todo,(new,j))
    return result
root_index=min(range(len(verts)),key=lambda i:verts[i].z+math.hypot(verts[i].x,verts[i].y)*.12)
root_distance=distances(root_index)
assert len(root_distance)==len(verts),'Unexpected disconnected framework'
candidates=[i for i,p in enumerate(verts) if p.z>.85 and all(root_distance[i]>=root_distance[j] for j,_ in graph[i])]
candidates.sort(key=lambda i:root_distance[i],reverse=True)
sockets=[]; suppressed=set()
for tip in candidates:
    if tip in suppressed: continue
    local=distances(tip,.34)
    suppressed.update(local)
    end=[verts[i] for i,d in local.items() if d<.035]
    neck=[verts[i] for i,d in local.items() if .10<d<.17]
    if len(neck)<3: continue
    at=sum(end,Vector())/len(end)
    inside=sum(neck,Vector())/len(neck)
    axis=(at-inside).normalized()
    # Bark bumps have a wide neck relative to endpoint reach; exclude them.
    radius=sum((p-inside).cross(axis).length for p in neck)/len(neck)
    if radius>.085: continue
    at-=axis*.085
    sockets.append({'at':[at.x,at.z,-at.y],'axis':[axis.x,axis.z,-axis.y],'radius':radius,'geodesic':root_distance[tip]})
sockets.sort(key=lambda s:math.atan2(s['at'][2],s['at'][0]))
cut_height=2.6
assert len(sockets)>=10,len(sockets)

cluster=imported(RAW,'OsmanthusCluster')
# P2's default exported forward axis puts the cut base at +X, not at minimum Z.
# Measured from the 15 coplanar end-cap faces in the immutable source mesh.
anchor=Vector((.4976445593,-.0768985947,-.2787912348))
axis=Vector((-.9977619052,.0493941568,.0450721607)).normalized()
rotation=axis.rotation_difference(Vector((0,0,1)))
for v in cluster.data.vertices: v.co=rotation@(v.co-anchor)
lo,hi=bounds(cluster); scale=1.05/(hi.z-lo.z)
for v in cluster.data.vertices: v.co*=scale
# Narrow only the buried stem collar. The original cap was wider than the
# framework's branch tips, leaving a conspicuous exposed saw-cut annulus.
for v in cluster.data.vertices:
    t=max(0,min(1,v.co.z/.22)); factor=.27+.73*t*t*(3-2*t)
    v.co.x*=factor; v.co.y*=factor
lo,hi=bounds(cluster)
mesh=cluster.data
image=next(n.image for n in mesh.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
pixels=np.array(image.pixels[:],dtype=np.float32).reshape(image.size[1],image.size[0],4)
leaf=np.zeros(len(mesh.vertices)); count=np.zeros(len(mesh.vertices))
for loop in mesh.loops:
    uv=mesh.uv_layers.active.data[loop.index].uv
    r,g,b=pixels[min(image.size[1]-1,max(0,int(uv.y*image.size[1]))),min(image.size[0]-1,max(0,int(uv.x*image.size[0]))),:3]
    leaf[loop.vertex_index]+=max(0,min(1,(float(g)/max(float(r),.001)-.98)/.14))
    count[loop.vertex_index]+=1
leaf/=np.maximum(count,1)
weights=mesh.color_attributes.new(name='WindWeights',type='FLOAT_COLOR',domain='POINT')
mesh.color_attributes.active_color=weights
for i,v in enumerate(mesh.vertices):
    t=max(0,min(1,(v.co.z-.18)/.78))
    weights.data[i].color=(t*t*(3-2*t),float(leaf[i])*t,(v.co.y-lo.y)/max(.001,hi.y-lo.y),1)

parts={'tree_trunk':trunk,'tree_cluster':cluster}
source_open={}
for key,obj in list(parts.items()):
	# P2 foliage contains open leaf surfaces. Preserve those authored borders;
	# closure is required for the repaired framework, not imposed on thin leaves.
    audit=bmesh.new(); audit.from_mesh(obj.data)
    bmesh.ops.remove_doubles(audit,verts=list(audit.verts),dist=1e-6)
    source_open[key]=sum(e.is_boundary for e in audit.edges); audit.free()
    for poly in obj.data.polygons: poly.use_smooth=True
    for mat in obj.data.materials:
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        bsdf.inputs['Roughness'].default_value=.96
        bsdf.inputs['Specular IOR Level'].default_value=.08
        mat.use_backface_culling=False
    low=obj.copy(); low.data=obj.data.copy(); low.name=key+'_low'
    bpy.context.collection.objects.link(low)
    bpy.context.view_layer.objects.active=low
    bm=bmesh.new(); bm.from_mesh(low.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bm.to_mesh(low.data); bm.free()
    mod=low.modifiers.new('Distant silhouette','DECIMATE'); mod.ratio=.5
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new(); bm.from_mesh(low.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.dissolve_degenerate(bm,dist=1e-6,edges=list(bm.edges))
    if key=='tree_trunk':
        # Decimation can collapse a tiny cut tip into an isolated double-sided
        # triangle. The trunk is a connected solid; discard disconnected debris.
        remaining=set(bm.verts); components=[]
        while remaining:
            todo=[remaining.pop()]; component=[]
            while todo:
                v=todo.pop(); component.append(v)
                for edge in v.link_edges:
                    other=edge.other_vert(v)
                    if other in remaining: remaining.remove(other); todo.append(other)
            components.append(component)
        largest=max(components,key=len)
        debris=[v for component in components if component is not largest for v in component]
        if debris: bmesh.ops.delete(bm,geom=debris,context='VERTS')
    bm.normal_update(); bm.to_mesh(low.data); bm.free()
    parts[key+'_low']=low

bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'tree_modules.blend'))
report={'blender':bpy.app.version_string,'rootstock_source':str(framework.relative_to(ROOT)),'cluster_source':str(RAW.relative_to(ROOT)),'framework_height':cut_height,'raw_framework_open_edges':raw_trunk_open,'filled_framework_faces':len(filled),'sockets':sockets,'cluster_anchor_raw':list(anchor),'cluster_axis_raw':list(axis),'source_open_edges':source_open,'parts':{}}
for name,obj in parts.items():
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    obj.data.calc_loop_triangles()
    low,high=bounds(obj)
    report['parts'][name]={'triangles':len(obj.data.loop_triangles),'dimensions_blender':list(high-low),'min_blender':list(low),'max_blender':list(high),'materials':len(obj.data.materials)}
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_vertex_color='ACTIVE',export_skins=False)

for name in parts:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj=imported(OUT/(name+'.glb'),name)
    obj.data.calc_loop_triangles()
    assert len(obj.data.loop_triangles)==report['parts'][name]['triangles'],(name,len(obj.data.loop_triangles),report['parts'][name]['triangles'])
    assert obj.data.uv_layers
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    opens=sum(e.is_boundary for e in bm.edges)
    report['parts'][name]['open_edges_after_audit_weld']=opens
    report['parts'][name]['reimport_verified']=True
    bm.free()
    baseline=source_open[name.removesuffix('_low')]
    assert opens<=baseline,(name,opens,baseline)
    if not name.endswith('_low'): assert opens==baseline,(name,opens,baseline)

(SOURCE/'tree-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(OUT/'tree_sockets.json').write_text(json.dumps({'trunk_height':cut_height,'sockets':sockets,'cluster_bounds':report['parts']['tree_cluster']},indent=2),encoding='utf-8')
# Each near/far pair references one identical image, not four embedded copies.
spec=importlib.util.spec_from_file_location('glb_shared',ROOT/'scripts/share-glb-textures.py')
shared=importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)
for name in parts:
    path=OUT/(name+'.glb'); doc,binary=shared.read_glb(path); discard=set()
    for img in doc.get('images',[]):
        payload=shared.image_bytes(doc,binary,img)
        filename=name.removesuffix('_low')+'_color.jpg'
        (OUT/filename).write_bytes(payload)
        discard.add(img.pop('bufferView')); img.pop('mimeType',None); img['uri']=filename
    if discard: path.write_bytes(shared.encode_glb(doc,binary,discard))
print('TREE_COMPONENTS_VERIFIED',json.dumps(report))
