extends SceneTree
## Real wall-clock sampling of the production scene, not a release executable or MovieMaker.
## run-performance-validation.ps1 collects Windows working set / window-thread CPU alongside it.

const Farm = preload("res://farm/farm_state.gd")
const Store = preload("res://farm/farm_store.gd")
const Decorations = preload("res://farm/decoration_state.gd")
const Settings = preload("res://settings/settings_store.gd")
var scene: Node3D
var output_dir: String = ""
var suite: String = "acceptance"
var cases: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0
var sample_seconds: float = 60.0
var warmup_seconds: float = 5.0
var phase: String = "starting"
var _status_tick: int = 0
var _scene_started: int = 0
var _initial_harvested: Dictionary
var _actual_image_size: Vector2i


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=").simplify_path()
		elif argument.begins_with("--suite="):
			suite = argument.trim_prefix("--suite=")
	_run.call_deferred()


func _run() -> void:
	var allowed: String = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification")
	if output_dir.is_empty() or not output_dir.replace("\\", "/").begins_with(allowed.replace("\\", "/") + "/") or suite not in ["acceptance", "4k", "smoke"]:
		push_error("Use an isolated --output below .local/verification and an explicit supported suite.")
		quit(1)
		return
	if OS.has_feature("movie") or DisplayServer.get_name() == "headless":
		push_error("Performance evidence requires real rendering and the normal wall clock.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	if suite == "smoke":
		sample_seconds = 2.0
		warmup_seconds = 1.0
	var resolution := Vector2i(3840, 2160) if suite == "4k" else Vector2i(1920, 1080)
	root.size = resolution
	var store := Store.new(output_dir.path_join("farm"))
	_expect(store.load_state().kind == "missing", "Every run requires a fresh isolated farm directory")
	var now: float = Time.get_unix_time_from_system()
	var data: Dictionary = Farm.new(now).snapshot()
	data.harvested = {"greens": 10, "radish": 6}
	for index: int in 6:
		data.fields[Farm.FIELD_IDS[index]].crop_id = "greens" if index % 2 == 0 else "radish"
		data.fields[Farm.FIELD_IDS[index]].growth_seconds = 1800.0 if index % 2 == 0 else 5400.0
	var decorations := Decorations.new()
	decorations.unlock(data.harvested)
	decorations.place("pot", "ground_01", 0)
	decorations.place("flowerpot", "ground_02", 0)
	decorations.place("lantern", "hanging_01", 0)
	_expect(store.save(data, decorations.snapshot()).ok, "Maximum 54-plant / 3-decoration fixture is saved through the real owners")
	var preferences := Settings.new(output_dir.path_join("preferences"))
	_expect(preferences.load_settings().ok and preferences.save(Settings.DEFAULTS.duplicate(true)).ok, "Windowed standard preferences are isolated")
	if not failures.is_empty():
		_finish()
		return
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(output_dir.path_join("farm"))
	scene.settings_store = Settings.new(output_dir.path_join("preferences"))
	root.add_child(scene)
	root.grab_focus()
	scene.window_activity.set_foreground_frame_limit(60)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_expect(scene._loaded and not scene._save_failed and not scene.game_menu.visible, "Production scene is loaded and accepts gameplay input")
	var rendered: Vector2i = root.get_texture().get_image().get_size()
	_actual_image_size = rendered
	_expect(rendered == resolution, "Actual rendered image matches the requested native resolution")
	_expect(scene.farm.fields.size() == 6 and scene.decoration_layout.lantern_anchors().size() == 1, "Full farm and placed lantern are present")
	for body: StaticBody3D in scene.farm.fields:
		_expect(body.get_node("Crops").get_child_count() == 9, "Each field has nine mature crop instances")
	_initial_harvested = scene.farm_state.snapshot().harvested
	_scene_started = Time.get_ticks_usec()
	_write("ready.json", {"pid": OS.get_process_id(), "engine_startup_seconds": float(_scene_started) / 1e6, "actual_image_size": [rendered.x, rendered.y], "window_size": [root.size.x, root.size.y], "suite": suite, "runtime": "Godot standard executable, production scene, no editor UI; not export release", "engine": Engine.get_version_info(), "adapter": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "vsync_mode": DisplayServer.window_get_vsync_mode(), "cap_fps": 60})
	if not failures.is_empty():
		_finish()
		return
	var hours: Array[int] = []
	hours.assign([12, 21] if suite in ["acceptance", "smoke"] else [12])
	var views: Array[String] = []
	views.assign(["overview", "focus", "arrange"] if suite in ["acceptance", "smoke"] else ["overview", "focus"])
	var modes: Array[String] = []
	modes.assign(["all_high", "lod", "lod_dof"])
	for hour: int in hours:
		for view: String in views:
			var group_start: int = cases.size()
			for mode: String in modes:
				await _prepare(hour, view, mode)
				await _measure("%s_%s_%s" % [hour, view, mode], "")
			if modes.size() == 3:
				_expect(cases[group_start + 1].visible_primitives.median < cases[group_start].visible_primitives.median * 0.95, "LOD reduces actual drawn geometry in the same view: %d/%s" % [hour, view])
	if suite in ["acceptance", "smoke"]:
		await _prepare(12, "overview", "lod_dof")
		await _measure("12_slow_approach_lod_dof", "approach")
		await _prepare(21, "focus", "lod_dof")
		await _measure("21_slow_turn_lod_dof", "turn")
		await _background_probe(5.0 if suite == "smoke" else 30.0)
	if suite == "acceptance":
		await _prepare(12, "overview", "lod_dof")
		# Count only actual monotonic time. No injected growth clock, fast time scale,
		# or MovieMaker frames can satisfy the 30-minute continuous run requirement.
		while float(Time.get_ticks_usec() - _scene_started) / 1e6 < 1800.0:
			await _measure("continuous_%02d" % cases.size(), "")
		_expect(Time.get_ticks_usec() - _scene_started >= 1800_000_000, "Continuous production scene ran for at least thirty real minutes")
	_finish()


func _prepare(hour: int, view: String, mode: String) -> void:
	phase = "warmup_%s_%s_%s" % [hour, view, mode]
	_write_status()
	scene.decoration_layout.finish_mode()
	scene._reset_view()
	await create_timer(0.85).timeout
	scene.atmosphere.set_preview_hour(hour)
	scene.focus_detail.set_quality("standard")
	root.mesh_lod_threshold = 0.0 if mode == "all_high" else 1.0
	scene.focus_detail.set_depth_of_field(mode == "lod_dof")
	if view == "focus":
		scene._focus_field(5)
	elif view == "arrange":
		scene._begin_decoration()
		await create_timer(0.85).timeout
		scene.decoration_layout.select_item("lantern")
	await create_timer(warmup_seconds).timeout
	_expect(scene.window_activity.is_foreground(), "Warmup completed in the foreground: " + phase)
	var expected_field: int = 5 if view == "focus" else -1
	_expect(scene.selected_field == expected_field and scene.camera.focused == (view == "focus") and not scene.camera.is_transitioning(), "Settled camera and selected field match the intended view: " + view)
	_expect(scene.decoration_layout.active == (view == "arrange") and not scene.game_menu.visible, "Arrangement/menu visibility matches the intended view: " + view)
	_expect(root.size == _actual_image_size and DisplayServer.window_get_size() == _actual_image_size, "Native render dimensions remain fixed between cases")


func _measure(label: String, motion: String) -> void:
	phase = label
	_write_status()
	var rows := PackedStringArray(["tick_usec,frame_ms,cpu_render_ms,cpu_setup_ms,gpu_ms,engine_process_monitor_ms,visible_primitives,shadow_primitives,draw_calls,foreground"])
	var intervals: Array[float] = []
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var process_monitor: Array[float] = []
	var primitives: Array[float] = []
	var shadow_primitives: Array[float] = []
	var offscreen_frames: int = 0
	var first: int = Time.get_ticks_usec()
	var previous: int = first
	var target_change: int = -1
	var normal_transition: float = scene.camera.transition_seconds
	if motion == "approach":
		scene.camera.transition_seconds = 1.8
	while float(Time.get_ticks_usec() - first) / 1e6 < sample_seconds:
		await RenderingServer.frame_post_draw
		var tick: int = Time.get_ticks_usec()
		var elapsed: float = float(tick - first) / 1e6
		var frame_ms: float = float(tick - previous) / 1000.0
		previous = tick
		var render_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		var setup_ms: float = RenderingServer.get_frame_setup_time_cpu()
		var gpu_ms: float = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		var engine_process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var visible_count: int = RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var shadow_count: int = RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var calls: int = RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var foreground: bool = scene.window_activity.is_foreground()
		offscreen_frames += 0 if foreground else 1
		intervals.append(frame_ms)
		cpu.append(render_ms + setup_ms)
		gpu.append(gpu_ms)
		process_monitor.append(engine_process_ms)
		primitives.append(visible_count)
		shadow_primitives.append(shadow_count)
		rows.append("%d,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%d" % [tick, frame_ms, render_ms, setup_ms, gpu_ms, engine_process_ms, visible_count, shadow_count, calls, int(foreground)])
		if motion == "turn":
			scene.camera.drag(Vector2(sin(elapsed * PI / 10.0) * frame_ms * 0.012, 0), false)
		elif motion == "approach":
			var segment: int = int(elapsed / 10.0)
			if segment != target_change:
				target_change = segment
				if segment % 2 == 0:
					scene._focus_field(segment % 6)
				else:
					scene._return_overview()
		if tick - _status_tick >= 1_000_000:
			_write_status()
	var duration: float = float(Time.get_ticks_usec() - first) / 1e6
	scene.camera.transition_seconds = normal_transition
	var file := FileAccess.open(output_dir.path_join(label + ".csv"), FileAccess.WRITE)
	file.store_string("\n".join(rows) + "\n")
	file.close()
	var frame_stats: Dictionary = _stats(intervals)
	var row: Dictionary = {"case": label, "real_seconds": duration, "frames": intervals.size(), "average_fps": intervals.size() / duration, "wall_frame_ms": frame_stats, "cpu_render_and_setup_ms": _stats(cpu), "gpu_render_ms": _stats(gpu), "engine_process_monitor_ms": _stats(process_monitor), "visible_primitives": _stats(primitives), "shadow_primitives": _stats(shadow_primitives), "foreground_lost_frames": offscreen_frames, "quality": scene.focus_detail.get_settings(), "msaa_enum": root.msaa_3d, "mesh_lod_threshold": root.mesh_lod_threshold, "dof_amount": scene.camera.attributes.dof_blur_amount}
	row["scene_context"] = {"render_size": [_actual_image_size.x, _actual_image_size.y], "native_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y], "selected_field_index": scene.selected_field, "camera_focused": scene.camera.focused, "arrangement_active": scene.decoration_layout.active, "menu_visible": scene.game_menu.visible, "camera_position": [scene.camera.position.x, scene.camera.position.y, scene.camera.position.z], "scripted_motion": motion, "approach_duration_seconds": 1.8 if motion == "approach" else normal_transition}
	cases.append(row)
	_expect(offscreen_frames == 0, "No samples silently discarded after focus loss: " + label)
	_expect(row.cpu_render_and_setup_ms.median > 0.0 and row.gpu_render_ms.median > 0.0 and row.visible_primitives.median > 0.0, "Actual render timings and geometry counters are available: " + label)
	if suite == "acceptance" and label.contains("lod_dof"):
		_expect(frame_stats.p95 <= 20.0 and frame_stats.p99 <= 33.4, "1080p standard frame interval target: " + label)
	_expect(not scene._save_failed, "Automatic saves remain successful throughout: " + label)
	_write("partial-results.json", {"suite": suite, "cases": cases, "failures": failures})
	print("PERFORMANCE_CASE case=%s seconds=%.2f p95=%.3f p99=%.3f foreground_lost=%d" % [label, duration, frame_stats.p95, frame_stats.p99, offscreen_frames])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_dir.path_join(label + ".png"))


func _background_probe(seconds: float) -> void:
	_expect(scene.farm_state.snapshot().harvested == _initial_harvested, "Presentation comparisons never grant harvest rewards")
	scene.decoration_layout.finish_mode()
	scene._focus_field(0)
	await create_timer(0.85).timeout
	scene._select_tool("harvest")
	scene._apply_tool()
	scene._select_tool("sow")
	scene._apply_tool()
	var before: Dictionary = scene.farm_state.get_field("field_01")
	var before_utc: float = Time.get_unix_time_from_system()
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.2
	AudioServer.add_bus_effect(0, capture)
	phase = "background_minimized"
	_write_status()
	root.mode = Window.MODE_MINIMIZED
	await create_timer(1.0).timeout
	capture.clear_buffer()
	var started: int = Time.get_ticks_usec()
	var frames: int = Engine.get_process_frames()
	var peak: float = 0.0
	var captured_frames: int = 0
	while float(Time.get_ticks_usec() - started) / 1e6 < seconds:
		await create_timer(0.1).timeout
		var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		captured_frames += samples.size()
		for sample: Vector2 in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		if Time.get_ticks_usec() - _status_tick >= 1_000_000:
			_write_status()
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1e6
	var fps: float = float(Engine.get_process_frames() - frames) / elapsed
	_expect(not scene.window_activity.is_foreground() and Engine.max_fps <= 15 and fps <= 15.5, "Actual minimized run respects the 15fps cap")
	_expect(captured_frames > 0 and peak < 0.00001, "Actual captured Master audio is silent while minimized")
	root.mode = Window.MODE_WINDOWED
	root.grab_focus()
	await create_timer(1.0).timeout
	var after: Dictionary = scene.farm_state.get_field("field_01")
	var utc_delta: float = Time.get_unix_time_from_system() - before_utc
	_expect(absf((after.growth_seconds - before.growth_seconds) - utc_delta) < 1.2, "Real UTC growth continues through minimization")
	_expect(scene.window_activity.is_foreground() and scene.farm_audio.is_foreground(), "Focus and sound state recover")
	capture.clear_buffer()
	await create_timer(0.12).timeout
	var restored_peak: float = 0.0
	for sample: Vector2 in capture.get_buffer(capture.get_frames_available()):
		restored_peak = maxf(restored_peak, maxf(absf(sample.x), absf(sample.y)))
	_expect(restored_peak > 0.00001, "Actual Master signal returns after window restore")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	_write("background.json", {"requested_seconds": seconds, "real_seconds": elapsed, "qualified_duration": suite == "acceptance", "actual_fps": fps, "audio_peak": peak, "captured_audio_frames": captured_frames, "restored_audio_peak": restored_peak, "utc_delta_seconds": utc_delta, "growth_delta_seconds": after.growth_seconds - before.growth_seconds, "os_sleep_tested": false})


func _write_status() -> void:
	_status_tick = Time.get_ticks_usec()
	_write("status.json", {"pid": OS.get_process_id(), "phase": phase, "ticks_usec": _status_tick, "frames_drawn": Engine.get_frames_drawn(), "process_frames": Engine.get_process_frames(), "foreground": root.has_focus(), "window_mode": root.mode, "cap_fps": Engine.max_fps})


func _stats(values: Array[float]) -> Dictionary:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value: float in ordered:
		total += value
	return {"min": ordered[0], "median": ordered[ordered.size() / 2], "p95": ordered[mini(ordered.size() - 1, ceili(ordered.size() * 0.95) - 1)], "p99": ordered[mini(ordered.size() - 1, ceili(ordered.size() * 0.99) - 1)], "max": ordered[-1], "mean": total / ordered.size()}


func _write(filename: String, data: Dictionary) -> void:
	var file := FileAccess.open(output_dir.path_join(filename + ".tmp"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if DirAccess.rename_absolute(output_dir.path_join(filename + ".tmp"), output_dir.path_join(filename)) != OK:
		push_error("Could not persist validation evidence: " + filename)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _finish() -> void:
	phase = "finished"
	_write_status()
	_write("results.json", {"suite": suite, "qualified_duration": suite != "smoke", "checks": checks, "failures": failures, "real_scene_seconds": float(Time.get_ticks_usec() - _scene_started) / 1e6 if _scene_started > 0 else 0.0, "cases": cases, "clock": "real UTC and monotonic wall clock; no time injection", "cpu_scope": "render+setup excludes script/physics; engine process monitor is a delayed engine metric. Windows main/window thread sampled separately at 1Hz.", "runtime": "Godot standard executable running production scene, not exported release"})
	if is_instance_valid(scene):
		# Reuse production audio shutdown only after all measured results are saved.
		scene.farm_audio.shutdown()
		await create_timer(0.1, true, false, true).timeout
		await process_frame
		scene.free()
	await process_frame
	await process_frame
	print("PERFORMANCE_VALIDATION suite=%s checks=%d failures=%d" % [suite, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
