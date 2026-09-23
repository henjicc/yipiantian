extends Node
## Sole owner of presentation scheduling. Real time is settled before resuming.

signal foreground_changed(active: bool)
signal presentation_changed(visible: bool)
signal deep_idle_changed(enabled: bool)

const DEEP_IDLE_MSEC: int = 300000
var _suspended: bool = false
var _hidden_since: int = 0
var _deep_idle: bool = false
var _previous_pause: bool = false
var _previous_low_usage: bool = false
var _previous_sleep: int = 0
var _render_size := Vector2i.ZERO

var _foreground_cap: int = 0
var _active: bool = true
var _elapsed: float = 0.0
var _wallpaper: bool = false
var _wallpaper_interacting: bool = false
var _wallpaper_visible: bool = true
var _wallpaper_transition: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_tree().get_nodes_in_group("farm_window_activity_owner").is_empty():
		push_error("Only one WindowActivity may own the presentation frame cap.")
		queue_free()
		return
	add_to_group("farm_window_activity_owner")
	_foreground_cap = Engine.max_fps if Engine.max_fps > 0 else 60
	_previous_low_usage = OS.low_processor_usage_mode
	_previous_sleep = OS.low_processor_usage_mode_sleep_usec
	get_window().focus_entered.connect(_refresh)
	get_window().focus_exited.connect(_refresh)
	get_window().size_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if _suspended and not _deep_idle and Time.get_ticks_msec() - _hidden_since >= DEEP_IDLE_MSEC:
		_deep_idle = true
		# Godot 4.7.2 releases the 3D buffers for a zero-sized render target.
		# Only the server target changes; native window bounds and UI stay intact.
		_render_size = get_window().get_texture().get_size()
		RenderingServer.viewport_set_size(get_window().get_viewport_rid(), 0, 0)
		deep_idle_changed.emit(true)
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		_refresh()


func _exit_tree() -> void:
	if is_in_group("farm_window_activity_owner"):
		_set_suspended(false, false)
		Engine.max_fps = _foreground_cap


func is_foreground() -> bool:
	return _active


func is_suspended() -> bool:
	return _suspended


func _set_suspended(enabled: bool, notify: bool = true) -> void:
	if enabled == _suspended: return
	_suspended = enabled
	if enabled:
		_hidden_since = Time.get_ticks_msec()
		_previous_pause = get_tree().paused
		RenderingServer.set_render_loop_enabled(false)
		presentation_changed.emit(false)
		get_tree().paused = true
		OS.low_processor_usage_mode = true
		OS.low_processor_usage_mode_sleep_usec = 50000
	else:
		# Signals run synchronously: restore resources and settle UTC before drawing.
		if _deep_idle:
			_deep_idle = false
			var size: Vector2i = get_window().size if get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS else _render_size
			RenderingServer.viewport_set_size(get_window().get_viewport_rid(), size.x, size.y)
			if notify: deep_idle_changed.emit(false)
		if notify: presentation_changed.emit(true)
		get_tree().paused = _previous_pause
		OS.low_processor_usage_mode = _previous_low_usage
		OS.low_processor_usage_mode_sleep_usec = _previous_sleep
		RenderingServer.set_render_loop_enabled(true)


func set_wallpaper(enabled: bool) -> void:
	_wallpaper = enabled
	_wallpaper_interacting = false
	_wallpaper_transition = false
	_wallpaper_visible = true
	_refresh()


func set_wallpaper_interacting(enabled: bool) -> void:
	_wallpaper_interacting = enabled
	_wallpaper_transition = false
	_refresh()


func set_wallpaper_visible(uncovered: bool) -> void:
	_wallpaper_visible = uncovered
	_apply_frame_limit()


func begin_wallpaper_restore() -> void:
	# SetParent sends synchronous cross-process window messages. Keep pumping
	# them promptly until the native host has finished restoring the window.
	_wallpaper_transition = true
	_apply_frame_limit()


func set_foreground_frame_limit(limit: int) -> void:
	_foreground_cap = maxi(limit, 0)
	_apply_frame_limit()


func _refresh() -> void:
	var active: bool = not _wallpaper and get_window().has_focus() and get_window().mode != Window.MODE_MINIMIZED
	if active != _active:
		_active = active
		foreground_changed.emit(active)
	_apply_frame_limit()


func _apply_frame_limit() -> void:
	# Headless DisplayServer reports MINIMIZED even though tests still need their
	# scene timers and input. Native invisibility is meaningful only with a display.
	var hidden: bool = DisplayServer.get_name() != "headless" and not _wallpaper_transition and ((_wallpaper and not _wallpaper_visible) or (not _wallpaper and get_window().mode == Window.MODE_MINIMIZED))
	_set_suspended(hidden)
	if hidden:
		# Pump the private host pipe promptly; paused scene nodes do no work.
		Engine.max_fps = 20
		return
	# The user observes the second-screen development preview while working on
	# the first screen. Losing keyboard focus must not turn its animation into 15 Hz.
	var visible_preview: bool = OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview") and get_window().visible and get_window().mode != Window.MODE_MINIMIZED
	if _wallpaper_transition:
		Engine.max_fps = 60
	elif _wallpaper and _wallpaper_interacting and _wallpaper_visible:
		Engine.max_fps = _foreground_cap
	elif _wallpaper:
		var cap: int = 30
		Engine.max_fps = mini(_foreground_cap, cap) if _foreground_cap > 0 else cap
	elif _active:
		Engine.max_fps = _foreground_cap
	elif visible_preview:
		Engine.max_fps = mini(_foreground_cap,60) if _foreground_cap > 0 else 60
	else:
		Engine.max_fps = mini(_foreground_cap,15) if _foreground_cap > 0 else 15
