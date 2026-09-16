---
type: Reference
title: "Godot Pitfalls & Breaking Changes"
description: "@export @onready var speed: float = 100.0"
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# Godot Pitfalls & Breaking Changes

**Verified 2026-06-19** against Godot 4.7 (the breaking-change and new-feature notes below are version-tagged). Re-verify the version-specific sections when a new Godot minor ships. The 4.7 facts are grounded in the official [Upgrading to 4.7](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html) migration guide and the [4.7 release notes](https://godotengine.org/releases/4.7/).

## Critical Pitfalls

### 1. @onready + @export = broken
```gdscript
# BAD: @onready overrides the inspector value at _ready time
@export @onready var speed: float = 100.0

# GOOD: Use one or the other
@export var speed: float = 100.0
@onready var sprite: Sprite2D = $Sprite2D
```

### 2. Parent not ready in child's _ready()
```gdscript
# BAD: parent's _ready() hasn't run yet
func _ready() -> void:
    get_parent().health  # parent may not be initialized

# GOOD: defer or use signal
func _ready() -> void:
    get_parent().ready.connect(_on_parent_ready, CONNECT_ONE_SHOT)
```

### 3. Resources are shared by reference
```gdscript
var a: ItemData = load("res://sword.tres")
var b: ItemData = load("res://sword.tres")
a.value = 999
print(b.value)  # 999! Same instance

# Fix: duplicate()
var unique: ItemData = load("res://sword.tres").duplicate()
```

### 4. Untyped code is 2x slower
```gdscript
# BAD
var speed = 100.0
var items = []

# GOOD
var speed: float = 100.0
var items: Array[Item] = []
```

### 5. get_node() every frame
```gdscript
# BAD: traverses tree each call
func _process(delta: float) -> void:
    get_node("Sprite2D").rotation += delta

# GOOD: cache with @onready
@onready var sprite: Sprite2D = $Sprite2D
```

### 6. Brittle node paths
```gdscript
# BAD
@onready var label = $"../../UI/Panel/VBox/Label"

# GOOD: unique names
@onready var label: Label = %ScoreLabel
```

### 7. _process for physics
```gdscript
# BAD: inconsistent at varying framerates
func _process(delta: float) -> void:
    move_and_slide()

# GOOD: _physics_process for physics
func _physics_process(delta: float) -> void:
    move_and_slide()
```

### 8. await hangs forever
```gdscript
# BAD: if signal never emits, coroutine leaks
await some_signal_that_might_never_fire

# SAFER: timeout pattern
var tween := create_tween()
tween.tween_callback(func() -> void: timed_out = true).set_delay(5.0)
await some_signal
tween.kill()
```

### 9. Forgetting set_input_as_handled()
```gdscript
# BAD: event propagates to _unhandled_input too
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        toggle_pause()

# GOOD: consume the event
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        toggle_pause()
        get_viewport().set_input_as_handled()
```

### 10. Not freeing nodes (memory leaks)
```gdscript
# Always queue_free() when done
func _on_screen_exited() -> void:
    queue_free()

# Godot 4.6: Use ObjectDB snapshots to debug leaked nodes
```

### 11. Using deprecated TileMap
```gdscript
# OLD (deprecated since 4.3)
var tilemap: TileMap = $TileMap
tilemap.set_cell(0, Vector2i(5, 3), 0, Vector2i(0, 0))  # layer param

# NEW
var layer: TileMapLayer = $GroundLayer
layer.set_cell(Vector2i(5, 3), 0, Vector2i(0, 0))  # no layer param
```

### 12. Typed array assignment from filter/map
```gdscript
# BAD: filter returns untyped Array
var items: Array[Item] = inventory.filter(func(i): return i.rare)  # ERROR

# GOOD: use .assign()
items.assign(inventory.filter(func(i: Item) -> bool: return i.rare))
```

### 13. Packed-array element writes skip the property setter (4.7)
```gdscript
# Since 4.7, writing one element no longer calls the property's setter.
var path: PackedVector2Array:
    set(value):
        path = value
        _rebuild()                 # this does NOT run on the line below

func _ready() -> void:
    path[0] = Vector2(5, 5)        # element write: setter is skipped, _rebuild() never fires

# Fix: reassign the whole array (or call the rebuild yourself)
    var p := path
    p[0] = Vector2(5, 5)
    path = p                       # full assignment triggers the setter
```

### 14. Overriding a typed-return method needs an explicit return (4.7)
```gdscript
# Since 4.7, an override inherits the parent's typed return, so a missing
# return is now a parse error where 4.6 silently returned null.
func get_speed() -> float:
    return 100.0

# Subclass override: must return a float explicitly now
func get_speed() -> float:        # inherited return type is enforced
    speed = 50.0
    return speed                  # 4.6 let you forget this; 4.7 errors
```

## Godot 4.7 Breaking Changes

For full details see the official [Upgrading to 4.7](https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html) guide. Most listed breaks are C#-only; the GDScript- and scene-facing ones are below.

### GDScript behavior
- Writing a single element of a packed array (`arr[i] = x`) no longer calls the array property's setter (see pitfall 13).
- An override of a method with a typed return now inherits that return type, so a missing `return` is a parse error (see pitfall 14).
- `Object.is_class()` takes a `StringName` instead of a `String` (auto-converts in GDScript; matters only for strictly-typed call sites).

### Input device IDs changed
- Keyboard and mouse input events used to report `device == 0`. They now report `InputEvent.DEVICE_ID_KEYBOARD` (16) and `InputEvent.DEVICE_ID_MOUSE` (32). Any code that hardcoded `event.device == 0` to mean "keyboard/mouse" breaks. See [input.md](input.md).

### RichTextLabel image API renamed
- `add_image()` / `update_image()`: the `width_in_percent` / `height_in_percent` bool params became `width_unit` / `height_unit` taking the new `RichTextLabel.ImageUnit` enum, and `width` / `height` changed from `int` to `float`.
- The constant `RichTextLabel.UPDATE_WIDTH_IN_PERCENT` is now `UPDATE_WIDTH_UNIT`.

### Removed
- `AudioEffectSpectrumAnalyzer.tap_back_pos` property removed (flag for audio-visualizer code).
- Android Google Play OBB export support removed; migrate to App Bundle / Play Asset Delivery, or use the separate Godot OBB Android plugin.

### 2D / rendering appearance changes
- `CanvasItem` no longer adds an antialiasing feather when drawing lines. Lines that relied on the implicit feather now look thinner; increase line width to compensate.
- The `LinearToSRGB` visual-shader node no longer clamps to `[0.0, 1.0]` on the Mobile and Forward+ renderers.

### Changed defaults (re-test if you relied on the old value)
| Node / setting | Property | Old | New |
|---|---|---|---|
| `LookAtModifier3D` | `relative` | `true` | `false` |
| Project Settings | `rendering/reflections/sky_reflections/roughness_layers` | `7` | `8` |
| `AudioStreamPlayer` | `area_mask` (effect) | enabled (`1`) | disabled (`0`) |
| `ResourceImporterDynamicFont` | `hinting` | `1` | `3` |
| Jolt `SoftBody3D` | `mass` | `0` | `1` kg |

Jolt physics also flipped the `WorldBoundaryShape3D.plane.d` sign convention and changed `SoftBody3D.linear_stiffness` behavior; `Area3D` now reports overlaps with `SoftBody3D`.

### Virtual methods that gained required params (only if you override them)
- `PhysicsServer2DExtension._body_set_shape_as_one_way_collision()` gained a `direction` parameter.
- `OpenXRExtensionWrapper._on_register_metadata()` gained `interaction_profile_metadata`.
- `EditorVCSInterface._commit()` gained `amend`.

### Still deprecated, not removed
- `TileMap` remains deprecated (since 4.3) but still loads; use `TileMapLayer`. It was **not** removed in 4.7.

## Godot 4.6 Breaking Changes

### Glow post-processing
- Glow now composited BEFORE tonemapping (was after)
- Default blend mode changed to Screen
- Default glow levels changed

### Physics
- Jolt Physics is default for NEW 3D projects (existing unchanged)
- Godot Physics still available

### Rendering
- Direct3D 12 is default on Windows for new projects

### Nodes
- Nodes now have internal unique IDs
- Re-save scenes via "Upgrade Project Files" to populate

### Signals
- Signals starting with underscore are hidden from auto-completion

## Deprecated API (4.x cumulative)

| Deprecated | Replacement |
|---|---|
| `TileMap` | `TileMapLayer` (4.3) |
| `yield` | `await` (4.0) |
| `connect("signal", obj, "method")` | `signal.connect(callable)` (4.0) |
| `emit_signal("name")` | `signal.emit()` (4.0) |
| `onready var` | `@onready var` (4.0) |
| `export var` | `@export var` (4.0) |
| `tool` keyword | `@tool` annotation (4.0) |
| `remote/puppet/master` | Multiplayer API (4.0) |

## Godot 4.7 New Features

Nodes and APIs (covered in the topical reference files):
- `AreaLight3D` rectangular area light (`Light3D` subclass). See [3d.md](3d.md).
- `VirtualJoystick` on-screen joystick `Control` for touch. See [input.md](input.md).
- `Tween.tween_await(signal)` pauses a tween until a signal fires. See [animation.md](animation.md).
- `Control.offset_transform_*` animates a control without affecting container layout. See [ui.md](ui.md).
- `GradientTexture2D.FILL_CONIC` conic (CSS-style) gradient fill. See [ui.md](ui.md).
- `CollisionShape2D.one_way_collision_direction` (Vector2) sets one-way collision to any direction. See [physics.md](physics.md).
- Input device IDs `InputEvent.DEVICE_ID_KEYBOARD` / `DEVICE_ID_MOUSE`, plus gyro/accelerometer reads and `Input.ignore_joypad_on_unfocused_application`. See [input.md](input.md).
- `DrawableTexture2D` (`Texture2D` subclass) for blitting onto a texture from code (`setup()` + `blit_rect()`, not a `draw_*` canvas).
- `Viewport.SCALING_3D_MODE_NEAREST` for crisp retro 3D. See [3d.md](3d.md).
- HDR output on Windows, macOS, iOS, visionOS, and Linux (Wayland); clearcoat moved toward Disney PBR.

Editor and workflow:
- Asset Store replaces the Asset Library (ratings, zoom, background threading). See [editor-tooling.md](editor-tooling.md).
- Dedicated `MeshLibrary` editor (like the TileSet editor) for GridMap tiles. See [3d.md](3d.md).
- GDExtensions are listed in Project Settings; right-click Inspector categories to copy/paste property values. See [editor-tooling.md](editor-tooling.md).
- Inline shader previews; selective per-platform export template downloads; GABE Android build environment is stable.
- 3D editor: vertex snapping (B), trackball rotation (U), Path3D collider snapping, CSG autosmoothing; 2D Scene Paint mode (B) for scattering nodes.
- Android: Picture-in-Picture, embedded resizable game window, standalone on-device export; Android XR and Steam Frame day-one support.

## Godot 4.6 New Features

- IK framework: TwoBoneIK3D, SplineIK3D, FABRIK3D, CCDIK3D, JacobianIK3D
- SSR completely rewritten
- LibGodot (engine embeddable as library)
- ObjectDB snapshots for debugging memory leaks
- Debugger "Step Out" button
- Scene tiles support 90-degree rotation
- Unified docking system with floating panels
- Game speed controls during editor testing
- Patch PCK delta encoding
- GDExtension JSON-based interface
- String placeholder highlighting in editor
- Drag resources into script editor for auto @export
