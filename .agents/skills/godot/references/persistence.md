---
type: Reference
title: "Saving & Persistence Reference"
description: "Always write saves and config to `user://`."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Saving & Persistence Reference

**Verified 2026-06-06** against Godot 4.x. Godot 4 replaced the 3.x `File` with the static `FileAccess`, `Directory` with `DirAccess`, and `to_json`/`parse_json` with the `JSON` class. Re-verify if a newer minor changes them.

## Where files go: res:// vs user://

| Prefix | Maps to | Writable at runtime |
|---|---|---|
| `res://` | Project folder (baked into the exported PCK) | No (read-only in exports) |
| `user://` | Per-user app data dir (OS-specific) | Yes; use for saves, settings, logs |

Always write saves and config to `user://`. Resolve the real path with `ProjectSettings.globalize_path("user://save.dat")` when debugging.

## Pick a format

| Need | Use |
|---|---|
| Game state of typed `Resource` objects | `ResourceSaver` / `load` (see [architecture.md](architecture.md)) |
| Settings, key/value sections | `ConfigFile` |
| Interop, human-readable, untrusted data | `JSON` |
| Raw bytes or your own line format | `FileAccess` |

## FileAccess (raw read/write)

`FileAccess.open(path, flags)` returns a `FileAccess` or `null` on failure. It is `RefCounted`, so it closes automatically when the variable goes out of scope (no manual `close()` needed in GDScript).

```gdscript
func save_text(path: String, text: String) -> void:
    var f := FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        push_error("save failed: %s" % FileAccess.get_open_error())
        return
    f.store_string(text)

func load_text(path: String) -> String:
    if not FileAccess.file_exists(path):
        return ""
    var f := FileAccess.open(path, FileAccess.READ)
    return f.get_as_text()
```
ModeFlags: `READ`, `WRITE` (truncates), `READ_WRITE` (keeps contents), `WRITE_READ` (truncates). Also `store_line`/`get_line`, `store_var`/`get_var` (binary Variant), `store_8`/`store_32`, `eof_reached()`.

`store_var`/`get_var` round-trips any Variant in Godot's binary format. It is compact but engine-specific and not human-readable; prefer JSON for anything other apps or versions must read.

## JSON

```gdscript
# Encode
var data := {"level": 3, "hp": 80, "items": ["sword", "potion"]}
var json_text := JSON.stringify(data, "\t")     # second arg = indent for pretty output

# Decode (simple)
var parsed: Variant = JSON.parse_string(json_text)   # null on parse error
if parsed is Dictionary:
    var hp: int = parsed["hp"]

# Decode with error reporting
var json := JSON.new()
var err := json.parse(json_text)
if err != OK:
    push_error("JSON %d: %s" % [json.get_error_line(), json.get_error_message()])
else:
    var result: Variant = json.get_data()
```
JSON numbers decode as `float`; cast to `int` where you need integers. JSON cannot represent Godot types (`Vector2`, `Color`); store them as arrays/dicts and reconstruct on load.

## ConfigFile (settings)

INI-style sections and key/value pairs, ideal for options menus.
```gdscript
const SETTINGS := "user://settings.cfg"

func save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("audio", "master", 0.8)
    cfg.set_value("video", "fullscreen", true)
    cfg.save(SETTINGS)

func load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SETTINGS) != OK:
        return                                   # first run; use defaults
    var vol: float = cfg.get_value("audio", "master", 1.0)   # 3rd arg = default
```

## DirAccess (folders)

```gdscript
DirAccess.dir_exists_absolute("user://saves")
DirAccess.make_dir_recursive_absolute("user://saves")
var d := DirAccess.open("user://saves")
if d:
    for file in d.get_files():
        print(file)
DirAccess.remove_absolute("user://saves/old.json")
```

## A minimal save/load helper

```gdscript
const SAVE := "user://save.json"

func save_game(state: Dictionary) -> void:
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(state, "\t"))

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE):
        return {}
    var f := FileAccess.open(SAVE, FileAccess.READ)
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    return parsed if parsed is Dictionary else {}
```

## Security note

Loading a `.tres`/`.res` or `get_var(allow_objects=true)` from an **untrusted** source can instantiate arbitrary objects and run code. For user-supplied or downloaded saves, use JSON (data only) and validate fields before applying them. Keep `allow_objects` off when reading untrusted binary Variants.
