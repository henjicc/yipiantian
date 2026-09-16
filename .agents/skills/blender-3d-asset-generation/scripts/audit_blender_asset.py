#!/usr/bin/env python3
"""Audit the open Blender scene and emit a machine-readable JSON report.

Run with Blender, not the system Python:
  blender --background asset.blend --python audit_blender_asset.py -- --output report.json
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from pathlib import Path

import bpy
import bmesh


def script_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Write JSON to this path; stdout when omitted")
    parser.add_argument("--max-triangles", type=int, default=None)
    parser.add_argument("--require-uv", action="store_true")
    parser.add_argument("--require-applied-scale", action="store_true")
    parser.add_argument("--fail-on-warnings", action="store_true")
    return parser.parse_args(script_args())


def rounded(values) -> list[float]:
    return [round(float(value), 6) for value in values]


def mesh_report(obj: bpy.types.Object) -> dict:
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    non_manifold_edges = sum(1 for edge in bm.edges if not edge.is_manifold)
    loose_vertices = sum(1 for vertex in bm.verts if not vertex.link_edges)
    bm.free()

    loop_triangles = len(mesh.loop_triangles)
    if not mesh.loop_triangles and mesh.polygons:
        mesh.calc_loop_triangles()
        loop_triangles = len(mesh.loop_triangles)

    return {
        "name": obj.name,
        "vertices": len(mesh.vertices),
        "edges": len(mesh.edges),
        "faces": len(mesh.polygons),
        "triangles": loop_triangles,
        "uv_layers": [layer.name for layer in mesh.uv_layers],
        "material_slots": len(obj.material_slots),
        "dimensions": rounded(obj.dimensions),
        "location": rounded(obj.location),
        "rotation_euler": rounded(obj.rotation_euler),
        "scale": rounded(obj.scale),
        "non_manifold_edges": non_manifold_edges,
        "loose_vertices": loose_vertices,
        "modifiers": [{"name": mod.name, "type": mod.type} for mod in obj.modifiers],
    }


def main() -> int:
    args = parse_args()
    meshes = [mesh_report(obj) for obj in bpy.context.scene.objects if obj.type == "MESH"]
    total_triangles = sum(item["triangles"] for item in meshes)
    warnings: list[str] = []
    failures: list[str] = []

    for item in meshes:
        if item["non_manifold_edges"]:
            warnings.append(f"{item['name']}: {item['non_manifold_edges']} non-manifold edges")
        if item["loose_vertices"]:
            warnings.append(f"{item['name']}: {item['loose_vertices']} loose vertices")
        if args.require_uv and not item["uv_layers"]:
            failures.append(f"{item['name']}: missing UV map")
        if args.require_applied_scale and any(not math.isclose(value, 1.0, abs_tol=1e-5) for value in item["scale"]):
            failures.append(f"{item['name']}: scale is not applied ({item['scale']})")

    if args.max_triangles is not None and total_triangles > args.max_triangles:
        failures.append(f"triangle budget exceeded: {total_triangles} > {args.max_triangles}")

    missing_files = []
    for image in bpy.data.images:
        if not image.filepath or image.packed_file:
            continue
        resolved = bpy.path.abspath(image.filepath)
        if not os.path.exists(resolved):
            missing_files.append({"image": image.name, "path": resolved})
    if missing_files:
        failures.append(f"{len(missing_files)} external image file(s) are missing")

    armatures = []
    for obj in bpy.context.scene.objects:
        if obj.type == "ARMATURE":
            armatures.append({"name": obj.name, "bones": len(obj.data.bones)})

    report = {
        "schema_version": 1,
        "blender_version": bpy.app.version_string,
        "source_file": bpy.data.filepath or None,
        "scene": bpy.context.scene.name,
        "units": {
            "system": bpy.context.scene.unit_settings.system,
            "scale_length": bpy.context.scene.unit_settings.scale_length,
        },
        "summary": {
            "objects": len(bpy.context.scene.objects),
            "mesh_objects": len(meshes),
            "triangles": total_triangles,
            "materials": len(bpy.data.materials),
            "images": len(bpy.data.images),
            "armatures": len(armatures),
            "actions": len(bpy.data.actions),
        },
        "meshes": meshes,
        "armatures": armatures,
        "actions": [action.name for action in bpy.data.actions],
        "missing_files": missing_files,
        "warnings": warnings,
        "failures": failures,
        "passed": not failures and not (args.fail_on_warnings and warnings),
    }

    payload = json.dumps(report, indent=2, sort_keys=True)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload + "\n", encoding="utf-8")
    else:
        print(payload)
    return 0 if report["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
