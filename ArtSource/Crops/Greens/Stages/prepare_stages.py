"""Prepare one approved Tripo crop stage, preserving the raw model.

Blender --background --python this_file.py -- --asset greens_sprout --source raw.glb
Only named 3.1 crop stages are accepted. Inspect output and audit before adoption.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Matrix, Vector


CONFIG = {
    "greens_sprout": {"width": 0.14, "triangles": 700, "low_triangles": 280},
    "greens_young": {"width": 0.30, "triangles": 2000, "low_triangles": 650},
    "radish_sprout": {"width": 0.14, "triangles": 700, "low_triangles": 280},
    "radish_young": {"width": 0.28, "triangles": 2000, "low_triangles": 650},
    "radish_mature": {"width": 0.42, "triangles": 3200, "low_triangles": 1000},
}
REPO = Path(__file__).resolve().parents[4]


def mesh_stats(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    result = {
        "triangles": len(mesh.loop_triangles),
        "vertices": len(mesh.vertices),
        "materials": len(mesh.materials),
        "uv_layers": len(mesh.uv_layers),
        "non_manifold_edges": sum(not edge.is_manifold for edge in bm.edges),
        "loose_vertices": sum(not vertex.link_edges for vertex in bm.verts),
        "degenerate_faces": sum(face.calc_area() < 1e-12 for face in bm.faces),
        "bounds_min": [min(vertex.co[axis] for vertex in mesh.vertices) for axis in range(3)],
        "bounds_max": [max(vertex.co[axis] for vertex in mesh.vertices) for axis in range(3)],
    }
    bm.free()
    return result


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def decimate_to(obj, count):
    actual = mesh_stats(obj)["triangles"]
    if actual > count:
        select_only(obj)
        mod = obj.modifiers.new("Stage silhouette budget", "DECIMATE")
        mod.ratio = count / actual
        bpy.ops.object.modifier_apply(modifier=mod.name)


def repair_small_gaps(obj):
    """Repair the inspected tiny stem seam / basal triangular gap, not leaf edges."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    removed = 0
    # The young greens source contains one three-face junction in its central fold.
    for edge in list(bm.edges):
        if edge.is_valid and len(edge.link_faces) > 2:
            if edge.calc_length() > 0.025:
                raise RuntimeError("Non-manifold junction exceeds inspected repair scope")
            excess = sorted(edge.link_faces, key=lambda face: face.calc_area())[:-2]
            removed += len(excess)
            bmesh.ops.delete(bm, geom=excess, context="FACES_ONLY")
    boundary = [edge for edge in bm.edges if edge.is_boundary]
    if len(boundary) > 16 or any(edge.calc_length() > 0.025 for edge in boundary):
        raise RuntimeError("Open edge exceeds inspected small-gap repair scope")
    # Remember adjacent UVs before filling; repair is in tiny hidden stem/base areas.
    uv_layer = bm.loops.layers.uv.active
    uv_by_vertex = {vertex: vertex.link_loops[0][uv_layer].uv.copy()
                    for vertex in bm.verts if uv_layer and vertex.link_loops}
    filled = bmesh.ops.holes_fill(bm, edges=boundary, sides=16)["faces"] if boundary else []
    for face in filled:
        face.smooth = True
        for loop in face.loops:
            if uv_layer and loop.vert in uv_by_vertex:
                loop[uv_layer].uv = uv_by_vertex[loop.vert]
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    remaining = sum(not edge.is_manifold for edge in bm.edges)
    if remaining:
        raise RuntimeError(f"Small-gap repair left {remaining} non-manifold edges")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return {"removed_overlap_faces": removed, "filled_faces": len(filled)}


def export(obj, path):
    select_only(obj)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=False, export_animations=False,
        export_texcoords=True, export_normals=True, export_materials="EXPORT",
    )
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"Missing export: {path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--asset", choices=CONFIG, required=True)
    parser.add_argument("--source", type=Path, required=True)
    options = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    source = options.source.resolve(strict=True)
    if REPO not in source.parents:
        raise RuntimeError("Raw input must be inside this project")
    config = CONFIG[options.asset]
    crop = options.asset.split("_", 1)[0]
    source_dir = REPO / "ArtSource/Crops" / ("Greens/Stages" if crop == "greens" else "Radish")
    blend_dir = source_dir / "blend"
    blend_dir.mkdir(parents=True, exist_ok=True)
    target_dir = REPO / "Game/art/crops" / crop
    target_dir.mkdir(parents=True, exist_ok=True)
    report = {"asset": options.asset, "blender": bpy.app.version_string,
              "source": source.relative_to(REPO).as_posix(), "settings": config}

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not objects:
        raise RuntimeError("No crop meshes in Tripo output")
    # Bake imported transforms into vertices before joining and root alignment.
    for obj in objects:
        transform = obj.matrix_world.copy()
        obj.parent = None
        obj.data.transform(transform)
        obj.matrix_world = Matrix.Identity(4)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = options.asset
    report["raw"] = mesh_stats(obj)

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
    bm.to_mesh(obj.data)
    bm.free()
    decimate_to(obj, config["triangles"])
    points = [vertex.co.copy() for vertex in obj.data.vertices]
    lower = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    upper = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    width = max(upper.x - lower.x, upper.y - lower.y)
    if width <= 0.0:
        raise RuntimeError("Invalid crop bounds")
    # The bottom 3% belongs to the shared root, avoiding leaf-asymmetric centring.
    root_points = [point for point in points if point.z <= lower.z + (upper.z - lower.z) * 0.03]
    root = Vector((sum(p.x for p in root_points) / len(root_points),
                   sum(p.y for p in root_points) / len(root_points), lower.z))
    factor = config["width"] / width
    for vertex in obj.data.vertices:
        vertex.co = (vertex.co - root) * factor
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.data.update()
    report["high_repair"] = repair_small_gaps(obj)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    for material in obj.data.materials:
        if material and material.node_tree:
            for node in material.node_tree.nodes:
                if node.type == "BSDF_PRINCIPLED":
                    node.inputs["Roughness"].default_value = 0.93
                    node.inputs["Metallic"].default_value = 0.0
                    node.inputs["Specular IOR Level"].default_value = 0.12
    # Pack imported images so editable sources survive moving the repository.
    bpy.ops.file.pack_all()
    report["high"] = mesh_stats(obj)
    report["images"] = [{"name": image.name, "size": list(image.size), "packed": bool(image.packed_file)}
                        for image in bpy.data.images if image.type == "IMAGE"]
    high_path = target_dir / f"{options.asset}.glb"
    export(obj, high_path)

    low = obj.copy()
    low.data = obj.data.copy()
    bpy.context.collection.objects.link(low)
    low.name = f"{options.asset}_low"
    decimate_to(low, config["low_triangles"])
    report["low_repair"] = repair_small_gaps(low)
    # Keep the identical root coordinate, material and source-space transforms.
    report["low"] = mesh_stats(low)
    low_path = target_dir / f"{options.asset}_low.glb"
    export(low, low_path)
    low.hide_render = True
    low.hide_set(True)
    select_only(obj)
    blend_path = blend_dir / f"{options.asset}.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    report["exported"] = [path.relative_to(REPO).as_posix() for path in [high_path, low_path, blend_path]]

    # Verify standalone GLBs by clean re-import, not only the export return value.
    for label, path in [("reimport_high", high_path), ("reimport_low", low_path)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(path))
        imported = [item for item in bpy.context.scene.objects if item.type == "MESH"]
        if len(imported) != 1:
            raise RuntimeError(f"Expected one joined crop mesh: {path}")
        report[label] = mesh_stats(imported[0])
        if report[label]["uv_layers"] == 0 or report[label]["materials"] == 0:
            raise RuntimeError(f"Missing UV/material after export: {path}")
    report_path = blend_dir / f"{options.asset}-report.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("CROP_STAGE_PREPARED " + json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
