---
type: Reference
title: "Navigation & Pathfinding Reference"
description: "For the hand-built `AStar2D` graph pattern, see [architecture.md](architecture.md)."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Navigation & Pathfinding Reference

**Verified 2026-06-06** against Godot 4.x. Godot 4 reworked navigation around `NavigationServer2D`/`3D`, `NavigationAgent2D`/`3D`, and baked navmesh regions, and added `AStarGrid2D` for grid pathfinding. Re-verify signatures if a newer minor changes them.

## Pick an approach

| Approach | Best for |
|---|---|
| `AStarGrid2D` | Uniform tile grids (tactics, roguelikes); built-in, no manual graph |
| `AStar2D` | Arbitrary node graphs (waypoints, irregular connections) |
| `NavigationAgent2D` + navmesh | Free/continuous movement over walkable areas with avoidance |

For the hand-built `AStar2D` graph pattern, see [architecture.md](architecture.md). Prefer `AStarGrid2D` below when the world is a plain grid.

## AStarGrid2D (grid pathfinding, built-in)

No manual point/connection wiring. Define the region, mark solids, query a path.
```gdscript
var astar := AStarGrid2D.new()
astar.region = Rect2i(0, 0, width, height)
astar.cell_size = Vector2(TILE, TILE)
astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
astar.update()                                   # call after configuring

for wall in wall_cells:
    astar.set_point_solid(wall, true)            # block a cell

var path: Array[Vector2i] = astar.get_id_path(Vector2i(0, 0), Vector2i(9, 9))
var world_path: PackedVector2Array = astar.get_point_path(start, goal)   # in pixels
```
Toggle `set_point_solid` and `set_point_weight_scale` as the map changes, then re-query (no full rebuild needed).

## NavigationAgent2D (navmesh movement)

For agents moving continuously over walkable areas (not locked to a grid).

### 1. Bake a walkable area
Add a `NavigationRegion2D` with a `NavigationPolygon`; outline the walkable area (or bake from the tilemap/collision) so the `NavigationServer2D` has a map. `TileMapLayer` can also contribute navigation per tile.

### 2. Drive a body with the agent
```gdscript
extends CharacterBody2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D

const SPEED := 200.0

func set_goal(world_pos: Vector2) -> void:
    agent.target_position = world_pos            # triggers async path computation

func _physics_process(_delta: float) -> void:
    if agent.is_navigation_finished():
        return
    var next: Vector2 = agent.get_next_path_position()   # call every physics frame
    velocity = global_position.direction_to(next) * SPEED
    move_and_slide()
```
Tune with `path_desired_distance` (how close before advancing a waypoint) and `target_desired_distance` (how close counts as arrived). Listen to `navigation_finished` for arrival. The first path may be empty for a frame or two while the server computes it; guard with `is_navigation_finished()`.

### 3. Local avoidance (RVO)
With multiple agents, enable avoidance and route velocity through the server:
```gdscript
func _ready() -> void:
    agent.avoidance_enabled = true
    agent.velocity_computed.connect(_on_safe_velocity)

func _physics_process(_delta: float) -> void:
    var next := agent.get_next_path_position()
    var intended := global_position.direction_to(next) * SPEED
    agent.set_velocity(intended)                 # do NOT move_and_slide here

func _on_safe_velocity(safe: Vector2) -> void:   # avoidance-adjusted velocity
    velocity = safe
    move_and_slide()
```

## One-shot path query (no agent node)

```gdscript
var map := get_world_2d().navigation_map
var path: PackedVector2Array = NavigationServer2D.map_get_path(
    map, global_position, target, true)          # true = optimize
```

## 3D

`NavigationRegion3D` + `NavigationMesh` (bake from the scene geometry), `NavigationAgent3D`, and `NavigationServer3D.map_get_path` mirror the 2D API with `Vector3`. Bake the navmesh after geometry changes.

## Pitfalls

- Not calling `get_next_path_position()` every physics frame; the agent's internal path logic needs it to advance.
- Calling `move_and_slide()` directly while avoidance is on; with avoidance you must move from inside the `velocity_computed` handler.
- Expecting a path the same frame you set `target_position`; computation is async.
- Forgetting `astar.update()` after configuring `AStarGrid2D`, or re-querying without toggling `set_point_solid` when the map changed.
