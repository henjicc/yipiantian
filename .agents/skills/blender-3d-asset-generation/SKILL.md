---
name: blender-3d-asset-generation
description: Create, inspect, repair, optimize, automate, render, and export game-ready 3D assets with Blender and Python. Use for Blender scene handling, bpy automation, low-poly or stylized modeling, topology, UVs, PBR materials, texture baking, rigging, animation, LODs, collision meshes, glTF/FBX export, headless asset generation, render previews, or preparing assets for Unity and other real-time engines.
---

# Blender 3D Asset Generation

Treat every asset as a verified pipeline product, not merely a pleasing viewport image. Preserve the source scene, work non-destructively, measure the result, render it from useful angles, and verify the exported file independently.

## Establish the asset contract

Determine or reasonably default:

- Intended engine, platform, camera distance, art direction, and performance tier.
- Deliverables: `.blend`, interchange format, textures, animations, collision, LODs, and previews.
- Coordinate system, forward/up axes, unit scale, origin/pivot, naming, and folder conventions.
- Triangle, material, texture-memory, bone, and animation budgets.
- Whether the task modifies an existing source or creates a new asset.

For detailed quality targets, read [references/game-ready-assets.md](references/game-ready-assets.md). For Blender scene and data practices, read [references/blender-core.md](references/blender-core.md).

## Select the safest control path

Prefer the most inspectable path available:

1. Use direct `bpy` data access for deterministic scene construction and batch edits.
2. Use `bpy.ops` only when an operator is genuinely appropriate; establish and validate its required context.
3. Use Blender background mode for repeatable generation, audits, renders, and exports.
4. Use an available Blender MCP bridge only after discovering its live tools and confirming the intended Blender instance and file.
5. Use interactive UI work only when visual judgment or a UI-only operation requires it.

Never claim an Editor or MCP change occurred when no connected tool confirmed it.

## Run the asset loop

### 1. Inspect

- Record Blender version, render engine, units, scene collections, linked data, modifiers, materials, images, armatures, actions, and external dependencies.
- Inspect existing names, transforms, object origins, UV maps, normals, topology, and export settings before editing.
- Save or duplicate recoverable source state before destructive operations.

### 2. Block out

- Match silhouette, proportion, scale, pivot, and gameplay readability before detail.
- Evaluate the asset from its real gameplay camera and expected on-screen size.
- Keep semantic parts separate while proportions are changing; join only for a deliberate reason.

### 3. Build clean geometry

- Use topology that supports deformation, shading, baking, and the target silhouette.
- Avoid accidental internal faces, duplicates, zero-area geometry, non-manifold boundaries, and extreme thin slivers.
- Apply or intentionally preserve transforms. Make modifier order explicit and keep a reversible source where practical.
- Use weighted normals, hard edges, bevels, and smoothing consistently with the chosen shading workflow.

### 4. UV and shade

- Create UVs with intentional seams, stable texel density, adequate padding, and no accidental overlap outside the chosen workflow.
- Keep material count proportional to draw-call and authoring needs.
- Use real-time-friendly PBR inputs and pack texture channels only when the target importer expects it.
- Test color-space choices: color textures generally use sRGB; data maps generally do not.

### 5. Rig and animate when required

- Use a clear root hierarchy, stable bone names, constrained weights, and production-safe rest transforms.
- Check deformation at extreme poses, not only the bind pose.
- Name actions consistently, define frame ranges, remove accidental keys, and decide whether root motion is authored or in-place.

### 6. Optimize for the target

- Spend triangles on silhouette and deformation. Remove unseen complexity only when it does not create shading or maintenance problems.
- Build LODs from measured screen-size needs. Preserve silhouette and material compatibility across levels.
- Author simple collision and sockets/attachment points separately from render geometry.
- Consolidate textures and materials when it reduces runtime cost without harming reuse or visual quality.

### 7. Validate and export

- Run [scripts/audit_blender_asset.py](scripts/audit_blender_asset.py) inside Blender for a machine-readable scene report.
- Apply the correct axis, scale, animation, material, and selection settings for the target format.
- Export to a new artifact path; do not overwrite the only source copy.
- Re-import the exported artifact into a clean Blender scene or target engine and verify scale, orientation, hierarchy, materials, normals, animation, and bounds.
- Render a turntable or contact sheet from representative angles.

Read [references/automation-and-qa.md](references/automation-and-qa.md) before scripting, headless execution, batch export, or final delivery.

## Make strong game assets

Use this order of importance:

1. Gameplay-readable silhouette.
2. Correct dimensions, origin, and orientation.
3. Stable topology and shading.
4. Consistent materials and texel density.
5. Rig and animation that survive export.
6. Measured runtime cost.
7. Presentation polish.

Do not hide structural problems with a beauty render. A successful asset must look right, import right, animate right, collide right, and fit its budget.

## Report evidence

Report:

- Source and exported paths.
- Blender version and export format/settings.
- Object, triangle, material, texture, armature, bone, and action counts.
- Units, dimensions, origin, forward/up orientation, and unapplied transforms.
- UV, normals, manifold, missing-file, and naming checks.
- Preview-render and clean re-import results.
- Known limitations and target-engine checks still required.

Use [references/official-blender-sources.md](references/official-blender-sources.md) to verify version-specific API or exporter behavior.
