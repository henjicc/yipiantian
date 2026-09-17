"""Rebuild five image-guided Tripo stones and their shared runtime colour atlas.
Run with Blender 5.2.2 --background --python-exit-code 1 --python this_file.py. Raw inputs stay immutable.
"""
from pathlib import Path
import bpy, bmesh, json
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
OUT = REPO / 'Game/art/environment/modules'
NAMES = ['boulder', 'flat', 'long', 'round', 'cleft']
BUDGETS = [1500, 800, 1300, 1000, 1600]
HEIGHTS = [.27, .12, .22, .22, .34]
bpy.ops.wm.read_factory_settings(use_empty=True)
atlas_pixels = np.zeros((2048, 2048, 4), dtype=np.float32)
atlas_pixels[:, :, 3] = 1
report = {'blender': bpy.app.version_string, 'atlas': [2048,2048], 'meshes': {}}
prepared = []
for index, name in enumerate(NAMES):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/name/'raw/model.glb'))
    objects = [o for o in bpy.data.objects if o not in before and o.type == 'MESH']
    assert len(objects) == 1, (name, len(objects))
    obj = objects[0]
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.name = f'stone_{index}'
    bm = bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bmesh.ops.triangulate(bm, faces=list(bm.faces)); bm.to_mesh(obj.data); bm.free()
    obj.data.calc_loop_triangles()
    raw_triangles = len(obj.data.loop_triangles)
    points = [v.co for v in obj.data.vertices]
    low = Vector([min(p[k] for p in points) for k in range(3)])
    high = Vector([max(p[k] for p in points) for k in range(3)])
    span = high-low
    # The measured scene already stretches its bedding stones vertically at the
    # shore. Preserve each horizontal outline, with role-specific bedding height.
    horizontal = .95 / max(span.x, span.y)
    pivot = Vector(((low.x+high.x)/2, (low.y+high.y)/2, low.z))
    for vertex in obj.data.vertices:
        p = vertex.co-pivot
        vertex.co = Vector((p.x*horizontal, p.y*horizontal, p.z*HEIGHTS[index]/span.z))
    textures = [n.image for mat in obj.data.materials for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]
    assert len(textures) == 1, (name, len(textures))
    image = textures[0]
    original_texture = list(image.size)
    image.scale(640,640)
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(640,640,4)
    x = (index % 3)*672+16; y = (index//3)*672+16
    atlas_pixels[y-16:y+656,x-16:x+656] = np.pad(pixels,((16,16),(16,16),(0,0)),mode='edge')
    for uv in obj.data.uv_layers.active.data:
        uv.uv.x = (x + uv.uv.x*640)/2048
        uv.uv.y = (y + uv.uv.y*640)/2048
    decimate = obj.modifiers.new('Runtime silhouette budget','DECIMATE')
    decimate.ratio = BUDGETS[index]/raw_triangles
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    bm=bmesh.new(); bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=1e-7)
    bmesh.ops.triangulate(bm, faces=list(bm.faces)); bm.to_mesh(obj.data); bm.free()
    for polygon in obj.data.polygons: polygon.use_smooth=True
    if obj.data.has_custom_normals: obj.data.normals_split_custom_set([(0,0,0)]*len(obj.data.loops))
    obj.data.update(); obj.data.calc_loop_triangles()
    bm=bmesh.new(); bm.from_mesh(obj.data)
    stats={'source':name,'raw_triangles':raw_triangles,'runtime_triangles':len(obj.data.loop_triangles),'original_texture':original_texture,'uv_layers':len(obj.data.uv_layers),'non_manifold_edges':sum(not e.is_manifold for e in bm.edges),'loose_vertices':sum(not v.link_faces for v in bm.verts),'zero_area_faces':sum(f.calc_area()<1e-12 for f in bm.faces)}
    bm.free()
    assert stats['loose_vertices']==0 and stats['zero_area_faces']==0
    report['meshes'][obj.name]=stats
    prepared.append(obj)

atlas=bpy.data.images.new('river_stones_color',width=2048,height=2048,alpha=False)
atlas.pixels.foreach_set(atlas_pixels.ravel())
atlas.filepath_raw=str(OUT/'river_stones_color.png'); atlas.file_format='PNG'; atlas.save()
material=bpy.data.materials.new('River stone painted atlas'); material.use_nodes=True
bsdf=material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=.96; bsdf.inputs['Specular IOR Level'].default_value=.08
texture=material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=atlas
material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])
for obj in prepared:
    obj.data.materials.clear(); obj.data.materials.append(material)
    bpy.context.view_layer.update()
    report['meshes'][obj.name]['dimensions_godot_xyz']=[obj.dimensions.x,obj.dimensions.z,obj.dimensions.y]
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(obj.name+'.glb')),export_format='GLB',use_selection=True)
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'river_stones.blend'))
for name,stats in report['meshes'].items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for obj in meshes: obj.data.calc_loop_triangles()
    assert sum(len(o.data.loop_triangles) for o in meshes)==stats['runtime_triangles']
    assert len(meshes)==1 and len(meshes[0].data.materials)==1
    images=[im for im in bpy.data.images if im.type=='IMAGE']
    assert len(images)==1 and list(images[0].size)==[2048,2048]
    stats['reimport_verified']=True
(ROOT/'asset-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('ROCKS_PREPARED',json.dumps(report))
