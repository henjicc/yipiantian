extends Node
## Presentation lifecycle only. Never pauses the tree, clock or farm state.

signal foreground_changed(active: bool)

var _foreground_cap: int = 0
var _active: bool = true
var _elapsed: float = 0.0


func _ready() -> void:
	if not get_tree().get_nodes_in_group("farm_window_activity_owner").is_empty():
		push_error("Only one WindowActivity may own the presentation frame cap.")
		queue_free()
		return
	add_to_group("farm_window_activity_owner")
	_foreground_cap = Engine.max_fps
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


func set_foreground_frame_limit(limit: int) -> void:
	_foreground_cap = maxi(limit, 0)
	_apply_frame_limit()


func _refresh() -> void:
	var active: bool = get_window().has_focus() and get_window().mode != Window.MODE_MINIMIZED
	if active != _active:
		_active = active
		foreground_changed.emit(active)
	_apply_frame_limit()


func _apply_frame_limit() -> void:
	Engine.max_fps = _foreground_cap if _active else mini(_foreground_cap, 15) if _foreground_cap > 0 else 15
