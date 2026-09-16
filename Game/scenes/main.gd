extends Node3D

signal farm_changed(result: Dictionary)

const FarmState = preload("res://farm/farm_state.gd")
const FarmStore = preload("res://farm/farm_store.gd")
const DecorationState = preload("res://farm/decoration_state.gd")
const DecorationLayout = preload("res://scenes/decoration_layout.gd")
const FarmAudio = preload("res://audio/farm_audio.gd")
const DayNight = preload("res://atmosphere/day_night.gd")
const WindowActivity = preload("res://atmosphere/window_activity.gd")
const HUD = preload("res://scenes/farm_hud.gd")

@onready var farm: FarmLayout = $Farm
@onready var camera: FarmCamera = $Camera3D
# One clock boundary: tests inject a callable before adding the scene to the tree.
var clock: Callable = Time.get_unix_time_from_system
var farm_state: FarmState
var decoration_state: DecorationState
var decoration_layout: DecorationLayout
var farm_audio: FarmAudio
var atmosphere: DayNight
var window_activity: WindowActivity
var store: FarmStore
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
var _loaded: bool = false
var _save_failed: bool = false
var _record_session: String = ""


func _ready() -> void:
	get_tree().auto_accept_quit = false
	# Recording is explicitly isolated before any player-state load. A release package
	# does not carry the recording implementation and refuses its launch parameter.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--record-session="):
			if not OS.has_feature("editor"):
				push_error("Development recording arguments are unavailable in this build.")
				get_tree().quit(1)
				return
			_record_session = argument.trim_prefix("--record-session=").simplify_path()
			var allowed: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(".local/recordings")
			if not _record_session.is_absolute_path() or not _record_session.replace("\\", "/").begins_with(allowed.replace("\\", "/") + "/"):
				push_error("Recording session must be inside the project's isolated recording directory.")
				get_tree().quit(1)
				return
			store = FarmStore.new(_record_session.path_join("farm"))
	if store == null:
		store = FarmStore.new()
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.tool_requested.connect(_select_tool)
	hud.crop_requested.connect(_select_crop)
	hud.overview_requested.connect(_return_overview)
	hud.reset_requested.connect(_reset_view)
	hud.retry_requested.connect(_retry_storage)
	hud.recovery_requested.connect(_recover_storage)
	hud.exit_requested.connect(func() -> void: get_tree().quit())
	hud.decoration_requested.connect(_begin_decoration)
	camera.motion_finished.connect(_refresh_hud)
	_load_game()
	# The courtyard owns all slot transforms and art; no duplicate fallback layout.
	var courtyard: Node3D = $Environment
	decoration_layout = DecorationLayout.new()
	decoration_layout.name = "Decorations"
	add_child(decoration_layout)
	decoration_layout.configure(courtyard, camera, decoration_state if _loaded else DecorationState.new())
	decoration_layout.mode_changed.connect(func(_active: bool) -> void: _refresh_hud())
	decoration_layout.confirmed.connect(_save_farm)
	farm_audio = FarmAudio.new()
	farm_audio.name = "FarmAudio"
	add_child(farm_audio)
	atmosphere = DayNight.new()
	atmosphere.name = "DayNight"
	add_child(atmosphere)
	atmosphere.configure($DirectionalLight3D, $WorldEnvironment, courtyard.get_water_surface())
	atmosphere.set_backdrop_material(courtyard.get_backdrop_material())
	atmosphere.night_weight_changed.connect(farm_audio.set_night_weight)
	farm_audio.set_night_weight(atmosphere.get_night_weight())
	window_activity = WindowActivity.new()
	window_activity.name = "WindowActivity"
	window_activity.foreground_changed.connect(farm_audio.set_foreground)
	add_child(window_activity)
	farm_audio.set_foreground(window_activity.is_foreground())
	decoration_layout.confirmed.connect(_refresh_lanterns)
	_refresh_lanterns()
	var timer := Timer.new()
	timer.name = "SettlementTimer"
	timer.wait_time = 1.0
	timer.timeout.connect(settle_farm)
	add_child(timer)
	timer.start()
	var save_timer := Timer.new()
	save_timer.name = "SaveTimer"
	save_timer.wait_time = 30.0
	save_timer.timeout.connect(func() -> void:
		if _loaded and not _save_failed:
			_save_farm())
	add_child(save_timer)
	save_timer.start()
	if not _record_session.is_empty():
		var recording: Node = load("res://development/recording_session.gd").new()
		recording.session_dir = _record_session
		recording.farm_scene = self
		add_child(recording)


func _load_game() -> void:
	var result: Dictionary = store.load_state()
	if not result.ok:
		_loaded = false
		farm.visible = false
		hud.show_storage_issue(result.kind, false)
		return
	if result.kind == "missing":
		farm_state = FarmState.new(clock.call())
		decoration_state = DecorationState.new()
	else:
		farm_state = FarmState.new()
		farm_state.restore_snapshot(result.farm)
		decoration_state = DecorationState.new()
		decoration_state.restore_snapshot(result.decorations)
	decoration_state.unlock(farm_state.snapshot().harvested)
	if decoration_layout != null:
		decoration_layout.bind_state(decoration_state)
		_refresh_lanterns()
	_loaded = true
	farm.visible = true
	settle_farm()
	_save_farm()
	print("FARM_LOAD stage=%s version=%d migrated=%s saved=%s" % [result.kind, FarmStore.VERSION, result.get("migrated", false), not _save_failed])


func _save_farm() -> bool:
	if not _loaded:
		return false
	var result: Dictionary = store.save(farm_state.snapshot(), decoration_state.snapshot())
	_save_failed = not result.ok
	if _save_failed:
		if decoration_layout != null:
			decoration_layout.finish_mode()
		_cancel_input()
		selected_tool = ""
		hud.show_storage_issue(result.kind, true)
	else:
		hud.show_saved()
	_refresh_hud()
	return result.ok


func _retry_storage() -> void:
	if _loaded:
		settle_farm()
		_save_farm()
	else:
		_load_game()


func _recover_storage() -> void:
	var result: Dictionary = store.recover()
	if not result.ok:
		hud.show_storage_issue(result.kind, false)
		return
	_load_game()


func _request_exit() -> void:
	_cancel_input()
	if decoration_layout != null:
		decoration_layout.finish_mode()
	if not _loaded:
		get_tree().quit()
		return
	settle_farm()
	if _save_farm():
		get_tree().quit()


func settle_farm() -> void:
	if not _loaded:
		return
	var result: Dictionary = farm_state.settle(clock.call())
	if result.ok:
		refresh_farm()


func refresh_farm() -> void:
	for field_id: String in FarmState.FIELD_IDS:
		farm.show_field(farm_state.get_field(field_id))
	_refresh_hud()


func _refresh_hud() -> void:
	if hud == null or not _loaded:
		return
	var field: Dictionary = {} if selected_field < 0 else farm_state.get_field(farm.field_id(selected_field))
	hud.show_state(field, farm_state.snapshot().harvested, selected_tool, selected_crop, camera.is_transitioning() or _save_failed)
	hud.show_decoration_mode(decoration_layout != null and decoration_layout.active)


func _begin_decoration() -> void:
	if not _loaded or _save_failed or decoration_layout == null:
		return
	_return_overview()
	decoration_layout.begin_mode()
	farm_audio.play_ui()


func _refresh_lanterns() -> void:
	if atmosphere != null and decoration_layout != null:
		atmosphere.set_lantern_anchors(decoration_layout.lantern_anchors())


func _input(event: InputEvent) -> void:
	if not _loaded or _save_failed:
		return
	if decoration_layout != null and decoration_layout.active:
		decoration_layout.observe_input(event)
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			if decoration_layout.selected_item.is_empty():
				decoration_layout.finish_mode()
			else:
				decoration_layout.cancel_preview()
			get_viewport().set_input_as_handled()
		return
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
	if not _loaded or _save_failed:
		return
	if decoration_layout != null and decoration_layout.active:
		decoration_layout.handle_input(event)
		return
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_request_exit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_cancel_input()
		selected_tool = ""
		if decoration_layout != null and decoration_layout.active:
			if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
				decoration_layout.finish_mode()
			else:
				decoration_layout.cancel_preview()
		if is_node_ready():
			_refresh_hud()
			if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _loaded and not _save_failed:
				settle_farm()
				_save_farm()
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
	if not _loaded or _save_failed or selected_field < 0 or camera.is_transitioning():
		return
	selected_tool = "" if selected_tool == tool else tool
	farm_audio.play_ui()
	hud.clear_feedback()
	_refresh_hud()


func _select_crop(crop_id: String) -> void:
	_cancel_input()
	selected_crop = crop_id
	farm_audio.play_ui()
	_refresh_hud()


func _apply_tool() -> void:
	if not _loaded or _save_failed or selected_tool.is_empty():
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
	farm_audio.play_action(selected_tool, result)
	if result.ok:
		selected_tool = ""
		var unlocked: Array[String] = decoration_state.unlock(farm_state.snapshot().harvested)
		hud.show_unlocks(unlocked)
		refresh_farm()
		farm_changed.emit(result)
		_save_farm()


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
