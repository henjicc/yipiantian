extends Node
## Presentation lifecycle only. Never pauses the tree, clock or farm state.

signal foreground_changed(active: bool)

var _foreground_cap: int = 0
var _active: bool = true
var _elapsed: float = 0.0
var _wallpaper: bool = false
var _wallpaper_interacting: bool = false
var _wallpaper_visible: bool = true
var _wallpaper_transition: bool = false


func _ready() -> void:
	if not get_tree().get_nodes_in_group("farm_window_activity_owner").is_empty():
		push_error("Only one WindowActivity may own the presentation frame cap.")
		queue_free()
		return
	add_to_group("farm_window_activity_owner")
	_foreground_cap = Engine.max_fps if Engine.max_fps > 0 else 60
	get_window().focus_entered.connect(_refresh)
	get_window().focus_exited.connect(_refresh)
	get_window().size_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		_refresh()


func _exit_tree() -> void:
	if is_in_group("farm_window_activity_owner"):
		Engine.max_fps = _foreground_cap


func is_foreground() -> bool:
	return _active


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
	# The user observes the second-screen development preview while working on
	# the first screen. Losing keyboard focus must not turn its animation into 15 Hz.
	var visible_preview: bool = OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview") and get_window().visible and get_window().mode != Window.MODE_MINIMIZED
	if _wallpaper_transition:
		Engine.max_fps = 60
	elif _wallpaper and _wallpaper_interacting and _wallpaper_visible:
		Engine.max_fps = _foreground_cap
	elif _wallpaper:
		# Keep settlement/timers alive while avoiding rendering an occluded desktop.
		var cap: int = 30 if _wallpaper_visible else 2
		Engine.max_fps = mini(_foreground_cap, cap) if _foreground_cap > 0 else cap
	elif _active:
		Engine.max_fps = _foreground_cap
	elif visible_preview:
		Engine.max_fps = mini(_foreground_cap,60) if _foreground_cap > 0 else 60
	else:
		Engine.max_fps = mini(_foreground_cap,15) if _foreground_cap > 0 else 15
