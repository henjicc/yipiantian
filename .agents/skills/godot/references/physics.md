---
type: Reference
title: "Physics & Movement Reference"
description: "`AnimatableBody2D` is a `StaticBody2D` that reports motion to the physics engine (moving platforms)."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# Physics & Movement Reference

**Verified 2026-06-19** against Godot 4.7. Godot 4 renamed the kinematic body to `CharacterBody2D`/`3D`, made `move_and_slide()` argument-less, and renamed RayCast `cast_to` to `target_position`. Re-verify signatures if a newer minor changes them.

## Choosing a body type

| Node | Use for | Moved by |
|---|---|---|
| `StaticBody2D` | Walls, floors, immovable geometry | Not moved (or `constant_linear_velocity`) |
| `CharacterBody2D` | Player and NPCs you move by code | `velocity` + `move_and_slide()` |
| `RigidBody2D` | Physics-driven objects (crates, debris) | Forces/impulses, the engine integrates |
| `Area2D` | Detection zones, pickups, hurtboxes | Code; does not collide, only detects |

`AnimatableBody2D` is a `StaticBody2D` that reports motion to the physics engine (moving platforms). The 3D nodes (`CharacterBody3D`, etc.) mirror these one-to-one.

## CharacterBody2D

`velocity` is a member (`Vector2`). `move_and_slide()` takes no arguments, reads and writes `velocity`, applies it scaled by the physics delta internally, and returns `true` if it collided. Always drive it from `_physics_process`.

### Platformer template
```gdscript
extends CharacterBody2D

const SPEED := 300.0
const JUMP_VELOCITY := -400.0
const GRAVITY := 980.0

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += GRAVITY * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY
    var dir := Input.get_axis("move_left", "move_right")
    velocity.x = dir * SPEED if dir else move_toward(velocity.x, 0.0, SPEED)
    move_and_slide()
```

### Top-down template
```gdscript
extends CharacterBody2D

const SPEED := 200.0

func _ready() -> void:
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # no floor/wall notion

func _physics_process(_delta: float) -> void:
    velocity = Input.get_vector("left", "right", "up", "down") * SPEED
    move_and_slide()
```

### State after move_and_slide()
```gdscript
is_on_floor()    # bool, valid only after move_and_slide()
is_on_wall()
is_on_ceiling()
get_real_velocity()                       # actual velocity incl. slides
get_last_motion()                         # Vector2 moved this frame
get_floor_normal()
```

Key tuning properties: `up_direction` (default `Vector2(0, -1)`), `floor_max_angle` (default 45 degrees, in radians), `floor_snap_length` (keeps the body stuck to slopes/stairs), `floor_stop_on_slope`, `motion_mode` (`MOTION_MODE_GROUNDED` default, or `MOTION_MODE_FLOATING`).

### Reading slide collisions
```gdscript
move_and_slide()
for i in get_slide_collision_count():
    var c := get_slide_collision(i)          # KinematicCollision2D
    var other := c.get_collider()
    var normal := c.get_normal()
    if other is Enemy:
        (other as Enemy).take_damage(1)
```

### move_and_collide (manual, no auto-sliding)
```gdscript
# You scale by delta yourself; returns KinematicCollision2D or null
var collision := move_and_collide(velocity * delta)
if collision:
    velocity = velocity.bounce(collision.get_normal())
```

## Collision layers and masks

Two separate bitmasks per physics body:
- `collision_layer`: which layers this body *occupies* (what it is).
- `collision_mask`: which layers this body *scans* for (what it detects).

A detects B only if A's mask shares a bit with B's layer. Name the bits in Project Settings under Layer Names so the inspector reads "player"/"enemy"/"world" instead of numbers.

```gdscript
# Prefer the 1-based value helpers over raw bit math
set_collision_layer_value(2, true)   # occupy layer 2
set_collision_mask_value(3, true)    # also scan layer 3
var scans_world := get_collision_mask_value(1)
```

### One-way collision (any direction, Godot 4.7)

On a `CollisionShape2D` or `CollisionPolygon2D`, enable `one_way_collision` (bool, default `false`) to let bodies pass through from one side (jump-through platforms); `one_way_collision_margin` (float, default `1.0`) controls the depth tolerance. Before 4.7 the passable side was locked to the shape's local "up"; 4.7 adds `one_way_collision_direction` (a `Vector2`, default `Vector2(0, 1)`) so it can point anywhere relative to the shape, local to its rotation.
```gdscript
$CollisionShape2D.one_way_collision = true
$CollisionShape2D.one_way_collision_direction = Vector2(1, 0)   # blocks from the left only
```

## Area2D (detection, not collision)

```gdscript
extends Area2D

func _ready() -> void:
    body_entered.connect(_on_body_entered)   # PhysicsBody enters
    area_entered.connect(_on_area_entered)   # another Area enters

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        queue_free()  # picked up
```

`monitoring` (this area detects others) and `monitorable` (others can detect this area) are separate toggles. Overlap signals fire during physics; query current overlaps with `get_overlapping_bodies()` / `get_overlapping_areas()`.

## RigidBody2D

Let the engine integrate; do not set `position` directly each frame.
```gdscript
apply_central_impulse(Vector2(0, -500))   # instant kick
apply_central_force(Vector2(100, 0))      # continuous, per-frame
linear_velocity = Vector2(200, 0)         # direct set when needed

# Read/override physics state safely here, not in _physics_process
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    state.linear_velocity = state.linear_velocity.limit_length(MAX_SPEED)
```
Set `freeze = true` (with `freeze_mode`) to park a rigid body without removing it.

## Raycasting

### Node-based RayCast2D (persistent)
```gdscript
@onready var ray: RayCast2D = $RayCast2D

func _physics_process(_delta: float) -> void:
    ray.target_position = Vector2(0, 64)   # endpoint, local space (was cast_to in 3.x)
    if ray.is_colliding():
        var hit := ray.get_collider()
        var point := ray.get_collision_point()    # global
        var normal := ray.get_collision_normal()
```
Call `force_raycast_update()` after moving the ray when you need a result the same frame.

### One-shot space query (no node)
```gdscript
func raycast(from: Vector2, to: Vector2) -> Dictionary:
    var space := get_world_2d().direct_space_state
    var params := PhysicsRayQueryParameters2D.create(from, to)
    params.collision_mask = 1
    params.exclude = [self]
    return space.intersect_ray(params)   # {} if nothing hit, else position/normal/collider
```

## Groups for gameplay queries

```gdscript
add_to_group("enemies")
if body.is_in_group("player"): ...
for e in get_tree().get_nodes_in_group("enemies"):
    e.alert(global_position)
get_tree().call_group("enemies", "despawn")   # call a method on all
```

## Process callbacks

| Callback | Runs | Use for |
|---|---|---|
| `_process(delta)` | Every rendered frame | Visuals, UI, non-physics timers |
| `_physics_process(delta)` | Fixed step (default 60 Hz) | Movement, `move_and_slide`, forces, raycasts |

Physics delta is constant; render delta varies with framerate. Never call `move_and_slide()` or read physics state from `_process`.

## 3D differences

`CharacterBody3D` works the same with `Vector3` velocity; `up_direction` defaults to `Vector3.UP`. Use `Input.get_vector` for planar XZ movement and apply gravity on `velocity.y`. RayCast3D and `PhysicsRayQueryParameters3D` mirror the 2D API. Jolt Physics became the default 3D engine for new 3D projects in 4.6 (it was added as a built-in option in 4.4); existing projects keep their configured engine.
