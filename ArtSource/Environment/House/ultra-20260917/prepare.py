"""Rebuild the adopted H3.1 Ultra house from its immutable raw GLB.

Blender 5.2; replaces this version's source/audit and the two formal house GLBs.
The legacy house source and its fitted ridge repair remain untouched.
"""
from pathlib import Path
import bpy,bmesh,json
from mathutils import Vector
root=Path(__file__).resolve().parent
repo=root.parents[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root/'raw/model.glb'))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(objects)==1
high=objects[0];high.name='house_high';bpy.context.view_layer.objects.active=high
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
def clean(obj):
    obj.data.validate(clean_customdata=False)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
    bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    obj.data.validate(clean_customdata=False);obj.data.update()
clean(high)
pts=[v.co.copy() for v in high.data.vertices]
lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
scale=7.2/max((hi-lo).x,(hi-lo).y);pivot=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
for v in high.data.vertices:
    p=(v.co-pivot)*scale;v.co=Vector((p.y,-p.x,p.z))
for mat in high.data.materials:
    for n in mat.node_tree.nodes:
        if n.type=='BSDF_PRINCIPLED':
            n.inputs['Roughness'].default_value=.97;n.inputs['Metallic'].default_value=0;n.inputs['Specular IOR Level'].default_value=.08
high.data.calc_loop_triangles()
low=high.copy();low.data=high.data.copy();low.name='house_low';bpy.context.collection.objects.link(low)
bpy.context.view_layer.objects.active=low
dec=low.modifiers.new('Same-source distant architecture','DECIMATE');dec.ratio=18000/len(high.data.loop_triangles)
bpy.ops.object.modifier_apply(modifier=dec.name);clean(low)
for p in low.data.polygons:p.use_smooth=True
low.data.normals_split_custom_set([(0,0,0)]*len(low.data.loops))
out=repo/'Game/art/environment/house';out.mkdir(parents=True,exist_ok=True)
report={'source':'raw/model.glb','blender':bpy.app.version_string,'requested_triangles':60000,'raw_triangles':len(high.data.loop_triangles),'godot_import':'Disable automatic LOD; retain authored 54434/18000 tiers.','meshes':{}}
for ob in [high,low]:
    ob.data.calc_loop_triangles();bpy.context.view_layer.update();bm=bmesh.new();bm.from_mesh(ob.data)
    stats=dict(triangles=len(ob.data.loop_triangles),dimensions_godot_xyz=[ob.dimensions.x,ob.dimensions.z,ob.dimensions.y],materials=len(ob.data.materials),uv_layers=len(ob.data.uv_layers),non_manifold_edges=sum(not e.is_manifold for e in bm.edges),loose_vertices=sum(not v.link_edges for v in bm.verts),zero_area_faces=sum(f.calc_area()<1e-12 for f in bm.faces));bm.free()
    assert stats['loose_vertices']==0 and stats['zero_area_faces']==0
    report['meshes'][ob.name]=stats
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
    bpy.ops.export_scene.gltf(filepath=str(out/(ob.name+'.glb')),export_format='GLB',use_selection=True)
low.hide_render=True;low.hide_set(True);bpy.context.scene.unit_settings.system='METRIC';bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(root/'house.blend'))
for name,stats in report['meshes'].items():
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/(name+'.glb')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for ob in meshes:ob.data.calc_loop_triangles()
    assert sum(len(o.data.loop_triangles) for o in meshes)==stats['triangles']
    stats['textures']=[{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.type=='IMAGE']
    assert stats['textures'] and all(min(im['size'])>0 for im in stats['textures']);stats['reimport_verified']=True
(root/'asset-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('HOUSE_ULTRA_READY',json.dumps(report))
