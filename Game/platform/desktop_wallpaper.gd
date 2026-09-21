extends Node
## Private inherited pipes bind this host to this game; no network listener. Mouse forwarding is limited to the uncovered desktop.
signal changed(active: bool)
signal visibility_changed(uncovered: bool)
signal restoring
signal failed(message: String)
signal quit_requested
signal pointer_moved(position: Vector2)
signal interaction_changed(enabled: bool)
signal workarea_changed(area: Vector4)
signal pointer_left
signal pointer_button(position: Vector2, button: int, pressed: bool, factor: float)

var interacting: bool = false

var active: bool = false
var busy: bool = false
var _host: Dictionary = {}
var _pipe: FileAccess
var _pending: String = ""
var _window_state: Dictionary = {}
var _deadline: int = 0
var _stopping: bool = false
var _quit_after_restore: bool = false
var _finishing: bool = false

func _ready() -> void:
	set_process(false)

func executable_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(".local/builds/windows/FarmDesktop.exe")
	return OS.get_executable_path().get_base_dir().path_join("FarmDesktop.exe")

func available() -> bool:
	return OS.get_name() == "Windows" and DisplayServer.get_name() != "headless" and FileAccess.file_exists(executable_path())

func enter() -> void:
	if busy or active or not _host.is_empty(): return
	if not available():
		failed.emit("桌面组件未找到，请使用包含 FarmDesktop.exe 的完整游戏包。")
		return
	busy = true
	var window: Window = get_window()
	_window_state = {"mode": window.mode, "screen": window.current_screen, "position": window.position,
		"size": window.size, "borderless": window.borderless}
	window.mode = Window.MODE_WINDOWED
	window.borderless = true
	window.current_screen = int(_window_state.screen)
	# Give the engine a frame to leave exclusive fullscreen before native reparenting.
	await get_tree().process_frame
	_host = OS.execute_with_pipe(executable_path(), PackedStringArray([
		str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)), str(OS.get_process_id())]), false)
	if _host.is_empty():
		_reset_window()
		busy = false
		failed.emit("桌面模式未能启动，已返回农场。")
		return
	_pipe = _host.stdio
	_pending = ""
	_stopping = false
	_quit_after_restore = false
	_deadline = Time.get_ticks_msec() + 7000
	set_process(true)

func restore() -> void:
	if _host.is_empty() or _stopping: return
	restoring.emit()
	busy = true
	_deadline = Time.get_ticks_msec() + 5000
	_send("RESTORE")

func set_interacting(value: bool) -> void:
	if not active or busy: return
	busy = true
	_deadline = Time.get_ticks_msec() + 5000
	restoring.emit()
	_send("INTERACT" if value else "OBSERVE")

func _send(command: String) -> void:
	if _pipe == null: return
	_pipe.store_buffer((command + "\n").to_utf8_buffer())
	if _pipe.get_error() != OK:
		push_error("DESKTOP_HOST pipe write failed: " + command)

func _process(_delta: float) -> void:
	if _host.is_empty() or _finishing: return
	if not OS.is_process_running(int(_host.pid)):
		var unexpected: bool = not _stopping
		await _finish()
		if unexpected: failed.emit("桌面组件已停止，已恢复游戏显示。")
		return
	# Windows pipe length is the number of immediately available bytes (PeekNamedPipe).
	var count: int = int(_pipe.get_length()) if _pipe != null else 0
	if count > 0:
		_pending += _pipe.get_buffer(mini(count, 4096)).get_string_from_utf8()
		if _pending.length() > 8192:
			failed.emit("桌面组件返回了无效状态，正在恢复游戏。")
			restore()
			_pending = ""
		while _pending.contains("\n"):
			var split: int = _pending.find("\n")
			var line: String = _pending.substr(0, split)
			_pending = _pending.substr(split + 1)
			_receive(line)
	if busy and Time.get_ticks_msec() > _deadline:
		# Closing our pipe makes the host restore its owned window and terminate.
		push_error("DESKTOP_HOST timed out; closing inherited pipe for native rollback")
		_pipe.close()
		_pipe = null
		_stopping = true
		busy = false
		failed.emit("桌面切换超时，正在取消；请稍后重试。")

func _receive(line: String) -> void:
	if line.begins_with("WORKAREA "):
		var values: PackedStringArray = line.split(" ", false)
		if values.size() != 5: return
		for i: int in range(1, 5):
			if not values[i].is_valid_float(): return
		var area := Vector4(float(values[1]), float(values[2]), float(values[3]), float(values[4]))
		if area.is_finite() and area.x >= 0 and area.y >= 0 and area.z <= 1 and area.w <= 1 and area.z > area.x and area.w > area.y:
			workarea_changed.emit(area)
		return
	if line == "LEAVE":
		pointer_left.emit()
		return
	if line.begins_with("POINTER ") or line.begins_with("BUTTON "):
		var parts: PackedStringArray = line.split(" ", false)
		var is_button: bool = parts[0] == "BUTTON"
		var offset: int = 3 if is_button else 1
		if active and not busy and parts.size() == (6 if is_button else 3) and parts[offset].is_valid_float() and parts[offset+1].is_valid_float():
			var point := Vector2(float(parts[offset]), float(parts[offset+1]))
			if point.is_finite() and point.x >= 0.0 and point.x < 1.0 and point.y >= 0.0 and point.y < 1.0:
				if not is_button:
					pointer_moved.emit(point)
				elif parts[1] in ["1", "2", "3", "4", "5"] and parts[2] in ["0", "1"] and parts[5].is_valid_float():
					var factor: float = float(parts[5])
					if is_finite(factor) and factor >= 0.0 and factor <= 100.0:
						pointer_button.emit(point, int(parts[1]), parts[2] == "1", factor)
		return
	print("DESKTOP_HOST " + line)
	match line:
		"RESTORING", "ATTACHING":
			busy = true
			_deadline = Time.get_ticks_msec() + 5000
			restoring.emit()
		"INTERACTIVE", "OBSERVING":
			interacting = line == "INTERACTIVE"
			busy = false
			interaction_changed.emit(interacting)
		"ATTACHED":
			interacting = false
			active = true
			busy = false
			changed.emit(true)
		"VISIBLE": visibility_changed.emit(true)
		"COVERED": visibility_changed.emit(false)
		"RESTORED":
			_stopping = true
			_send("STOP")
		"QUIT": _quit_after_restore = true
		_:
			if line.begins_with("ERROR "):
				failed.emit("桌面模式暂时不可用，正在恢复游戏。" + "（" + line.trim_prefix("ERROR ") + "）")

func _reset_window() -> void:
	if _window_state.is_empty(): return
	var window: Window = get_window()
	# Native desktop resizing updates DisplayServer's fullscreen detection, while
	# Window.mode may still cache WINDOWED. Explicitly leave the native mode first.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	window.mode = Window.MODE_WINDOWED
	window.borderless = bool(_window_state.borderless)
	window.current_screen = clampi(int(_window_state.screen), 0, DisplayServer.get_screen_count()-1)
	window.size = _window_state.size
	window.position = _window_state.position
	window.mode = int(_window_state.mode) as Window.Mode
	_window_state.clear()

func _finish() -> void:
	_finishing = true
	# Drain native window messages before applying the original Godot window mode.
	await get_tree().process_frame
	await get_tree().process_frame
	_reset_window()
	active = false
	interacting = false
	busy = false
	if _pipe != null: _pipe.close()
	_pipe = null
	_host.clear()
	set_process(false)
	changed.emit(false)
	_finishing = false
	if _quit_after_restore: quit_requested.emit()

func _exit_tree() -> void:
	if _pipe != null:
		_send("STOP")
		_pipe.close()
	_host.clear()
