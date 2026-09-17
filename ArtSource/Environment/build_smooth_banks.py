"""Rounded, closed bank meshes; Blender 5.2.2, metres, Godot Y-up export.

Keeps the established cultivation plateau at 0.13 m. The outer shore uses
continuous Catmull-Rom contours and several sloping rings, not a bevel over a
vertical polygon wall. Historical build_modules.py and its GLB remain intact.
"""
from pathlib import Path
import bpy, bmesh, json, math

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'Game/art/environment/modules'
SOURCE = ROOT / 'ArtSource/Environment/Banks/20260918'
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system = 'METRIC'
rim = [(-7.5,-7.6),(-4.8,-8.4),(-1,-8.2),(2.5,-7.9),(5.6,-6.5),(6.5,-3.8),(6.4,-.8),(6.8,1.3),(5.8,4.8),(3.5,6.1),(.7,6.7),(-2.5,6.1),(-5.5,5.6),(-7.2,3.2),(-7.6,.2),(-7.1,-3.6)]
# East bank is authored around the actual bridge endpoint (world 10.37, 0.21).
east = [(-2.9,-1.1),(-1.9,-3.5),(1.3,-3.8),(3.5,-2.1),(4.2,.7),(3.2,3.8),(.5,4.4),(-2.8,3.9),(-3.05,2.5)]
mat = bpy.data.materials.new('Soft earthen shore')
mat.diffuse_color=(.38,.36,.24,1)
mat.use_nodes=True
bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
bsdf.inputs['Base Color'].default_value=mat.diffuse_color
bsdf.inputs['Roughness'].default_value=.96
reports={}

def bank(name, points):
    contour=[]
    for i in range(len(points)):
        p0,p1,p2,p3=[points[k%len(points)] for k in [i-1,i,i+1,i+2]]
        for j in range(16):
            t=j/16
            contour.append(tuple(.5*((2*p1[c])+(-p0[c]+p2[c])*t+(2*p0[c]-5*p1[c]+4*p2[c]-p3[c])*t*t+(-p0[c]+3*p1[c]-3*p2[c]+p3[c])*t*t*t) for c in [0,1]))
    n=len(contour)
    # Stay level under all existing paths, roots and fields; rounded shoulder
    # begins near the old perimeter and widens naturally into the water.
    rings=[(.87,.13),(.96,.13),(.985,.105),(1.01,.035),(1.035,-.09),(1.055,-.25),(1.075,-.48),(1.065,-.76),(1.015,-1.02)]
    verts=[(0,0,.13)]
    for scale,height in rings:
        for i,(x,z) in enumerate(contour):
            wave=(math.sin(i/n*math.tau*7+.4)+.45*math.sin(i/n*math.tau*13))*.012
            verts.append((x*scale,-z*scale,height+(wave if height<.13 else 0)))
    faces=[(0,1+i,1+(i+1)%n) for i in range(n)]
    for r in range(len(rings)-1):
        for i in range(n):
            a=1+r*n+i; b=1+r*n+(i+1)%n
            faces.append((a,a+n,b+n,b))
    verts.append((0,0,-1.02)); bottom=len(verts)-1
    faces.extend((bottom,1+(len(rings)-1)*n+(i+1)%n,1+(len(rings)-1)*n+i) for i in range(n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh)
    assert all(e.is_manifold for e in bm.edges), name+' must be closed'
    bm.free()
    for p in mesh.polygons:p.use_smooth=True
    bpy.context.view_layer.update()
    mesh.calc_loop_triangles()
    reports[name]={'triangles':len(mesh.loop_triangles),'dimensions_godot_xyz':[obj.dimensions.x,obj.dimensions.z,obj.dimensions.y],'closed':True,'materials':1,'plateau_y':.13}
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True)
    return obj

bank('island_bank_v2',rim)
bank('east_bank_v2',east)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'rounded-banks.blend'))
for name,report in reports.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(OUT/(name+'.glb')))
    actual=sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    assert actual==report['triangles'],(name,actual,report)
    report['reimport_triangles']=actual
(SOURCE/'audit.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
print('BANK_EXPORT_PASS',json.dumps(reports))
