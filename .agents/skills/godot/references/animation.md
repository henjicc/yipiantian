---
type: Reference
title: "Animation & Tween Reference"
description: "Create with `create_tween()` on any node."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# Animation & Tween Reference

**Verified 2026-06-19** against Godot 4.7. Godot 4 replaced the 3.x `Tween` *node* with code-created tweens from `create_tween()`; `Tween.new()` is invalid. Re-verify signatures if a newer minor changes them.

## Tween vs AnimationPlayer vs AnimationTree

| Tool | Use for |
|---|---|
| `Tween` (code) | Short, dynamic, fire-and-forget motion: move, fade, scale, shake, UI transitions |
| `AnimationPlayer` | Authored keyframe animations (sprite frames, cutscenes, complex multi-track) |
| `AnimationTree` | Blending and state machines over AnimationPlayer clips (locomotion, blend spaces) |

## Tween (code-driven)

Create with `create_tween()` on any node. Tweeners run **sequentially** by default; each `tween_*` call appends a step.

```gdscript
func _ready() -> void:
    var t := create_tween()
    t.tween_property(self, "position", Vector2(200, 0), 0.5)
    t.tween_property(self, "modulate:a", 0.0, 0.3)     # sub-property path
    t.tween_callback(queue_free)                        # runs after the fade
```

Property paths are strings, with `:` for sub-components (`"position:x"`, `"modulate:a"`, `"scale"`).

### Easing and transitions
```gdscript
var t := create_tween()
t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)   # applies to the whole tween
t.tween_property($Sprite2D, "position:y", -50.0, 0.4).as_relative()
```
`TRANS_*`: LINEAR, SINE, QUAD, CUBIC, QUART, QUINT, EXPO, CIRC, ELASTIC, BOUNCE, BACK, SPRING. `EASE_*`: IN, OUT, IN_OUT, OUT_IN. Per-step overrides chain onto the returned `PropertyTweener` (`.set_trans()`, `.set_delay()`, `.from()`, `.as_relative()`).

### Parallel, chaining, looping
```gdscript
var t := create_tween()
t.set_parallel()                          # following steps run together
t.tween_property(self, "position", target, 0.5)
t.tween_property(self, "rotation", TAU, 0.5)
t.chain().tween_callback(_on_arrived)     # chain() waits for the parallel block

create_tween().set_loops(3).tween_property(...)   # no arg = infinite
```

### Other tweeners and awaiting
```gdscript
t.tween_interval(0.25)                                     # pause in the sequence
t.tween_method(_set_shader_value, 0.0, 1.0, 1.0)          # call a setter with lerped values
t.tween_await(continue_button.pressed)                     # 4.7: hold the sequence until a signal fires
await t.finished                                          # coroutine waits for completion
```
`tween_await(signal)` (Godot 4.7) appends an `AwaitTweener` step that pauses the sequence until `signal` emits (or its connection becomes invalid), so a tween can wait on a button press, an animation, or any custom signal mid-chain without splitting into multiple coroutines.

### Lifecycle gotchas
- A tween auto-starts the same frame and frees itself when done. Keep a reference only if you call `kill()`, `pause()`, or `stop()`.
- Bind a tween's lifetime to a node with `t.bind_node(node)` so it dies when the node frees.
- A new `create_tween()` does not cancel earlier ones on the same property. Track and `kill()` the old tween to avoid two tweens fighting over `position`.

## AnimationPlayer

Authored clips with keyframe tracks. Drive it from code:
```gdscript
@onready var anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    anim.animation_finished.connect(_on_anim_finished)

func attack() -> void:
    anim.play("attack")
    await anim.animation_finished
    anim.play("idle")

func _on_anim_finished(name: StringName) -> void:
    if name == "death":
        queue_free()
```
Useful API: `play(name, custom_blend, custom_speed, from_end)`, `play_backwards(name)`, `stop()`, `pause()`, `is_playing()`, `current_animation`, `speed_scale` (negative plays backwards), `queue(name)` to chain, and `animation_finished`/`animation_changed` signals.

Animation tracks can keyframe any property and also fire **Call Method** tracks (e.g. spawn a hitbox mid-swing) and **Audio** tracks. Set `callback_mode_process` to physics when syncing to gameplay.

## AnimationTree (blending & state machines)

Wrap an `AnimationPlayer` with an `AnimationTree` whose `tree_root` is a blend tree or state machine. Set `active = true`. Drive state machines through the playback object:

```gdscript
@onready var tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = tree.get("parameters/playback")

func _physics_process(_delta: float) -> void:
    if velocity.length() > 0.0:
        playback.travel("run")          # travel respects transitions/conditions
    else:
        playback.travel("idle")

# Blend-space / blend-tree parameters are plain set() calls:
    tree.set("parameters/Move/blend_position", input_dir)
```

`travel()` finds a path through the state machine to the target state; setting `parameters/.../blend_position` drives 1D/2D blend spaces (e.g. directional locomotion).

## 2D sprite animation

- `AnimatedSprite2D` + `SpriteFrames` for simple frame-by-frame sprites: `play("walk")`, `animation_finished`, `sprite_frames`.
- For a sprite sheet on a plain `Sprite2D`, keyframe `frame` (with `hframes`/`vframes`) in an AnimationPlayer, or tween it.
