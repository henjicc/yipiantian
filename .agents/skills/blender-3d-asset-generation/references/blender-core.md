# Blender Core Practices

## Contents

- Scene safety
- Data API and operators
- Coordinates and transforms
- Geometry and shading
- Collections and naming
- Dependency management

## Scene safety

Inspect before changing. Save intentional milestones such as `asset_blockout.blend`, `asset_high.blend`, and `asset_game.blend`, or use source control for text and exported artifacts. Avoid overwriting the only working source with an automated batch step.

Treat linked libraries, overrides, Geometry Nodes, drivers, constraints, and modifiers as dependencies. Determine whether a requested edit belongs in the local file, the source library, or an override.

## Data API and operators

Prefer `bpy.data` and object properties for deterministic scripts. Operators reproduce interactive actions but often depend on mode, selection, active object, area, region, and other context. Before calling an operator:

1. Confirm the required object and mode.
2. Set the active object and selection deliberately.
3. Use `poll()` when available.
4. Check the returned status.
5. Inspect the resulting data rather than assuming success.

Avoid long chains of selection-dependent operators in production automation. Encapsulate context-sensitive actions and restore prior state where practical.

## Coordinates and transforms

- Set scene units explicitly and document what one Blender unit means.
- Model at plausible scale because lighting, physics, camera clipping, and import behavior depend on it.
- Define the asset origin for its use: ground contact for a character, hinge for a door, logical center for a prop.
- Apply scale before operations that assume unit scale, unless the non-applied transform is intentional.
- Freeze export axis settings in the pipeline; never fix orientation by trial and error on every asset.

## Geometry and shading

- Put density where it changes silhouette or deformation.
- Use support loops or bevels according to the shading style and intended distance.
- Check face orientation, custom split normals, auto smooth behavior, tangent-space requirements, and mirrored transforms.
- Triangulate predictably before baking or when exact engine triangulation matters; preserve an editable quad-based source if useful.
- Evaluate normals after modifier application and export.

## Collections and naming

Use collections for semantic grouping, exports, LODs, collisions, rig controls, and render setup. Prefer stable machine-readable names:

| Purpose | Example |
|---|---|
| Render mesh | `CHR_Cat_Body` |
| Collision | `COL_Cat_Capsule` |
| LOD | `ENV_Tree_LOD0` |
| Socket | `SOCKET_Weapon_R` |
| Armature | `RIG_Cat` |
| Action | `Cat_Run_Loop` |

Adapt prefixes to the project rather than forcing a new convention into an existing production.

## Dependency management

Pack or copy external images only when the delivery contract calls for it. Prefer relative paths for portable projects. Audit missing images, fonts, caches, linked libraries, and simulation data before handoff. Do not assume a `.blend` file is self-contained.
