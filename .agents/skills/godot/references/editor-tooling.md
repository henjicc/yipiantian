---
type: Reference
title: "Editor Tooling & Exposing Tunables Reference"
description: "The clean Godot answer to \"let me adjust custom things in the editor instead of hunting for constants in code\" is **data-driven design**: never hardcode a tunable as a code constant when you can…"
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# Editor Tooling & Exposing Tunables Reference

**Verified 2026-06-19** against Godot 4.7. In 4.6 the dock API changed: `EditorPlugin.add_control_to_dock()` and `add_control_to_bottom_panel()` are **deprecated** in favor of `add_dock(EditorDock)`. `@export_tool_button` arrived in 4.4. Re-verify if a newer minor changes them.

The clean Godot answer to "let me adjust custom things in the editor instead of hunting for constants in code" is **data-driven design**: never hardcode a tunable as a code constant when you can expose it as an `@export` or store it in a `Resource` the inspector edits. Reach for the lightest tool that works, and only build custom editor UI when the inspector genuinely cannot express what you need.

## Decision guide (reach for the first that fits)

| Need | Use |
|---|---|
| Tweak a node's own values | `@export` vars, grouped, in the Inspector |
| Centralize/share tunables across scenes, swap presets | custom `Resource` (`.tres`) data files |
| Run an action or live preview in-editor, no play mode | `@tool` + `@export_tool_button` |
| A persistent custom panel/dock with widgets | `EditorPlugin` + `add_dock()` |
| A custom control for a specific property type | `EditorInspectorPlugin` + `EditorProperty` |
| A one-off batch operation | `EditorScript` (File > Run) |

## 1. @export in the Inspector (default, covers most cases)

Expose tunables as exported variables; the Inspector becomes your control panel. Group them so the panel stays readable.
```gdscript
@export_category("Enemy")
@export_group("Combat")
@export_range(1, 500, 1, "or_greater") var max_health: int = 100
@export_range(0.0, 10.0, 0.1) var attack_cooldown: float = 1.5
@export_subgroup("Loot")
@export var drop_table: Array[ItemData] = []
```
See [gdscript.md](gdscript.md) for the full annotation list (`@export_enum/_file/_dir/_flags/_color_no_alpha`, etc.). Never combine `@export` with `@onready` (see [pitfalls.md](pitfalls.md)).

## 2. Custom Resources as shared, editable data

When the same constants are used across many scenes, or you want swappable presets (difficulty tiers, enemy archetypes, weapon stats), put them in a custom `Resource`. You then edit `.tres` files in the Inspector and the data lives in one place, not scattered through scripts.
```gdscript
class_name EnemyStats
extends Resource

@export var display_name: String = ""
@export_range(1, 999) var health: int = 10
@export var speed: float = 80.0
@export var loot: Array[ItemData] = []
```
Create `res://data/enemies/goblin.tres`, `dragon.tres`, etc. (FileSystem > right-click > New Resource), fill them in the Inspector, and reference one per enemy:
```gdscript
@export var stats: EnemyStats     # drop a .tres in; designers tune without touching code
```
This is the cleanest fix for "crawling the codebase for constants": the constants become data assets. See [architecture.md](architecture.md) for the Resource system and `.tres` details.

## 3. @tool scripts and inspector buttons

`@tool` makes a script run inside the editor, for live preview, validation, or one-click actions. Guard anything that should only happen at runtime.
```gdscript
@tool
extends Node2D

@export var radius: float = 32.0:
    set(value):
        radius = value
        queue_redraw()                     # live preview as you drag the value

@export_tool_button("Regenerate", "Reload") var regen_action: Callable = regenerate

func regenerate() -> void:
    # runs when the inspector button is clicked, no play mode needed
    ...

func _ready() -> void:
    if Engine.is_editor_hint():
        return                              # skip gameplay setup in the editor
```
`@export_tool_button` (4.4+) needs the class to be `@tool` and the variable to hold a `Callable`. Use `_get_configuration_warnings()` to flag misconfigured nodes with a warning icon in the scene tree.

## 4. EditorPlugin: custom docks and panels

When you want a real panel (sliders, lists, buttons that drive your data), ship an editor plugin under `addons/`.

`addons/my_tools/plugin.cfg`:
```ini
[plugin]
name="My Tools"
description="Custom tuning dock"
author="you"
version="1.0"
script="plugin.gd"
```

`addons/my_tools/plugin.gd`:
```gdscript
@tool
extends EditorPlugin

var dock: EditorDock

func _enter_tree() -> void:
    dock = preload("res://addons/my_tools/dock.tscn").instantiate()
    add_dock(dock)                          # 4.6 API; set EditorDock.default_slot for placement

func _exit_tree() -> void:
    remove_dock(dock)                       # ALWAYS clean up what you added
    dock.free()
```
- **4.6**: prefer `add_dock(EditorDock)` / `remove_dock()`. The older `add_control_to_dock(slot, control)` and `add_control_to_bottom_panel(control, title)` still work but are deprecated.
- Still current: `add_control_to_container()`, `add_inspector_plugin()`, `add_autoload_singleton()`.
- Enable the plugin in Project Settings > Plugins. The dock's controls can read and write your config `Resource`, giving you the "adjust custom things in a panel" workflow.

## 5. Custom inspector widgets (EditorInspectorPlugin + EditorProperty)

To replace the default editor for a specific property (a custom curve, a tile picker), add an inspector plugin from your `EditorPlugin`:
```gdscript
add_inspector_plugin(my_inspector_plugin)   # in _enter_tree; remove_inspector_plugin in _exit_tree
```
`EditorInspectorPlugin` implements `_can_handle(object)` and `_parse_property(...)`, calling `add_property_editor(name, editor)` to inject an `EditorProperty` subclass. The `EditorProperty` builds its control in `_init()`, syncs from data in `_update_property()`, and writes back with `emit_changed(get_edited_property(), value)`.

## Editor quality-of-life (Godot 4.7)

- **Inspector copy/paste:** right-click a category or group of properties to copy and paste their values as a block, handy for cloning tuned setups across nodes/resources.
- **GDExtensions in Project Settings:** loaded `.gdextension` files now have a dedicated section in Project Settings, so you can see what native extensions a project pulls in.
- **Asset Store** replaces the Asset Library for browsing and installing addons/plugins (ratings, preview zoom, background-threaded downloads). Enable an installed plugin under Project Settings > Plugins as before.
- **MeshLibrary editor** gives GridMap tiles a dedicated editor like the TileSet editor (see [3d.md](3d.md)).

## Pitfalls

- Hardcoding a tunable as a `const` in code when it could be an `@export` or a Resource field. That is the thing to avoid.
- Building a custom dock for what a single `@export` would do. Escalate only when the Inspector cannot express it.
- In 4.6, reaching for the deprecated `add_control_to_dock` / `add_control_to_bottom_panel`; use `add_dock()`.
- Forgetting `@tool` on an editor script or plugin (it will not run in the editor).
- Not removing controls/docks/inspector plugins in `_exit_tree()` (leaks on plugin reload).
- `@export_tool_button` whose var is not a `Callable`, or whose class is not `@tool`.
- Running gameplay or destructive logic in a `@tool` script without an `Engine.is_editor_hint()` guard.
