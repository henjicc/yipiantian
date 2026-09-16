"""Fill the visible ridge underside slit with a fitted clay closure, preserving raw Tripo."""
from pathlib import Path
import bpy, bmesh, json
folder=Path(__file__).resolve().parent;repo=folder.parents[2]
bpy.ops.wm.open_mainfile(filepath=str(folder/'house.blend'))
report=json.loads((folder/'asset-audit.json').read_text(encoding='utf-8'))
mat=bpy.data.objects['house_high'].data.materials[0].copy()
mat.name='Ridge clay infill texture'
# Tiny end closures have too little UV area for a stretched source atlas patch.
# Match its dark grey clay value instead; retain original roof texture everywhere else.
p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for link in list(p.inputs['Base Color'].links):mat.node_tree.links.remove(link)
p.inputs['Base Color'].default_value=(.075,.083,.072,1)
for name in ['house_high','house_low']:
    obj=bpy.data.objects[name]
    # Safe repeat execution: replace only the previous authored closure material.
    if obj.get('ridge_repaired'):
        bm=bmesh.new();bm.from_mesh(obj.data)
        indices=[i for i,m in enumerate(obj.data.materials) if m and m.name.startswith('Ridge clay infill')]
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index in indices],context='FACES')
        bmesh.ops.delete(bm,geom=[v for v in bm.verts if not v.link_faces],context='VERTS')
        bm.to_mesh(obj.data);bm.free()
    obj.hide_set(False);obj.hide_render=False
    verts=[];faces=[]
    for side in [-1,1]:
        offset=len(verts)
        for x,z in [(side*2.08,4.35),(side*2.53,4.44)]:
            verts.extend([(x,.07,4.10),(x,.36,4.10),(x,.36,z),(x,.07,z)])
        for face in [(3,2,1,0),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:faces.append(tuple(v+offset for v in face))
    data=bpy.data.meshes.new('Fitted ridge closure');data.from_pydata(verts,[],faces);data.materials.append(mat)
    patch=bpy.data.objects.new('Clay ridge underside',data);bpy.context.collection.objects.link(patch)
    bpy.ops.object.select_all(action='DESELECT');patch.select_set(True);obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
    used={p.material_index for p in obj.data.polygons}
    for i in reversed(range(len(obj.data.materials))):
        if i not in used:obj.data.materials.pop(index=i)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    obj['ridge_repaired']=True;obj.data.calc_loop_triangles()
    report['meshes'][name]['triangles']=len(obj.data.loop_triangles);report['meshes'][name]['materials']=len(obj.data.materials)
    bpy.ops.export_scene.gltf(filepath=str(repo/'Game/art/environment/house'/(name+'.glb')),export_format='GLB',use_selection=True)
bpy.data.objects['house_low'].hide_set(True);bpy.data.objects['house_low'].hide_render=True
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(folder/'house.blend'))
report['ridge_repair']={'method':'Two fitted 12 triangle clay closures inside the raised ridge ends; raw unchanged','date':'2026-09-17'}
for name in ['house_high','house_low']:
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(repo/'Game/art/environment/house'/(name+'.glb')))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in objects:o.data.calc_loop_triangles()
    assert sum(len(o.data.loop_triangles) for o in objects)==report['meshes'][name]['triangles']
    report['meshes'][name]['reimport_verified']=True
(folder/'asset-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('RIDGE_REPAIR',report['ridge_repair'])
