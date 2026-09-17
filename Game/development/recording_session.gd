extends Node
## Only instantiated by the explicit development recording launcher.
## This node owns the window/tour; Movie Maker or FFmpeg captures, and FFmpeg encodes H.264.

const TARGET_SIZE := Vector2i(3840, 2160)
var session_dir: String
var farm_scene: Node3D
var _demo: bool = false
var _started: bool = false
var _stopping: bool = false
var _elapsed: float = 0.0
var _poll_elapsed: float = 0.0
var _stage: int = 0
var _farm_demo: bool = false
var _farm_now: float = 0.0
var _courtyard_demo: bool = false
var _final_demo: bool = false
var _tree_demo: bool = false
var _camera_demo: bool = false
var _tree_start: Transform3D
var _movie_frame_limit: int = 0


func _ready() -> void:
	set_process(false)
	var config_file := FileAccess.open(session_dir.path_join("config.json"), FileAccess.READ)
	if config_file == null:
		push_error("Recording configuration cannot be opened.")
		get_tree().quit(1)
		return
	var config: Variant = JSON.parse_string(config_file.get_as_text())
	if not config is Dictionary:
		_fail("Invalid recording configuration.")
		return
	_demo = bool(config.get("demo", false))
	_farm_demo = bool(config.get("farm_demo", false))
	_courtyard_demo = bool(config.get("courtyard_demo", false))
	_final_demo = bool(config.get("final_demo", false))
	_tree_demo = bool(config.get("tree_demo", false))
	_camera_demo = bool(config.get("camera_demo", false))
	_movie_frame_limit = int(config.get("movie_frame_limit", 0))
	if OS.has_feature("movie") and bool(config.get("capture_audio", false)):
		# Only this explicit editor-only isolated recording session may render an
		# offline soundtrack while unfocused. Normal gameplay retains focus mute.
		farm_scene.window_activity.foreground_changed.disconnect(farm_scene.farm_audio.set_foreground)
		farm_scene.farm_audio.set_foreground(true)
	if _farm_demo or _courtyard_demo or _final_demo:
		_farm_now = farm_scene.clock.call()
		farm_scene.clock = func() -> float: return _farm_now
	if _courtyard_demo or _final_demo:
		var fixture: Dictionary = farm_scene.farm_state.snapshot()
		fixture.harvested.greens = 9
		fixture.harvested.radish = 6
		for index in 6:
			var id: String = farm_scene.farm.field_id(index)
			for cell_id: String in farm_scene.farm_state.CELL_IDS:
				var cell_index: int = farm_scene.farm_state.CELL_IDS.find(cell_id)
				# Both species share a bed; the recording's selected cell remains
				# mature greens so the original single-harvest assertions still apply.
				var crop: String = "greens" if (cell_index % 4 < 2) else "radish"
				fixture.fields[id].cells[cell_id] = {"crop_id": crop, "growth_seconds": [0.0, 0.6, 1.0][index % 3] * (1800.0 if crop == "greens" else 5400.0), "watered": false, "last_settled_utc_seconds": _farm_now}
		if not farm_scene.farm_state.restore_snapshot(fixture):
			_fail("The isolated courtyard recording fixture is invalid.")
			return
		farm_scene.decoration_state.unlock(fixture.harvested)
		farm_scene.refresh_farm()
		farm_scene._save_farm()
		# Only the isolated demonstration substitutes the HUD's local clock timer.
		# Never change the system clock or the production HUD's update contract.
		for child: Node in farm_scene.hud.get_children():
			if child is Timer and child.timeout.is_connected(Callable(farm_scene.hud, "_update_clock")):
				child.stop()
		_set_demo_hour(12.0)
	if _tree_demo or _camera_demo:
		for child: Node in farm_scene.hud.get_children():
			if child is Timer and child.timeout.is_connected(Callable(farm_scene.hud,"_update_clock")): child.stop()
		_set_demo_hour(16.5)
	# Movie Maker advances the simulation by 1/60 s for each saved frame.
	# It does not wait for the live encoder's handshake.
	_started = OS.has_feature("movie")
	if _demo:
		farm_scene.camera.transition_seconds = 1.8
	var screen: int = int(config.get("screen", -1))
	var screens: Array[Dictionary] = []
	for index in DisplayServer.get_screen_count():
		var size := DisplayServer.screen_get_size(index)
		screens.append({"index": index, "width": size.x, "height": size.y})
		if screen == -1 and size == TARGET_SIZE:
			screen = index
	if screen < 0 or screen >= DisplayServer.get_screen_count() or DisplayServer.screen_get_size(screen) != TARGET_SIZE:
		_fail("A native 3840x2160 display is required. Detected: " + JSON.stringify(screens))
		return
	DisplayServer.window_set_current_screen(screen)
	# Exclusive fullscreen avoids Windows' extra border pixels on captured windows.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	Engine.max_fps = 60
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var actual_size := DisplayServer.window_get_size()
	# In this 4.7.2 canvas_items setup Texture2D.get_size() includes the content scale
	# a second time. Read the actual image once; never read back frames during capture.
	var render_size := get_viewport().get_texture().get_image().get_size()
	if actual_size != TARGET_SIZE or Vector2i(render_size) != TARGET_SIZE:
		_fail("Recording requires native 4K window and viewport, got %s / %s." % [actual_size, render_size])
		return
	_write_json("ready.json", {
		"pid": OS.get_process_id(),
		"hwnd": DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE),
		"screen": screen, "screens": screens,
		"width": actual_size.x, "height": actual_size.y,
		"render_width": int(render_size.x), "render_height": int(render_size.y),
		"window_mode": DisplayServer.window_get_mode(), "demo": _demo
	})
	set_process(true)


func _process(delta: float) -> void:
	# MovieMaker must mix after playback destruction before its fixed-frame quit.
	# Release only the recording audio in the final three frames; keep the image
	# and exact requested frame count. Ordinary game lifecycle is unaffected.
	if OS.has_feature("movie") and _movie_frame_limit > 0 and Engine.get_process_frames() >= _movie_frame_limit - 3:
		_release_recording_audio()
	_poll_elapsed += delta
	if _poll_elapsed >= 0.1:
		_poll_elapsed = 0.0
		if FileAccess.file_exists(session_dir.path_join("finish")):
			get_tree().quit()
			return
		if not _started and FileAccess.file_exists(session_dir.path_join("start")):
			_started = true
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or DisplayServer.window_get_size() != TARGET_SIZE:
			_request_stop("window_changed")
	if not _started or _stopping or not _demo:
		return
	_elapsed += delta
	if _camera_demo:
		_run_camera_demo(delta)
		return
	if _tree_demo:
		_run_tree_demo()
		return
	if _final_demo:
		_run_final_demo(delta)
		return
	if _courtyard_demo:
		_run_courtyard_demo(delta)
		return
	if _farm_demo:
		_run_farm_demo(delta)
		return
	if _stage == 0 and _elapsed >= 4.0:
		farm_scene._focus_field(4)
		_stage = 1
	elif _stage == 1 and _elapsed >= 9.0:
		_stage = 2
	elif _stage == 2:
		farm_scene.camera.drag(Vector2(-16.7, 0.0) * delta, false)
		if _elapsed >= 14.0:
			_stage = 3
	elif _stage == 3 and _elapsed >= 17.0:
		farm_scene._return_overview()
		_stage = 4


func _run_camera_demo(delta: float) -> void:
	var camera: FarmCamera = farm_scene.camera
	if _stage == 0 and _elapsed >= 4.0:
		camera.zoom(-6.0)
		_stage = 1
	elif _stage == 1 and _elapsed >= 8.0:
		farm_scene._toggle_free_view()
		_stage = 2
	elif _stage == 2 and _elapsed >= 9.0:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true
		press.position = camera.unproject_position(Vector3(0, 2.5, -3))
		camera.free_input(press)
		_stage = 3
	elif _stage == 3:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(-deg_to_rad(3.0) / 0.003 * delta, 0)
		camera.free_input(motion)
		if _elapsed >= 14.0:
			camera.end_free_drag(MOUSE_BUTTON_LEFT)
			_stage = 4
	elif _stage == 4 and _elapsed >= 17.0:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true
		press.position = get_viewport().get_visible_rect().size * 0.5
		camera.free_input(press)
		_stage = 5
	elif _stage == 5:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(45, -12) * delta
		motion.position = get_viewport().get_visible_rect().size * 0.5
		camera.free_input(motion)
		if _elapsed >= 19.0:
			camera.end_free_drag(MOUSE_BUTTON_RIGHT)
			_stage = 6
	elif _stage == 6 and _elapsed >= 22.0:
		farm_scene._return_overview()
		_stage = 7
	elif _stage == 7 and _elapsed >= 25.0:
		camera.zoom(100.0)
		_stage = 8


func _run_tree_demo() -> void:
	var target := Vector3(-6.05,1.8,4.3)
	var offset := Vector3(5.1,2.1,7.7)
	if _stage == 0 and _elapsed >= 4.0:
		farm_scene._toggle_free_view()
		_tree_start = farm_scene.camera.transform
		_stage = 1
	if _stage == 1:
		var close := Transform3D(Basis.IDENTITY,target+offset).looking_at(target)
		farm_scene.camera.transform = _tree_start.interpolate_with(close,smoothstep(4.0,5.8,_elapsed))
		if _elapsed >= 5.8: _stage = 2
	elif _stage == 2 and _elapsed >= 9.0:
		_stage = 3
	elif _stage == 3:
		var angle: float = deg_to_rad(-15.0)*clampf((_elapsed-9.0)/5.0,0.0,1.0)
		farm_scene.camera.position = target+offset.rotated(Vector3.UP,angle)
		farm_scene.camera.look_at(target)
		if _elapsed >= 14.0: _stage = 4
	elif _stage == 4 and _elapsed >= 17.0:
		farm_scene._return_overview()
		_stage = 5


func _run_farm_demo(delta: float) -> void:
	# Explicit, isolated recording fixture: the normal game always uses real UTC.
	# Invoke the same scene actions and persistence boundary used by player input.
	if _stage == 0 and _elapsed >= 4.0:
		farm_scene._focus_field(0)
		_stage = 1
	elif _stage == 1 and _elapsed >= 6.5:
		farm_scene._select_cell("cell_06")
		farm_scene._select_crop("greens")
		farm_scene._apply_tool()
		_stage = 2
	elif _stage == 2 and _elapsed >= 9.0:
		farm_scene._select_tool("water")
		farm_scene._apply_tool()
		_stage = 3
	elif _stage == 3:
		farm_scene.camera.drag(Vector2(-16.7, 0.0) * delta, false)
		if _elapsed >= 14.0:
			_farm_now += 1440.0
			farm_scene.settle_farm()
			farm_scene._save_farm()
			_stage = 4
	elif _stage == 4 and _elapsed >= 17.0:
		farm_scene._select_tool("harvest")
		farm_scene._apply_tool()
		_write_json("farm-demo-result.json", {
			"controlled_utc_advance_seconds": 1440,
			"snapshot": farm_scene.farm_state.snapshot(),
			"saved": not farm_scene._save_failed
		})
		_stage = 5
	elif _stage == 5 and _elapsed >= 21.0:
		farm_scene._return_overview()
		_stage = 6


func _run_courtyard_demo(delta: float) -> void:
	var layout: Node3D = farm_scene.decoration_layout
	if _stage == 0 and _elapsed >= 4.0:
		farm_scene._focus_field(2)
		_stage = 1
	elif _stage == 1 and _elapsed >= 6.5:
		farm_scene._select_cell("cell_06")
		farm_scene._select_tool("harvest")
		farm_scene._apply_tool()
		_stage = 2
	elif _stage == 2 and _elapsed >= 9.0:
		_stage = 3
	elif _stage == 3:
		farm_scene.camera.drag(Vector2(-16.7, 0.0) * delta, false)
		if _elapsed >= 14.0:
			farm_scene._return_overview()
			_stage = 4
	elif _stage == 4 and _elapsed >= 18.0:
		farm_scene._begin_decoration()
		_stage = 5
	elif _stage == 5 and _elapsed >= 19.0 and not farm_scene.camera.is_transitioning():
		layout.select_item("pot")
		layout.preview_at("ground_03")
		_stage = 6
	elif _stage == 6 and _elapsed >= 21.0:
		layout.confirm_preview()
		_stage = 7
	elif _stage == 7 and _elapsed >= 23.0:
		layout.select_item("flowerpot")
		layout.preview_at("ground_04")
		_stage = 8
	elif _stage == 8 and _elapsed >= 26.0:
		layout.confirm_preview()
		_stage = 9
	elif _stage == 9 and _elapsed >= 28.0:
		layout.select_item("lantern")
		layout.preview_at("hanging_02")
		_stage = 10
	elif _stage == 10 and _elapsed >= 31.0:
		layout.confirm_preview()
		_stage = 11
	elif _stage == 11 and _elapsed >= 34.0:
		layout.finish_mode()
		_stage = 12
	elif _stage == 12 and _elapsed >= 36.0:
		_set_demo_hour(21.0)
		_write_json("courtyard-demo-result.json", {
			"fixture_harvested": {"greens": 9, "radish": 6},
			"fixture_hours": [12, 21], "farm": farm_scene.farm_state.snapshot(),
			"decorations": farm_scene.decoration_state.snapshot(), "saved": not farm_scene._save_failed
		})
		_stage = 13


func _run_final_demo(delta: float) -> void:
	# Isolated six-stage/cumulative fixture; production rules, LOD and DOF stay active.
	var layout: Node3D = farm_scene.decoration_layout
	if _stage == 0 and _elapsed >= 4.0:
		farm_scene._focus_field(2)
		_stage = 1
	elif _stage == 1 and _elapsed >= 6.5:
		_demo_action("harvest")
		_stage = 2
	elif _stage == 2 and _elapsed >= 9.0:
		_demo_action("sow")
		_stage = 3
	elif _stage == 3 and _elapsed >= 12.0:
		_demo_action("water")
		_stage = 4
	elif _stage == 4 and _elapsed >= 13.0:
		_stage = 5
	elif _stage == 5:
		farm_scene.camera.drag(Vector2(-16.7, 0.0) * delta, false)
		if _elapsed >= 18.0:
			_farm_now += 300.0
			farm_scene.settle_farm()
			_stage = 6
	elif _stage == 6 and _elapsed >= 21.0:
		_farm_now += 1140.0
		farm_scene.settle_farm()
		_stage = 7
	elif _stage == 7 and _elapsed >= 24.0:
		_demo_action("harvest")
		_stage = 8
	elif _stage == 8 and _elapsed >= 27.0:
		farm_scene._return_overview()
		_stage = 9
	elif _stage == 9 and _elapsed >= 31.0:
		farm_scene._begin_decoration()
		_stage = 10
	elif _stage == 10 and _elapsed >= 32.0 and not farm_scene.camera.is_transitioning():
		layout.select_item("pot")
		layout.preview_at("ground_03")
		_stage = 11
	elif _stage == 11 and _elapsed >= 34.0:
		layout.confirm_preview()
		_stage = 12
	elif _stage == 12 and _elapsed >= 35.0:
		layout.select_item("flowerpot")
		layout.preview_at("ground_04")
		_stage = 13
	elif _stage == 13 and _elapsed >= 38.0:
		layout.confirm_preview()
		_stage = 14
	elif _stage == 14 and _elapsed >= 39.0:
		layout.select_item("lantern")
		layout.preview_at("hanging_02")
		_stage = 15
	elif _stage == 15 and _elapsed >= 42.0:
		layout.confirm_preview()
		_stage = 16
	elif _stage == 16 and _elapsed >= 44.0:
		layout.finish_mode()
		_stage = 17
	elif _stage == 17 and _elapsed >= 46.0:
		_stage = 18
	elif _stage == 18:
		_set_demo_hour(lerpf(12.0, 21.0, clampf((_elapsed - 46.0) / 6.0, 0.0, 1.0)))
		if _elapsed >= 52.0:
			_write_json("final-demo-result.json", {
				"fixture_harvested": {"greens": 9, "radish": 6},
				"controlled_utc_advance_seconds": 1440,
				"fixture_hours": [12, 21], "farm": farm_scene.farm_state.snapshot(),
				"hud_clock_matches_fixture": farm_scene.hud._clock.text == "21:00",
				"decorations": farm_scene.decoration_state.snapshot(),
				"presentation": farm_scene.focus_detail.get_settings(),
				"mesh_lod_threshold": get_viewport().mesh_lod_threshold,
				"saved": not farm_scene._save_failed
			})
			_stage = 19


func _demo_action(tool: String) -> void:
	if farm_scene.selected_cell.is_empty():
		farm_scene._select_cell("cell_06")
	if tool == "sow":
		farm_scene._select_crop("greens")
	elif farm_scene.selected_tool != tool:
		farm_scene._select_tool(tool)
	farm_scene._apply_tool()


func _set_demo_hour(hour: float) -> void:
	farm_scene.atmosphere.set_preview_hour(hour)
	var minutes: int = int(round(hour * 60.0)) % 1440
	farm_scene.hud._clock.text = "%02d:%02d" % [floori(minutes / 60.0), minutes % 60]
	farm_scene.hud._day_icon.texture = farm_scene.hud.SUN if minutes >= 360 and minutes < 1080 else farm_scene.hud.MOON


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_request_stop("user_f9")
		get_viewport().set_input_as_handled()


func _request_stop(reason: String) -> void:
	if _stopping:
		return
	_stopping = true
	_write_json("stop.json", {"reason": reason})
	if OS.has_feature("movie"):
		_release_recording_audio()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit()


func _release_recording_audio() -> void:
	if is_instance_valid(farm_scene.farm_audio):
		farm_scene.farm_audio.free()
		farm_scene.farm_audio = null


func _fail(message: String) -> void:
	_write_json("error.json", {"error": message})
	push_error(message)
	get_tree().quit(1)


func _write_json(filename: String, data: Dictionary) -> void:
	var path := session_dir.path_join(filename)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_error("Cannot write recording state: " + path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		push_error("Cannot publish recording state: " + path)
		get_tree().quit(1)
