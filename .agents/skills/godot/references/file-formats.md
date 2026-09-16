---
type: Reference
title: "Text File Formats Reference (.tscn / .tres / project.godot)"
description: "Godot's scene (`.tscn`) and resource (`.tres`) files are human-readable INI-like text, which is why they belong in version control over the binary `.scn`/`.res`."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Text File Formats Reference (.tscn / .tres / project.godot)

**Verified 2026-06-06** against Godot 4.x. Godot 4 scenes/resources use `format=3`, string resource ids (`"1_7bt6s"`) with `uid="uid://.."`, and **`load_steps` is deprecated and ignored** (the 3.x "count the resources" rule no longer applies). Godot 4.4+ writes `.gd.uid` sidecars for scripts. Re-verify if a newer minor changes the format.

Godot's scene (`.tscn`) and resource (`.tres`) files are human-readable INI-like text, which is why they belong in version control over the binary `.scn`/`.res`. You can hand-author or patch them, but the editor is the source of truth; round-trip risky edits through it.

## .tscn (text scene)

```
[gd_scene load_steps=3 format=3 uid="uid://cecaux1sm7mo0"]

[ext_resource type="Script" path="res://scripts/player.gd" id="1_player"]
[ext_resource type="Texture2D" uid="uid://c4cp0al3ljsjv" path="res://assets/player.png" id="2_tex"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_box"]
size = Vector2(16, 24)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_player")

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("RectangleShape2D_box")

[connection signal="body_entered" from="Hurtbox" to="." method="_on_hurtbox_body_entered"]
```

Rules:
- **Header**: `format=3` marks a Godot 4 scene. `uid="uid://.."` is the stable identity. `load_steps` is deprecated and ignored in format=3; the editor still writes a value but you do not need to compute it when authoring by hand (in 3.x it had to equal ext+sub resources + 1).
- **Resource ids are strings** in Godot 4 (`"1_player"`, `"RectangleShape2D_box"`), not bare integers. `ext_resource` may carry a `uid=` so references survive file moves.
- **ext_resource**: external files (scripts, textures, other scenes). Reference with `ExtResource("id")`.
- **sub_resource**: resources embedded in this file. Reference with `SubResource("id")`.
- **Nodes**: the root `[node]` has no `parent`. Direct children use `parent="."`. Deeper nodes use `parent="Parent"` or `parent="Parent/Child"` (paths exclude the root name).
- **Properties** appear under a node only when they differ from the default.
- **Connections**: a `[connection]` block wires a signal from one node to a method on another, the text equivalent of an editor signal connection.
- An instanced child scene appears as `[node name=".." instance=ExtResource("..")]`; override the subtree with an `[editable path=".."]` block.

## .tres (text resource)

```
[gd_resource type="Resource" script_class="CardData" load_steps=2 format=3 uid="uid://dxy.."]

[ext_resource type="Script" path="res://scripts/data/card_data.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
card_name = "Fireball"
mp_cost = 3
```
The header is `[gd_resource ...]`; `script_class` names the `class_name` for a custom Resource. The single `[resource]` block holds the property values. Nested resources use `[sub_resource]` exactly as in scenes.

## UIDs and sidecar files

- `uid://..` is a stable identifier the editor maps to a path, so references survive moves and renames. Prefer `uid://` (or plain `res://` paths) in `load()` calls.
- Scenes and resources embed their UID in the header. Scripts and shaders have no header, so Godot 4.4+ writes a sidecar next to them: `player.gd.uid`, `effect.gdshader.uid`. **Commit these `.uid` files**; they are how references stay stable across machines.
- `ResourceUID` and `--import` regenerate the UID cache. If links break after a manual move, reopen the project or run `godot --headless --import`.

## project.godot

INI sections configure the project. Common ones:
```ini
[application]
config/name="My Game"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")

[autoload]
GameState="*res://scripts/autoload/game_state.gd"   ; leading * = enabled singleton
Events="*res://scripts/autoload/events.gd"

[display]
window/size/viewport_width=480
window/size/viewport_height=320
window/stretch/mode="viewport"          ; pixel-art friendly with a small viewport

[input]
move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"physical_keycode":87)]   ; W; editor writes the full object
}

[layer_names]
2d_physics/layer_1="world"
2d_physics/layer_2="player"
2d_physics/layer_3="enemy"
```
`config/features` records the engine version and renderer; read it to learn the project's Godot version. The `[input]` event objects are verbose; add actions in the editor's Input Map and copy the generated block rather than writing the object by hand. Name physics/render layers under `[layer_names]` so masks read as words in the inspector.

## Version control

- Commit: all `.tscn`, `.tres`, `.gd`, `.gdshader`, `.uid` files, `project.godot`, `export_presets.cfg`.
- Ignore: the `.godot/` folder (import cache and editor state) and exported builds. A fresh clone rebuilds `.godot/` via `godot --headless --import`.
