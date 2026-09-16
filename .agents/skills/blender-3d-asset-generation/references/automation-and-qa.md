# Blender Automation and QA

## Contents

- Headless execution
- Script design
- Export verification
- Preview rendering
- Failure handling

## Headless execution

Run reproducible operations in background mode:

```bash
blender --background source.blend --python script.py -- --output report.json
```

Arguments after `--` belong to the script. Set explicit input/output paths. Keep temporary and generated files inside the project or an approved temporary directory.

## Script design

- Check Blender version and required add-ons before mutation.
- Use deterministic names and idempotent operations where practical.
- Avoid relying on the current selection, active area, or mode.
- Validate paths and never delete broad directories from an asset script.
- Log structured results and return a non-zero process status for failed gates.
- Save to a new output path after successful validation, not halfway through a destructive sequence.
- Seed procedural randomness when repeatability matters.

## Export verification

An exporter returning success is only one signal. Verify by importing into a clean scene or the target engine and checking:

- Bounds, position, scale, forward/up orientation, and origin.
- Object hierarchy and naming.
- Mesh count, triangle count, submeshes, normals, and tangents.
- Materials, texture assignments, alpha, and color spaces.
- Skeleton, bone orientation, skin weights, action/clip names, loop behavior, and root motion.
- Cameras, lights, custom properties, shape keys, and sockets when included.

Prefer glTF/GLB for an open, inspectable real-time interchange path when it satisfies the target. Use FBX when the downstream pipeline requires it, and lock the tested exporter/importer settings.

## Preview rendering

Create evidence that exposes defects:

- Neutral three-quarter beauty render.
- Front, side, back, and top contact sheet.
- Wireframe and face-orientation views.
- Matcap or neutral-light shading check.
- UV layout and texture-set montage.
- Rig extreme-pose sheet and animation preview where applicable.

Do not use a single dramatic render as the only QA artifact.

## Failure handling

Stop and preserve evidence when:

- Blender reports missing data or an exporter exception.
- A context-sensitive operator fails its poll.
- The audit identifies an unintended scale, missing UV, broken link, non-manifold mesh, or budget violation.
- Clean re-import differs materially from the source.

Fix the source cause, re-export, and re-run the same checks. Do not manually patch only the exported result unless that result is the intentional source of truth.
