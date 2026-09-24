extends SceneTree
## Same populated scene/camera, real rendering counters; never MovieMaker timing.

const Farm = preload("res://farm/farm_state.gd")
const Store = preload("res://farm/farm_store.gd")
const Decoration = preload("res://farm/decoration_state.gd")
const Detail = preload("res://presentation/focus_detail.gd")
var scene: Node3D
var output_dir: String = ""
var records: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0
var now: float = 1800000000.0
var uncapped: bool = false
var sample_frames: int = 120
var functional_only: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_dir = arg.trim_prefix("--output=")
		if arg == "--functional-only":
			functional_only = true
			sample_frames = 6
		if arg == "--uncapped":
			uncapped = true
			sample_frames = 360
	_run.call_deferred()


func _run() -> void:
	if output_dir.is_empty():
		push_error("A local evidence directory is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var save_dir: String = output_dir.path_join("save-%d" % Time.get_ticks_usec())
	var store = Store.new(save_dir)
	store.load_state()
	var data: Dictionary = Farm.new(now).snapshot()
	# Ambient swimming can unlock this journal mark during camera checks.
	# Seed it so the full farm snapshot still detects interaction side effects.
	Farm.Memories.mark(data.memories, "company", now)
	data.harvested.greens = 10
	data.harvested.radish = 6
	for index: int in 6:
		for cell_index: int in Farm.CELL_IDS.size():
			var cell: Dictionary = data.fields[Farm.FIELD_IDS[index]].cells[Farm.CELL_IDS[cell_index]]
			cell.crop_id = "greens" if (index + cell_index) % 2 == 0 else "radish"
			cell.ground = "ready"
			cell.growth_seconds = Farm.Crops.definition(cell.crop_id).duration_seconds
	var decorations = Decoration.new()
	decorations.unlock(data.harvested)
	decorations.place("pot", "ground_01", 0)
	decorations.place("flowerpot", "ground_02", 0)
	decorations.place("lantern", "hanging_01", 0)
	_expect(store.save(data, decorations.snapshot()).ok, "Maximum crop/decor fixture saved through production owner")
	root.size = Vector2i(3840, 2160)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(save_dir)
	scene.settings_store = load("res://settings/settings_store.gd").new(scene.store.directory.path_join("preferences"))
	scene.clock = func() -> float: return now
	root.add_child(scene)
	# Stable observation cadence without stealing keyboard focus from the user.
	if functional_only: scene.window_activity.set_wallpaper(true)
	if not functional_only: root.grab_focus()
	scene.atmosphere.set_preview_hour(12.0)
	scene.window_activity.set_foreground_frame_limit(0 if uncapped else 60)
	if uncapped:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await create_timer(1.0).timeout
	if not functional_only:
		_expect(scene.window_activity.is_foreground(), "Benchmark uses foreground native window")
	var before: Dictionary = scene.farm_state.snapshot()
	var decorations_before: Dictionary = scene.decoration_state.snapshot()
	var meshes_before: Array[int] = _mesh_ids()
	_expect(_field_bias(0) == 1.0 and _field_bias(5) == 1.0, "Overview uses distance-responsive detail, never forces the lowest LOD")
	for view: String in ["overview", "focus"]:
		if view == "focus":
			await _click(_point(5))
			_expect(scene.selected_field == 5 and _field_bias(5) > 1.0, "Real selection prepares high detail before camera arrives")
			await create_timer(0.42).timeout
			await _shot("focus_approach_mid")
			await create_timer(0.43).timeout
		for mode: String in ["all_high", "lod", "lod_dof"]:
			root.mesh_lod_threshold = 0.0 if mode == "all_high" else 1.0
			scene.focus_detail.set_depth_of_field(mode == "lod_dof")
			await create_timer(1.5 if uncapped else 0.6).timeout
			await _measure(view, mode)
			await _shot(view + "_" + mode)
		var first: int = records.size() - 3
		_expect(records[first + 1].visible_primitives.median <= records[first].visible_primitives.median, "LOD never increases primitive cost at a fixed camera: " + view)
		if view == "overview":
			scene.focus_detail.set_quality("low")
			await create_timer(1.5 if uncapped else 0.6).timeout
			await _measure(view, "low")
			await _shot("overview_low")
			scene.focus_detail.set_quality("standard")
	_expect(_mesh_ids() == meshes_before, "LOD/DOF changes never recreate or swap imported meshes")
	_expect(scene.farm_state.snapshot() == before, "Presentation comparisons never change farm data")
	_expect(_field_bias(5) > 1.0 and _field_bias(4) == 1.0, "Selected high detail remains distinct from same-depth neighbour")
	_expect(scene._field_at(_point(5)) == 5, "Selected field ray hit is unchanged by lower-detail neighbours")
	_expect(_clear_band_contains_field(5), "Entire operation field and plant heights fit the clear band")
	# Directly exercise destination replacement during existing camera tweens.
	scene._focus_field(0)
	await create_timer(0.12).timeout
	scene._focus_field(4)
	await create_timer(0.12).timeout
	scene._return_overview()
	await create_timer(0.12).timeout
	scene._focus_field(1)
	await create_timer(0.85).timeout
	_expect(scene.selected_field == 1 and _field_bias(1) > 1.0 and _field_bias(4) == 1.0, "Rapid focus/return interruption belongs only to latest target")
	_expect(_clear_band_contains_field(1), "Interrupted focus still preserves full clear operation band")
	var stable_meshes: Array[int] = _mesh_ids()
	for zoom: float in [-100.0, 100.0, -3.1, 0.2, -0.2, 0.2, -0.2]:
		scene.camera.zoom(zoom)
		await create_timer(0.35).timeout
		_expect(_clear_band_contains_field(1) and _field_bias(1) > 1.0, "Zoom limits and threshold neighbourhood retain focused detail and clear band")
	scene.camera.drag(Vector2(900, -900), false)
	scene.camera.drag(Vector2(900, 900), true)
	await create_timer(0.25).timeout
	_expect(_clear_band_contains_field(1), "Extreme yaw/pitch/pan remain inside geometric clear band")
	await _shot("focus_extreme")
	_expect(_mesh_ids() == stable_meshes, "No per-zoom geometry churn")
	scene.focus_detail.set_depth_of_field(false)
	await create_timer(0.5).timeout
	_expect(not scene.camera.attributes.dof_blur_far_enabled and _field_bias(4) == 1.0, "DOF off keeps LOD active")
	_expect(scene.focus_detail.set_quality("low"), "Low quality accepted")
	scene.focus_detail.set_depth_of_field(true)
	await create_timer(0.5).timeout
	_expect(not scene.camera.attributes.dof_blur_far_enabled and _field_bias(1) > 1.0 and root.msaa_3d == Viewport.MSAA_2X, "Low quality uses 2x MSAA without DOF while retaining operation detail")
	_expect(scene.focus_detail.get_settings().dof_enabled, "Low quality retains the user's enabled DOF preference")
	_expect(not scene.focus_detail.set_quality("invalid") and not scene.focus_detail.set_depth_of_field(true, NAN), "Invalid settings do not become presentation state")
	var sun: DirectionalLight3D = scene.get_node("DirectionalLight3D")
	_expect(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Low quality retains balanced shadow coverage")
	scene.focus_detail.set_quality("high")
	_expect(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and is_equal_approx(sun.directional_shadow_split_1, .1), "High quality restores near shadow detail")
	scene.focus_detail.set_quality("standard")
	_expect(root.msaa_3d == Viewport.MSAA_2X and scene.focus_detail.get_settings().dof_enabled, "Standard keeps 2x MSAA and retained DOF preference")
	_expect(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and is_equal_approx(sun.directional_shadow_split_1, .45) and is_equal_approx(sun.directional_shadow_max_distance, 48.0) and sun.directional_shadow_blend_splits, "Standard restores balanced, blended shadows without shortening coverage")
	scene._begin_decoration()
	await create_timer(0.85).timeout
	_expect(scene.selected_field == -1 and not scene.camera.attributes.dof_blur_far_enabled and _field_bias(1) == 1.0, "Arrangement always returns to clear distance-responsive overview")
	_expect(scene.farm_state.snapshot() == before, "All focus/settings/arrangement changes leave farming untouched")
	_expect(scene.decoration_state.snapshot() == decorations_before, "Display and arrangement entry do not change confirmed decoration data")
	scene.decoration_layout.finish_mode()
	# A subsequent stage build must inherit the current presentation policy.
	scene._focus_field(0)
	await create_timer(0.85).timeout
	# Inspect thin background leaves, trellis and roof edges without DOF hiding them.
	scene.focus_detail.set_depth_of_field(false)
	await create_timer(0.3).timeout
	root.mesh_lod_threshold = 0.0
	await _shot("foliage_all_high")
	root.mesh_lod_threshold = 1.0
	await _shot("foliage_lod")
	scene.farm_state.harvest("field_01", "cell_01", now)
	scene.farm_state.sow("field_01", "cell_01", "greens", now)
	scene.refresh_farm()
	_expect(_field_bias(0) > 1.0, "Newly planted stage immediately inherits selected detail")
	scene._return_overview()
	await create_timer(0.85).timeout
	_expect(_field_bias(0) == 1.0, "Returning restores regenerated crop to overview detail")
	var report: Dictionary = {"timing_valid": not functional_only and scene.window_activity.is_foreground(), "engine": Engine.get_version_info(), "render_size": root.get_texture().get_image().get_size(), "logical_size": root.content_scale_size, "device": RenderingServer.get_video_adapter_name(), "samples_per_case": sample_frames, "fps_cap": 0 if uncapped else 60, "vsync": DisplayServer.window_get_vsync_mode(), "recording": false, "records": records, "checks": checks, "failures": failures}
	var file := FileAccess.open(output_dir.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), false)
	scene.free()
	await process_frame
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("FOCUS_DETAIL_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _measure(view: String, mode: String) -> void:
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var frame_ms: Array[float] = []
	var primitives: Array[float] = []
	var shadows: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for index: int in sample_frames:
		await RenderingServer.frame_post_draw
		var tick: int = Time.get_ticks_usec()
		frame_ms.append(float(tick - previous) / 1000.0)
		previous = tick
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu())
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		primitives.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		shadows.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
	var row: Dictionary = {"view": view, "mode": mode, "msaa_enum": root.msaa_3d, "cpu_render_and_setup_ms": _stats(cpu), "gpu_render_ms": _stats(gpu), "wall_frame_ms": _stats(frame_ms), "visible_primitives": _stats(primitives), "shadow_primitives": _stats(shadows), "near_clear": scene.camera.attributes.dof_blur_near_distance, "far_clear": scene.camera.attributes.dof_blur_far_distance, "dof_amount": scene.camera.attributes.dof_blur_amount}
	records.append(row)
	_expect(_stats(gpu).median > 0.0 and _stats(primitives).median > 0.0, "Actual viewport timing and draw counters available: " + view + "/" + mode)


func _stats(values: Array[float]) -> Dictionary:
	values.sort()
	return {"median": values[values.size() / 2], "p95": values[int(values.size() * 0.95)]}


func _mesh_ids() -> Array[int]:
	var ids: Array[int] = []
	for mesh: MeshInstance3D in scene.farm.find_children("*", "MeshInstance3D", true, false):
		ids.append(mesh.mesh.get_instance_id())
	return ids


func _field_bias(index: int) -> float:
	var meshes: Array[Node] = scene.farm.fields[index].get_node("Crops").find_children("*", "MeshInstance3D", true, false)
	return meshes[0].lod_bias if not meshes.is_empty() else -1.0


func _clear_band_contains_field(index: int) -> bool:
	var depths: Vector2 = Detail.depth_range(scene.camera, scene.farm.fields[index].global_transform, AABB(Vector3(-1.4, -0.1, -1.15), Vector3(2.8, 0.75, 2.3)))
	return scene.camera.attributes.dof_blur_near_distance <= depths.x and scene.camera.attributes.dof_blur_far_distance >= depths.y


func _point(index: int) -> Vector2:
	return scene.camera.unproject_position(scene.farm.fields[index].global_position + Vector3(0, 0.3, 0))


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await physics_frame
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(output_dir.path_join(label + ".png")) == OK, "Saved " + label)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
