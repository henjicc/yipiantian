"""Prepare immutable Tripo homestead islands, retain high source geometry.
Blender 5.2.2; 10 metre horizontal span; base pivot; Godot +Z front.
Usage: blender --background --python prepare.py -- willow bamboo cottage
"""
from pathlib import Path
import bpy,bmesh,json,sys
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
OUT=REPO/'Game/art/environment/islets'
OUT.mkdir(parents=True,exist_ok=True)
names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['willow','bamboo','cottage']

def stats(obj):
    obj.data.calc_loop_triangles()
    bm=bmesh.new();bm.from_mesh(obj.data)
    # Diagnose geometric continuity separately from the GLB's UV splits.
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    result={'triangles':len(obj.data.loop_triangles),'open_edges':sum(e.is_boundary for e in bm.edges),'zero_area_faces':sum(f.calc_area()<1e-12 for f in bm.faces),'materials':len(obj.data.materials),'uv_layers':len(obj.data.uv_layers)}
    bm.free();return result

for name in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    raw=list((ROOT/'20260918'/f'{name}-original').rglob('model.glb'))
    assert len(raw)==1,raw
    bpy.ops.import_scene.gltf(filepath=str(raw[0]))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(meshes)==1,meshes
    high=meshes[0];high.name=name+'_high';bpy.context.view_layer.objects.active=high
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    pts=[v.co.copy() for v in high.data.vertices]
    lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
    scale=10/max((hi-lo).x,(hi-lo).y);pivot=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    for v in high.data.vertices:
        p=(v.co-pivot)*scale;v.co=Vector((p.y,-p.x,p.z))
    for mat in high.data.materials:
        for node in mat.node_tree.nodes:
            if node.type=='BSDF_PRINCIPLED':
                node.inputs['Roughness'].default_value=.96
                node.inputs['Metallic'].default_value=0
                node.inputs['Specular IOR Level'].default_value=.08
    source=stats(high)
    low=high.copy();low.data=high.data.copy();low.name=name+'_low';bpy.context.collection.objects.link(low)
    bpy.context.view_layer.objects.active=low
    bm=bmesh.new();bm.from_mesh(low.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    bm.to_mesh(low.data);bm.free()
    low.data.calc_loop_triangles()
    dec=low.modifiers.new('Distant homestead silhouette','DECIMATE');dec.ratio=min(1,24000/len(low.data.loop_triangles))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    # Decimation can leave invalid near-zero loops; resolve them on the work
    # copy before export, rather than accepting exporter-side silent removal.
    low.data.validate(clean_customdata=False)
    bm=bmesh.new();bm.from_mesh(low.data)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bm.to_mesh(low.data);bm.free();low.data.update()
    for p in low.data.polygons:p.use_smooth=True
    low.data.normals_split_custom_set([(0,0,0)]*len(low.data.loops))
    report={'blender':bpy.app.version_string,'source':str(raw[0].relative_to(ROOT)),'width_metres':10,'mesh':{}}
    for obj in [high,low]:
        result=stats(obj);assert result['zero_area_faces']==0,result
        bpy.context.view_layer.update();result['dimensions_godot_xyz']=[obj.dimensions.x,obj.dimensions.z,obj.dimensions.y]
        report['mesh'][obj.name]=result
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
        bpy.ops.export_scene.gltf(filepath=str(OUT/(obj.name+'.glb')),export_format='GLB',use_selection=True)
    low.hide_render=True;low.hide_set(True);bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'20260918'/(name+'.blend')))
    for tier,result in report['mesh'].items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(OUT/(tier+'.glb')))
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
        assert len(objects)==1 and stats(objects[0])['triangles']==result['triangles']
        textures=[{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.type=='IMAGE']
        assert textures and all(min(im['size'])>0 for im in textures)
        result['textures']=textures;result['reimport_verified']=True
    (ROOT/'20260918'/(name+'-audit.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('ISLET_READY',name,json.dumps(report))
