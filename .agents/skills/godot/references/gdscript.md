---
type: Reference
title: "GDScript Reference"
description: "var health: int = 100"
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# GDScript Reference

**Verified 2026-06-19** against Godot 4.7. Check the project's Godot version first; re-verify version-specific syntax if newer. 4.7 ships no new GDScript syntax but changes two behaviors (packed-array element writes skip the property setter; typed-return overrides now require an explicit `return`) covered under "Godot 4.7 behavior changes" below.

## Variable Declarations

```gdscript
# Explicit type annotation (preferred)
var health: int = 100
var velocity: Vector2 = Vector2.ZERO

# Type inference with :=
var speed := 600.0
var is_alive := true

# Constants
const MAX_HEALTH := 100
const BOARD_SIZE := Vector2i(10, 10)

# Static variables (shared across instances)
static var spawn_count := 0
```

## Typed Collections

```gdscript
# Typed arrays
var inventory: Array[Item] = []
var scores: Array[int] = [10, 20, 30]

# Typed dictionaries (Godot 4.4+)
var item_quantities: Dictionary[String, int] = {"potion": 5}
var stats: Dictionary[String, float] = {"attack": 10.0}

# IMPORTANT: Use .assign() for filtered results into typed arrays
displayed_items.assign(
    inventory.filter(func(item: Item) -> bool: return item.category == cat)
)
```

## Functions

```gdscript
func calculate_damage(base: float, multiplier: float) -> float:
    return base * multiplier

func heal(amount := 10) -> void:
    health = mini(health + amount, MAX_HEALTH)

static func get_count() -> int:
    return spawn_count
```

## Properties

```gdscript
var score: int:
    get:
        return _score
    set(value):
        _score = clampi(value, 0, 9999)
        score_changed.emit(_score)
```

## Annotations

### Script-level
- `@tool` - runs in editor
- `@icon("res://icon.png")` - custom editor icon

### Variable annotations
```gdscript
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = %ScoreLabel          # % = unique node name

@export var speed: float = 300.0
@export_range(0, 100) var percentage: int = 50
@export_range(0, 1000, 1, "or_greater") var damage: int
@export_enum("Sword", "Bow", "Staff") var weapon_type: int
@export_file("*.tscn") var level_path: String
@export_dir var save_dir: String
@export_multiline var description: String
@export_flags("Fire", "Ice", "Lightning") var elements: int = 0
@export_exp_easing var fade_curve: float
@export_color_no_alpha var tint: Color

# Inspector organization
@export_category("Stats")     # bold top-level heading
@export_group("Movement")     # collapsible group
@export_subgroup("Jump")      # nested sub-section

# Newer 4.x exports (see editor-tooling.md)
@export_storage var _cached: int  # saved but hidden in inspector
@export_tool_button("Run") var run := _do  # 4.4+; needs @tool, var must be a Callable
```

**CRITICAL: Never combine @onready with @export. @onready overrides exported values.**

### Warning control
```gdscript
@warning_ignore("unused_variable")
var temp := 0
```

## Signals

```gdscript
# Declaration
signal died
signal health_changed(new_health: int)
signal damage_taken(amount: float, source: Node)

# Emitting
health_changed.emit(current_health)

# Connecting
$Button.pressed.connect(_on_button_pressed)
enemy.died.connect(_on_enemy_died)
timer.timeout.connect(_on_timeout, CONNECT_ONE_SHOT)

# Bind extra args
buttons[i].pressed.connect(_on_btn.bind(i))

# Unbind signal args you don't need
$Area2D.area_entered.connect(_trigger.unbind(1))

# Disconnect
health_changed.disconnect(_on_health_changed)
```

Signal parameter types are NOT enforced at emit time.

## Enums

```gdscript
enum State { IDLE, WALKING, RUNNING }
var current_state: State = State.IDLE

# Anonymous (values become script constants)
enum { TILE_GRASS, TILE_WATER, TILE_STONE }
```

## Lambdas

```gdscript
var is_pos := func(x: float) -> bool: return x >= 0.0
is_pos.call(8.0)

items.sort_custom(func(a: Item, b: Item) -> bool: return a.price > b.price)

button.pressed.connect(func() -> void:
    score += 1
)
```

## Await / Coroutines

```gdscript
await enemy.ready
await get_tree().create_timer(0.2).timeout
var action: String = await player_action_chosen

# Any function with await becomes a coroutine
# Callers can await it: await spawn_enemy()
# WARNING: If signal never emits, coroutine hangs until object freed
```

## Match with Pattern Guards

```gdscript
match current_state:
    State.IDLE:
        play("idle")
    State.WALKING, State.RUNNING:
        play("move")
    _:
        pass

# Guards with "when"
match value:
    var x when x > 100:
        print("Large: ", x)
    _:
        print("Other")
```

## Abstract Classes (Godot 4.5+)

```gdscript
@abstract
class_name BaseEnemy
extends CharacterBody2D

@abstract
func get_attack_damage() -> int:
    return 0
```

## Godot 4.7 behavior changes

Two silent-but-breaking changes, no new syntax:

```gdscript
# 1. Writing one element of a packed-array property no longer calls its setter.
var path: PackedVector2Array:
    set(value): path = value; _rebuild()

path[0] = Vector2.ZERO     # 4.7: setter does NOT fire, _rebuild() skipped
var p := path; p[0] = Vector2.ZERO; path = p   # reassign the whole array to trigger it

# 2. An override inherits the parent's typed return, so a missing return now errors.
func score() -> int:
    return 0
# override must end in `return <int>`; 4.6 silently returned null, 4.7 is a parse error
```
Also: `Object.is_class()` now takes a `StringName` (auto-converts from `String` literals). See [pitfalls.md](pitfalls.md) for the full 4.7 break list.

## Class Structure and Inheritance

```gdscript
class_name Player
extends CharacterBody2D

# Preloading
const BulletScene := preload("res://bullet.tscn")

# super calls parent
func _ready() -> void:
    super()

func take_damage(amount: int) -> void:
    super.take_damage(amount)
```

## Node Access

```gdscript
$Sprite2D              # direct child
$UI/HBox/Label         # nested path
%ScoreLabel            # unique name (anywhere in scene)
```

## Recommended File Structure

```gdscript
@tool                          # 1. Tool annotation
class_name MyClass             # 2. Class name
extends Node2D                 # 3. Extends

## Documentation comment       # 4. Docstring

signal health_changed(hp: int) # 5. Signals
enum State { IDLE, RUN }       # 6. Enums
const MAX_SPEED := 400.0       # 7. Constants
@export var speed: float       # 8. Exports
var health: int = 100          # 9. Public vars
var _state: State              # 10. Private vars
@onready var sprite: Sprite2D = $Sprite2D  # 11. Onready

func _ready() -> void: pass    # 12. Engine callbacks
func _process(delta: float) -> void: pass
func take_damage(a: int) -> void: pass  # 13. Public methods
func _update_state() -> void: pass      # 14. Private methods
```

## preload vs load

```gdscript
# preload: compile-time, path must be literal string constant
const SCENE := preload("res://bullet.tscn")

# load: runtime, can use variables, causes small hitch
var scene: PackedScene = load("res://level_%d.tscn" % n)

# Threaded loading for large resources
ResourceLoader.load_threaded_request(path)
# ...later:
var res = ResourceLoader.load_threaded_get(path)
```

## Static Typing Performance

Statically typed GDScript runs up to 2x faster than untyped. Always add types.
