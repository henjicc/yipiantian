"""Rebuild courtyard assets, preserving immutable Tripo originals and texture UVs.
Blender 5.2 --background --python-exit-code 1 --python prepare.py -- asset...
Birds use checked Tripo avian rigs, with locally authored looping motion.
"""
from pathlib import Path
import bpy, bmesh, json, math, sys, hashlib
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
SOURCE = ROOT/'20260918'
OUT = REPO/'Game/art/environment/courtyard_life'
OUT.mkdir(parents=True, exist_ok=True)
# Height in metres, except kitchen/food heaps: their longest horizontal extent.
SPECS = {'duck':(.52,9000), 'goose':(.78,10000), 'hen':(.43,7000),
 'bamboo':(2.65,22000), 'osmanthus':(3.7,35000), 'willow':(4.5,35000),
 'chrysanthemum':(.53,11000), 'lantern':(.57,9000), 'kitchen':(2.85,26000),
 'pepper':(.36,7000), 'slices':(.40,6500), 'pomelo':(.29,6500),
 'radish_bundle':(.43,8500), 'seedling':(.12,3500)}
PLANTS = {'bamboo','osmanthus','willow','chrysanthemum','seedling'}
BIRDS = {'duck','goose','hen'}

def stats(obj):
    obj.data.calc_loop_triangles()
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    data=dict(triangles=len(obj.data.loop_triangles),open_edges=sum(e.is_boundary for e in bm.edges),
        zero_area_faces=sum(f.calc_area()<1e-12 for f in bm.faces),uv_layers=len(obj.data.uv_layers))
    bm.free()
    return data

def reduce_mesh(obj,budget):
    bpy.context.view_layer.objects.active=obj
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    bm.to_mesh(obj.data); bm.free()
    obj.data.calc_loop_triangles()
    if len(obj.data.loop_triangles)>budget:
        mod=obj.modifiers.new('Audited manual detail tier','DECIMATE')
        mod.ratio=budget/len(obj.data.loop_triangles)
        bpy.ops.object.modifier_apply(modifier=mod.name)

def semantic_regions():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/'osmanthus-parts/model.glb'))
    verts=[]; faces=[]; labels=[]
    for obj in [o for o in bpy.context.scene.objects if o.type=='MESH']:
        obj.data.calc_loop_triangles(); start=len(verts)
        verts.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        for tri in obj.data.loop_triangles:
            faces.append(tuple(start+i for i in tri.vertices)); labels.append(obj.name)
    lo=Vector([min(p[i] for p in verts) for i in range(3)])
    hi=Vector([max(p[i] for p in verts) for i in range(3)])
    return BVHTree.FromPolygons(verts,faces,all_triangles=True), labels, (lo+hi)*.5, max(hi-lo)

def wind_weights(obj,semantic=None):
    mesh=obj.data; points=[v.co.copy() for v in mesh.vertices]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    span=hi-lo; center=(lo+hi)*.5
    texture=next(n.image for n in mesh.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
    pix=np.asarray(texture.pixels[:],dtype=np.float32).reshape(texture.size[1],texture.size[0],4)
    leaf=np.zeros(len(points)); count=np.zeros(len(points))
    for loop in mesh.loops:
        uv=mesh.uv_layers.active.data[loop.index].uv
        r,g,b=pix[min(texture.size[1]-1,max(0,int(uv.y*texture.size[1]))),
                    min(texture.size[0]-1,max(0,int(uv.x*texture.size[0]))),:3]
        leaf[loop.vertex_index]+=np.clip((float(g)/max(float(r),.001)-.97)/.16,0,1)
        count[loop.vertex_index]+=1
    leaf/=np.maximum(count,1)
    attr=mesh.color_attributes.new(name='WindWeights',type='FLOAT_COLOR',domain='POINT')
    mesh.color_attributes.active_color=attr
    groups={}; shared={}
    for i,p in enumerate(points):
        h=(p.z-lo.z)/span.z
        w=(max(0,(h-.18)/.82)**1.7,float(leaf[i])*max(0,min(1,(h-.23)/.22)),
           (p.y-lo.y)/max(span.y,.001),1)
        shared.setdefault(tuple(round(float(x),6) for x in p),[]).append(w)
        if semantic:
            bvh,labels,mid,extent=semantic
            _,_,index,_=bvh.find_nearest((p-center)/max(span)*extent+mid)
            label=labels[index]
            if label not in groups: groups[label]=obj.vertex_groups.new(name='Semantic_'+label)
            groups[label].add([i],1.0,'REPLACE')
    for i,p in enumerate(points):
        attr.data[i].color=np.mean(shared[tuple(round(float(x),6) for x in p)],axis=0)
    return list(groups)

def author_bird_motion(armature,name):
    bpy.context.scene.render.fps=30
    bpy.context.scene.frame_start=1; bpy.context.scene.frame_end=121
    for frame in range(1,122,4):
        phase=(frame-1)/120*math.tau
        for bone in armature.pose.bones:
            bone.rotation_mode='XYZ'
            angle=0.0
            if 'Head_0' in bone.name: angle=.045*math.sin(phase)
            if 'Limb_0' in bone.name: angle=(.25 if name=='hen' else .20)*math.sin(phase*2+(math.pi if 'Right' in bone.name else 0))
            if angle!=0 or 'Head_0' in bone.name or 'Limb_0' in bone.name:
                bone.rotation_euler.x=angle
                bone.keyframe_insert('rotation_euler',frame=frame)
    if armature.animation_data and armature.animation_data.action:
        armature.animation_data.action.name='Forage' if name=='hen' else 'Paddle'
    bpy.context.scene.frame_set(1)

def repair_hen_feet(obj,rig):
    """Remove cross-leg/to-body toe weights in the immutable rig's working copy.

    The two feet are disconnected below the ankles and lie on opposite sides of
    the rig midline. Keep their authored toe chains; fade back to the original
    shin weights above the ankle so this does not create a hard weight seam.
    """
    mesh_to_rig=rig.matrix_world.inverted()@obj.matrix_world
    midline=rig.data.bones['tripo::Root'].head_local.x
    groups={g.index:g.name for g in obj.vertex_groups}
    report={'changed_vertices':0,'cross_leg_vertices_over_5_percent':0}
    for side in ['Left','Right']:
        foot=rig.data.bones[f'tripo::0_{side}_Limb_1']
        foot_groups={obj.vertex_groups[b.name].index for b in [foot,*foot.children_recursive]}
        leg_groups=foot_groups|{obj.vertex_groups[foot.parent.name].index,
                               obj.vertex_groups[foot.parent.parent.name].index}
        opposite='Right' if side=='Left' else 'Left'
        other_hip=rig.data.bones[f'tripo::0_{opposite}_Limb_0'].parent.name
        # 4 cm in the unnormalized Tripo rig (~1.76 cm in the game).
        transition=.04
        for v in obj.data.vertices:
            p=mesh_to_rig@v.co
            if (p.x>midline)!=(side=='Left') or p.z>=foot.head_local.z+transition: continue
            old={g.group:g.weight for g in v.groups}
            if sum(w for i,w in old.items() if opposite in groups[i] or groups[i]==other_hip)>.05:
                report['cross_leg_vertices_over_5_percent']+=1
            own={i:w for i,w in old.items() if i in foot_groups}
            total=sum(own.values())
            own={i:w/total for i,w in own.items()} if total>1e-8 else {obj.vertex_groups[foot.name].index:1.0}
            t=min(1.0,max(0.0,(p.z-foot.head_local.z)/transition))
            t=t*t*(3-2*t)
            shin={i:w for i,w in old.items() if i in leg_groups}
            total=sum(shin.values())
            shin={i:w/total for i,w in shin.items()} if total>1e-8 else own
            new={i:(1-t)*own.get(i,0)+t*shin.get(i,0) for i in own.keys()|shin.keys()}
            for i in old: obj.vertex_groups[i].remove([v.index])
            for i,w in new.items():
                if w>0: obj.vertex_groups[i].add([v.index],w,'REPLACE')
            report['changed_vertices']+=1
    return report

for name in (sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else SPECS):
    size,budget=SPECS[name]
    semantic=semantic_regions() if name=='osmanthus' else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    raw=SOURCE/(name+('-rig' if name in BIRDS else '-original'))/'model.glb'
    bpy.ops.import_scene.gltf(filepath=str(raw))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name!='Icosphere']
    assert len(meshes)==1,[o.name for o in meshes]
    for obj in list(bpy.context.scene.objects):
        if obj.type=='MESH' and obj not in meshes: bpy.data.objects.remove(obj,do_unlink=True)
    high=meshes[0]; high.name=name+'_high'
    original=stats(high)
    points=[high.matrix_world@v.co for v in high.data.vertices]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    extent=hi-lo; pivot=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    factor=size/(max(extent.x,extent.y) if name in {'kitchen','pepper','slices'} else extent.z)
    rig=None; semantic_groups=[]; skin_repair=None
    if name in BIRDS:
        rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
        if name=='hen': skin_repair=repair_hen_feet(high,rig)
        root=bpy.data.objects.new(name+'_MetricRoot',None); bpy.context.collection.objects.link(root)
        for obj in list(bpy.context.scene.objects):
            if obj!=root and obj.parent is None: obj.parent=root
        root.matrix_world=Matrix.Scale(factor,4)@Matrix.Translation(-pivot)
        author_bird_motion(rig,name)
    else:
        bpy.context.view_layer.objects.active=high; high.select_set(True)
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        if name in PLANTS: semantic_groups=wind_weights(high,semantic)
        for vertex in high.data.vertices:
            p=(vertex.co-pivot)*factor
            vertex.co=Vector((p.y,-p.x,p.z))
    for material in high.data.materials:
        material.use_backface_culling=False
        for node in material.node_tree.nodes:
            if node.type=='BSDF_PRINCIPLED':
                node.inputs['Roughness'].default_value=.95
                node.inputs['Metallic'].default_value=0
                node.inputs['Specular IOR Level'].default_value=.08
    source_copy=high.copy();source_copy.data=high.data.copy();source_copy.name=name+'_source'
    bpy.context.collection.objects.link(source_copy); source_copy.hide_render=True;source_copy.hide_set(True)
    # Small repeated seedlings only: retain the full high source alongside the runtime copy.
    if name=='seedling': reduce_mesh(high,9000)
    low=high.copy();low.data=high.data.copy();low.name=name+'_low';bpy.context.collection.objects.link(low)
    reduce_mesh(low,budget)
    report=dict(blender=bpy.app.version_string,source=str(raw.relative_to(ROOT)),original=original,
        semantic_regions=semantic_groups,rig=rig.name if rig else None,meshes={})
    if skin_repair: report['foot_weight_repair']=skin_repair
    for obj in [high,low]:
        bpy.ops.object.select_all(action='DESELECT')
        obj.hide_set(False);obj.select_set(True);bpy.context.view_layer.objects.active=obj
        if rig: rig.select_set(True);root.select_set(True)
        path=OUT/(obj.name+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
             export_vertex_color='ACTIVE',export_animations=bool(rig),export_skins=bool(rig))
        report['meshes'][obj.name]=stats(obj)
        resource='res://'+str(path.relative_to(REPO/'Game')).replace('\\','/')
        cache='res://.godot/imported/'+path.name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.scn'
        # Rebuilding an existing asset must retain its Godot UID and import settings.
        if not path.with_suffix('.glb.import').exists():
            path.with_suffix('.glb.import').write_text('[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\npath="'+cache+'"\n\n[deps]\nsource_file="'+resource+'"\ndest_files=["'+cache+'"]\n\n[params]\nmeshes/generate_lods=false\n',encoding='utf-8')
    low.hide_render=True;low.hide_set(True)
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    for tier,result in report['meshes'].items():
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/(tier+'.glb')))
        obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
        assert stats(obj)['triangles']==result['triangles'] and len(obj.data.uv_layers)>0
        result['reimport_verified']=True
        result['textures']=[dict(name=im.name,size=list(im.size)) for im in bpy.data.images if im.type=='IMAGE']
        assert result['textures'] and all(min(im['size'])>0 for im in result['textures'])
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        bounds=[max(p[i] for p in points)-min(p[i] for p in points) for i in range(3)]
        result['dimensions_godot_xyz']=[bounds[0],bounds[2],bounds[1]]
    (SOURCE/(name+'-audit.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('COURTYARD_ASSET_READY',name)
