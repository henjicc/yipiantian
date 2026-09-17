"""Blender 5.2: immutable Tripo references -> audited island/plant runtime tiers.
Run: blender --background --python-exit-code 1 --python prepare.py -- <names>
"""
from pathlib import Path
import bpy, bmesh, json, sys, hashlib
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
SOURCE = ROOT / '20260918'
OUT = REPO / 'Game/art/environment/archipelago'
OUT.mkdir(parents=True, exist_ok=True)
PLANTS = {'reed': (1.35, 6000, 1800), 'cattail': (1.05, 5500, 1600), 'trapa': (.52, 3500, 1200)}
NAMES = ['rice_hamlet', 'mulberry_court', 'bamboo_inlet', 'canal_courts', 'willow_meadow', *PLANTS]

def stats(obj):
    obj.data.calc_loop_triangles()
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    result = dict(triangles=len(obj.data.loop_triangles), open_edges=sum(e.is_boundary for e in bm.edges),
                  zero_area_faces=sum(f.calc_area() < 1e-12 for f in bm.faces),
                  materials=len(obj.data.materials), uv_layers=len(obj.data.uv_layers))
    bm.free()
    return result

def reduce_mesh(obj, budget):
    bpy.context.view_layer.objects.active = obj
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    bm.to_mesh(obj.data); bm.free()
    obj.data.calc_loop_triangles()
    if len(obj.data.loop_triangles) > budget:
        modifier = obj.modifiers.new('Preserve silhouette at viewing size', 'DECIMATE')
        modifier.ratio = budget / len(obj.data.loop_triangles)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.validate(clean_customdata=False)
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(obj.data); bm.free(); obj.data.update()
    for polygon in obj.data.polygons: polygon.use_smooth = True
    obj.data.normals_split_custom_set([(0, 0, 0)] * len(obj.data.loops))

for name in (sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else NAMES):
    assert name in NAMES
    raw = SOURCE / (name+'-original') / 'model.glb'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(raw))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assert len(objects) == 1, [o.name for o in objects]
    high = objects[0]; high.name = name+'_high'
    bpy.context.view_layer.objects.active = high
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    original = stats(high)
    points = [v.co.copy() for v in high.data.vertices]
    lo = Vector([min(p[i] for p in points) for i in range(3)])
    hi = Vector([max(p[i] for p in points) for i in range(3)])
    extent = hi-lo
    metric = (extent.z if name != 'trapa' else max(extent.x, extent.y)) if name in PLANTS else max(extent.x, extent.y)
    size = PLANTS[name][0] if name in PLANTS else 10.0
    pivot = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
    for vertex in high.data.vertices:
        p = (vertex.co-pivot)*(size/metric)
        vertex.co = Vector((p.y, -p.x, p.z))
    # Keep the immutable full mesh in the .blend even for repeatedly drawn plants.
    source_copy = high.copy(); source_copy.data=high.data.copy(); source_copy.name=name+'_source'
    bpy.context.collection.objects.link(source_copy)
    source_copy.hide_render=True; source_copy.hide_set(True)
    for material in high.data.materials:
        for node in material.node_tree.nodes:
            if node.type == 'BSDF_PRINCIPLED':
                node.inputs['Roughness'].default_value=.96
                node.inputs['Metallic'].default_value=0
                node.inputs['Specular IOR Level'].default_value=.08
    if name in PLANTS: reduce_mesh(high, PLANTS[name][1])
    low = high.copy(); low.data=high.data.copy(); low.name=name+'_low'
    bpy.context.collection.objects.link(low)
    reduce_mesh(low, PLANTS[name][2] if name in PLANTS else 14000)
    report = dict(blender=bpy.app.version_string, source=str(raw.relative_to(ROOT)), original=original, mesh={})
    for obj in [high, low]:
        result = stats(obj)
        assert result['zero_area_faces'] == 0 and result['uv_layers'] > 0, result
        bpy.context.view_layer.update()
        result['dimensions_godot_xyz']=[obj.dimensions.x,obj.dimensions.z,obj.dimensions.y]
        report['mesh'][obj.name]=result
        bpy.ops.object.select_all(action='DESELECT'); obj.hide_set(False); obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        path=OUT/(obj.name+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True)
        # Import sidecars are formal settings, not the .godot cache.
        resource='res://'+str(path.relative_to(REPO/'Game')).replace('\\','/')
        cache='res://.godot/imported/'+path.name+'-'+hashlib.md5(resource.encode()).hexdigest()+'.scn'
        settings=path.with_suffix('.glb.import')
        if not settings.exists():
            settings.write_text('[remap]\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\npath="'+cache+'"\n\n[deps]\nsource_file="'+resource+'"\ndest_files=["'+cache+'"]\n\n[params]\nmeshes/generate_lods=false\n',encoding='utf-8')
    low.hide_render=True; low.hide_set(True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    for tier, result in report['mesh'].items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(OUT/(tier+'.glb')))
        imported=[o for o in bpy.context.scene.objects if o.type=='MESH']
        assert len(imported)==1 and stats(imported[0])['triangles']==result['triangles']
        result['textures']=[dict(name=im.name,size=list(im.size)) for im in bpy.data.images if im.type=='IMAGE']
        assert result['textures'] and all(min(im['size'])>0 for im in result['textures'])
        result['reimport_verified']=True
    (SOURCE/(name+'-audit.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('ARCHIPELAGO_READY',name,json.dumps(report))
