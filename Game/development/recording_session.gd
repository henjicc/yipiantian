extends Node
## Only instantiated by the explicit development recording launcher.
## FFmpeg owns capture/encoding; this node owns the recording window and optional tour.

const TARGET_SIZE := Vector2i(3840, 2160)
var session_dir: String
var farm_scene: Node3D
var _demo: bool = false
var _started: bool = false
var _stopping: bool = false
var _elapsed: float = 0.0
var _poll_elapsed: float = 0.0
var _stage: int = 0


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


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_request_stop("user_f9")
		get_viewport().set_input_as_handled()


func _request_stop(reason: String) -> void:
	if _stopping:
		return
	_stopping = true
	_write_json("stop.json", {"reason": reason})


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
