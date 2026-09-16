---
type: Reference
title: "SceneTree, Lifecycle & Pausing Reference"
description: "For the per-node callback order (`_init` / `_enter_tree` / `_ready` bottom-up / `_process`), see [architecture.md](architecture.md)."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# SceneTree, Lifecycle & Pausing Reference

**Verified 2026-06-06** against Godot 4.x. Godot 4 renamed `change_scene` to `change_scene_to_file` and added `change_scene_to_packed`. Re-verify if a newer minor changes them.

For the per-node callback order (`_init` / `_enter_tree` / `_ready` bottom-up / `_process`), see [architecture.md](architecture.md). This file covers the tree-wide concerns: changing scenes, pausing, timers, and safe tree mutation.

## get_tree() essentials

`get_tree()` returns the `SceneTree` singleton from any node in the tree.
```gdscript
get_tree().paused = true
get_tree().reload_current_scene()
get_tree().quit()                          # graceful exit at end of frame
get_tree().current_scene                   # root node of the active main scene
get_tree().root                            # the Window at the very top
get_tree().get_first_node_in_group("player")
await get_tree().process_frame             # wait one rendered frame
await get_tree().physics_frame             # wait one physics step
```

## Changing scenes (built-in)

Prefer the engine's switch over a hand-rolled manager for the common case:
```gdscript
get_tree().change_scene_to_file("res://scenes/level_2.tscn")   # returns Error
# Preload then swap (no load hitch at the switch):
const NEXT := preload("res://scenes/level_2.tscn")
get_tree().change_scene_to_packed(NEXT)
get_tree().reload_current_scene()                               # restart on death
```
These free the old scene and instance the new one for you. Roll a custom manager (see the event-bus/autoload pattern in [architecture.md](architecture.md)) only when you need transitions, additive scenes, or to keep state nodes alive across the swap.

For persistent state across scene changes, keep it in an autoload, not in the scene being freed.

## Pausing

Set `get_tree().paused = true`. Each node then obeys its `process_mode`:

| `process_mode` | Behavior while paused |
|---|---|
| `PROCESS_MODE_INHERIT` (default) | Follows the parent |
| `PROCESS_MODE_PAUSABLE` | Stops (the normal gameplay setting) |
| `PROCESS_MODE_WHEN_PAUSED` | Runs only while paused (pause menus) |
| `PROCESS_MODE_ALWAYS` | Always runs (music, input that toggles pause) |
| `PROCESS_MODE_DISABLED` | Never runs |

```gdscript
func toggle_pause() -> void:
    get_tree().paused = not get_tree().paused
    $PauseMenu.visible = get_tree().paused

func _ready() -> void:
    $PauseMenu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED   # stays live while paused
```
Pause affects `_process`, `_physics_process`, and animations/tweens on pausable nodes. It does not stop `_input` unless the node is itself paused.

## Timers

### One-shot SceneTreeTimer (no node needed)
```gdscript
await get_tree().create_timer(1.5).timeout
spawn_wave()
# create_timer(time_sec, process_always=true): pass false to make it respect pause
await get_tree().create_timer(1.0, false).timeout
```

### Timer node (repeating, editable in scene)
```gdscript
@onready var cooldown: Timer = $Cooldown    # one_shot/wait_time set in inspector

func _ready() -> void:
    cooldown.timeout.connect(_on_cooldown)

func fire() -> void:
    if cooldown.is_stopped():
        shoot()
        cooldown.start()                      # or start(custom_seconds)
```

## Safe tree mutation: deferred calls

Adding, removing, or reparenting nodes during a physics callback or while iterating signals can crash or flush mid-step. Defer it.
```gdscript
add_child(bullet)                # fine in _ready / normal flow
call_deferred("add_child", bullet)   # safe during _physics_process or signal handlers
remove_child.call_deferred(node)
node.set_deferred("monitoring", false)   # toggle physics flags safely
```
`queue_free()` is already deferred: it frees the node (and its children) at the end of the frame. Guard against double use with `is_queued_for_deletion()`, and after an `await`, re-check `is_instance_valid(node)` because the node may have freed while you waited.

## Toggling processing per node

```gdscript
set_process(false)            # stop _process for this node
set_physics_process(false)    # stop _physics_process
set_process_input(false)
process_priority = -1         # orders this node's processing within the frame
```

## Window / viewport quick access

```gdscript
get_viewport().get_visible_rect().size     # current viewport size
get_window().mode = Window.MODE_FULLSCREEN
get_viewport().set_input_as_handled()      # consume the current input event
```
