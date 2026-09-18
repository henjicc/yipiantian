"""Normalize immutable Tripo food models for Godot. Blender 5.2.2, no decimation.
blender --background --python-exit-code 1 --python ArtSource/Environment/Kitchen/prepare.py
"""
from pathlib import Path
import bpy, bmesh, json, hashlib, importlib.util, sys
from mathutils import Vector
sys.dont_write_bytecode = True

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
SOURCE=ROOT/'20260918'
OUT=REPO/'Game/art/environment/kitchen'
OUT.mkdir(parents=True,exist_ok=True)
SPECS={'stir_fry':.42,'root_soup':.40,'pickled_greens':.38}
audit_path=REPO/'.agents/skills/blender-3d-asset-generation/scripts/audit_blender_asset.py'
spec=importlib.util.spec_from_file_location('asset_audit',audit_path)
audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)

def geometry(obj):
    obj.data.calc_loop_triangles()
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    result=dict(triangles=len(obj.data.loop_triangles),open_edges=sum(e.is_boundary for e in bm.edges),
                zero_area_faces=sum(f.calc_area()<1e-12 for f in bm.faces))
    bm.free();return result

for name,width in SPECS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    raw=next((SOURCE/(name+'-original')).rglob('model.glb'))
    bpy.ops.import_scene.gltf(filepath=str(raw))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert len(objects)==1
    obj=objects[0];bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    points=[v.co.copy() for v in obj.data.vertices]
    lo=Vector([min(p[i] for p in points) for i in range(3)])
    hi=Vector([max(p[i] for p in points) for i in range(3)])
    pivot=Vector(((lo.x+hi.x)*.5,(lo.y+hi.y)*.5,lo.z))
    factor=width/max(hi.x-lo.x,hi.y-lo.y)
    for vertex in obj.data.vertices:
        p=(vertex.co-pivot)*factor
        vertex.co=Vector((p.y,-p.x,p.z))
    obj.name=name
    for material in obj.data.materials:
        material.use_backface_culling=False
        for node in material.node_tree.nodes:
            if node.type=='BSDF_PRINCIPLED':
                node.inputs['Roughness'].default_value=.9
                node.inputs['Metallic'].default_value=0
                node.inputs['Specular IOR Level'].default_value=.08
    report=dict(blender=bpy.app.version_string,source=str(raw.relative_to(ROOT)),geometry=geometry(obj),width=width)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    original_args=sys.argv
    sys.argv=['blender','--','--output',str(SOURCE/(name+'-blender-audit.json')),'--require-uv','--require-applied-scale']
    assert audit.main()==0
    sys.argv=original_args
    path=OUT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False)
    resource='res://'+path.relative_to(REPO/'Game').as_posix()
    cache='res://.godot/imported/'+path.name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.scn'
    path.with_suffix('.glb.import').write_text('[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\npath="'+cache+'"\n\n[deps]\nsource_file="'+resource+'"\ndest_files=["'+cache+'"]\n\n[params]\nmeshes/generate_lods=false\n',encoding='utf-8')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
    assert geometry(mesh)['triangles']==report['geometry']['triangles'] and mesh.data.uv_layers
    report['reimport_verified']=True
    report['textures']=[dict(name=im.name,size=list(im.size)) for im in bpy.data.images if im.type=='IMAGE']
    assert report['textures'] and all(min(im['size'])>0 for im in report['textures'])
    (SOURCE/(name+'-audit.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('KITCHEN_ASSET_READY',name)
