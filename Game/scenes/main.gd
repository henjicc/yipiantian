extends Node3D

signal farm_changed(result: Dictionary)

const Crops = preload("res://farm/crop_catalog.gd")
const ToolCursor = preload("res://ui/tool_cursor.gd")
const FarmState = preload("res://farm/farm_state.gd")
const FarmStore = preload("res://farm/farm_store.gd")
const DecorationState = preload("res://farm/decoration_state.gd")
const DecorationLayout = preload("res://scenes/decoration_layout.gd")
const FarmAudio = preload("res://audio/farm_audio.gd")
const DayNight = preload("res://atmosphere/day_night.gd")
const WindowActivity = preload("res://atmosphere/window_activity.gd")
const FocusDetail = preload("res://presentation/focus_detail.gd")
const HUD = preload("res://scenes/farm_hud.gd")
const SettingsStore = preload("res://settings/settings_store.gd")
const GameMenu = preload("res://ui/game_menu.gd")
const CameraTuning = preload("res://ui/camera_tuning.gd")
const CourtyardPlan = preload("res://layout/courtyard_plan.gd")
var courtyard_plan := CourtyardPlan.new()

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
var focus_detail: FocusDetail
var store: FarmStore
var hud: HUD
var settings_store: SettingsStore
var game_menu: GameMenu
var settings_values: Dictionary = {}
var _settings_dirty: bool = false
var _settings_issue: String = ""
var _allow_leave_settings: bool = false
var selected_field: int = -1
var selected_cell: String = ""
var selected_palette: String = ""
var selected_tool: String = ""
var selected_crop: String = "greens"
var hover_field: int = -1
var hover_cell: String = ""
var _pointer_position := Vector2(-100, -100)
var tool_cursor: ToolCursor
var camera_tuning: CameraTuning
var _dragging: bool = false
var _press_position := Vector2.INF
var _press_dragged: bool = false
var _pressed_field: int = -1
var _pressed_cell: String = ""
var _press_context: Dictionary = {}
var _tool_press: Dictionary = {}
var _picks: Array[Dictionary] = []
var _loaded: bool = false
var _save_failed: bool = false
var _record_session: String = ""
var _exiting: bool = false


func _enter_tree() -> void:
	# Children build their geometry in _ready; share one plan before that happens.
	$Environment.plan = courtyard_plan
	$Farm.plan = courtyard_plan

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_window().min_size = Vector2i(960, 600)
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
			settings_store = SettingsStore.new(_record_session.path_join("preferences"))
	if store == null:
		store = FarmStore.new()
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.tool_press_started.connect(_start_tool_press)
	hud.tool_requested.connect(_finish_tool_press)
	hud.crop_requested.connect(_select_crop)
	hud.cancel_tool_requested.connect(_cancel_tool)
	hud.palette_requested.connect(_open_palette)
	tool_cursor = ToolCursor.new()
	add_child(tool_cursor)
	hud.overview_requested.connect(_return_overview)
	hud.reset_requested.connect(_reset_view)
	hud.retry_requested.connect(_retry_storage)
	hud.recovery_requested.connect(_recover_storage)
	hud.exit_requested.connect(_finish_exit)
	hud.decoration_requested.connect(_begin_decoration)
	hud.settings_requested.connect(_open_menu)
	hud.free_view_requested.connect(_toggle_free_view)
	if OS.is_debug_build():
		camera_tuning = CameraTuning.new()
		camera_tuning.camera = camera
		hud.get_node("Layout").add_child(camera_tuning)
		hud.camera_tuning_requested.connect(_toggle_camera_tuning)
		camera_tuning.visibility_changed.connect(_refresh_hud)
		camera_tuning.depth_of_field_changed.connect(func(enabled: bool, strength: float) -> void:
			settings_values.dof_enabled = enabled
			focus_detail.set_depth_of_field(enabled, strength))
		camera_tuning.fog_strength_changed.connect(func(strength: float) -> void:
			focus_detail.set_fog_strength(strength))
	camera.motion_finished.connect(_refresh_hud)
	_load_game()
	# The courtyard owns all slot transforms and art; no duplicate fallback layout.
	var courtyard: Node3D = $Environment
	decoration_layout = DecorationLayout.new()
	decoration_layout.name = "Decorations"
	add_child(decoration_layout)
	decoration_layout.configure(courtyard, camera, decoration_state if _loaded else DecorationState.new())
	decoration_layout.mode_changed.connect(_on_decoration_mode_changed)
	decoration_layout.confirmed.connect(_save_farm)
	farm_audio = FarmAudio.new()
	farm_audio.name = "FarmAudio"
	add_child(farm_audio)
	atmosphere = DayNight.new()
	atmosphere.name = "DayNight"
	add_child(atmosphere)
	atmosphere.configure($DirectionalLight3D, $WorldEnvironment, courtyard.get_water_surface())
	hud.preview_hour_requested.connect(func(hour: float) -> void: atmosphere.set_preview_hour(hour))
	hud.time_preview_opened.connect(func() -> void:
		_cancel_input()
		camera.cancel_free_gesture()
		decoration_layout.cancel_pointer_gesture())
	atmosphere.set_backdrop_material(courtyard.get_backdrop_material())
	atmosphere.window_warmth_changed.connect(courtyard.set_window_warmth)
	courtyard.set_window_warmth(atmosphere.get_window_warmth())
	atmosphere.night_weight_changed.connect(farm_audio.set_night_weight)
	farm_audio.set_night_weight(atmosphere.get_night_weight())
	window_activity = WindowActivity.new()
	window_activity.name = "WindowActivity"
	window_activity.foreground_changed.connect(farm_audio.set_foreground)
	add_child(window_activity)
	farm_audio.set_foreground(window_activity.is_foreground())
	decoration_layout.confirmed.connect(_refresh_lanterns)
	_refresh_lanterns()
	focus_detail = FocusDetail.new()
	focus_detail.name = "FocusDetail"
	add_child(focus_detail)
	focus_detail.configure(camera, farm.fields, courtyard, decoration_layout)
	_setup_settings()
	if OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview"):
		_report_preview_ready.call_deferred()
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
		if game_menu != null:
			game_menu.dismiss()
		if decoration_layout != null:
			decoration_layout.finish_mode()
		_cancel_input()
		selected_tool = ""
		selected_palette = ""
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
	if _exiting:
		return
	_cancel_input()
	if not _loaded:
		_finish_exit()
		return
	if game_menu != null:
		if (_settings_dirty or not _settings_issue.is_empty()) and not _allow_leave_settings:
			_open_menu()
			if not _save_settings():
				return
		game_menu.dismiss()
	if decoration_layout != null:
		decoration_layout.finish_mode()
	settle_farm()
	if _save_farm():
		_finish_exit()


func _finish_exit() -> void:
	if _exiting:
		return
	_exiting = true
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	# Admission is final: saving succeeded, or the player explicitly chose to
	# leave without saving. No UI, timers, focus events or repeated close may write
	# state or restart audio during the short mixer drain.
	get_viewport().gui_disable_input = true
	process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(farm_audio):
		farm_audio.shutdown()
	await get_tree().create_timer(0.1, true, false, true).timeout
	await get_tree().process_frame
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
	var cell: Dictionary = {} if hover_field < 0 or hover_cell.is_empty() else farm_state.get_cell(farm.field_id(hover_field), hover_cell)
	hud.show_state(cell, farm_state.snapshot().harvested, selected_tool, selected_crop, camera.is_transitioning() or _save_failed or camera.free_view or (camera_tuning != null and camera_tuning.visible), selected_field, selected_palette)
	hud.show_decoration_mode(decoration_layout != null and decoration_layout.active)


func _begin_decoration() -> void:
	if not _loaded or _save_failed or decoration_layout == null:
		return
	if decoration_layout.active:
		decoration_layout.finish_mode()
		return
	_return_overview()
	decoration_layout.begin_mode()
	farm_audio.play_ui()


func _on_decoration_mode_changed(active: bool) -> void:
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	selected_field = -1
	selected_cell = ""
	farm.select_field(-1)
	farm.select_cell(-1, "")
	if focus_detail != null:
		focus_detail.set_focus()
	camera.set_decoration_framing(active)
	_refresh_hud()


func _refresh_lanterns() -> void:
	if atmosphere != null and decoration_layout != null:
		atmosphere.set_lantern_anchors(decoration_layout.lantern_anchors())


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer_position = event.position
	if not _loaded or _save_failed:
		return
	if camera_tuning != null and camera_tuning.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			camera_tuning.hide()
			get_viewport().set_input_as_handled()
		return
	if game_menu != null and game_menu.visible:
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			if decoration_layout.active and not decoration_layout.selected_item.is_empty():
				decoration_layout.cancel_preview()
			else:
				_request_menu_close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and OS.is_debug_build():
		_toggle_free_view()
		get_viewport().set_input_as_handled()
		return
	if camera.free_view:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_return_overview()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and (not event.pressed or event.canceled):
			camera.end_free_drag(event.button_index)
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
	if selected_tool == "sow" and event is InputEventMouseButton and event.pressed and not event.canceled and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not hud.is_time_preview_open():
		var ids: Array[String] = Crops.crop_ids()
		_select_crop(ids[posmod(ids.find(selected_crop) + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), ids.size())])
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
			if event.canceled:
				_cancel_input()
			elif hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				_cancel_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if camera_tuning != null and camera_tuning.visible:
		return
	if not _loaded or _save_failed or (game_menu != null and game_menu.visible):
		return
	if camera.free_view:
		camera.free_input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and not event.canceled and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_cancel_input()
		if decoration_layout != null:
			decoration_layout.cancel_pointer_gesture()
		camera.zoom((-0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8) * event.factor)
		get_viewport().set_input_as_handled()
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
					_tool_press = {}
					_press_position = event.position
					_press_dragged = _dragging
					_picks.append({"down": true, "position": event.position, "dragged": _dragging,
						"action_allowed": not camera.is_transitioning(), "selection": selected_field})
				elif _press_position != Vector2.INF:
					_picks.append({"down": false, "position": event.position, "dragged": _press_dragged,
						"action_allowed": not camera.is_transitioning()})
					_press_position = Vector2.INF
			MOUSE_BUTTON_MIDDLE:
				_cancel_input()
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		camera.drag(event.relative, event.shift_pressed)


func _physics_process(_delta: float) -> void:
	_update_hover()
	if camera.free_view or (game_menu != null and game_menu.visible):
		_cancel_input()
		return
	# Space queries belong to the physics boundary. Each gesture carries its admission
	# state so a click made in flight can never become an action after the tween ends.
	var picks: Array[Dictionary] = _picks
	_picks = []
	for pick: Dictionary in picks:
		var hit: Dictionary = _farm_hit(pick.position)
		var index: int = hit.get("field", -1)
		var cell_id: String = hit.get("cell", "")
		if pick.down:
			_pressed_field = index
			_pressed_cell = cell_id
			_press_context = pick
		else:
			if not pick.dragged and index >= 0 and index == _pressed_field and cell_id == _pressed_cell:
				if pick.action_allowed and _press_context.get("action_allowed", false) and not camera.is_transitioning():
					if not selected_tool.is_empty() and not cell_id.is_empty():
						selected_field = index
						selected_cell = cell_id
						_apply_tool()
					elif index != selected_field or not camera.focused:
						_focus_field(index)
					else:
						_select_cell(cell_id)
			_pressed_field = -1
			_pressed_cell = ""
			_press_context = {}


func _notification(what: int) -> void:
	if _exiting:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_request_exit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_pointer_position = Vector2(-100, -100)
		_cancel_input()
		if is_instance_valid(camera):
			camera.cancel_free_gesture()
			camera.cancel_zoom()
		selected_tool = ""
		selected_palette = ""
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
	return int(_farm_hit(screen_point).get("field", -1))


func _cell_at(screen_point: Vector2, field_index: int) -> String:
	var hit: Dictionary = _farm_hit(screen_point)
	return str(hit.get("cell", "")) if hit.get("field", -1) == field_index else ""


func _farm_hit(screen_point: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen_point)
	var end := origin + camera.project_ray_normal(screen_point) * 120.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var index: int = int(hit.collider.get_meta("field_index", -1))
	if index < 0:
		return {}
	# Only the actual top soil plane can select a cell; bed sides still focus its field.
	var cell_id: String = farm.cell_at(index, hit.position) if hit.normal.y > 0.9 else ""
	return {"field": index, "cell": cell_id}


func _focus_field(index: int) -> void:
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	selected_field = index
	selected_cell = ""
	farm.select_field(index)
	farm.select_cell(-1, "")
	focus_detail.set_focus(farm.fields[index])
	camera.focus_field(farm.fields[index].global_position)
	_refresh_hud()


func _select_cell(cell_id: String) -> void:
	if selected_field < 0 or (not cell_id.is_empty() and not FarmState.CELL_IDS.has(cell_id)):
		return
	_cancel_input()
	selected_cell = cell_id
	farm.select_cell(selected_field, cell_id)
	_refresh_hud()


func _tools_available() -> bool:
	return _loaded and not _save_failed and not _exiting and not (camera_tuning != null and camera_tuning.visible) and not camera.free_view and not camera.is_transitioning() and not (game_menu != null and game_menu.visible) and not (decoration_layout != null and decoration_layout.active)


func _start_tool_press(tool: String) -> void:
	var dragging: bool = _dragging
	_cancel_input()
	if not dragging and _tools_available():
		_tool_press = {"tool": tool}


func _finish_tool_press(tool: String) -> void:
	var admitted: bool = _tool_press.get("tool", "") == tool
	_tool_press = {}
	if admitted:
		_select_tool(tool)


func _can_work_cell() -> bool:
	return _tools_available() and selected_field >= 0 and not selected_cell.is_empty()


func _open_palette(palette: String) -> void:
	if not _tools_available() or palette not in ["sow", "tools"]:
		return
	_cancel_input()
	selected_tool = ""
	selected_palette = "" if selected_palette == palette else palette
	farm_audio.play_ui()
	_refresh_hud()


func _select_tool(tool: String) -> void:
	_cancel_input()
	if not _tools_available() or tool not in ["sow", "water", "harvest"]:
		return
	selected_tool = "" if selected_tool == tool else tool
	selected_palette = "sow" if tool == "sow" else "tools"
	_refresh_hud()


func _select_crop(crop_id: String) -> void:
	if not _tools_available() or not Crops.crop_ids().has(crop_id):
		return
	_cancel_input()
	camera.cancel_zoom()
	selected_crop = crop_id
	selected_tool = "sow"
	selected_palette = "sow"
	farm_audio.play_ui()
	_refresh_hud()


func _cancel_tool() -> void:
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	_refresh_hud()


func _update_hover() -> void:
	if tool_cursor == null:
		return
	var ui: Control = get_viewport().gui_get_hovered_control()
	var blocked: bool = not _tools_available() or _dragging or (ui != null and ui.mouse_filter != Control.MOUSE_FILTER_IGNORE) or not get_viewport().get_visible_rect().has_point(_pointer_position)
	var hit: Dictionary = {} if blocked else _farm_hit(_pointer_position)
	var index: int = hit.get("field", -1)
	var cell_id: String = hit.get("cell", "")
	if index != hover_field or cell_id != hover_cell:
		hover_field = index
		hover_cell = cell_id
		farm.select_cell(index, cell_id)
		_refresh_hud()
	tool_cursor.show_tool("" if blocked else selected_tool, selected_crop)


func _apply_tool() -> void:
	if not _can_work_cell() or selected_tool.is_empty():
		return
	var field_id: String = farm.field_id(selected_field)
	var now: float = clock.call()
	var result: Dictionary
	match selected_tool:
		"sow": result = farm_state.sow(field_id, selected_cell, selected_crop, now)
		"water": result = farm_state.water(field_id, selected_cell, now)
		"harvest": result = farm_state.harvest(field_id, selected_cell, now)
		_: return
	farm_audio.play_action(selected_tool, result)
	if result.ok:
		decoration_state.unlock(farm_state.snapshot().harvested)
		refresh_farm()
		farm_changed.emit(result)
		_save_farm()


func _cancel_or_return() -> void:
	_cancel_input()
	if not selected_tool.is_empty() or not selected_palette.is_empty():
		_cancel_tool()
	elif not selected_cell.is_empty():
		_select_cell("")
	else:
		_return_overview()


func _return_overview() -> void:
	if camera_tuning != null:
		camera_tuning.hide()
	if camera.free_view:
		camera.set_free_view(false)
		hud.show_free_view(false)
	if decoration_layout != null and decoration_layout.active:
		decoration_layout.finish_mode()
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	selected_field = -1
	selected_cell = ""
	farm.select_field(-1)
	farm.select_cell(-1, "")
	focus_detail.set_focus()
	camera.return_overview()
	_refresh_hud()


func _reset_view() -> void:
	_return_overview()
	camera.reset_view()
	_refresh_hud()


func _toggle_free_view() -> void:
	if not OS.is_debug_build() or not _loaded or _save_failed or (game_menu != null and game_menu.visible):
		return
	var enabled: bool = not camera.free_view
	_return_overview()
	if enabled:
		camera.set_free_view(true)
		hud.show_free_view(true)


func _toggle_camera_tuning() -> void:
	if camera_tuning == null or not _loaded or _save_failed or (game_menu != null and game_menu.visible):
		return
	if camera_tuning.visible:
		camera_tuning.hide()
		return
	_return_overview()
	hud.hide_time_preview()
	camera_tuning.present(focus_detail.get_settings())


func _cancel_input(cancel_tool_press: bool = true) -> void:
	if cancel_tool_press:
		_tool_press = {}
	_dragging = false
	_press_position = Vector2.INF
	_press_dragged = true
	_pressed_field = -1
	_pressed_cell = ""
	_press_context = {}
	_picks.clear()


func _setup_settings() -> void:
	if settings_store == null:
		settings_store = SettingsStore.new()
	var loaded: Dictionary = settings_store.load_settings()
	settings_values = loaded.settings
	if OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview"):
		# Development startup overrides the old window preference for this session.
		settings_values.fullscreen = true
	if not loaded.ok:
		_settings_issue = {
			"corrupt": "设置文件无法读取，已使用默认设置；原件保留。保存设置时会先留存原件。",
			"unsupported": "设置来自较新版本，本次使用默认设置；原件保留，暂时不能覆盖。",
		}.get(loaded.kind, "设置暂时无法读取，本次使用默认设置；农场进度不受影响。")
	game_menu = GameMenu.new()
	game_menu.name = "GameMenu"
	add_child(game_menu)
	game_menu.settings_changed.connect(_change_settings)
	game_menu.save_requested.connect(_save_settings)
	game_menu.close_requested.connect(_request_menu_close)
	game_menu.quit_requested.connect(_request_exit)
	_apply_settings()
	hud.show_settings_issue(not _settings_issue.is_empty())


func _apply_settings() -> void:
	farm_audio.set_volumes(settings_values.master, settings_values.music, settings_values.effects)
	focus_detail.set_quality(settings_values.quality)
	focus_detail.set_depth_of_field(settings_values.dof_enabled, focus_detail.get_settings().dof_strength)
	# Headless validation has no OS window; preference validation remains identical.
	if DisplayServer.get_name() != "headless":
		var window: Window = get_window()
		var desired: Window.Mode = Window.MODE_FULLSCREEN if settings_values.fullscreen else Window.MODE_WINDOWED
		if settings_values.fullscreen and OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview"):
			desired = Window.MODE_EXCLUSIVE_FULLSCREEN
		if window.mode != desired:
			_cancel_input()
			window.mode = desired
			if not settings_values.fullscreen:
				window.borderless = false


func _open_menu() -> void:
	if game_menu == null or not _loaded or _save_failed:
		return
	_cancel_input()
	if camera_tuning != null:
		camera_tuning.hide()
	hud.hide_time_preview()
	camera.free_input_enabled = false
	camera.cancel_free_gesture()
	camera.cancel_zoom()
	decoration_layout.cancel_pointer_gesture()
	selected_tool = ""
	selected_palette = ""
	_allow_leave_settings = false
	_refresh_hud()
	game_menu.present(settings_values, _settings_issue)
	farm_audio.play_ui()


func _change_settings(value: Dictionary) -> void:
	if not SettingsStore.valid_settings(value):
		return
	settings_values = value.duplicate(true)
	_settings_dirty = true
	_allow_leave_settings = false
	_apply_settings()
	hud.show_settings_issue(true)


func _save_settings() -> bool:
	var result: Dictionary = settings_store.save(settings_values)
	if result.ok:
		_settings_dirty = false
		_settings_issue = ""
		_allow_leave_settings = false
		game_menu.set_status("设置已保存。")
	else:
		_settings_issue = "设置未能保存，本次调整仍然有效。可重试保存；农场进度不受影响。"
		if result.kind in ["unsupported", "unsupported_pending"]:
			_settings_issue = "设置来自较新版本，未能保存；原件保留，本次调整只在当前窗口有效。"
		_allow_leave_settings = true
		game_menu.set_status(_settings_issue, true)
	hud.show_settings_issue(not result.ok)
	return result.ok


func _request_menu_close() -> void:
	_cancel_input()
	decoration_layout.cancel_pointer_gesture()
	if (_settings_dirty or not _settings_issue.is_empty()) and not _allow_leave_settings:
		if not _save_settings():
			return
	game_menu.dismiss()
	_allow_leave_settings = false
	camera.free_input_enabled = true
	_refresh_hud()
	hud.get_node("Layout/ViewControls/Settings").grab_focus()


func _report_preview_ready() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("DEV_PREVIEW_READY screen=%d mode=%d size=%s" % [DisplayServer.window_get_current_screen(), get_window().mode, DisplayServer.window_get_size()])
