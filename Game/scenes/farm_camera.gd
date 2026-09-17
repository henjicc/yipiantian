class_name FarmCamera
extends Camera3D

signal motion_finished

const DEFAULT_POINT := Vector3(0.0, 0.85, 0.0)
const DEFAULT_VIEW := Vector3(25.0, 28.0, 28.0)
const FOCUS_DISTANCE: float = 10.4
const ARRANGEMENT_DISTANCE: float = 31.0
const ZOOM_SECONDS: float = 0.26
const SurfacePick = preload("res://scenes/camera_surface_pick.gd")

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
var _decoration_framing: bool = false
var _decoration_return_point: Vector3 = DEFAULT_POINT
var _decoration_return_view: Vector3 = DEFAULT_VIEW
var free_view: bool = false
var free_input_enabled: bool = true
var _free_drag_button: MouseButton = MOUSE_BUTTON_NONE
var _free_pivot: Vector3
var _surface_pick := SurfacePick.new()
var _free_zoom: Tween
var _free_zoom_target: Vector3
var _free_return_point: Vector3
var _free_return_view: Vector3


func _ready() -> void:
	fov = 29.0
	near = 0.1
	far = 600.0
	_apply_pose()


func _process(delta: float) -> void:
	if free_view:
		if free_input_enabled and get_window().has_focus():
			var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
			var speed: float = 10.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0 if Input.is_physical_key_pressed(KEY_CTRL) else 3.5
			move_free(direction, delta * speed)
		return
	_apply_pose()


func set_free_view(enabled: bool) -> void:
	if enabled == free_view:
		return
	cancel_free_gesture()
	if enabled:
		_free_return_point = _destination_point if is_transitioning() else focus_point
		_free_return_view = _destination_view if is_transitioning() else view
		_stop_transition()
		_free_pivot = focus_point
		free_view = true
	else:
		free_view = false
		_surface_pick.clear()
		_move_to(_free_return_point, _free_return_view)


func move_free(direction: Vector3, distance: float) -> void:
	if not free_view:
		return
	var movement: Vector3 = global_basis.x * direction.x + Vector3.UP * direction.y + global_basis.z * direction.z
	if movement.length_squared() > 0.0:
		_stop_free_zoom()
		var offset := movement.normalized() * distance
		global_position += offset
		_free_pivot += offset


func cancel_free_gesture() -> void:
	_free_drag_button = MOUSE_BUTTON_NONE
	_stop_free_zoom()


func end_free_drag(button: MouseButton) -> void:
	if button == _free_drag_button:
		cancel_free_gesture()


func free_input(event: InputEvent) -> void:
	if not free_view or not free_input_enabled:
		return
	if event is InputEventMouseButton:
		if not event.pressed or event.canceled:
			end_free_drag(event.button_index)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] and _free_drag_button == MOUSE_BUTTON_NONE:
			_stop_free_zoom()
			var depth: float = maxf(0.5, global_basis.z.dot(global_position - _free_pivot))
			_free_pivot = _surface_pick.pick(self, event.position, depth)
			_free_drag_button = event.button_index
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_free((-0.6 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.6) * event.factor)
	elif event is InputEventMouseMotion:
		if _free_drag_button == MOUSE_BUTTON_LEFT:
			_orbit_free(event.relative)
		elif _free_drag_button in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			var depth: float = maxf(0.5, global_basis.z.dot(global_position - _free_pivot))
			var offset := project_position(event.position - event.relative, depth) - project_position(event.position, depth)
			global_position += offset
			_free_pivot += offset


func _orbit_free(relative: Vector2) -> void:
	var yaw := Basis(Vector3.UP, -relative.x * 0.003)
	var pitch: float = asin(clampf(-global_basis.z.y, -1.0, 1.0))
	var pitch_delta: float = clampf(pitch - relative.y * 0.003, deg_to_rad(-89), deg_to_rad(89)) - pitch
	var turn := Basis(yaw * global_basis.x, pitch_delta) * yaw
	# Rotate pose and offset together: an off-centre clicked point stays under the cursor.
	global_transform = Transform3D((turn * global_basis).orthonormalized(), _free_pivot + turn * (global_position - _free_pivot))


func _zoom_free(amount: float) -> void:
	_free_drag_button = MOUSE_BUTTON_NONE
	var target := _free_zoom_target if _free_zoom != null and _free_zoom.is_running() else global_position
	_stop_free_zoom()
	_free_zoom_target = target + global_basis.z * amount
	_free_zoom = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_free_zoom.tween_property(self, "global_position", _free_zoom_target, ZOOM_SECONDS)


func _stop_free_zoom() -> void:
	if _free_zoom != null and _free_zoom.is_valid():
		_free_zoom.kill()


func focus_field(point: Vector3) -> void:
	if _decoration_framing:
		set_decoration_framing(false)
	if not focused:
		# Re-entering focus while returning must remember the overview destination,
		# not a transient position halfway through that return.
		var returning: bool = _transition != null and _transition.is_running()
		_saved_point = _destination_point if returning else focus_point
		_saved_view = _destination_view if returning else view
	focused = true
	_anchor = point + Vector3(0.0, 0.35, 0.0)
	_move_to(_anchor, Vector3(view.x, 40.0, FOCUS_DISTANCE))


func return_overview() -> void:
	if not focused:
		return
	focused = false
	_anchor = DEFAULT_POINT
	_move_to(_saved_point, _saved_view)


func reset_view() -> void:
	# Reset means the normal default, including when a caller resets during framing.
	_decoration_framing = false
	focused = false
	_anchor = DEFAULT_POINT
	_move_to(DEFAULT_POINT, DEFAULT_VIEW)


func set_decoration_framing(active: bool) -> void:
	if active == _decoration_framing:
		return
	if active:
		if focused:
			return_overview()
		var returning: bool = is_transitioning()
		_decoration_return_point = _destination_point if returning else focus_point
		_decoration_return_view = _destination_view if returning else view
		_decoration_framing = true
		# Use a tested operation pose, independent of the player's extreme orbit.
		# Its higher angle keeps all eight slots visible above the bottom tool shelf.
		_move_to(DEFAULT_POINT - Vector3.UP * 1.8, Vector3(25.0, 34.0, ARRANGEMENT_DISTANCE))
	else:
		_decoration_framing = false
		_move_to(_decoration_return_point, _decoration_return_view)


func zoom(amount: float) -> void:
	var point := _destination_point if is_transitioning() else focus_point
	var target := _destination_view if is_transitioning() else view
	var maximum: float = FOCUS_DISTANCE if focused else ARRANGEMENT_DISTANCE if _decoration_framing else DEFAULT_VIEW.z
	target.z = clampf(target.z + amount, 8.5, maximum)
	# Accumulate wheel ticks against the destination, not a half-finished tween.
	_move_to(point, target, ZOOM_SECONDS)


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
		view.y = clampf(view.y + relative.y * 0.18, 32.0 if focused else 24.0, 54.0 if focused else 40.0)
	_apply_pose()
	motion_finished.emit()


func is_transitioning() -> bool:
	return _transition != null and _transition.is_running()


func _move_to(point: Vector3, target_view: Vector3, duration: float = -1.0) -> void:
	_stop_transition()
	_destination_point = point
	_destination_view = target_view
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var seconds: float = transition_seconds if duration < 0.0 else duration
	_transition.tween_property(self, "focus_point", point, seconds)
	_transition.tween_property(self, "view", target_view, seconds)
	_transition.finished.connect(func() -> void: motion_finished.emit())


func _stop_transition() -> void:
	if _transition and _transition.is_valid():
		_transition.kill()


func _apply_pose() -> void:
	var yaw := deg_to_rad(view.x)
	var pitch := deg_to_rad(view.y)
	position = focus_point + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * view.z
	look_at(focus_point)
