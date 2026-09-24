"""Metric cottage kit with painted atlas; never modifies the adopted main house."""
from pathlib import Path
import bpy,bmesh,json,math,importlib.util
from mathutils import Vector
SOURCE=Path(__file__).resolve().parent
ROOT=SOURCE.parents[2]
OUT=ROOT/'Game/art/environment/parametric_kit'
bpy.ops.wm.read_factory_settings(use_empty=True)
image=bpy.data.images.load(str(SOURCE/'house-material-atlas.png'))
material=bpy.data.materials.new('JiangnanPaintedAtlas'); material.use_nodes=True
bsdf=material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value=.96; bsdf.inputs['Specular IOR Level'].default_value=.08
texture=material.node_tree.nodes.new('ShaderNodeTexImage'); texture.image=image
material.node_tree.links.new(texture.outputs['Color'],bsdf.inputs['Base Color'])
parts={}
# Godot points are converted once to Blender's Z-up convention.
def point(v): return (v[0],-v[2],v[1])
def paint(obj,quadrant,variant=0):
    obj.data.materials.clear(); obj.data.materials.append(material)
    colour=obj.data.color_attributes.get('PigmentColor') or obj.data.color_attributes.new(name='PigmentColor',type='FLOAT_COLOR',domain='POINT')
    obj.data.color_attributes.active_color=colour
    tint=(.80,.80,.80,1) if quadrant==2 else (1,1,1,1)
    if obj.name.startswith(('Paper panes','Translucent upper paper')):tint=(1,.85,.58,1)
    for entry in colour.data:entry.color=tint
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='Paint')
    pts=[Vector((v.co.x,v.co.z,-v.co.y)) for v in obj.data.vertices]
    lo=Vector([min(v[i] for v in pts) for i in range(3)])
    hi=Vector([max(v[i] for v in pts) for i in range(3)])
    # UV quadrants: wood upper left, plaster upper right, tile lower left,
    # stone lower right. Keep a guard band away from neighbouring materials.
    origin=[(.025,.525),(.525,.525),(.025,.025),(.525,.025)][quadrant]
    for f in obj.data.polygons:
        n=Vector((f.normal.x,f.normal.z,-f.normal.y))
        drop=max(range(3),key=lambda i:abs(n[i]))
        axes=[i for i in range(3) if i!=drop]
        if 1 in axes: axes=[next(i for i in axes if i!=1),1]
        for li in f.loop_indices:
            v=pts[obj.data.loops[li].vertex_index]
            a=(v[axes[0]]-lo[axes[0]])/max(.001,hi[axes[0]]-lo[axes[0]])
            b=(v[axes[1]]-lo[axes[1]])/max(.001,hi[axes[1]]-lo[axes[1]])
            # Three roof pigments share one image; small swatches avoid borders.
            size=.45 if quadrant!=2 else .22
            shift=(variant%2)*.22 if quadrant==2 else 0
            uv.data[li].uv=(origin[0]+shift+size*a,origin[1]+(variant//2)*.22+size*b)
def box(name,size,at=(0,0,0),q=0,bevel=.012):
    bpy.ops.mesh.primitive_cube_add(size=1,location=point(at))
    o=bpy.context.object; o.name=name; o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft worn edge','BEVEL'); mod.width=min(bevel,min(size)*.22);mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    paint(o,q)
    return o
def merge(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    # All atlas regions use the same shader/material; collapse duplicate slots.
    for poly in o.data.polygons:poly.material_index=0
    o.data.materials.clear();o.data.materials.append(material)
    parts[name]=o;return o
def mesh(name,verts,faces,q):
    data=bpy.data.meshes.new(name);data.from_pydata([point(v) for v in verts],[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);paint(o,q)
    return o
merge('house_wall',[box('LimeWall',(1,1,1),q=1,bevel=0)])
merge('house_stone',[box('FoundationStone',(1,.35,.42),q=3,bevel=.035)])
merge('house_post',[box('TimberPost',(.18,1,.18),at=(0,.5,0),bevel=.015)])
merge('house_beam',[box('TimberBeam',(.17,.18,1),bevel=.012)])
merge('house_roof_deck',[box('RoofSheathing',(1,.028,1),q=2,bevel=0)])
# Unit triangular gable, front along +Z, bottom Y=0; scale across its base.
gable=mesh('LimeGable',[(-.5,0,-.5),(.5,0,-.5),(0,1,-.5),(-.5,0,.5),(.5,0,.5),(0,1,.5)],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],1)
merge('house_gable',[gable])
def window(name,pattern):
    group=[box('Paper panes',(1.08,.96,.025),(0,0,-.035),1,.002)]
    for x in [-.62,.62]:group.append(box('Window jamb',(.12,1.2,.15),(x,0,0),0))
    for y in [-.55,.55]:group.append(box('Window rail',(1.24,.12,.15),(0,y,0),0))
    for x in [-.36,0,.36]:group.append(box('Lattice upright',(.038,1.0,.046),(x,0,.07),0,.004))
    rows=[-.32,-.10,.12,.34] if pattern==0 else [-.34,.0,.34]
    for y in rows:group.append(box('Lattice rail',(1.15,.035,.045),(0,y,.075),0,.004))
    if pattern==1:
        for x in [-.52,-.18,.18,.52]:
            group.append(box('Small upper lattice',(.025,.32,.042),(x,.17,.076),0,.003))
    group.append(box('Window sill',(1.44,.11,.25),(0,-.62,.025),0))
    merge(name,group)
window('house_window_a',0);window('house_window_b',1)
door=[]
for x in [-.73,.73]:door.append(box('Door jamb',(.12,2.22,.19),(x,1.11,0),0))
door.append(box('Door header',(1.58,.14,.19),(0,2.18,0),0))
door.append(box('Door sill',(1.58,.09,.24),(0,.045,.025),3))
for side in [-1,1]:
    x=side*.35
    door.append(box('Door panel',(.66,2.08,.085),(x,1.10,-.025),0))
    door.append(box('Translucent upper paper',(.52,.91,.018),(x,1.66,.025),1,.002))
    for dx in [-.28,0,.28]:door.append(box('Door stile',(.045,2.00,.075),(x+dx,1.10,.045),0,.004))
    for y in [.12,1.16,2.12]:door.append(box('Door rail',(.64,.07,.08),(x,y,.05),0,.006))
    for y in [1.36,1.56,1.76,1.96]:door.append(box('Door lattice',(.54,.03,.055),(x,y,.058),0,.003))
    for dx in [-.14,.14]:door.append(box('Door lattice',(.028,.90,.055),(x+dx,1.66,.058),0,.003))
    for dx in [-.18,.18]:door.append(box('Lower moulding',(.020,.88,.03),(x+dx,.63,.035),0,.003))
    bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,location=point((side*.13,1.02,.15)),rotation=(math.pi/2,0,0),major_radius=.053,minor_radius=.009)
    ring=bpy.context.object;paint(ring,2);door.append(ring)
merge('house_door',door)
def tile(name,cap,variant=0,far=False):
    nx=7 if not far else 5;nz=4 if not far else 2
    width=.33 if not cap else .16;length=.50
    verts=[]
    for lower in [False,True]:
        for z in range(nz):
            t=z/(nz-1)
            for x in range(nx):
                u=x/(nx-1)
                arch=math.sin(u*math.pi)*(.060 if cap else -.045)
                y=arch+.009*math.sin(t*math.pi)-(.017 if lower else 0)
                verts.append(((u-.5)*width,y,(t-.5)*length))
    n=nx*nz;faces=[]
    for z in range(nz-1):
        for x in range(nx-1):
            a=z*nx+x;faces.extend([(a,a+nx,a+nx+1,a+1),(a+n,a+1+n,a+nx+1+n,a+nx+n)])
    rim=list(range(nx))+[z*nx+nx-1 for z in range(1,nz)]+list(range(n-2,n-nx-1,-1))+[z*nx for z in range(nz-2,0,-1)]
    for i,a in enumerate(rim):
        b=rim[(i+1)%len(rim)];faces.append((a,b,b+n,a+n))
    o=mesh(name,verts,faces,2);paint(o,2,variant)
    for p in o.data.polygons:p.use_smooth=True
    merge(name,[o])
for variant in range(3):
    for cap in [False,True]:
        for far in [False,True]:
            tile('house_tile_'+('cap' if cap else 'pan')+str(variant)+('_low' if far else ''),cap,variant,far)
# Ridge roll is also a curved ceramic shell, with a carved curl at either end.
curve=bpy.data.curves.new('RidgeCurl','CURVE');curve.dimensions='3D';curve.resolution_u=10;curve.bevel_depth=.09;curve.bevel_resolution=3;curve.use_fill_caps=True
spline=curve.splines.new('BEZIER')
positions=[(0,0,0),(.14,.025,0),(.28,.09,0),(.37,.22,0),(.34,.34,0),(.25,.38,0),(.20,.32,0)]
spline.bezier_points.add(len(positions)-1)
for p,v in zip(spline.bezier_points,positions):p.co=point(v);p.handle_left_type='AUTO';p.handle_right_type='AUTO'
o=bpy.data.objects.new('CeramicRidgeCurl',curve);bpy.context.collection.objects.link(o)
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
paint(o,2);merge('house_finial',[o])
# Low variants for detailed woodwork retain openings; only the near-only bevels
# and curl subdivision are simplified, not replaced by flat window paintings.
for name in ['house_window_a','house_window_b','house_door','house_finial']:
    src=parts[name];low=src.copy();low.data=src.data.copy();low.name=name+'_low';bpy.context.collection.objects.link(low)
    bpy.context.view_layer.objects.active=low
    bm=bmesh.new();bm.from_mesh(low.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bm.to_mesh(low.data);bm.free()
    mod=low.modifiers.new('Distant detail','DECIMATE');mod.ratio=.5;bpy.ops.object.modifier_apply(modifier=mod.name)
    parts[low.name]=low
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'house_modules.blend'))
report={'blender':bpy.app.version_string,'atlas':'house-material-atlas.png','tripo_calls':0,'units':'metres; Godot Y up, facade +Z','parts':{}}
for name,obj in parts.items():
    obj.data.calc_loop_triangles()
    report['parts'][name]={'triangles':len(obj.data.loop_triangles),'materials':len(obj.data.materials)}
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_vertex_color='ACTIVE')
for name in parts:
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    count=0
    for obj in meshes:
        obj.data.calc_loop_triangles();count+=len(obj.data.loop_triangles)
        assert obj.data.uv_layers and all(math.isfinite(c) for v in obj.data.vertices for c in v.co)
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        opened=sum(e.is_boundary for e in bm.edges)
        report['parts'][name]['open_edges_after_audit_weld']=opened
        assert opened==0,(name,opened)
        bm.free()
    assert count==report['parts'][name]['triangles']
    report['parts'][name]['reimport_verified']=True
spec=importlib.util.spec_from_file_location('glb_shared',ROOT/'scripts/share-glb-textures.py')
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
for name in parts:
    path=OUT/(name+'.glb');doc,binary=shared.read_glb(path);discard=set()
    for img in doc.get('images',[]):
        assert shared.image_bytes(doc,binary,img)==(SOURCE/'house-material-atlas.png').read_bytes()
        discard.add(img.pop('bufferView'));img.pop('mimeType',None);img['uri']='house_material_atlas.png'
    path.write_bytes(shared.encode_glb(doc,binary,discard))
(SOURCE/'house-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('HOUSE_KIT_VERIFIED',json.dumps(report))
