"""Metric bamboo components. Blender Z-up -> Godot Y-up, poles along Godot Z."""
from pathlib import Path
import bpy
import json
import math
import importlib.util
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parents[2]
OUT = ROOT / 'Game/art/environment/parametric_kit'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'

def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = .94
    node.inputs['Specular IOR Level'].default_value = .06
    return mat

bamboo = material('GongbiBambooSkin', (.50, .56, .42))
node_mat = material('GongbiBambooNode', (.46, .49, .37))
rope = material('GongbiHempBinding', (.48, .42, .32))
cut = material('GongbiBambooCut', (.62, .58, .42))
ATLAS = OUT / 'bamboo_gongbi_atlas.png'
image = bpy.data.images.load(str(ATLAS))
image.pack()
color_factors = {mat.name:list(mat.diffuse_color) for mat in [bamboo,node_mat,rope,cut]}
for mat in [bamboo, node_mat, rope, cut]:
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = image
    tint = mat.node_tree.nodes.new('ShaderNodeMixRGB'); tint.blend_type = 'MULTIPLY'
    tint.inputs[0].default_value = 1
    tint.inputs[2].default_value = mat.diffuse_color
    mat.node_tree.links.new(tex.outputs['Color'], tint.inputs[1])
    mat.node_tree.links.new(tint.outputs[0], bsdf.inputs['Base Color'])
    # No alpha connection, bump, normal or extra roughness map.

def lathe(name, profile, sides, mat):
    verts, faces = [], []
    for y, radius in profile:
        for j in range(sides):
            a = j * math.tau / sides
            verts.append((radius * math.cos(a), y, radius * math.sin(a)))
    for k in range(len(profile)-1):
        for j in range(sides):
            a = k*sides+j; b = k*sides+(j+1)%sides
            faces.append((a,a+sides,b+sides,b))
    faces += [tuple(range(sides)), tuple((len(profile)-1)*sides+j for j in reversed(range(sides)))]
    mesh = bpy.data.meshes.new(name); mesh.from_pydata(verts, [], faces); mesh.update()
    obj = bpy.data.objects.new(name, mesh); bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat); mesh.materials.append(cut)
    uv = mesh.uv_layers.new(name='GongbiAtlas')
    for poly in mesh.polygons:
        poly.use_smooth = len(poly.vertices) == 4
        if not poly.use_smooth: poly.material_index = 1
        seam = poly.use_smooth and {mesh.loops[li].vertex_index%sides for li in poly.loop_indices} == {0,sides-1}
        for li in poly.loop_indices:
            idx = mesh.loops[li].vertex_index
            x, y, z = verts[idx]
            if not poly.use_smooth:
                # Lower-left quadrant: radial cut, never a collapsed UV line.
                radius = profile[0 if y<0 else -1][1]
                uv.data[li].uv = (.25+.222*x/radius, .268+.222*z/radius)
            else:
                across = (idx%sides)/sides
                if seam and idx%sides == 0: across = 1.0
                # Mirrored circumference keeps the two seam edges identical.
                across = 1-abs(across*2-1)
                along = (y-profile[0][0])/(profile[-1][0]-profile[0][0])
                if mat == node_mat:
                    uv.data[li].uv = (.65+.20*along,.52+.46*across)
                else:
                    uv.data[li].uv = (.02+.46*along,.59+.29*across)
    return obj

parts = {}
parts['bamboo'] = lathe('BambooInternode', [(-.5,.040),(-.48,.043),(-.25,.041),(0,.039),(.25,.041),(.48,.043),(.5,.040)], 14, bamboo)
parts['bamboo_low'] = lathe('BambooInternodeFar', [(-.5,.042),(0,.039),(.5,.042)], 8, bamboo)
parts['node'] = lathe('BambooNode', [(-.012,.041),(-.007,.045),(0,.046),(.007,.045),(.012,.041)], 16, node_mat)
for poly in parts['node'].data.polygons: poly.material_index=0
# A binding cuff, including several rope turns and a small tuck. Its centre sits
# over crossing poles; runtime rotates it to each actual joint.
binding = []
for j in range(4):
    bpy.ops.mesh.primitive_torus_add(major_segments=20, minor_segments=6, location=(0, (j-1.5)*.014, 0), rotation=(math.pi/2,0,0), major_radius=.070, minor_radius=.010)
    obj=bpy.context.object; obj.data.materials.append(rope); binding.append(obj)
    # Torus U follows the rope around the pole. Sample only the clean upper
    # part of the rope quadrant; the source's outer background is never used.
    uv=obj.data.uv_layers.active; uv.name='GongbiAtlas'
    for loop in uv.data:
        u,v=loop.uv
        loop.uv=(.52+.46*u,.30+.17*(1-abs(v*2-1)))
bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1, location=(0,.014,.075))
tuck=bpy.context.object; tuck.scale=(.020,.032,.014); tuck.data.materials.append(rope); binding.append(tuck)
uv=tuck.data.uv_layers.active; uv.name='GongbiAtlas'
for loop in uv.data:
    u,v=loop.uv; loop.uv=(.55+.40*u,.32+.12*v)
bpy.ops.object.select_all(action='DESELECT')
for obj in binding: obj.select_set(True)
bpy.context.view_layer.objects.active=binding[0]; bpy.ops.object.join()
parts['binding']=bpy.context.object; parts['binding'].name='HempBinding'
bpy.context.scene.cursor.location=(0,0,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
for poly in parts['binding'].data.polygons: poly.use_smooth=True

bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'bamboo_modules.blend'))
report={'blender':bpy.app.version_string,'parts':{},'new_tripo_calls':0,'texture_source':ATLAS.relative_to(ROOT).as_posix(), 'normal_maps':0, 'roughness_maps':0, 'color_factors_linear':color_factors}
for name, obj in parts.items():
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    obj.data.calc_loop_triangles()
    report['parts'][name]={'triangles':len(obj.data.loop_triangles),'dimensions_blender':list(obj.dimensions),'uv':bool(obj.data.uv_layers)}
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for name in parts:
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
    meshes=[o for o in set(bpy.context.scene.objects)-before if o.type=='MESH']
    triangles=0
    for obj in meshes:
        obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
        assert obj.data.uv_layers
        assert all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
        assert all(n.image for mat in obj.data.materials for n in mat.node_tree.nodes if n.type=='TEX_IMAGE')
    assert triangles==report['parts'][name]['triangles']
    report['parts'][name]['reimport_verified']=True
# Link new files to existing identical runtime textures. Reuse the project's GLB
# packing implementation; source .blend keeps its packed images for editing.
spec=importlib.util.spec_from_file_location('glb_shared',ROOT/'scripts/share-glb-textures.py')
shared=importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)
for name in parts:
    path=OUT/(name+'.glb'); doc, binary=shared.read_glb(path)
    discard=set()
    for img in doc.get('images',[]):
        payload=shared.image_bytes(doc,binary,img)
        assert payload == ATLAS.read_bytes(), name
        discard.add(img.pop('bufferView')); img.pop('mimeType',None)
        img['uri']=ATLAS.name
    # Blender's exporter omits this legacy MixRGB multiplier. Preserve the
    # authored source factor explicitly, as in prepare_railing.py.
    for mat in doc['materials']:
        assert 'normalTexture' not in mat
        pbr=mat['pbrMetallicRoughness']
        assert 'metallicRoughnessTexture' not in pbr
        pbr['baseColorFactor']=color_factors[mat['name']]
    if discard: path.write_bytes(shared.encode_glb(doc,binary,discard))
(SOURCE/'audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PARAMETRIC_MODULES_VERIFIED',json.dumps(report))
