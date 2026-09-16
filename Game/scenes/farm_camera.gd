class_name FarmCamera
extends Camera3D

signal motion_finished

const DEFAULT_POINT := Vector3(0.0, 0.6, 0.0)
const DEFAULT_VIEW := Vector3(32.0, 34.0, 26.0)

var focus_point: Vector3 = DEFAULT_POINT
var view: Vector3 = DEFAULT_VIEW # yaw, pitch, distance
var focused: bool = false
var transition_seconds: float = 0.75
var _saved_point: Vector3 = DEFAULT_POINT
var _saved_view: Vector3 = DEFAULT_VIEW
var _anchor: Vector3 = DEFAULT_POINT
var _transition: Tween
var _destination_point: Vector3 = DEFAULT_POINT
var _destination_view: Vector3 = DEFAULT_VIEW


func _ready() -> void:
	fov = 35.0
	near = 0.1
	far = 150.0
	_apply_pose()


func _process(_delta: float) -> void:
	_apply_pose()


func focus_field(point: Vector3) -> void:
	if not focused:
		# Re-entering focus while returning must remember the overview destination,
		# not a transient position halfway through that return.
		var returning: bool = _transition != null and _transition.is_running()
		_saved_point = _destination_point if returning else focus_point
		_saved_view = _destination_view if returning else view
	focused = true
	_anchor = point + Vector3(0.0, 0.35, 0.0)
	_move_to(_anchor, Vector3(view.x, 36.0, 9.5))


func return_overview() -> void:
	if not focused:
		return
	focused = false
	_anchor = DEFAULT_POINT
	_move_to(_saved_point, _saved_view)


func reset_view() -> void:
	focused = false
	_anchor = DEFAULT_POINT
	_move_to(DEFAULT_POINT, DEFAULT_VIEW)


func zoom(amount: float) -> void:
	_stop_transition()
	view.z = clampf(view.z + amount, 7.5 if focused else 22.0, 15.0 if focused else 34.0)
	_apply_pose()
	motion_finished.emit()


func drag(relative: Vector2, pan: bool) -> void:
	_stop_transition()
	if pan:
		var right := Vector3(cos(deg_to_rad(view.x)), 0.0, -sin(deg_to_rad(view.x)))
		var forward := Vector3(sin(deg_to_rad(view.x)), 0.0, cos(deg_to_rad(view.x)))
		focus_point += (-right * relative.x - forward * relative.y) * view.z * 0.0014
		var limit: float = 1.1 if focused else 2.0
		focus_point.x = clampf(focus_point.x, _anchor.x - limit, _anchor.x + limit)
		focus_point.z = clampf(focus_point.z, _anchor.z - limit, _anchor.z + limit)
	else:
		view.x = clampf(view.x - relative.x * 0.18, -12.0, 68.0)
		view.y = clampf(view.y + relative.y * 0.18, 28.0, 58.0)
	_apply_pose()
	motion_finished.emit()


func is_transitioning() -> bool:
	return _transition != null and _transition.is_running()


func _move_to(point: Vector3, target_view: Vector3) -> void:
	_stop_transition()
	_destination_point = point
	_destination_view = target_view
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(self, "focus_point", point, transition_seconds)
	_transition.tween_property(self, "view", target_view, transition_seconds)
	_transition.finished.connect(func() -> void: motion_finished.emit())


func _stop_transition() -> void:
	if _transition and _transition.is_valid():
		_transition.kill()


func _apply_pose() -> void:
	var yaw := deg_to_rad(view.x)
	var pitch := deg_to_rad(view.y)
	position = focus_point + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * view.z
	look_at(focus_point)
