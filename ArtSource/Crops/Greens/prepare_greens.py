"""Prepare the recorded Tripo source; run with Blender --background --python."""
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector

folder = Path(__file__).resolve().parent
repo = folder.parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / 'tripo_original.glb'))
mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if len(mesh_objects) != 1:
    raise RuntimeError('Expected the recorded single-mesh Tripo source')
obj = mesh_objects[0]
obj.name = 'greens_mature'
bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
bm.to_mesh(obj.data)
bm.free()
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
modifier = obj.modifiers.new('Prototype silhouette budget', 'DECIMATE')
modifier.ratio = 0.34
bpy.ops.object.modifier_apply(modifier=modifier.name)
points = [v.co.copy() for v in obj.data.vertices]
lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
bottom = Vector(((lo.x+hi.x)/2, (lo.y+hi.y)/2, lo.z))
# A 48 cm wide stylized crop; keep the root on the ground in every instance.
factor = 0.48 / max(hi.x-lo.x, hi.y-lo.y)
for vertex in obj.data.vertices:
    vertex.co = (vertex.co - bottom) * factor
for polygon in obj.data.polygons:
    polygon.use_smooth = True
obj.data.update()
bpy.context.scene.unit_settings.system = 'METRIC'
for material in obj.data.materials:
    for node in material.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            node.inputs['Roughness'].default_value = 0.93
            node.inputs['Metallic'].default_value = 0.0
            node.inputs['Specular IOR Level'].default_value = 0.12
bpy.ops.wm.save_as_mainfile(filepath=str(folder / 'greens_mature.blend'))
destination = repo / 'Game/art/crops/greens/greens_mature.glb'
bpy.ops.export_scene.gltf(filepath=str(destination), export_format='GLB', use_selection=True)
obj.data.calc_loop_triangles()
print(f'PREPARED triangles={len(obj.data.loop_triangles)} size={tuple(obj.dimensions)} export={destination}')
