"""Reproducible Blender preparation of the nine approved 3.2 generated assets."""
from pathlib import Path
import sys, json, bpy, bmesh
from mathutils import Vector

repo = Path(__file__).resolve().parents[2]
plan = json.loads((repo / 'ArtSource/Environment/production-plan.json').read_text(encoding='utf-8-sig'))
requested = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []

def clean(mesh):
    mesh.validate(clean_customdata=False)
    bm=bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()

for spec in plan:
    if requested and spec['id'] not in requested: continue
    folder=repo/spec['folder']; source=folder/'tripo-original/model.glb'
    if not source.exists():
        print('PENDING',spec['id']); continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    if len(meshes)>1: bpy.ops.object.join()
    high=bpy.context.object; high.name=spec['id']+'_high'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    clean(high.data)
    pts=[v.co.copy() for v in high.data.vertices]
    lo=Vector([min(p[i] for p in pts) for i in range(3)])
    hi=Vector([max(p[i] for p in pts) for i in range(3)])
    dim=hi-lo
    denominator=dim.z if spec['axis']=='height' else max(dim.x,dim.y)
    scale=spec['size']/denominator
    pivot=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,hi.z if spec['id']=='lantern' else lo.z))
    for v in high.data.vertices:
        p=(v.co-pivot)*scale
        v.co=Vector((p.y,-p.x,p.z))
    for mat in high.data.materials:
        if not mat.use_nodes: continue
        for node in mat.node_tree.nodes:
            if node.type=='BSDF_PRINCIPLED':
                node.inputs['Roughness'].default_value=.97
                node.inputs['Metallic'].default_value=0
                node.inputs['Specular IOR Level'].default_value=.08
    high.data.calc_loop_triangles()
    raw_tris=len(high.data.loop_triangles)
    low=high.copy(); low.data=high.data.copy(); low.name=spec['id']+'_low'
    bpy.context.collection.objects.link(low)
    bpy.context.view_layer.objects.active=low
    dec=low.modifiers.new('Same-source distant silhouette','DECIMATE')
    # Keep at least 45% for leaf edges / thin members, not blindly a tiny count.
    dec.ratio=min(1,max(.45,spec['low']/raw_tris))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    out=repo/('Game/art/decorations' if 'Decorations' in spec['folder'] else 'Game/art/environment')/spec['id']
    out.mkdir(parents=True,exist_ok=True)
    report={'source':str(source.relative_to(repo)).replace('\\','/'),'blender':bpy.app.version_string,
        'root':'top hanging loop' if spec['id']=='lantern' else 'ground bottom centre',
        'raw_triangles':raw_tris,'requested_triangles':spec['faces'],'meshes':{}}
    for obj in [high,low]:
        clean(obj.data)
        for face in obj.data.polygons: face.use_smooth=True
        obj.data.normals_split_custom_set([(0,0,0)]*len(obj.data.loops))
        bpy.context.view_layer.update(); obj.data.calc_loop_triangles()
        bm=bmesh.new(); bm.from_mesh(obj.data)
        report['meshes'][obj.name]={'triangles':len(obj.data.loop_triangles),
            'dimensions_godot_xyz':[obj.dimensions.x,obj.dimensions.z,obj.dimensions.y],
            'materials':len(obj.data.materials),'uv_layers':len(obj.data.uv_layers),
            'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),
            'loose_vertices':sum(not v.link_edges for v in bm.verts),
            'zero_area_faces':sum(f.calc_area()<1e-12 for f in bm.faces)}
        bm.free()
        bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.export_scene.gltf(filepath=str(out/(obj.name+'.glb')),export_format='GLB',use_selection=True)
    low.hide_render=True; low.hide_set(True)
    bpy.context.scene.unit_settings.system='METRIC'; bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(folder/(spec['id']+'.blend')))
    for name,stats in report['meshes'].items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(out/(name+'.glb')))
        objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
        for o in objects: o.data.calc_loop_triangles()
        assert sum(len(o.data.loop_triangles) for o in objects)==stats['triangles'],name
        stats['textures']=[{'name':im.name,'size':list(im.size)} for im in bpy.data.images if im.type=='IMAGE']
        assert stats['textures'] and all(min(t['size'])>0 for t in stats['textures']),name
        stats['reimport_verified']=True
    (folder/'asset-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('ASSET_READY',spec['id'],json.dumps(report['meshes']))
