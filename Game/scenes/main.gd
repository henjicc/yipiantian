extends Node3D

@onready var farm: FarmLayout = $Farm
@onready var camera: FarmCamera = $Camera3D
var selected_field: int = -1
var _status: Label
var _dragging: bool = false
var _press_position := Vector2.INF
var _press_dragged: bool = false
var _pressed_field: int = -1
var _picks: Array[Dictionary] = []


func _ready() -> void:
	_build_hud()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _press_position != Vector2.INF:
		_press_dragged = _press_dragged or event.position.distance_to(_press_position) > 7.0
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = false
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var hovered := get_viewport().gui_get_hovered_control()
			if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				_cancel_input()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_press_position = event.position
					_press_dragged = false
					_picks.append({"down": true, "position": event.position, "dragged": false})
				else:
					_picks.append({"down": false, "position": event.position, "dragged": _press_dragged})
					_press_position = Vector2.INF
			MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
				_press_dragged = true
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					camera.zoom(-0.8)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					camera.zoom(0.8)
	elif event is InputEventMouseMotion and _dragging:
		camera.drag(event.relative, event.shift_pressed)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_return_overview()


func _physics_process(_delta: float) -> void:
	# Space queries run at the physics boundary; UI-consumed clicks never enter this queue.
	for pick in _picks:
		var index: int = _field_at(pick.position)
		if pick.down:
			_pressed_field = index
		else:
			if not pick.dragged and index >= 0 and index == _pressed_field:
				_focus_field(index)
			_pressed_field = -1
	_picks.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		_cancel_input()


func _field_at(screen_point: Vector2) -> int:
	var origin := camera.project_ray_origin(screen_point)
	var end := origin + camera.project_ray_normal(screen_point) * 120.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1
	return int(hit.collider.get_meta("field_index", -1))


func _focus_field(index: int) -> void:
	selected_field = index
	farm.select_field(index)
	camera.focus_field(farm.fields[index].global_position)
	_status.text = "第 %d 块田" % (index + 1)


func _return_overview() -> void:
	_cancel_input()
	selected_field = -1
	farm.select_field(-1)
	camera.return_overview()
	_status.text = "全景"


func _reset_view() -> void:
	_return_overview()
	camera.reset_view()


func _cancel_input() -> void:
	_dragging = false
	_press_position = Vector2.INF
	_press_dragged = true
	_pressed_field = -1
	_picks.clear()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	root.theme = theme
	var title := Label.new()
	title.text = "我有一片田"
	title.position = Vector2(30, 22)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("465650"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	_status = Label.new()
	_status.text = "全景"
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.position = Vector2(-180, 30)
	_status.size = Vector2(150, 30)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.add_theme_color_override("font_color", Color("465650"))
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status)
	var bar := HBoxContainer.new()
	bar.name = "ViewControls"
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -148
	bar.offset_right = 148
	bar.offset_top = -76
	bar.offset_bottom = -26
	bar.add_theme_constant_override("separation", 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in [["全景", _return_overview], ["视角复位", _reset_view]]:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(142, 48)
		button.pressed.connect(item[1])
		button.add_theme_color_override("font_color", Color("4c5d50"))
		button.add_theme_color_override("font_hover_color", Color("354c3d"))
		for state in ["normal", "hover", "pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("f0e8d4") if state == "normal" else Color("e0dcc1")
			style.set_corner_radius_all(18)
			style.border_color = Color("9d9b7c")
			style.set_border_width_all(1 if state != "focus" else 2)
			button.add_theme_stylebox_override(state, style)
		bar.add_child(button)
