---
type: Reference
title: "Particles & VFX Reference"
description: "Both share the same conceptual properties."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Particles & VFX Reference

**Verified 2026-06-06** against Godot 4.x. Godot 4 renamed the particle process material to `ParticleProcessMaterial` (3.x `ParticlesMaterial`) and added the `finished` signal for one-shot emitters. Re-verify if a newer minor changes them.

## GPUParticles2D vs CPUParticles2D

| Node | Use for |
|---|---|
| `GPUParticles2D` | Many particles, simulated on the GPU; the default for effects |
| `CPUParticles2D` | Fewer particles, CPU-simulated; safest on the Compatibility (GL) renderer and low-end/web, and easier to tweak per-instance from code |

Both share the same conceptual properties. `GPUParticles2D` drives behavior through a `ParticleProcessMaterial` (or a custom particle `ShaderMaterial`); `CPUParticles2D` exposes the same knobs as direct node properties. `CPUParticles2D.convert_from_particles()` ports a GPU setup to CPU.

## Emitter properties

```gdscript
emitting         # bool: actively emitting
amount           # particle count (GPU: fixed buffer; changing it restarts)
lifetime         # seconds each particle lives
one_shot         # emit a single burst, then stop
explosiveness    # 0 = even stream, 1 = all at once (bursts)
preprocess       # start mid-simulation (e.g. a fire already burning)
speed_scale      # simulation speed multiplier
local_coords     # false = particles stay in world space (trails); true = follow the node
texture          # the per-particle texture
```

## ParticleProcessMaterial (the look and motion)

Configure in the inspector or code on `GPUParticles2D.process_material`:
```gdscript
var mat := ParticleProcessMaterial.new()
mat.direction = Vector3(0, -1, 0)
mat.spread = 45.0
mat.initial_velocity_min = 80.0
mat.initial_velocity_max = 160.0
mat.gravity = Vector3(0, 200, 0)
mat.scale_min = 0.5
mat.scale_max = 1.5
mat.color = Color.ORANGE
$GPUParticles2D.process_material = mat
```
Common knobs: `emission_shape` (point/sphere/box), velocity and angular-velocity ranges, `gravity`, `damping`, `scale`/`scale_over_velocity`, `color` and `color_ramp` (a `GradientTexture1D` for fade-out), `hue_variation`, and turbulence.

## One-shot burst that frees itself

The idiom for hit sparks, explosions, pickups, footstep puffs:
```gdscript
func spawn_burst(scene: PackedScene, at: Vector2) -> void:
    var fx: GPUParticles2D = scene.instantiate()
    fx.global_position = at
    fx.one_shot = true
    fx.emitting = true
    add_child(fx)
    fx.finished.connect(fx.queue_free)   # frees after the last particle dies
```
For a reusable, already-placed one-shot emitter, call `restart()` to replay it instead of re-instancing. For frequently spawned effects, pool the emitters rather than instancing each time (see [performance.md](performance.md)).

## Continuous emitter toggle

```gdscript
$Thruster.emitting = engine_on        # stream while a condition holds
```
Turning `emitting` off lets in-flight particles finish; `restart()` clears them immediately.

## Trails and world-space

Set `local_coords = false` so emitted particles stay where they were born while the emitter moves, which is what makes trails and smoke read correctly. With `local_coords = true` the whole effect rigidly follows the node.

## Notes

- GPU particles can behave differently or be limited on the Compatibility renderer and some web targets; if an effect must look identical everywhere, use `CPUParticles2D`.
- A custom particle `ShaderMaterial` (a `shader_type particles` shader) gives full control over per-particle motion; see [shaders.md](shaders.md).
- 3D mirrors this with `GPUParticles3D` / `CPUParticles3D` and the same `ParticleProcessMaterial`.
