---
name: godot
description: Godot game engine development skill, a dated snapshot tracking the current stable Godot (4.x, currently 4.7). Covers GDScript static typing and syntax, scene and node architecture, the resource system, signals, autoloads, the SceneTree and lifecycle, physics and movement, collision and raycasts, input, math and vectors, navigation and pathfinding, TileMapLayer, UI and Control nodes, animation and tweens, audio, shaders, particles, saving and persistence, performance, testing, multiplayer, the editor and CLI workflow, the .tscn/.tres/project.godot text formats, and version-specific pitfalls and breaking changes. Use when working on any Godot project, whether writing GDScript, creating or editing scenes and resources, configuring project.godot, building game systems, or debugging Godot-specific issues. Triggers on any Godot game development task. Check the project's Godot version first; this snapshot ages, so verify version-specific claims against the official docs when the snapshot date looks old.
tags: [game, godot, gdscript]
date: 2026-06-19
---

# Godot Development

This skill tracks the current stable Godot, captured as a dated snapshot. The paradigms (typed GDScript, TileMapLayer over TileMap, annotation and signal syntax, call-down-signal-up) move slowly. The exact version numbers and per-release breaking changes move fast, so the version-specific facts are dated and meant to be re-verified.

## Snapshot and freshness

- **Snapshot date: 2026-06-19** (the `date` in the frontmatter). The snapshot currently targets the **Godot 4.x** line, with **4.7** as the current stable. Each reference file also carries its own `Verified` date.
- **Check the project's Godot version first.** Read `project.godot` for `config/features` (e.g. `PackedStringArray("4.7", ...)`) and the editor version. The installed major.minor decides which pitfalls and APIs apply. Never assume it from memory.
- **Staleness rule.** If today is well past a reference file's `Verified` date, or a new Godot minor has shipped, treat that file's version-specific claims (breaking changes, "new in" features, default-changed behavior) as suspect and confirm against the official release notes. The core paradigm sections age far slower than the version notes.
- **Updating.** When a claim matters for the task, confirm it against the official Godot docs or the release notes for that version, then refresh the reference file and bump its `Verified` line. Maintainers: see [MAINTENANCE.md](MAINTENANCE.md).

## Core Rules

1. **Always use static typing** - typed GDScript is significantly faster and catches errors at parse time
2. **Use TileMapLayer, not TileMap** - TileMap is deprecated since 4.3
3. **Use annotation syntax** - `@export`, `@onready`, `@tool` (not the old keywords)
4. **Use the current signal syntax** - `signal.connect(callable)`, `signal.emit()`
5. **Call down, signal up** - parents call children, children emit signals
6. **Never combine @onready with @export** - @onready overrides exported values

## Project Structure Convention

```
res://
  scenes/         .tscn scene files with co-located .gd scripts
  scripts/
    autoload/     singleton scripts (registered in project.godot)
    data/         class_name Resource definitions
    systems/      game system logic
  resources/      .tres data files (organized by type)
  assets/
    sprites/      textures, spritesheets
    tilesets/     tileset resources
    audio/        sound effects, music
```

## Reference Files

Consult these based on the task at hand. Each carries its own `Verified` date.

**Language and project**
- **GDScript syntax, annotations, signals, typed collections, lambdas, await, match, abstract classes, file structure convention** - See [references/gdscript.md](references/gdscript.md)
- **Scene organization, autoloads, event bus, resource system, grid movement, turn-based patterns, fog of war** - See [references/architecture.md](references/architecture.md)
- **SceneTree, changing scenes (change_scene_to_file), pausing and process_mode, timers, deferred calls and safe tree mutation, node lifecycle** - See [references/scene-tree.md](references/scene-tree.md)
- **Text file formats (.tscn, .tres, project.godot), ext_resource/sub_resource, connections, UIDs and .uid sidecars, version control** - See [references/file-formats.md](references/file-formats.md)
- **Editor tooling and exposing tunables in the editor, @export and grouping, data-driven custom Resources, @tool and @export_tool_button, EditorPlugin docks (add_dock), custom inspector widgets** - See [references/editor-tooling.md](references/editor-tooling.md)
- **Common pitfalls, deprecated API, breaking changes, new features** - See [references/pitfalls.md](references/pitfalls.md)

**Gameplay systems**
- **Physics bodies (CharacterBody2D/3D), move_and_slide, collision layers/masks, Area2D, RigidBody2D, raycasts, groups, process callbacks** - See [references/physics.md](references/physics.md)
- **Input Map and actions, polling vs events, get_vector and action strength, physical_keycode, mouse and gamepad, runtime remapping** - See [references/input.md](references/input.md)
- **Math and utility globals (lerp, move_toward, clamp, remap, snapped), randomness and RandomNumberGenerator, Vector2/3 helpers, framerate-independent smoothing** - See [references/math.md](references/math.md)
- **Navigation and pathfinding, AStarGrid2D, AStar2D, NavigationAgent2D/3D and navmesh baking, local avoidance, one-shot path queries** - See [references/navigation.md](references/navigation.md)
- **TileMapLayer API, cell methods, coordinate conversion, terrains, custom data, migration from TileMap** - See [references/tilemaplayer.md](references/tilemaplayer.md)
- **High-level multiplayer, @rpc, ENetMultiplayerPeer, authority and identity, MultiplayerSpawner and MultiplayerSynchronizer** - See [references/multiplayer.md](references/multiplayer.md)
- **3D essentials, the 2D-to-3D node map, Node3D transforms, Camera3D, lighting and Environment, meshes and StandardMaterial3D, glTF import, CSG, GridMap** - See [references/3d.md](references/3d.md)

**Presentation**
- **UI and Control nodes, anchors and offsets, containers, size flags, theming, GUI input, mouse_filter, focus** - See [references/ui.md](references/ui.md)
- **Tweens (create_tween), easing, parallel and chained steps, AnimationPlayer, AnimationTree state machines, AnimatedSprite2D** - See [references/animation.md](references/animation.md)
- **Audio playback, AudioStreamPlayer 2D/3D, one-shot SFX pooling, buses and the AudioServer mixer, linear-vs-dB volume sliders** - See [references/audio.md](references/audio.md)
- **Shaders (gdshader), shader_type and processor functions, uniforms and hints, setting parameters from GDScript, 2D effects, when not to use a shader** - See [references/shaders.md](references/shaders.md)
- **Particles and VFX, GPUParticles2D vs CPUParticles2D, ParticleProcessMaterial, one-shot self-freeing bursts, trails and local_coords** - See [references/particles.md](references/particles.md)

**Data, tooling, and shipping**
- **Saving and persistence, res:// vs user://, FileAccess, JSON, ConfigFile, DirAccess, save/load helpers, untrusted-data security** - See [references/persistence.md](references/persistence.md)
- **Performance and optimization, profiling and monitors, object pooling, MultiMesh batching, off-screen culling, threading, server calls** - See [references/performance.md](references/performance.md)
- **Testing with GUT or GdUnit4, test structure and assertions, signals and scene runners, running headless in CI, what to test in a game** - See [references/testing.md](references/testing.md)
- **Editor and CLI workflow, running headless, importing, syntax-checking GDScript, standalone scripts, exporting builds, CI, verifying changes** - See [references/workflow.md](references/workflow.md)

## Quick Patterns

### Typed function
```gdscript
func calculate(base: float, mult: float) -> float:
    return base * mult
```

### Export with range
```gdscript
@export_range(0, 100, 1, "or_greater") var hp: int = 100
```

### Signal connect
```gdscript
$Button.pressed.connect(_on_pressed)
health_changed.emit(current_health)
```

### TileMapLayer cell
```gdscript
layer.set_cell(Vector2i(x, y), source_id, atlas_coords)
var pos: Vector2 = layer.map_to_local(Vector2i(x, y))
var cell: Vector2i = layer.local_to_map(world_pos)
```

### Resource definition
```gdscript
class_name CardData
extends Resource
@export var card_name: String
@export var mp_cost: int
```

### Autoload access
```gdscript
GameState.score += 100
Events.enemy_died.emit(self, global_position)
```

## Writing .tscn / .tres / project.godot as text

These are human-readable text formats you can author or patch directly. The essentials: scene headers use `format=3`, resource ids are strings (`"1_player"`), `load_steps` is deprecated and ignored, the root `[node]` has no `parent`, and direct children use `parent="."`. Commit `.tscn`, `.tres`, `.gd`, and the `.uid` sidecars; ignore the `.godot/` cache.

Full format details (ext_resource/sub_resource, connections, UIDs, project.godot sections) are in [references/file-formats.md](references/file-formats.md). When in doubt, let the editor write the file and copy its output rather than hand-authoring verbose blocks like input events.
