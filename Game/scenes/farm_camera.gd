class_name FarmCamera
extends Camera3D

signal motion_finished
signal overview_changed

const DEFAULT_POINT := Vector3(0.25, 0.75, 0.0)
const DEFAULT_VIEW := Vector3(27.5, 10.0, 25.5)
const MIN_YAW := -12.0
const MAX_YAW := 68.0
const FOCUS_DISTANCE: float = 10.4
const ARRANGEMENT_DISTANCE: float = 31.0
var construction_framing: bool = false
var construction_bounds := Rect2(-7.6,-8.4,14.4,15.1)
const ZOOM_RESPONSE: float = 16.0
const SurfacePick = preload("res://scenes/camera_surface_pick.gd")

var focus_point: Vector3 = DEFAULT_POINT
var view: Vector3 = DEFAULT_VIEW # yaw, pitch, distance
var overview_point: Vector3 = DEFAULT_POINT
var overview_view: Vector3 = DEFAULT_VIEW
var focused: bool = false
var _focus_distance: float = FOCUS_DISTANCE
var transition_seconds: float = 0.75
var _saved_point: Vector3 = DEFAULT_POINT
var _saved_view: Vector3 = DEFAULT_VIEW
var _anchor: Vector3 = DEFAULT_POINT
var _transition: Tween
var _distance_transition: Tween
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
var _zoom_active: bool = false
var _zoom_target: float = 0.0 # Distance in normal view; remaining travel in free view.
var _zoom_velocity: float = 0.0
var _free_return_point: Vector3
var _free_return_view: Vector3
var neighbor_view: bool = false
var _neighbor_return_point: Vector3
var _neighbor_return_view: Vector3

func view_neighbor(point: Vector3, angles: Vector3) -> void:
	if not neighbor_view:
		_neighbor_return_point = _destination_point if is_transitioning() else focus_point
		_neighbor_return_view = _destination_view if is_transitioning() else view
	neighbor_view=true
	_move_to(point,angles)

func leave_neighbor() -> void:
	if not neighbor_view: return
	neighbor_view=false
	_move_to(_neighbor_return_point,_neighbor_return_view)

func configure_layout(point: Vector3, distance: float) -> void:
	overview_point = point
	overview_view = Vector3(DEFAULT_VIEW.x,DEFAULT_VIEW.y,distance)
	focus_point = point
	view = overview_view
	_saved_point = point
	_saved_view = view
	_destination_point = point
	_destination_view = view
	_anchor = point


func _ready() -> void:
	fov = 36.0
	near = 0.1
	far = 600.0
	_apply_pose()


func _process(delta: float) -> void:
	_advance_zoom(delta)
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
	_zoom_target = (_zoom_target if _zoom_active else 0.0) + amount
	_zoom_active = true


func _stop_free_zoom() -> void:
	if free_view:
		cancel_zoom()


func cancel_zoom() -> void:
	var was_active := _zoom_active
	_zoom_active = false
	_zoom_velocity = 0.0
	if not free_view and was_active:
		_destination_view.z = view.z
		_notify_motion_finished()


func _advance_zoom(delta: float) -> void:
	if not _zoom_active:
		return
	# Exact critically damped spring: retain velocity across wheel ticks and use
	# elapsed seconds, so repeated input never restarts an easing curve.
	var current: float = 0.0 if free_view else view.z
	var error: float = current - _zoom_target
	var decay: float = exp(-ZOOM_RESPONSE * delta)
	var spring: float = _zoom_velocity + ZOOM_RESPONSE * error
	var next: float = _zoom_target + (error + spring * delta) * decay
	_zoom_velocity = (_zoom_velocity - ZOOM_RESPONSE * spring * delta) * decay
	var settled: bool = absf(next - _zoom_target) < 0.0001 and absf(_zoom_velocity) < 0.001
	if settled:
		next = _zoom_target
	if free_view:
		global_position += global_basis.z * next
		_zoom_target -= next
	else:
		# A focus transition may still be approaching from outside its final limit.
		var bounded := clampf(next, 8.5, maxf(current, _maximum_distance()))
		if not is_equal_approx(next, bounded):
			_zoom_velocity = 0.0
		view.z = bounded
	if settled:
		_zoom_active = false
		_zoom_velocity = 0.0
		_notify_motion_finished()


func _maximum_distance() -> float:
	if construction_framing: return maxf(maxf(34.0,overview_view.z+2.4),maxf(construction_bounds.size.x,construction_bounds.size.y)*1.8)
	return _focus_distance if focused else maxf(ARRANGEMENT_DISTANCE,overview_view.z+2.4) if _decoration_framing else overview_view.z

func set_construction_framing(enabled: bool, animate: bool = true) -> void:
	_stop_transition()
	set_free_view(false)
	construction_framing=enabled
	focused=false
	_anchor=overview_point
	if enabled and animate:
		var center: Vector2=construction_bounds.get_center()
		_move_to(Vector3(center.x,.4,center.y),Vector3(24,65,_maximum_distance()))
	elif not enabled: reset_view()


func overview_parameters() -> Dictionary:
	return {"yaw": overview_view.x, "pitch": overview_view.y, "distance": overview_view.z,
		"fov": fov, "target_x": overview_point.x, "target_y": overview_point.y, "target_z": overview_point.z}

func restore_overview_angles(angles: Vector2) -> void:
	overview_view.x = clampf(angles.x,MIN_YAW,MAX_YAW)
	overview_view.y = clampf(angles.y,10.0,40.0)
	view = overview_view
	_saved_view = view
	_destination_view = view
	_apply_pose()


func preview_overview(parameters: Dictionary) -> void:
	_stop_transition()
	cancel_free_gesture()
	free_view = false
	focused = false
	_decoration_framing = false
	overview_view = Vector3(parameters.yaw, parameters.pitch, parameters.distance)
	overview_point = Vector3(parameters.target_x, parameters.target_y, parameters.target_z)
	fov = parameters.fov
	view = overview_view
	focus_point = overview_point
	_anchor = overview_point
	_destination_view = view
	_destination_point = focus_point
	_saved_view = view
	_saved_point = focus_point
	_apply_pose()
	motion_finished.emit()


func focus_field(point: Vector3, size: Vector2 = Vector2(2.6,2.05)) -> void:
	if _decoration_framing:
		set_decoration_framing(false)
	if not focused:
		# Re-entering focus while returning must remember the overview destination,
		# not a transient position halfway through that return.
		var returning: bool = is_transitioning()
		_saved_point = _destination_point if returning else focus_point
		_saved_view = _destination_view if returning else view
	focused = true
	_focus_distance = FOCUS_DISTANCE*maxf(size.x/2.6,size.y/2.05)
	_anchor = point + Vector3(0.0, 0.35, 0.0)
	_move_to(_anchor, Vector3(view.x, 40.0, _focus_distance))


func return_overview() -> void:
	if not focused:
		return
	focused = false
	_anchor = overview_point
	_move_to(_saved_point, _saved_view)


func reset_view() -> void:
	# Reset means the normal default, including when a caller resets during framing.
	_decoration_framing = false
	focused = false
	_anchor = overview_point
	_move_to(overview_point, overview_view)


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
		_move_to(overview_point - Vector3.UP * 1.8, Vector3(25.0, 34.0, maxf(ARRANGEMENT_DISTANCE,overview_view.z+2.4)))
	else:
		_decoration_framing = false
		_move_to(_decoration_return_point, _decoration_return_view)


func zoom(amount: float) -> void:
	var target: float = _destination_view.z if is_transitioning() else view.z
	if not is_transitioning():
		_destination_point = focus_point
		_destination_view = view
	if _distance_transition != null and _distance_transition.is_valid():
		_distance_transition.kill()
	_zoom_target = clampf(target + amount, 8.5, _maximum_distance())
	_destination_view.z = _zoom_target
	_zoom_active = true


func drag(relative: Vector2, pan: bool) -> void:
	_stop_transition()
	if pan:
		var right := Vector3(cos(deg_to_rad(view.x)), 0.0, -sin(deg_to_rad(view.x)))
		var forward := Vector3(sin(deg_to_rad(view.x)), 0.0, cos(deg_to_rad(view.x)))
		focus_point += (-right * relative.x - forward * relative.y) * view.z * 0.0014
		var limit: float = 1.1 if focused else 2.0
		if construction_framing:
			focus_point.x=clampf(focus_point.x,construction_bounds.position.x,construction_bounds.end.x)
			focus_point.z=clampf(focus_point.z,construction_bounds.position.y,construction_bounds.end.y)
		else:
			focus_point.x = clampf(focus_point.x, _anchor.x - limit, _anchor.x + limit)
			focus_point.z = clampf(focus_point.z, _anchor.z - limit, _anchor.z + limit)
	else:
		view.x = clampf(view.x - relative.x * 0.18, MIN_YAW, MAX_YAW)
		view.y = clampf(view.y + relative.y * 0.18, 50.0 if construction_framing else 32.0 if focused else 10.0, 78.0 if construction_framing else 54.0 if focused else 40.0)
	_apply_pose()
	if not pan and not focused and not free_view and not neighbor_view and not construction_framing and not _decoration_framing:
		overview_view.x = view.x
		overview_view.y = view.y
		overview_changed.emit()
	motion_finished.emit()


func is_transitioning() -> bool:
	return (_transition != null and _transition.is_running()) or (_distance_transition != null and _distance_transition.is_running()) or (not free_view and _zoom_active)


func _move_to(point: Vector3, target_view: Vector3) -> void:
	_stop_transition()
	_destination_point = point
	_destination_view = target_view
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(self, "focus_point", point, transition_seconds)
	_transition.tween_property(self, "view:x", target_view.x, transition_seconds)
	_transition.tween_property(self, "view:y", target_view.y, transition_seconds)
	# Wheel input can take over distance without restarting focus/pan transitions.
	_distance_transition = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_distance_transition.tween_property(self, "view:z", target_view.z, transition_seconds)
	_transition.finished.connect(_notify_motion_finished)
	_distance_transition.finished.connect(_notify_motion_finished)


func _notify_motion_finished() -> void:
	if not is_transitioning():
		motion_finished.emit()


func _stop_transition() -> void:
	if _transition and _transition.is_valid():
		_transition.kill()
	if _distance_transition and _distance_transition.is_valid():
		_distance_transition.kill()
	_zoom_active = false
	_zoom_velocity = 0.0


func _apply_pose() -> void:
	var yaw := deg_to_rad(view.x)
	var pitch := deg_to_rad(view.y)
	position = focus_point + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * view.z
	look_at(focus_point)
