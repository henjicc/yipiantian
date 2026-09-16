---
type: Reference
title: "Math, Vectors & Randomness Reference"
description: "lerp(a, b, t) # linear interpolate, t in 0..1 (lerpf for typed floats)"
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Math, Vectors & Randomness Reference

**Verified 2026-06-06** against Godot 4.x. Godot 4 renamed several globals: `rand_range` is now `randf_range`/`randi_range`, `deg2rad`/`rad2deg` are `deg_to_rad`/`rad_to_deg`, and `stepify` is `snapped`. Re-verify if a newer minor changes them.

## Global math functions

```gdscript
lerp(a, b, t)          # linear interpolate, t in 0..1 (lerpf for typed floats)
inverse_lerp(a, b, v)  # the t that gives v
remap(v, in0, in1, out0, out1)   # rescale a range
clamp(v, lo, hi)       # also clampf / clampi for typed args
move_toward(from, to, delta)     # step toward without overshoot
smoothstep(lo, hi, v)  # eased 0..1
ease(t, curve)         # exp easing curve
snapped(v, step)       # round to nearest step (grid snapping; was stepify)
wrapf(v, lo, hi)       # wrap into range (wrapi for ints) - angles, indices
pingpong(v, length)    # bounce 0..length..0
deg_to_rad(d)  rad_to_deg(r)
is_equal_approx(a, b)  is_zero_approx(v)   # float comparison (never use ==)
abs(v)  sign(v)  min(a,b)  max(a,b)  posmod(a, b)
```
Constants: `PI`, `TAU` (2*PI, prefer for full turns), `INF`, `NAN`.

## Randomness

Call `randomize()` once at startup to seed from the system clock; for reproducible runs, set a fixed `seed(value)` instead.

```gdscript
func _ready() -> void:
    randomize()

randi()                       # random non-negative int
randf()                       # random float 0..1
randi_range(1, 6)             # inclusive int range (a d6)
randf_range(-1.0, 1.0)
var loot := ["sword", "shield", "potion"]
loot.pick_random()            # Array helper
[1, 2, 3].shuffle()           # in place
```

### Deterministic / per-system RNG
Use a `RandomNumberGenerator` instance when you need an independent, seedable stream (procedural generation, replays):
```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = level_seed                      # same seed -> same sequence
var roll := rng.randi_range(1, 20)
var weight := rng.randfn(0.0, 1.0)         # normal distribution
```

## Vector2 / Vector3 essentials

```gdscript
a.distance_to(b)            # also distance_squared_to (cheaper for comparisons)
a.direction_to(b)           # normalized vector from a to b
v.length()                  # length_squared() avoids the sqrt
v.normalized()              # unit vector (zero vector stays zero)
v.limit_length(max)         # cap magnitude
v.rotated(angle)            # Vector2; Vector3 needs rotated(axis, angle)
v.angle()                   # Vector2 heading in radians
a.angle_to(b)  a.dot(b)  a.cross(b)
v.lerp(to, t)  v.move_toward(to, delta)  v.slerp(to, t)
v.bounce(normal)  v.reflect(normal)  v.slide(normal)   # collision response
v.snapped(Vector2(16, 16))  # grid snap
```
Direction constants: `Vector2.UP/DOWN/LEFT/RIGHT/ZERO/ONE`, `Vector3.UP/FORWARD/...`. Use `Vector2i`/`Vector3i` for integer grid coordinates (tile maps, board positions).

## Common recipes

### Frame-rate-independent smoothing
Plain `lerp(current, target, 0.1)` is framerate-dependent. Make it stable with delta:
```gdscript
func _process(delta: float) -> void:
    var rate := 8.0
    position = position.lerp(target, 1.0 - exp(-rate * delta))
```

### Rotate to face a target
```gdscript
rotation = (target.global_position - global_position).angle()
# Smooth turn with a max speed:
var desired := global_position.angle_to_point(target.global_position)
rotation = rotate_toward(rotation, desired, TURN_SPEED * delta)
```

### Stick deadzone
```gdscript
var input := Input.get_vector("left", "right", "up", "down")  # already deadzoned per-action
# Manual: if input.length() < DEADZONE: input = Vector2.ZERO
```

### Weighted random pick
```gdscript
func weighted_pick(weights: Array[float]) -> int:
    var total := 0.0
    for w in weights: total += w
    var r := randf() * total
    for i in weights.size():
        r -= weights[i]
        if r <= 0.0: return i
    return weights.size() - 1
```

## Pitfalls

- Comparing floats with `==`. Use `is_equal_approx()` / `is_zero_approx()`.
- Framerate-dependent `lerp(a, b, const)` per frame. Fold in `delta` (recipe above).
- Reaching for 3.x names: `rand_range`, `deg2rad`, `rad2deg`, `stepify`. They no longer exist.
- Normalizing a possibly-zero vector and expecting a direction; guard with `if v != Vector2.ZERO`.
