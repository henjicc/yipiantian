"""Solid railing posts and matching timber: reuse the immutable Tripo colour atlas."""
from pathlib import Path
import bpy, bmesh, json, math, importlib.util

SOURCE=Path(__file__).resolve().parent
ROOT=SOURCE.parents[2]
OUT=ROOT/'Game/art/environment/parametric_kit'
ATLAS=ROOT/'Game/art/environment/procedural_bridge/post_Color_18e92ae5-d11c-4987-81d4-babb51731181.jpg'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system='METRIC'
wood=bpy.data.materials.new('SharedWeatheredTimber');wood.use_nodes=True
bsdf=wood.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=.94
bsdf.inputs['Specular IOR Level'].default_value=.08
image=bpy.data.images.load(str(ATLAS))
tex=wood.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
wood.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
rope=bpy.data.materials.new('MutedHemp');rope.use_nodes=True
rope.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.40,.32,.20,1)
rope.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.98
parts={}

def uv_wood(obj,long_axis):
    """Use only clean timber in the atlas, never its hole/rope/shadow islands.

    No image pixels are edited or generated. U follows the length of every
    member, so uprights and horizontal/diagonal rails share the same fibres.
    """
    obj.data.materials.append(wood)
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='WoodGrain')
    uv.name='WoodGrain'
    lo=[min(v.co[i] for v in obj.data.vertices) for i in range(3)]
    hi=[max(v.co[i] for v in obj.data.vertices) for i in range(3)]
    for face in obj.data.polygons:
        transverse=max((i for i in range(3) if i!=long_axis),key=lambda i:1-abs(face.normal[i]))
        along_axis=long_axis
        if abs(face.normal[long_axis])>.9:
            along_axis,transverse=[i for i in range(3) if i!=long_axis]
        for li in face.loop_indices:
            v=obj.data.vertices[obj.data.loops[li].vertex_index].co
            along=(v[along_axis]-lo[along_axis])/max(.001,hi[along_axis]-lo[along_axis])
            across=(v[transverse]-(lo[transverse]+hi[transverse])*.5)/max(.17,hi[transverse]-lo[transverse])+.5
            if sum(face.normal)<0: along=1-along
            uv.data[li].uv=(.709+.146*along,.462+.118*across)

def bevel_box(name,dimensions,location,axis,bevel,segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object;obj.name=name;obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=obj.modifiers.new('Soft worked edges','BEVEL');mod.width=bevel;mod.segments=segments
    bpy.ops.object.modifier_apply(modifier=mod.name)
    uv_wood(obj,axis)
    return obj

def shaft(name,far):
    # An eight-sided worn square is solid at all heights and in every direction.
    section=[(-.065,-.085),(.065,-.085),(.085,-.065),(.085,.065),(.065,.085),(-.065,.085),(-.085,.065),(-.085,-.065)]
    heights=[0,.30,.58,.82] if not far else [0,.82]
    vertices=[]
    for k,z in enumerate(heights):
        for i,(x,y) in enumerate(section):
            wave=(0 if far else math.sin(i*2.13+k*1.7)*.003)
            vertices.append((x+wave,y+wave*.6,z))
    faces=[]
    for k in range(len(heights)-1):
        for i in range(8):faces.append((k*8+i,k*8+(i+1)%8,(k+1)*8+(i+1)%8,(k+1)*8+i))
    faces += [tuple(reversed(range(8))),tuple((len(heights)-1)*8+i for i in range(8))]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    uv_wood(obj,2)
    return obj

def post(name,far):
    objects=[shaft('SolidTimberShaft',far)]
    objects.append(bevel_box('WornPostCap',(.205,.205,.085),(0,0,.8575),2,.015,1 if far else 3))
    objects.append(bevel_box('PostNeck',(.183,.183,.038),(0,0,.807),2,.006,1 if far else 2))
    if not far:
        # Square lashings follow the actual post section; no fake mortise recess.
        for z in [.511,.527,.543]:
            curve=bpy.data.curves.new('HempLashing','CURVE');curve.dimensions='3D'
            curve.resolution_u=1;curve.bevel_depth=.008;curve.bevel_resolution=2
            points=[(-.063,-.093),(.063,-.093),(.093,-.063),(.093,.063),(.063,.093),(-.063,.093),(-.093,.063),(-.093,-.063)]
            line=curve.splines.new('POLY');line.points.add(len(points)-1);line.use_cyclic_u=True
            for p,(x,y) in zip(line.points,points):p.co=(x,y,z,1)
            obj=bpy.data.objects.new('HempLashing',curve);bpy.context.collection.objects.link(obj)
            bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
            bpy.ops.object.convert(target='MESH');obj.data.materials.append(rope);objects.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    result=bpy.context.object;result.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return result

parts['fence_post']=post('SolidFencePost',False)
parts['fence_post_low']=post('SolidFencePostFar',True)
# Blender Y becomes Godot -Z: symmetric endpoints make the sign immaterial.
parts['fence_rail']=bevel_box('MatchingWeatheredRail',(.085,1,.085),(0,0,0),1,.008,2)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'railing_modules.blend'))
report={'blender':bpy.app.version_string,'source_task':'18e92ae5-d11c-4987-81d4-babb51731181','new_tripo_calls':0,'new_images':0,'atlas':str(ATLAS.relative_to(ROOT)).replace('\\','/'),'wood_uv_rectangle':[.709,.462,.855,.580],'parts':{}}
for name,obj in parts.items():
    obj.data.calc_loop_triangles()
    report['parts'][name]={'triangles':len(obj.data.loop_triangles),'dimensions_blender':list(obj.dimensions),'materials':len(obj.data.materials)}
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True)
for name in parts:
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
    meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
    triangles=0
    for obj in meshes:
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
        assert obj.data.uv_layers and all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
        for face in obj.data.polygons:
            if not obj.data.materials[face.material_index].name.startswith('SharedWeatheredTimber'):continue
            for li in face.loop_indices:
                u,v=obj.data.uv_layers.active.data[li].uv
                assert .709-1e-6<=u<=.855+1e-6 and .462-1e-6<=v<=.580+1e-6,(name,'lost timber UV',u,v)
        report['parts'][name]['wood_uv_verified']=True
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        opened=sum(edge.is_boundary for edge in bm.edges);bm.free()
        assert opened==0,(name,opened)
        report['parts'][name]['open_edges']=opened
        if name.startswith('fence_post'):
            # Ray from every side at the old mortise height must hit an outer
            # solid wall, not the inner back face of an empty socket.
            from mathutils import Vector
            for z in [.20,.65,.70,.76]:
                for axis in [Vector((1,0,0)),Vector((-1,0,0)),Vector((0,1,0)),Vector((0,-1,0))]:
                    hit,point,normal,index=obj.ray_cast(axis*.3+Vector((0,0,z)),-axis)
                    assert hit and point.dot(axis)>.06,(name,z,point)
            report['parts'][name]['solid_side_rays']=16
    assert triangles==report['parts'][name]['triangles']
    report['parts'][name]['reimport_verified']=True
spec=importlib.util.spec_from_file_location('shared',ROOT/'scripts/share-glb-textures.py')
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
for name in parts:
    path=OUT/(name+'.glb');doc,binary=shared.read_glb(path);discard=set()
    for img in doc.get('images',[]):
        assert shared.image_bytes(doc,binary,img)==ATLAS.read_bytes()
        discard.add(img.pop('bufferView'));img.pop('mimeType',None)
        img['uri']='../procedural_bridge/'+ATLAS.name
    path.write_bytes(shared.encode_glb(doc,binary,discard))
(SOURCE/'railing-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('SOLID_RAILING_VERIFIED',json.dumps(report))
