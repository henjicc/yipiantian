# Game-ready 3D Assets

## Contents

- Asset brief
- Modeling stages
- UVs and textures
- Rigging and animation
- LOD and collision
- Practical quality gates

## Asset brief

Define the asset in gameplay terms before modeling:

| Decision | Example question |
|---|---|
| Camera | Is the asset seen close-up, isometric, or at platformer distance? |
| Role | Hero, enemy, prop, modular kit, background, or VFX mesh? |
| Style | Low-poly, hand-painted, stylized PBR, realistic, or toon? |
| Platform | Mobile, web, desktop, console, XR? |
| Budget | Triangle, material, texture, bone, and animation limits? |
| Engine | Axis, scale, shader, compression, and importer expectations? |

Budgets are project-dependent. Measure representative scenes and target hardware instead of copying universal numbers.

## Modeling stages

1. **Reference and metrics:** collect orthographic/turnaround references when available; create scale guides.
2. **Blockout:** solve proportion, silhouette, negative space, modular dimensions, and pivot.
3. **Production mesh:** establish topology, smoothing boundaries, reusable symmetry, and deformation loops.
4. **High-frequency detail:** add only detail that survives the expected camera or contributes to baking.
5. **Game mesh:** optimize silhouette and deformation while preserving stable shading.
6. **Bake and inspect:** cage-check normal/AO bakes and inspect gradients, seams, and mirrored areas.
7. **Presentation:** render neutral turntables plus representative game lighting.

For low-poly work, low triangle count is not the sole goal. Strong planes, consistent edge language, clean shading, and readable proportions matter more than arbitrary minimalism.

## UVs and textures

- Maintain consistent texel density among assets of comparable importance.
- Place seams where they minimize stretch and are visually hidden or stylistically acceptable.
- Give islands enough padding for the target resolution and mip chain.
- Reserve intentional overlap for symmetry or tiling; flag it so audits do not treat it as accidental.
- Test baked normals with the target engine's tangent basis and importer.
- Keep PBR values physically plausible when using a physically based art direction, then stylize through shape, palette, and controlled response.

## Rigging and animation

- Keep the deformation skeleton separate from optional controls.
- Avoid non-uniform scale in deform hierarchies unless the export path is tested for it.
- Normalize weights and inspect joints at extreme bends.
- Make loop endpoints intentional; test at runtime frame rate and transition blends.
- Record whether actions contain root motion, events, additive animation, or reference-pose assumptions.

## LOD and collision

LOD quality is evaluated by transition visibility, silhouette retention, shading stability, and measured GPU/CPU benefit. A smaller mesh that increases material count or produces visible popping may be worse.

Collision should match gameplay, not render topology. Use primitives and simple convex forms where possible. Separate walkable surfaces, triggers, damage volumes, and interaction sockets by semantics.

## Practical quality gates

| Gate | Pass condition |
|---|---|
| Silhouette | Reads at expected camera distance and background contrast |
| Scale | Imports at the intended real/game-world size |
| Pivot | Rotates, places, and snaps correctly |
| Geometry | No accidental duplicate, zero-area, internal, or non-manifold elements |
| Shading | Normals and tangents remain stable after export |
| UV | Intended overlap only, useful density, sufficient padding |
| Materials | Supported by target pipeline; no missing textures |
| Rig | Stable hierarchy, weights, names, and rest pose |
| Animation | Correct clips, ranges, loops, root motion, and sampling |
| Runtime | Meets measured scene and target-device budgets |
| Handoff | Source, exports, textures, previews, and manifest are complete |
