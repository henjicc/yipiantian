---
type: Reference
title: "Editor & CLI Workflow Reference"
description: "The Godot executable is also the toolchain: it imports, syntax-checks, runs, and exports a project from the command line."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# Editor & CLI Workflow Reference

**Verified 2026-06-19** against Godot 4.7. Godot 4 runs headless via `--headless` (the 3.x `--no-window` flag and separate server binary are gone). Re-verify flags if a newer minor changes them.

The Godot executable is also the toolchain: it imports, syntax-checks, runs, and exports a project from the command line. Useful both in CI and when an agent operates a project without the editor open.

## Identify the project and version

```sh
godot --version                       # e.g. 4.7.stable.official
godot --path /path/to/project         # run the project's main scene
```
The project must contain a `project.godot`. Its `config/features` line (e.g. `PackedStringArray("4.7", "GL Compatibility")`) records the Godot version the project targets. Read it before assuming an API.

## Run and edit

```sh
godot --path .                        # run the main scene
godot --path . res://scenes/test.tscn # run a specific scene
godot -e --path .                     # open the editor
godot --path . --quit-after 300       # run 300 frames then exit (smoke test)
```

## Import assets headless (do this before exporting in CI)

A fresh checkout has no `.godot/imported/` cache; exports and headless runs need it. Generate it without opening the editor:
```sh
godot --headless --import --path .     # import all resources, then quit
# Older fallback that also works: godot --headless --editor --quit --path .
```

## Syntax-check GDScript without running

Fast way to validate a script (parse only, non-zero exit on error). Handy for an agent verifying an edit:
```sh
godot --headless --check-only --script res://scripts/player.gd
```

## Run a standalone GDScript (tooling, build steps)

A script that `extends SceneTree` (or `MainLoop`) runs as a program; call `quit()` to exit.
```gdscript
# tools/report.gd
extends SceneTree

func _init() -> void:
    print("assets: ", DirAccess.get_files_at("res://assets").size())
    quit()
```
```sh
godot --headless --path . -s tools/report.gd
```

## Export builds

Export presets live in `export_presets.cfg` (created in the editor under Project > Export). The export templates for the Godot version must be installed; Godot 4.7 lets you download templates for individual platforms/architectures instead of the full set. `--headless` is required on machines without a GPU (CI).
```sh
godot --headless --export-release "Windows Desktop" build/game.exe
godot --headless --export-debug   "Linux/X11"      build/game.x86_64
godot --headless --export-pack    "Web"            build/game.pck   # data pack only
```
Use a `.pck`/`.zip` pack with `--main-pack` to run data separately from the binary.

## Useful runtime flags

| Flag | Effect |
|---|---|
| `--headless` | No window or audio (`--display-driver headless --audio-driver Dummy`) |
| `--verbose` / `-v` | Verbose engine logging |
| `--debug` / `-d` | Local stdout debugger (stack traces on error) |
| `--quit-after N` | Quit after N frames; `--quit` quits after the first iteration |
| `--rendering-driver <d>` | `vulkan`, `d3d12`, `metal`, `opengl3` |
| `--resolution WxH`, `--position X,Y` | Window geometry |
| `--fixed-fps N`, `--disable-render-loop` | Deterministic / offline runs |

## CI export sketch

```sh
godot --headless --import --path .                                   # build import cache
godot --headless --export-release "Linux/X11" build/game.x86_64 --path .
```

## Verifying a change (for autonomous edits)

1. `godot --headless --check-only --script <edited>.gd` to catch parse errors fast.
2. `godot --path . --quit-after N` (or run the relevant scene) to confirm it boots without runtime errors; watch stdout with `--verbose`.
3. If the project has a test suite (GdUnit4, GUT), run it headless via its runner.

A clean parse and a boot with no errors in stdout is the minimum evidence a code change works; a green run is not the same as the screen looking right, so for UI changes still look at the rendered result.
