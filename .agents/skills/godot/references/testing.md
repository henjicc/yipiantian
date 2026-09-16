---
type: Reference
title: "Testing Reference"
description: "Godot ships no built-in unit-test runner."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Testing Reference

**Verified 2026-06-06** against Godot 4.x with GUT 9.x and GdUnit4. These are third-party addons with their own release cadence; treat the API below as orientation and confirm against the addon's own docs for the installed version. Re-verify when you bump the addon.

Godot ships no built-in unit-test runner. Two community frameworks cover Godot 4:

| Framework | Style | Notes |
|---|---|---|
| **GUT** (Godot Unit Test) | xUnit-style `assert_eq(a, b)` | Long-established; GUT 9.x targets Godot 4 |
| **GdUnit4** | Fluent `assert_that(x).is_equal(y)` | Embedded inspector, mocking, scene runner, GDScript + C# |

Install either from the Asset Library / Asset Store into `res://addons/`, then enable it in Project Settings > Plugins.

## Test structure and lifecycle

### GUT
```gdscript
extends GutTest                          # or extends "res://addons/gut/test.gd"

func before_each() -> void: ...          # before_all / after_each / after_all also exist

func test_damage_reduces_health() -> void:
    var p := Player.new()
    p.take_damage(30)
    assert_eq(p.health, 70, "30 damage off 100")
    p.free()
```

### GdUnit4
```gdscript
class_name PlayerTest
extends GdUnitTestSuite

func test_damage_reduces_health() -> void:
    var p := auto_free(Player.new())     # auto-freed at test end
    p.take_damage(30)
    assert_int(p.health).is_equal(70)
```

## Assertions

- **GUT**: `assert_eq`, `assert_ne`, `assert_true`, `assert_false`, `assert_null`, `assert_almost_eq`, `assert_has`, `assert_signal_emitted`, `assert_freed`.
- **GdUnit4**: fluent matchers, `assert_int(x).is_equal(n)`, `assert_str(s).has_length(n).starts_with(...)`, `assert_array(a).contains([...])`, `assert_bool(b).is_true()`, `assert_signal(obj).is_emitted("died")`, `assert_object(o).is_instanceof(Enemy)`.

## Signals, scenes, and async

Both can wait on signals and drive scenes:
```gdscript
# GdUnit4: load a scene, pump frames, assert
var runner := scene_runner("res://scenes/level.tscn")
await runner.simulate_frames(10)
assert_object(runner.find_child("Player")).is_not_null()

# GUT: instance with auto-cleanup, await a frame
var node := add_child_autofree(MyScene.instantiate())
await wait_frames(2)
assert_signal_emitted(node, "ready_done")
```
GdUnit4 also offers mocks/spies (`mock(Class)`, `spy_on`) for isolating collaborators.

## Running headless / CI

Import first so all classes and resources register, then run the framework's CLI runner (both emit JUnit XML for CI):

```sh
godot --headless --import --path .        # build the .godot cache first

# GUT
godot -d -s --path . addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit

# GdUnit4
./addons/gdUnit4/runtest.sh -a res://test     # runtest.cmd on Windows
```
`-gexit` (GUT) makes the run quit with a non-zero code on failure, which is what a CI step or an agent's verify step checks.

## What to test in a game

- **Test pure logic and data**: damage formulas, inventory rules, turn/state machines, `Resource` data, pathfinding results, save/load round-trips. These are fast and stable.
- **Integration-test scenes sparingly**: instance a scene, pump a few frames, assert on signals or state. Keep them few; they are slower and more brittle.
- **Avoid asserting exact pixels or frame-perfect timing.** Assert outcomes (health reached 0, signal fired, node freed), not rendering.

See [workflow.md](workflow.md) for running tests as part of verifying a change.
