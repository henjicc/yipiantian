"""Blender 5.2: preserve Tripo foliage, place root collars at soil, author sprouts.
Run with --background --python-exit-code 1 --python this_file.py.
"""
from pathlib import Path
import json, math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
# Whole source height and soil collar as a fraction above its lowest root.
CONFIG = {
    'spinach': (.40, .24), 'lettuce': (.36, .13),
    'chrysanthemum': (.48, .13), 'coriander': (.34, .06),
    'celery': (.51, .06), 'mustard': (.46, .06),
    'tatsoi': (.31, .30), 'carrot': (.57, .49),
    'scallion': (.48, .23), 'garlic': (.51, .22),
}
report = {'blender': bpy.app.version_string, 'assets': {}}

def bounds(objects):
    pts = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    return Vector([min(v[i] for v in pts) for i in range(3)]), Vector([max(v[i] for v in pts) for i in range(3)])

def export(objects, path):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_animations=False, export_yup=True, export_texcoords=True, export_normals=True)
    assert path.is_file() and path.stat().st_size > 100

def material(name, color):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = .92
    p.inputs['Specular IOR Level'].default_value = .15
    m.use_backface_culling = False
    return m

def sprout(crop):
    leafmat = material(crop+'_seed_leaf', (.16,.29,.075))
    stemmat = material(crop+'_seed_stem', (.29,.40,.14))
    objects = []
    # Closed curved leaflets: broad cotyledons for broadleaf crops, straps for alliums.
    allium = crop in ('scallion','garlic')
    for n in range(3 if allium else 2):
        verts=[]; faces=[]
        length=.095 if allium else .065
        width=.005 if allium else (.012 if crop=='carrot' else .020)
        angle=n*math.tau/(3 if allium else 2)+.25
        for side in (-1,1):
            for j in range(13):
                t=j/12
                for k in range(7):
                    u=k/3-1
                    x=width*math.sin(math.pi*t)**.7*u
                    y=length*t*(.38 if allium else 1)
                    z=.024+length*(t*.9 if allium else math.sin(t*math.pi*.75)*.42)+.006*u*u*math.sin(math.pi*t)+side*.0011
                    verts.append((x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle),z))
        for side in range(2):
            off=side*91
            for j in range(12):
                for k in range(6):
                    a=off+j*7+k; q=(a,a+1,a+8,a+7)
                    faces.append(q if side else q[::-1])
        edge=list(range(7))+[j*7+6 for j in range(1,13)]+list(range(89,83,-1))+[j*7 for j in range(11,0,-1)]
        for a,b in zip(edge,edge[1:]+edge[:1]): faces.append((a,b,b+91,a+91))
        mesh=bpy.data.meshes.new(crop+'_cotyledon');mesh.from_pydata(verts,[],faces);mesh.update()
        obj=bpy.data.objects.new(crop+'_cotyledon',mesh);bpy.context.collection.objects.link(obj)
        mesh.materials.append(leafmat)
        for p in mesh.polygons:p.use_smooth=True
        objects.append(obj)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=(0,0,.011))
    stem=bpy.context.object;stem.scale=(.004,.004,.018);stem.data.materials.append(stemmat)
    for p in stem.data.polygons:p.use_smooth=True
    objects.append(stem)
    return objects

for crop,(height,collar_fraction) in CONFIG.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/crop/'raw/model.glb'))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    assert objects
    for o in objects:
        o.data.transform(o.matrix_world);o.matrix_world.identity()
    lo,hi=bounds(objects);scale=height/(hi.z-lo.z)
    scale=min(scale,.40/max(hi.x-lo.x,hi.y-lo.y))
    collar=lo.z+(hi.z-lo.z)*collar_fraction
    at_collar=[v.co for o in objects for v in o.data.vertices if abs(v.co.z-collar)<(hi.z-lo.z)*.018]
    center=sum(at_collar,Vector())/len(at_collar) if at_collar else (lo+hi)*.5
    origin=Vector((center.x,center.y,collar))
    count=0
    for o in objects:
        for v in o.data.vertices:v.co=(v.co-origin)*scale
        o.data.calc_loop_triangles();count+=len(o.data.loop_triangles)
        for p in o.data.polygons:p.use_smooth=True
        for m in o.data.materials:
            m.use_backface_culling=False
            if m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type=='BSDF_PRINCIPLED':
                        n.inputs['Roughness'].default_value=.92;n.inputs['Metallic'].default_value=0
                        n.inputs['Specular IOR Level'].default_value=.12
    destination=REPO/'Game/art/crops'/crop;destination.mkdir(parents=True,exist_ok=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/crop/(crop+'.blend')))
    export(objects,destination/(crop+'_mature.glb'))
    lo,hi=bounds(objects)
    collar_points=[v.co for o in objects for v in o.data.vertices if abs(v.co.z)<.012]
    radius=[max(.018,min(.11,max(abs(v[i]) for v in collar_points))) for i in range(2)] if collar_points else [.035,.035]
    report['assets'][crop]={'triangles':count,'min':list(lo),'max':list(hi),'collar_fraction':collar_fraction,'soil_radius':radius,'decimated':False}
    # Same cultivar, compact immature leaves; root collar remains fixed.
    for o in objects:
        for v in o.data.vertices:
            v.co.x*=.54;v.co.y*=.54;v.co.z*=.64
    export(objects,destination/(crop+'_young.glb'))
    for o in objects:o.hide_set(True);o.hide_render=True
    sprouts=sprout(crop)
    export(sprouts,destination/(crop+'_sprout.glb'))
    # Re-import final output rather than relying on exporter success alone.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(destination/(crop+'_mature.glb')))
    imported=[o for o in bpy.context.scene.objects if o.type=='MESH']
    a,b=bounds(imported)
    assert (a-lo).length<.0001 and (b-hi).length<.0001, crop
    print('PREPARED',crop,count,flush=True)
(ROOT/'asset-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
