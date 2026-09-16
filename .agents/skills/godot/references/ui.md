---
type: Reference
title: "UI / Control Reference"
description: "UI lives under `Control` nodes, not `Node2D`."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# UI / Control Reference

**Verified 2026-06-19** against Godot 4.7. Godot 4 dropped the `rect_` prefix: it is `position`/`size`/`custom_minimum_size` (not `rect_position`/`rect_size`/`rect_min_size`) and anchor `offset_left/top/right/bottom` (not `margin_*`). 4.7 added `Control.offset_transform_*` (animate inside a container), `GradientTexture2D.FILL_CONIC`, and font-relative RichTextLabel images (and renamed the `add_image` percent params). Re-verify if a newer minor changes them.

## Control vs Node2D

UI lives under `Control` nodes, not `Node2D`. Controls have anchors, offsets, size flags, focus, and theme support. Put the whole UI under a `CanvasLayer` so it draws on top and ignores the world `Camera2D`.

```
CanvasLayer
  +-- Control (full-rect root)
        +-- MarginContainer
              +-- VBoxContainer
                    +-- Label
                    +-- Button
```

## Positioning: anchors, offsets, size

- `position` / `size` (Vector2): top-left and dimensions, relative to the parent rect.
- `custom_minimum_size` (Vector2): floor the node will not shrink below.
- `anchor_left/top/right/bottom` (0..1): which fraction of the parent edge each side tracks.
- `offset_left/top/right/bottom` (px): pixel distance from the anchored point.

Set anchors with presets instead of by hand:
```gdscript
set_anchors_preset(Control.PRESET_FULL_RECT)     # fill parent
set_anchors_preset(Control.PRESET_CENTER)
set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
```

## Prefer containers over manual anchoring

A `Container` lays out its children automatically; children give up their own `position`/`anchors`/`offsets`. This is the idiomatic way to build responsive UI.

| Container | Behavior |
|---|---|
| `VBoxContainer` / `HBoxContainer` | Stack children in a column/row |
| `GridContainer` | Grid with `columns` count |
| `MarginContainer` | Padding via theme constants `margin_left/top/right/bottom` |
| `CenterContainer` | Centers child at its minimum size |
| `PanelContainer` | Draws a StyleBox, then fills with the child |
| `ScrollContainer` | Scrollbars when the single child overflows |
| `TabContainer` | One child visible at a time, tabbed |
| `HSplitContainer` / `VSplitContainer` | Draggable divider between two children |
| `AspectRatioContainer` | Preserves child proportions on resize |
| `FlowContainer` | Wraps children to the next line/column |

### Size flags (how a child fills its container slot)
```gdscript
size_flags_horizontal = Control.SIZE_EXPAND_FILL   # grow to take free space and fill it
size_flags_vertical = Control.SIZE_SHRINK_CENTER
size_flags_stretch_ratio = 2.0                      # take 2x share vs siblings
```
`SIZE_FILL` (occupy the slot), `SIZE_EXPAND` (claim extra space), `SIZE_EXPAND_FILL` (both), `SIZE_SHRINK_CENTER`/`SHRINK_END` (stay minimum, align).

### Animating inside a container: offset_transform (Godot 4.7)

A `Container` overwrites a child's `position`/`scale`/`rotation` every layout pass, so a hover-pop or shake tween on a buttoned-up menu item normally fights the layout. 4.7 adds a separate visual transform that the container ignores:
```gdscript
button.offset_transform_enabled = true
var t := create_tween()
t.tween_property(button, "offset_transform_scale", Vector2(1.15, 1.15), 0.1)
```
Full set: `offset_transform_enabled` (bool), `offset_transform_position` / `offset_transform_position_ratio`, `offset_transform_rotation` (float), `offset_transform_scale`, `offset_transform_pivot` / `offset_transform_pivot_ratio`, and `offset_transform_visual_only`. Use it for juice (scale/rotate/nudge) on a control whose slot is managed by a container.

## Common nodes and signals

```gdscript
# Buttons
$Button.pressed.connect(_on_pressed)
$CheckButton.toggled.connect(func(on: bool) -> void: ...)
$OptionButton.item_selected.connect(func(idx: int) -> void: ...)

# Text
$Label.text = "Score: %d" % score
$RichTextLabel.bbcode_enabled = true
$RichTextLabel.text = "[b]Boss[/b] [color=red]warning[/color]"
$RichTextLabel.text = "press [img height=1em]res://key.png[/img]"  # 4.7: size inline images to font (1em)
$LineEdit.text_submitted.connect(_on_submit)      # Enter pressed
$TextEdit                                          # multiline editor

# Ranges
$HSlider.value_changed.connect(func(v: float) -> void: ...)
$ProgressBar.value = hp                            # also set min_value/max_value
```

## Input handling on Controls

Controls receive `_gui_input(event)`, gated by `mouse_filter`:
- `MOUSE_FILTER_STOP` (default): handle the event, stop propagation.
- `MOUSE_FILTER_PASS`: handle, then let it continue to nodes behind.
- `MOUSE_FILTER_IGNORE`: invisible to mouse (use on decorative labels/panels so clicks reach the control beneath).

```gdscript
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        accept_event()   # consume; equivalent to set_input_as_handled for GUI
```

Focus and keyboard/gamepad navigation: set `focus_mode`, wire `focus_neighbor_*`, and call `grab_focus()` on the first control when a menu opens.

## Theming

Prefer a `Theme` resource on a root Control (inherited by descendants) over per-node styling. For one-off tweaks use typed overrides:
```gdscript
$Label.add_theme_color_override("font_color", Color.RED)
$Label.add_theme_font_size_override("font_size", 24)
$Panel.add_theme_stylebox_override("panel", my_stylebox)
remove_theme_color_override("font_color")          # revert to theme
```
Each control type exposes named theme items (colors, fonts, font sizes, constants, styleboxes) listed under "Theme Properties" in its class docs.

## %unique names and @onready

UI trees get deep; use unique names so paths do not break when you reparent.
```gdscript
@onready var score_label: Label = %ScoreLabel      # mark node "Access as Unique Name"
@onready var hp_bar: ProgressBar = %HPBar
```

## Show/hide and modality

```gdscript
$Menu.visible = false                  # hidden but still in tree (process continues)
$Menu.hide()                           # same as visible = false
# Pause the world behind a menu without freezing the menu:
get_tree().paused = true
$PauseMenu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
```
For dialogs, `AcceptDialog`/`ConfirmationDialog`/`Window` provide `popup_centered()` and a `confirmed` signal.

## 4.7 extras

- `GradientTexture2D.fill = GradientTexture2D.FILL_CONIC` gives a conic (CSS-style sweep) gradient, alongside `FILL_LINEAR`/`FILL_RADIAL`/`FILL_SQUARE`. Useful as a `TextureRect` texture or `ProgressBar` fill.
- `PopupMenu` can show an optional search bar for long menus.
- A `TextureRect` can tile an `AtlasTexture` region as a repeating pattern.

## Pitfalls

- Building UI under `Node2D` instead of `Control`/`CanvasLayer`. UI belongs in the Control tree.
- Setting `position`/`offsets` on a child of a `Container`. The container overwrites them; for animation use `offset_transform_*` (4.7), otherwise change `custom_minimum_size` and size flags.
- Decorative panels eating clicks: set their `mouse_filter` to `IGNORE`.
- Reaching for Godot 3 names (`rect_size`, `margin_top`, `rect_min_size`). They no longer exist.
- **4.7 break:** `RichTextLabel.add_image()`/`update_image()` renamed the `width_in_percent`/`height_in_percent` bool args to `width_unit`/`height_unit` (now a `RichTextLabel.ImageUnit` enum), and `width`/`height` are `float`. The constant `UPDATE_WIDTH_IN_PERCENT` is now `UPDATE_WIDTH_UNIT`.
