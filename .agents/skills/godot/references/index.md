---
okf_version: "0.2"
---

# Per-area Godot 4.x reference notes behind the godot skill.

- [3D Essentials Reference](3d.md) - The 2D subsystems documented elsewhere have 3D twins with the same API and a `3D` suffix.
- [Animation & Tween Reference](animation.md) - Create with `create_tween()` on any node.
- [Godot Architecture Patterns](architecture.md) - func _ready() -> void:
- [Audio Reference](audio.md) - @onready var music: AudioStreamPlayer = $Music
- [Editor Tooling & Exposing Tunables Reference](editor-tooling.md) - The clean Godot answer to "let me adjust custom things in the editor instead of hunting for constants in code" is **data-driven design**: never hardcode a tunable as a code constant when you can…
- [Text File Formats Reference (.tscn / .tres / project.godot)](file-formats.md) - Godot's scene (`.tscn`) and resource (`.tres`) files are human-readable INI-like text, which is why they belong in version control over the binary `.scn`/`.res`.
- [GDScript Reference](gdscript.md) - var health: int = 100
- [Input Reference](input.md) - For input *propagation order* (`_input` / `_gui_input` / `_unhandled_input`) and the event-vs-polling decision, see [architecture.md](architecture.md).
- [Math, Vectors & Randomness Reference](math.md) - lerp(a, b, t) # linear interpolate, t in 0..1 (lerpf for typed floats)
- [High-Level Multiplayer Reference](multiplayer.md) - Godot's high-level API runs over a `MultiplayerPeer` (usually `ENetMultiplayerPeer`; `WebSocketMultiplayerPeer`/`WebRTC` for the web).
- [Navigation & Pathfinding Reference](navigation.md) - For the hand-built `AStar2D` graph pattern, see [architecture.md](architecture.md).
- [Particles & VFX Reference](particles.md) - Both share the same conceptual properties.
- [Performance & Optimization Reference](performance.md) - Do not guess. Use the editor's **Profiler** and **Monitors** panels (Debugger bottom dock) while the game runs, then attack the real hot spot.
- [Saving & Persistence Reference](persistence.md) - Always write saves and config to `user://`.
- [Physics & Movement Reference](physics.md) - `AnimatableBody2D` is a `StaticBody2D` that reports motion to the physics engine (moving platforms).
- [Godot Pitfalls & Breaking Changes](pitfalls.md) - @export @onready var speed: float = 100.0
- [SceneTree, Lifecycle & Pausing Reference](scene-tree.md) - For the per-node callback order (`_init` / `_enter_tree` / `_ready` bottom-up / `_process`), see [architecture.md](architecture.md).
- [Shaders Reference (gdshader)](shaders.md) - Godot's shading language (`.gdshader`) is GLSL-like.
- [Testing Reference](testing.md) - Godot ships no built-in unit-test runner.
- [TileMapLayer Reference (Godot 4.3+)](tilemaplayer.md) - `TileMap` is deprecated since Godot 4.3.
- [UI / Control Reference](ui.md) - UI lives under `Control` nodes, not `Node2D`.
- [Editor & CLI Workflow Reference](workflow.md) - The Godot executable is also the toolchain: it imports, syntax-checks, runs, and exports a project from the command line.
