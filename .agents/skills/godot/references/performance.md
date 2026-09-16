---
type: Reference
title: "Performance & Optimization Reference"
description: "Do not guess. Use the editor's **Profiler** and **Monitors** panels (Debugger bottom dock) while the game runs, then attack the real hot spot."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Performance & Optimization Reference

**Verified 2026-06-06** against Godot 4.x. The patterns here (measure first, pool, batch, cull, avoid per-frame allocations) are durable; the API names follow the current stable. Re-verify monitor constants if a newer minor changes them.

## Measure before optimizing

Do not guess. Use the editor's **Profiler** and **Monitors** panels (Debugger bottom dock) while the game runs, then attack the real hot spot. From code:
```gdscript
Performance.get_monitor(Performance.TIME_FPS)
Performance.get_monitor(Performance.TIME_PROCESS)          # CPU time in _process
Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
Engine.get_frames_per_second()
Performance.add_custom_monitor("game/enemies", func() -> int: return enemies.size())
```

## Top wins

### Static typing
Typed GDScript runs significantly faster and catches errors at parse time. Type everything (see [gdscript.md](gdscript.md)). This is the cheapest broad win.

### Pool instead of churn
Repeated `instantiate()` + `queue_free()` (bullets, particles, damage numbers) thrashes memory and triggers GC-like spikes. Reuse a pool:
```gdscript
var _pool: Array[Bullet] = []

func get_bullet() -> Bullet:
    var b: Bullet = _pool.pop_back() if not _pool.is_empty() else BULLET.instantiate()
    b.visible = true
    b.set_physics_process(true)
    return b

func release(b: Bullet) -> void:
    b.visible = false
    b.set_physics_process(false)
    _pool.append(b)                      # hide and park, do not free
```

### Batch identical visuals with MultiMesh
Thousands of identical sprites/meshes as separate nodes mean thousands of draw calls. `MultiMeshInstance2D`/`3D` draws them in one call:
```gdscript
var mm := MultiMesh.new()
mm.transform_format = MultiMesh.TRANSFORM_2D
mm.instance_count = count
for i in count:
    mm.set_instance_transform_2d(i, Transform2D(0.0, positions[i]))
$MultiMeshInstance2D.multimesh = mm
```

### Cull off-screen work
- `VisibleOnScreenEnabler2D` / `VisibleOnScreenNotifier2D` to pause or free nodes that leave the view.
- Disable processing on idle nodes: `set_process(false)`, `set_physics_process(false)`, and on Area2D set `monitoring = false`.
- Narrow physics with collision layers/masks so bodies only test relevant layers (see [physics.md](physics.md)).

## Avoid per-frame waste

- Cache node lookups with `@onready`; never `get_node()` in `_process` (see [pitfalls.md](pitfalls.md)).
- Prefer **signals over polling**. React to an event once instead of checking a condition every frame.
- Do not allocate in hot loops: reuse arrays/dictionaries, avoid building new `Array`/`String` each frame; use `distance_squared_to` instead of `distance_to` when only comparing.
- Move rarely-changing logic out of `_process` into timers or signals.

## Heavy lifting off the main thread

```gdscript
# Background work
var task := WorkerThreadPool.add_task(_expensive_gen)
WorkerThreadPool.wait_for_task_completion(task)

# Stream large assets without a frame hitch
ResourceLoader.load_threaded_request("res://big_level.tscn")
# ...poll ResourceLoader.load_threaded_get_status(path), then:
var scene := ResourceLoader.load_threaded_get("res://big_level.tscn")
```
Never touch the scene tree from a worker thread; marshal results back with `call_deferred`.

## Servers for extreme counts

For tens of thousands of lightweight items, bypass nodes and talk to the servers (`RenderingServer`, `PhysicsServer2D`) directly to create canvas items / bodies without per-node overhead. This trades convenience for throughput; reach for it only when profiling proves nodes are the bottleneck.

## Rendering hygiene

- Pack sprites into texture atlases to cut draw calls and texture swaps.
- Reuse materials; a unique material per node defeats batching. Use `resource_local_to_scene` only when an instance genuinely needs its own copy.
- Pick the renderer that fits the target: Forward+ for desktop, Mobile, or Compatibility (GL) for the web and low-end devices.

## Order of attack

1. Profile and find the real bottleneck.
2. Add static types everywhere.
3. Cut draw calls (atlas, MultiMesh, fewer unique materials).
4. Pool churned nodes; cull off-screen work.
5. Replace per-frame polling with signals; remove hot-loop allocations.
6. Only then reach for threads or direct server calls.
