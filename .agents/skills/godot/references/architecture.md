---
type: Reference
title: "Godot Architecture Patterns"
description: "func _ready() -> void:"
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Godot Architecture Patterns

**Verified 2026-06-06** against Godot 4.x. These patterns are paradigm-level and age slowly; the API names within them follow the current stable.

## Scene Organization

### "Call Down, Signal Up" Rule

- Parent calls methods on children: `$Child.do_thing()`
- Children emit signals upward: `signal happened.emit()`
- Siblings wired by common parent in `_ready()`
- NEVER use `get_parent()` to call parent methods

```gdscript
# Parent wires child signal to sibling
func _ready() -> void:
    $HurtBox.area_entered.connect($DamageHandler.on_hit)
```

### Node Initialization Order

1. `_init()` - top-down (parent first)
2. `_enter_tree()` - top-down (parent first)
3. `_ready()` - BOTTOM-UP (children first, parent last)
4. `_process()` - top-down (parent first)

In parent's `_ready()`, all children are initialized. In child's `_ready()`, parent is NOT yet ready.

## Autoload / Singleton Pattern

### Setup (project.godot)
```ini
[autoload]
GameState="*res://scripts/autoload/game_state.gd"
Events="*res://scripts/autoload/events.gd"
```

Must extend `Node` (or subclass). Persists across scene changes.

### Event Bus Pattern

```gdscript
# events.gd (autoload)
extends Node

signal enemy_died(enemy: Node, position: Vector2)
signal player_took_damage(amount: int)
signal level_completed(level_id: int)

# Any node emits: Events.enemy_died.emit(self, global_position)
# Any node listens: Events.enemy_died.connect(_on_enemy_died)
```

### Scene Switching

For the common case, use the built-in `get_tree().change_scene_to_file(path)` / `change_scene_to_packed(packed)` (see [scene-tree.md](scene-tree.md)). Roll a custom manager like the one below only when you need transitions, additive scenes, or to keep state nodes alive across the swap.

```gdscript
# scene_manager.gd (autoload)
extends Node

var current_scene: Node

func _ready() -> void:
    current_scene = get_tree().root.get_child(-1)

func change_scene(path: String) -> void:
    call_deferred("_deferred_change", path)

func _deferred_change(path: String) -> void:
    current_scene.free()
    var new_scene: PackedScene = load(path)
    current_scene = new_scene.instantiate()
    get_tree().root.add_child(current_scene)
    get_tree().current_scene = current_scene
```

## Resource System

### Custom Resources

```gdscript
class_name ItemData
extends Resource

@export var name: String = ""
@export var icon: Texture2D
@export var value: int = 0
@export var tags: Array[String] = []

func get_sell_price() -> int:
    return value / 2
```

Create .tres files in editor: right-click FileSystem -> New Resource -> pick class_name.

### Key Resource Facts
- Resources loaded from same path share one instance in memory
- Modifying one affects all references to same .tres
- Use `.duplicate()` for per-instance copies
- Set `resource_local_to_scene = true` for auto-unique copies per scene instance
- `.tres` = text (VCS-friendly), `.res` = binary (smaller, faster)

### Save/Load with Resources

```gdscript
class_name SaveData
extends Resource

@export var player_pos: Vector2
@export var health: int
@export var inventory: Array[ItemData] = []

# Save
ResourceSaver.save(data, "user://save.tres")

# Load
if ResourceLoader.exists("user://save.tres"):
    var data: SaveData = load("user://save.tres")
```

## Input Handling

### Propagation Order
1. `_input()` - system controls (pause, screenshot)
2. `_gui_input()` - UI/Control nodes
3. `_shortcut_input()` - shortcuts
4. `_unhandled_key_input()` - unhandled keys
5. `_unhandled_input()` - gameplay input (movement, attacks)

### Best Practices

```gdscript
# Use _unhandled_input for gameplay (runs after UI consumes events)
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("attack"):
        attack()
        get_viewport().set_input_as_handled()

# Use Input polling in _process/_physics_process for continuous actions
func _physics_process(delta: float) -> void:
    var dir := Input.get_vector("left", "right", "up", "down")
    velocity = dir * speed
    move_and_slide()
```

Event-based (_unhandled_input) for discrete actions: jump, attack, interact.
Polling (Input.is_action_pressed) for continuous: movement, aiming.

## Common 2D Game Patterns

### Grid-Based Movement

```gdscript
extends Node2D

const TILE_SIZE := 24

var grid_pos: Vector2i = Vector2i.ZERO

func move(direction: Vector2i) -> void:
    grid_pos += direction
    # Snap or tween
    var target := Vector2(grid_pos) * TILE_SIZE
    var tween := create_tween()
    tween.tween_property(self, "position", target, 0.1)
```

### Turn-Based State Machine

```gdscript
enum TurnPhase { PLAYER_INPUT, PLAYER_ACTION, ENEMY_ACTION, ENVIRONMENT }

var current_phase: TurnPhase = TurnPhase.PLAYER_INPUT

signal turn_completed

func advance_phase() -> void:
    match current_phase:
        TurnPhase.PLAYER_INPUT:
            current_phase = TurnPhase.PLAYER_ACTION
        TurnPhase.PLAYER_ACTION:
            current_phase = TurnPhase.ENEMY_ACTION
        TurnPhase.ENEMY_ACTION:
            current_phase = TurnPhase.ENVIRONMENT
        TurnPhase.ENVIRONMENT:
            current_phase = TurnPhase.PLAYER_INPUT
            turn_completed.emit()
```

### AStar2D Pathfinding

For a plain tile grid, prefer the built-in `AStarGrid2D` (no manual point/connection wiring); for navmesh-based continuous movement use `NavigationAgent2D`. Both are covered in [navigation.md](navigation.md). The manual `AStar2D` graph below suits arbitrary waypoint graphs with irregular connections.

```gdscript
var astar := AStar2D.new()

# Build grid
func build_pathfinding(width: int, height: int, walkable: Callable) -> void:
    for y in range(height):
        for x in range(width):
            var id := y * width + x
            if walkable.call(Vector2i(x, y)):
                astar.add_point(id, Vector2(x, y))
    # Connect neighbors
    for y in range(height):
        for x in range(width):
            var id := y * width + x
            if not astar.has_point(id):
                continue
            for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1,1), Vector2i(1,-1)]:
                var nx := x + dir.x
                var ny := y + dir.y
                var nid := ny * width + nx
                if astar.has_point(nid):
                    astar.connect_points(id, nid)

# Find path
func get_path_to(from: Vector2i, to: Vector2i, width: int) -> PackedVector2Array:
    var from_id := from.y * width + from.x
    var to_id := to.y * width + to.x
    return astar.get_point_path(from_id, to_id)
```

### Fog of War (Simple Approach)

```gdscript
enum Visibility { HIDDEN, SEEN, VISIBLE }

var vis_map: Array[Array] = []  # 2D array of Visibility

func update_visibility(player_pos: Vector2i, radius: int) -> void:
    # Reset all VISIBLE to SEEN
    for y in range(vis_map.size()):
        for x in range(vis_map[y].size()):
            if vis_map[y][x] == Visibility.VISIBLE:
                vis_map[y][x] = Visibility.SEEN
    # Reveal around player
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            var pos := player_pos + Vector2i(dx, dy)
            if pos.x >= 0 and pos.y >= 0 and pos.y < vis_map.size() and pos.x < vis_map[0].size():
                if Vector2(dx, dy).length() <= radius:
                    vis_map[pos.y][pos.x] = Visibility.VISIBLE
```

## File Extensions

| Extension | Purpose |
|-----------|---------|
| `.tscn` | Scene (text) |
| `.scn` | Scene (binary) |
| `.tres` | Resource (text) |
| `.res` | Resource (binary) |
| `.gd` | GDScript |
| `.gdshader` | Shader |
| `.import` | Import metadata (auto) |
| `.godot` | Project settings |
