extends Node3D

signal farm_changed(result: Dictionary)

const FarmState = preload("res://farm/farm_state.gd")
const HUD = preload("res://scenes/farm_hud.gd")

@onready var farm: FarmLayout = $Farm
@onready var camera: FarmCamera = $Camera3D
# One clock boundary: tests inject a callable before adding the scene to the tree.
var clock: Callable = Time.get_unix_time_from_system
var farm_state: FarmState
var hud: HUD
var selected_field: int = -1
var selected_tool: String = ""
var selected_crop: String = "greens"
var _dragging: bool = false
var _press_position := Vector2.INF
var _press_dragged: bool = false
var _pressed_field: int = -1
var _press_context: Dictionary = {}
var _picks: Array[Dictionary] = []


func _ready() -> void:
	if farm_state == null:
		farm_state = FarmState.new(clock.call())
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.tool_requested.connect(_select_tool)
	hud.crop_requested.connect(_select_crop)
	hud.overview_requested.connect(_return_overview)
	hud.reset_requested.connect(_reset_view)
	camera.motion_finished.connect(_refresh_hud)
	refresh_farm()
	var timer := Timer.new()
	timer.name = "SettlementTimer"
	timer.wait_time = 1.0
	timer.timeout.connect(settle_farm)
	add_child(timer)
	timer.start()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--record-session="):
			var recording: Node = load("res://development/recording_session.gd").new()
			recording.session_dir = argument.trim_prefix("--record-session=")
			recording.farm_scene = self
			add_child(recording)
			break


func settle_farm() -> void:
	var result: Dictionary = farm_state.settle(clock.call())
	if result.ok:
		refresh_farm()


func refresh_farm() -> void:
	for field_id: String in FarmState.FIELD_IDS:
		farm.show_field(farm_state.get_field(field_id))
	_refresh_hud()


func _refresh_hud() -> void:
	if hud == null:
		return
	var field: Dictionary = {} if selected_field < 0 else farm_state.get_field(farm.field_id(selected_field))
	hud.show_state(field, farm_state.snapshot().harvested, selected_tool, selected_crop, camera.is_transitioning())


func _input(event: InputEvent) -> void:
	# Cancellation sees even GUI-consumed releases; world gestures start only in unhandled input.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_or_return()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_or_return()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _press_position != Vector2.INF:
		_press_dragged = _press_dragged or event.position.distance_to(_press_position) > 7.0
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = false
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var hovered := get_viewport().gui_get_hovered_control()
			if event.canceled or (hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE):
				_cancel_input()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.double_click or event.canceled:
					_cancel_input()
				elif event.pressed:
					_press_position = event.position
					_press_dragged = _dragging
					_picks.append({"down": true, "position": event.position, "dragged": _dragging,
						"action_allowed": not camera.is_transitioning(), "selection": selected_field, "tool": selected_tool})
				elif _press_position != Vector2.INF:
					_picks.append({"down": false, "position": event.position, "dragged": _press_dragged,
						"action_allowed": not camera.is_transitioning()})
					_press_position = Vector2.INF
			MOUSE_BUTTON_MIDDLE:
				_cancel_input()
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_cancel_input()
					camera.zoom(-0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8)
	elif event is InputEventMouseMotion and _dragging:
		camera.drag(event.relative, event.shift_pressed)


func _physics_process(_delta: float) -> void:
	# Space queries belong to the physics boundary. Each gesture carries its admission
	# state so a click made in flight can never become an action after the tween ends.
	var picks: Array[Dictionary] = _picks
	_picks = []
	for pick: Dictionary in picks:
		var index: int = _field_at(pick.position)
		if pick.down:
			_pressed_field = index
			_press_context = pick
		else:
			if not pick.dragged and index >= 0 and index == _pressed_field:
				if index != selected_field:
					_focus_field(index)
				elif pick.action_allowed and _press_context.get("action_allowed", false) and not camera.is_transitioning():
					if _press_context.get("selection", -1) == selected_field and _press_context.get("tool", "") == selected_tool:
						_apply_tool()
			_pressed_field = -1
			_press_context = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_cancel_input()
		selected_tool = ""
		if is_node_ready():
			_refresh_hud()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN and is_node_ready():
		settle_farm()


func _field_at(screen_point: Vector2) -> int:
	var origin := camera.project_ray_origin(screen_point)
	var end := origin + camera.project_ray_normal(screen_point) * 120.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	return int(hit.collider.get_meta("field_index", -1))


func _focus_field(index: int) -> void:
	_cancel_input()
	selected_tool = ""
	selected_field = index
	farm.select_field(index)
	camera.focus_field(farm.fields[index].global_position)
	hud.clear_feedback()
	_refresh_hud()


func _select_tool(tool: String) -> void:
	_cancel_input()
	if selected_field < 0 or camera.is_transitioning():
		return
	selected_tool = "" if selected_tool == tool else tool
	hud.clear_feedback()
	_refresh_hud()


func _select_crop(crop_id: String) -> void:
	_cancel_input()
	selected_crop = crop_id
	_refresh_hud()


func _apply_tool() -> void:
	if selected_tool.is_empty():
		return
	var field_id: String = farm.field_id(selected_field)
	var now: float = clock.call()
	var result: Dictionary
	match selected_tool:
		"sow": result = farm_state.sow(field_id, selected_crop, now)
		"water": result = farm_state.water(field_id, now)
		"harvest": result = farm_state.harvest(field_id, now)
		_: return
	hud.show_result(result, selected_tool, selected_crop)
	if result.ok:
		selected_tool = ""
		refresh_farm()
		farm_changed.emit(result)


func _cancel_or_return() -> void:
	_cancel_input()
	if not selected_tool.is_empty():
		selected_tool = ""
		hud.clear_feedback()
		_refresh_hud()
	else:
		_return_overview()


func _return_overview() -> void:
	_cancel_input()
	selected_tool = ""
	selected_field = -1
	farm.select_field(-1)
	camera.return_overview()
	hud.clear_feedback()
	_refresh_hud()


func _reset_view() -> void:
	_return_overview()
	camera.reset_view()
	_refresh_hud()


func _cancel_input() -> void:
	_dragging = false
	_press_position = Vector2.INF
	_press_dragged = true
	_pressed_field = -1
	_press_context = {}
	_picks.clear()
