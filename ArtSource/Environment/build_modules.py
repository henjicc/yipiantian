"""3.2 measured courtyard modules: authored geometry, not generated scenery."""
from pathlib import Path
import bpy, bmesh, math, random, json, argparse, sys
from mathutils import Vector

repo=Path(__file__).resolve().parents[2]
folder=repo/'ArtSource/Environment/Modules'; folder.mkdir(exist_ok=True)
out=repo/'Game/art/environment/modules'; out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(32026)
args=argparse.ArgumentParser()
args.add_argument('--only', nargs='+', help='Rebuild the source scene but export/audit only these modules.')
options=args.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
reports={}
existing_reports=json.loads((folder/'asset-audit.json').read_text(encoding='utf-8')) if options.only else {}

def mat(name,color):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.97; p.inputs['Specular IOR Level'].default_value=.08
    return m
stone=[mat('River limestone '+str(i),c) for i,c in enumerate([(0.48,.50,.43),(.58,.58,.50),(.66,.65,.55),(.43,.47,.41),(.55,.59,.51)])]
clay=mat('Earth cut',(.32,.30,.20)); grass=mat('Sage bank',(.47,.53,.32))
timber=mat('Aged tea timber',(.33,.24,.15)); bamboo=mat('Dry bamboo',(.52,.46,.27))
ivory=mat('Lime plaster',(.84,.83,.72)); dark=mat('Window recess',(.16,.20,.17))
tiles=[mat('Gray clay tile '+str(i),c) for i,c in enumerate([(.30,.35,.32),(.37,.41,.36),(.42,.44,.37),(.27,.31,.29)])]

def mesh(name,verts,faces,material):
    d=bpy.data.meshes.new(name); d.from_pydata(verts,[],faces); d.update()
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); d.materials.append(material); return o
def box(name,loc,scale,material,bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(material)
    if bevel:
        m=o.modifiers.new('Hand softened corners','BEVEL'); m.width=bevel; m.segments=2
        bpy.ops.object.modifier_apply(modifier=m.name)
    return o
def pole(name,a,b,r,material):
    a=Vector(a); b=Vector(b); d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=d.length,location=(a+b)/2)
    o=bpy.context.object; o.name=name; o.rotation_euler=d.to_track_quat('Z','Y').to_euler(); o.data.materials.append(material)
    return o
def save(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    if len(objects)>1:bpy.ops.object.join()
    o=bpy.context.object; o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new(); bm.from_mesh(o.data); bmesh.ops.triangulate(bm,faces=list(bm.faces)); bm.to_mesh(o.data); bm.free()
    o.data.calc_loop_triangles()
    bpy.context.view_layer.update()
    if not options.only or name in options.only:
        reports[name]={'triangles':len(o.data.loop_triangles),'dimensions_godot_xyz':[o.dimensions.x,o.dimensions.z,o.dimensions.y],'lod':'single measured module','materials':len(o.data.materials)}
        bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True)
    o.hide_render=True; o.hide_set(True)
    return o

# Irregular bank top keeps all six field rectangles horizontal and fully supported.
rim=[(-7.5,-7.6),(-4.8,-8.4),(-1,-8.2),(2.5,-7.9),(5.6,-6.5),(6.5,-3.8),(6.4,-.8),(6.8,1.3),(5.8,4.8),(3.5,6.1),(.7,6.7),(-2.5,6.1),(-5.5,5.6),(-7.2,3.2),(-7.6,.2),(-7.1,-3.6)]
# Coordinates here X,Godot Z; Blender Y=-Z. Ring is subdivided with mild irregularity.
ring=[]
for i,p in enumerate(rim):
    q=rim[(i+1)%len(rim)]
    for t in [0,.25,.5,.75]:
        ring.append((p[0]*(1-t)+q[0]*t+rng.uniform(-.12,.12),-(p[1]*(1-t)+q[1]*t+rng.uniform(-.12,.12))))
n=len(ring); vs=[(0,0,.13)]+[(x,y,.13) for x,y in ring]+[(x*.99,y*.99,-.85-rng.random()*.15) for x,y in ring]
faces=[(0,1+(i+1)%n,1+i) for i in range(n)]+[(1+(i+1)%n,1+n+(i+1)%n,1+n+i,1+i) for i in range(n)]
land=mesh('Terraced natural bank',vs,faces,grass); land.data.materials.append(clay)
for f in land.data.polygons[n:]:f.material_index=1
save('island_bank',[land])

for k in range(5):
    # Consume the old stone generator's 18 draws so later modules keep their seed.
    for _ in range(9): rng.uniform(.39,.60)
    for _ in range(9): rng.uniform(.17,.25)
    # Sculpt a full, asymmetric worn stone with enough samples to shade smoothly.
    rock_rng=random.Random(4811+k)
    radii=[rock_rng.uniform(.40,.57) for _ in range(12)]
    verts=[]
    for level,(radius_scale,z) in enumerate([(.85,0),(1.0,.075),(.83,.18),(.50,.25)]):
        for i in range(12):
            a=i*math.tau/12
            r=radii[i]*radius_scale
            verts.append((math.cos(a)*r+.05*level/3,math.sin(a)*r*.78-.03*level/3,z+(.01*math.sin(a*3+k) if level else 0)))
    faces=[tuple(reversed(range(12))),tuple(range(36,48))]
    faces += [(level*12+i,level*12+(i+1)%12,(level+1)*12+(i+1)%12,(level+1)*12+i) for level in range(3) for i in range(12)]
    o=mesh('Naturally worn river stone',verts,faces,stone[k]); bevel=o.modifiers.new('Rounded weathering','BEVEL');bevel.width=.045;bevel.segments=3
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
    for face in o.data.polygons:face.use_smooth=True
    weighted=o.modifiers.new('Broad mineral planes','WEIGHTED_NORMAL'); weighted.weight=25
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    save('stone_'+str(k),[o])

# Segmented stone arch; true open underside, visible masonry joints, no solid block fake.
bridge=[]; count=22; length=4.6
for i in range(count):
    x0=-length/2+i*length/count+.007; x1=-length/2+(i+1)*length/count-.007
    z0=.20+1.05*math.sin(math.pi*(x0/length+.5)); z1=.20+1.05*math.sin(math.pi*(x1/length+.5))
    verts=[(x0,-.85,z0-.48),(x1,-.85,z1-.48),(x1,.85,z1-.48),(x0,.85,z0-.48),(x0,-.85,z0),(x1,-.85,z1),(x1,.85,z1),(x0,.85,z0)]
    bridge.append(mesh('Arch voussoir '+str(i),verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],stone[i%5]))
    block=bridge[-1];bpy.context.view_layer.objects.active=block
    bevel=block.modifiers.new('Worn masonry edges','BEVEL');bevel.width=.035;bevel.segments=3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
for side in [-1,1]:
    # Staggered masonry under each end grounds the arch in the river banks.
    for end in [-1,1]:
        for course in range(3):
            for column in range(2):
                x=end*(1.78+column*.32+(course%2)*.08)
                bridge.append(box('Bridge abutment',(x,side*.69,-.30+course*.22),(.37,.39,.22),stone[(course+column)%5],.025))
    for j in range(9):
        x=-2.3+j*.575; z=.20+1.05*math.sin(math.pi*(x/4.6+.5))
        bridge.append(box('Carved bridge post',(x,side*.86,z+.30),(.18,.21,.68),stone[(j+1)%5],.025))
        bridge.append(box('Cap',(x,side*.86,z+.66),(.25,.28,.09),stone[2],.025))
        if j:
            xp=x-.575; zp=.20+1.05*math.sin(math.pi*(xp/4.6+.5))
            # Closed, two-course stone parapets follow the arch, with visible
            # joints. This gives a silhouette like a small Jiangnan stone bridge.
            for course in range(2):
                centre=Vector(((xp+x)/2,side*.86,(zp+z)/2+.15+course*.18))
                panel=box('Masonry parapet',centre,(math.hypot(x-xp,z-zp)-.10,.16,.17),stone[(j+course)%5],.018)
                panel.rotation_euler.y=-math.atan2(z-zp,x-xp)
                bridge.append(panel)
            rail=box('Stone coping',((xp+x)/2,side*.86,(zp+z)/2+.54),(math.hypot(x-xp,z-zp),.24,.11),stone[1],.025)
            rail.rotation_euler.y=-math.atan2(z-zp,x-xp)
            bridge.append(rail)
save('stone_bridge',bridge)

rail=[]
for x in [-1,0,1]:
    rail.append(pole('Bamboo post',(x,0,0),(x,0,.85),.055,bamboo))
    for z in [.19,.52,.76]: rail.append(pole('Bamboo node',(x,0,z),(x,0,z+.035),.064,timber))
for z in [.27,.67]:rail.append(pole('Bamboo rail',(-1.08,0,z),(1.08,0,z),.043,bamboo))
save('bamboo_fence',rail)

gate=[]
for x in [-.9,.9]:
    gate.append(box('Gate squared post',(x,0,1.15),(.15,.16,2.30),timber,.035))
    gate.append(box('Gate stone foot',(x,0,.12),(.31,.32,.24),stone[1],.05))
gate.append(box('Gate lintel',(0,0,2.13),(2.18,.19,.22),timber,.035))
for x in [-.9,.9]:
    gate.append(pole('Gate diagonal brace',(x,0,1.6),(x*.45,0,2.12),.065,timber))
for side in [-1,1]:
    for i in range(30):
        x=-1.25+i*.086
        gate.append(pole('Bound straw roof reed',(x,0,2.61),(x,side*.67,2.10),.041,bamboo))
    for j in range(4):
        y=side*j*.22;z=2.61-abs(y)*.76
        gate.append(pole('Canopy binding',(-1.32,y,z+.035),(1.32,y,z+.035),.026,timber))
save('entrance_canopy',gate)

# Real side wing with tiled curved eaves, framed windows, wooden veranda.
wing=[box('Lime plaster side bay',(0,0,1.07),(2.6,2.5,2.14),ivory,.035)]
for y in [-1.25,1.25]:
    wing.append(mesh('Plastered gable', [(-1.3,y,2.1),(1.3,y,2.1),(0,y,2.93)],[(0,1,2) if y<0 else (2,1,0)],ivory))
for x in [-.85,.85]:
    wing.append(box('Deep window',(x,-1.27,1.28),(.57,.04,.76),dark,.02))
    for dx in [-.29,.29]:wing.append(box('Window stile',(x+dx,-1.31,1.28),(.055,.045,.84),timber,.008))
    for z in [.89,1.67]:wing.append(box('Window sill',(x,-1.31,z),(.64,.07,.055),timber,.01))
    for dx in [-.15,0,.15]:wing.append(box('Wood window lattice',(x+dx,-1.32,1.28),(.025,.04,.74),timber,.004))
wing.append(box('Door inset',(0,-1.27,.91),(.67,.035,1.65),timber,.015))
for x in [-.22,-.11,0,.11,.22]:wing.append(box('Door plank line',(x,-1.30,.91),(.012,.02,1.58),dark,.003))
for x in [-.32,.32]:wing.append(box('Door jamb',(x,-1.31,.91),(.055,.07,1.73),timber,.01))
for side in [-1,1]:
    for j in range(22):
        y=-1.48+j*.141
        for seg in range(5):
            x0=side*(seg*.34);x1=side*((seg+1)*.34)
            z0=2.93-abs(x0)*.48+.08*(abs(x0)/1.7)**5;z1=2.93-abs(x1)*.48+.08*(abs(x1)/1.7)**5
            vs=[(x0,y,z0),(x1,y,z1),(x1,y+.135,z1),(x0,y+.135,z0)]
            tile=mesh('Curved overlapping roof tile',vs,[(0,1,2,3) if side>0 else (3,2,1,0)],tiles[(j+seg)%4]);m=tile.modifiers.new('Tile thickness','SOLIDIFY');m.thickness=.045
            bpy.context.view_layer.objects.active=tile;bpy.ops.object.modifier_apply(modifier=m.name);wing.append(tile)
            if seg==4:wing.append(pole('Rounded tile eave',(x1,y,z1),(x1,y+.135,z1),.047,tiles[1]))
wing.append(pole('Ridge cap',(0,-1.54,2.96),(0,1.60,2.96),.12,tiles[1]))
save('side_wing',wing)

porch=[box('Stone veranda platform',(0,0,.14),(6.9,1.15,.28),stone[1],.05)]
for z,y,w in [(.065,-.80,5.7),(.025,-1.04,5.3)]:porch.append(box('Entry step',(0,y,z),(w,.30,.13),stone[2],.035))
for x in [-3.15,-1.5,1.5,3.15]:
    porch.append(pole('Veranda timber pillar',(x,.32,.28),(x,.32,2.37),.075,timber))
    porch.append(box('Post stone shoe',(x,.32,.34),(.22,.22,.20),stone[0],.035))
porch.append(box('Long lintel',(0,.32,2.29),(6.9,.15,.19),timber,.02))
for x0,x1 in [(-3.15,-1.5),(1.5,3.15)]:
    for z in [.62,.95]:porch.append(pole('Low veranda balustrade',(x0,-.38,z),(x1,-.38,z),.033,timber))
    for j in range(7):
        x=x0+(x1-x0)*j/6;porch.append(pole('Turned railing',(x,-.38,.32),(x,-.38,.98),.025,timber))
save('veranda',porch)

# Field rim comes in four gently softened timber sides with open soil interior.
rimobjects=[box('Long bed frame',(0,y,.03),(2.72,.075,.075),timber,.02) for y in [-1.065,1.065]]
rimobjects +=[box('Short bed frame',(x,0,.03),(.075,2.12,.075),timber,.02) for x in [-1.34,1.34]]
save('field_frame',rimobjects)

# Long open climbing frame. Local X is the growing row; Godot rotates it along
# the west fence. Four bays remain physically separate for future climbing crops.
trellis=[]
rope=mat('Hemp garden twine',(.40,.34,.22))
for x in [-2.16,-1.08,0,1.08,2.16]:
    for y in [-.47,.47]:
        trellis.append(pole('Rooted bamboo upright',(x,y,-.08),(x*.99,y*.86,1.96),.045,bamboo))
        for z in [.15,.49,.83,1.17,1.51,1.85]:
            trellis.append(pole('Bamboo joint',(x,y*(1-z*.07),z-.016),(x,y*(1-z*.07),z+.016),.055,bamboo))
    trellis.append(pole('Cross tie',(x,-.62,1.96),(x,.62,1.96),.039,bamboo))
for y in [-.46,.46]:
    trellis.append(pole('Long top rail',(-2.32,y,1.94),(2.32,y,1.94),.048,bamboo))
    trellis.append(pole('Low vine rail',(-2.20,y,.44),(2.20,y,.44),.029,bamboo))
    for i in range(17):
        x=-2.16+i*.27
        trellis.append(pole('Climbing twine',(x,y,.46),(x,y*.87,1.93),.009,rope))
for x in [-1.9,1.9]:
    trellis.append(pole('Stability brace',(x,-.47,1.55),(x+(-.26 if x>0 else .26),.47,1.93),.027,bamboo))
save('climbing_trellis',trellis)
assert not options.only or set(options.only)<=reports.keys(), 'Unknown module: '+str(options.only)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(folder/'courtyard_modules.blend'))
for name,report in reports.items():
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/(name+'.glb')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in meshes:o.data.calc_loop_triangles()
    assert sum(len(o.data.loop_triangles) for o in meshes)==report['triangles'],name
    report['reimport_verified']=True
existing_reports.update(reports)
(folder/'asset-audit.json').write_text(json.dumps(existing_reports,indent=2),encoding='utf-8')
print('MODULES_READY',json.dumps(reports))
