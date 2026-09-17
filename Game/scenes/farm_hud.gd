extends CanvasLayer
## UI owns presentation and emits intent; it never changes farm state.

signal cancel_tool_requested
signal tool_requested(tool: String)
signal tool_press_started(tool: String)
signal crop_requested(crop_id: String)
signal overview_requested
signal reset_requested
signal retry_requested
signal recovery_requested
signal exit_requested
signal decoration_requested
signal settings_requested
signal free_view_requested
signal preview_hour_requested(hour: float)
signal time_preview_opened

const Crops = preload("res://farm/crop_catalog.gd")
const FarmTheme = preload("res://ui/farm_theme.gd")
const INK := FarmTheme.INK
const SUN = preload("res://art/ui/sun.svg")
const MOON = preload("res://art/ui/moon.svg")
var _status: Label
var _harvested: Label
var _harvest_detail: Label
var _clock: Label
var _day_icon: TextureRect
var _settings: Button
var _feedback: Label
var _tool_status: Label
var _tools: HBoxContainer
var _crop_row: HBoxContainer
var _crop_buttons: Dictionary = {}
var _buttons: Dictionary = {}
var _session: Label
var _storage_overlay: ColorRect
var _storage_message: Label
var _retry: Button
var _recover: Button
var _exit: Button
var _view_controls: HBoxContainer
var _free_view: Button
var _time_panel: PanelContainer
var _time_slider: HSlider
var _preview_minutes: int = -1


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = FarmTheme.create()
	var left_plate := _status_plate(root)
	left_plate.position = Vector2(18, 18)
	left_plate.size = Vector2(300, 74)
	var basket := TextureRect.new()
	basket.texture = preload("res://art/ui/basket.svg")
	basket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	basket.position = Vector2(28, 29)
	basket.size = Vector2(50, 50)
	root.add_child(basket)
	var right_plate := _status_plate(root)
	right_plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right_plate.offset_left = -182
	right_plate.offset_right = -18
	right_plate.offset_top = 18
	right_plate.offset_bottom = 76
	_day_icon = TextureRect.new()
	_day_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_day_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_day_icon)
	_day_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_day_icon.offset_left = -169
	_day_icon.offset_right = -133
	_day_icon.offset_top = 29
	_day_icon.offset_bottom = 65
	_clock = _label(root, "", 26)
	_clock.name = "LocalClock"
	_clock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_clock.offset_left = -120
	_clock.offset_right = -30
	_clock.offset_top = 26
	_clock.offset_bottom = 65
	if OS.is_debug_build():
		_clock.mouse_filter = Control.MOUSE_FILTER_STOP
		_clock.gui_input.connect(_clock_input)
	_status = _label(root, "全景", 19)
	_status.name = "FieldStatus"
	_tag(_status, -210, -174)
	_session = _label(root, "正在读取存档", 14)
	_session.name = "SessionStatus"
	_session.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_session.offset_left = 20
	_session.offset_right = 130
	_session.offset_top = -42
	_session.offset_bottom = -15
	_session.add_theme_stylebox_override("normal", FarmTheme.paper(FarmTheme.PAPER, 10))
	_harvested = _label(root, "", 24)
	_harvested.name = "Harvested"
	_harvested.position = Vector2(91, 24)
	_harvest_detail = _label(root, "", 16)
	_harvest_detail.position = Vector2(91, 58)
	_feedback = _label(root, "", 19)
	_feedback.name = "Feedback"
	_tag(_feedback, -260, -220)
	_feedback.hide()
	_tool_status = _label(root, "", 17)
	_tool_status.name = "ToolStatus"
	_tag(_tool_status, -300, -270)
	_tool_status.hide()
	_tools = HBoxContainer.new()
	_tools.name = "FarmControls"
	root.add_child(_tools)
	_tools.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tools.offset_left = -320
	_tools.offset_right = 320
	_tools.offset_top = -160
	_tools.offset_bottom = -110
	_tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_tools.add_theme_constant_override("separation", 10)
	_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: Array in [["sow", "播种"], ["water", "浇水"], ["harvest", "收获"]]:
		var button := _button(_tools, item[1], 144)
		button.name = item[0].capitalize()
		button.icon = load("res://art/ui/%s.svg" % item[0])
		button.toggle_mode = true
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.button_down.connect(func() -> void: tool_press_started.emit(item[0]))
		button.pressed.connect(func() -> void: tool_requested.emit(item[0]))
		_buttons[item[0]] = button
	var cancel := _button(_tools, "取消", 88)
	cancel.name = "CancelTool"
	cancel.pressed.connect(func() -> void: cancel_tool_requested.emit())
	_crop_row = HBoxContainer.new()
	_crop_row.name = "CropChoices"
	root.add_child(_crop_row)
	_crop_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_crop_row.offset_left = -435
	_crop_row.offset_right = 435
	_crop_row.offset_top = -99
	_crop_row.offset_bottom = -15
	_crop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_crop_row.add_theme_constant_override("separation", 6)
	_crop_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for crop_id: String in Crops.crop_ids():
		var card := Button.new()
		card.name = crop_id
		card.custom_minimum_size = Vector2(66, 84)
		card.toggle_mode = true
		card.pressed.connect(func() -> void: crop_requested.emit(crop_id))
		_crop_row.add_child(card)
		var picture := TextureRect.new()
		picture.texture = load(Crops.icon_path(crop_id))
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.position = Vector2(7, 3)
		picture.size = Vector2(52, 54)
		card.add_child(picture)
		var caption := _label(card, Crops.definition(crop_id).name, 16)
		caption.position = Vector2(0, 57)
		caption.size = Vector2(66, 22)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_crop_buttons[crop_id] = card
	var bar := HBoxContainer.new()
	_view_controls = bar
	bar.name = "ViewControls"
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bar.offset_left = -410
	bar.offset_right = -18
	bar.offset_top = 88
	bar.offset_bottom = 130
	bar.add_theme_constant_override("separation", 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button(bar, "全景", 84).pressed.connect(func() -> void: overview_requested.emit())
	_button(bar, "复位", 84).pressed.connect(func() -> void: reset_requested.emit())
	var decorate := _button(bar, "布置", 84)
	decorate.name = "Decorate"
	decorate.pressed.connect(func() -> void: decoration_requested.emit())
	_settings = _button(bar, "设置", 100)
	_settings.name = "Settings"
	_settings.pressed.connect(func() -> void: settings_requested.emit())
	if OS.is_debug_build():
		_free_view = _button(root, "自由视角", 160)
		_free_view.name = "DebugFreeCamera"
		_free_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_free_view.offset_left = -178
		_free_view.offset_right = -18
		_free_view.offset_top = 140
		_free_view.offset_bottom = 182
		_free_view.pressed.connect(func() -> void: free_view_requested.emit())
		_build_time_preview(root)
	_build_storage_overlay(root)
	_update_clock()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_clock)
	add_child(timer)
	timer.start()


func _build_time_preview(root: Control) -> void:
	_time_panel = PanelContainer.new()
	_time_panel.name = "DebugTimePreview"
	root.add_child(_time_panel)
	_time_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_time_panel.offset_left = -350
	_time_panel.offset_right = -18
	_time_panel.offset_top = 196
	var box := VBoxContainer.new()
	_time_panel.add_child(box)
	_time_slider = HSlider.new()
	_time_slider.name = "TimeSlider"
	_time_slider.max_value = 1439
	_time_slider.step = 1
	_time_slider.custom_minimum_size = Vector2(296, 38)
	box.add_child(_time_slider)
	_time_slider.value_changed.connect(func(value: float) -> void:
		_preview_minutes = int(value)
		_update_clock()
		preview_hour_requested.emit(value / 60.0))
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var live := _button(actions, "恢复实时", 160)
	live.name = "LiveTime"
	live.pressed.connect(func() -> void:
		_preview_minutes = -1
		_update_clock()
		_sync_time_slider()
		preview_hour_requested.emit(-1.0))
	_button(actions, "收起", 110).pressed.connect(hide_time_preview)
	_time_panel.hide()


func _clock_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_clock.accept_event()
		if _time_panel.visible:
			hide_time_preview()
		else:
			_sync_time_slider()
			_time_panel.show()
			time_preview_opened.emit()


func _sync_time_slider() -> void:
	var local := Time.get_datetime_dict_from_system(false)
	_time_slider.set_value_no_signal(_preview_minutes if _preview_minutes >= 0 else int(local.hour) * 60 + int(local.minute))


func hide_time_preview() -> void:
	if _time_panel != null:
		_time_panel.hide()
		_time_slider.release_focus()


func _build_storage_overlay(root: Control) -> void:
	_storage_overlay = ColorRect.new()
	_storage_overlay.name = "StorageOverlay"
	_storage_overlay.color = Color(0.18, 0.23, 0.20, 0.78)
	root.add_child(_storage_overlay)
	_storage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	_storage_overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -135
	panel.offset_bottom = 135
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0e8d4")
	style.set_corner_radius_all(18)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_theme_constant_override("separation", 16)
	_storage_message = _label(box, "", 20)
	_storage_message.name = "Message"
	_storage_message.custom_minimum_size = Vector2(500, 70)
	_storage_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_retry = _button(box, "重试读取", 180)
	_retry.name = "Retry"
	_retry.pressed.connect(func() -> void: retry_requested.emit())
	_recover = _button(box, "从备份恢复", 180)
	_recover.name = "Recover"
	_recover.pressed.connect(func() -> void: recovery_requested.emit())
	_exit = _button(box, "退出", 180)
	_exit.name = "Exit"
	_exit.pressed.connect(func() -> void: exit_requested.emit())
	_storage_overlay.hide()


func show_free_view(active: bool) -> void:
	if _free_view != null:
		_free_view.text = "退出自由视角" if active else "自由视角"


func _status_plate(parent: Control) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = FarmTheme.paper()
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func show_storage_issue(kind: String, unsaved: bool) -> void:
	_session.text = "尚未保存" if unsaved else "存档未能读取"
	_storage_message.text = "保存未完成，最新进度仍在本次窗口中。请重试保存。" if unsaved else {
		"recovery_available": "存档未能读取，可恢复上一份备份。最近的改动可能丢失，原文件会保留。",
		"unsupported": "这份存档来自其他版本。请使用对应版本打开，原文件已保留。",
		"corrupt": "存档与备份都无法读取。原文件已保留，修复文件后可重试。"
	}.get(kind, "暂时无法读取存档。请检查存档文件夹后重试，原文件已保留。")
	_retry.text = "重试保存" if unsaved else "重试读取"
	_recover.visible = not unsaved and kind == "recovery_available"
	_exit.text = "仍然退出（最新进度未保存）" if unsaved else "退出"
	_storage_overlay.show()
	var choices: Array[Control] = [_retry]
	if _recover.visible:
		choices.append(_recover)
	choices.append(_exit)
	for index: int in choices.size():
		var control: Control = choices[index]
		var previous: NodePath = control.get_path_to(choices[posmod(index - 1, choices.size())])
		var following: NodePath = control.get_path_to(choices[(index + 1) % choices.size()])
		control.focus_previous = previous
		control.focus_next = following
		control.focus_neighbor_top = previous
		control.focus_neighbor_left = previous
		control.focus_neighbor_bottom = following
		control.focus_neighbor_right = following
	_retry.grab_focus()


func show_saved() -> void:
	_session.text = "已保存"
	_storage_overlay.hide()


func show_decoration_mode(active: bool) -> void:
	_view_controls.get_child(0).disabled = active
	_view_controls.get_child(1).disabled = active
	_view_controls.get_node("Decorate").text = "完成" if active else "布置"
	_tools.visible = not active
	_crop_row.visible = not active
	_status.visible = not active
	_feedback.visible = not active and not _feedback.text.is_empty()
	_tool_status.visible = not active and not _tool_status.text.is_empty()


func show_state(cell: Dictionary, harvested: Dictionary, _tool: String, crop_id: String, traveling: bool, field_index: int = -1) -> void:
	_harvested.text = "%d 篮" % Crops.total_harvested(harvested)
	_harvest_detail.text = "%s %d" % [Crops.definition(crop_id).name, harvested.get(crop_id, 0)]
	_tools.visible = true
	_crop_row.visible = true
	for id: String in _crop_buttons:
		var card: Button = _crop_buttons[id]
		card.disabled = traveling
		card.set_pressed_no_signal(_tool == "sow" and id == crop_id)
	for tool_id: String in _buttons:
		var button: Button = _buttons[tool_id]
		button.disabled = traveling
		button.set_pressed_no_signal(tool_id == _tool)
	_tools.get_node("CancelTool").disabled = _tool.is_empty()
	var chosen: Dictionary = Crops.definition(crop_id)
	_tool_status.text = "%s · %d 分钟 · 浇水节省 %d%%" % [chosen.name, chosen.duration_seconds / 60, roundi(chosen.water_progress * 100)] if _tool == "sow" else {"water": "浇水", "harvest": "收获"}.get(_tool, "")
	if cell.is_empty():
		_status.text = "全景" if field_index < 0 else "第 %d 块田 · 未选格" % (field_index + 1)
		_fit_tag(_status)
		_fit_tag(_tool_status)
		return
	var cell_index: int = int(cell.id.trim_prefix("cell_")) - 1
	var title: String = "第 %d 块田 · %d行%d列" % [int(cell.field_id.trim_prefix("field_")), int(cell_index / 4) + 1, cell_index % 4 + 1]
	if cell.stage == "empty":
		_status.text = title + " · 空格"
	else:
		var stage_name: String = {"sprout": "幼芽", "young": "幼株", "mature": "可收获"}[cell.stage]
		_status.text = "%s · %s · %s" % [title, Crops.definition(cell.crop_id).name, stage_name]
		if cell.stage != "mature":
			_status.text += " · 约 %d 分钟" % maxi(1, ceili(cell.remaining_seconds / 60.0))
			if cell.watered:
				_status.text += " · 已浇水"
	if traveling:
		_tool_status.text = "镜头移动中"
	_fit_tag(_status)
	_fit_tag(_tool_status)


func show_result(result: Dictionary, tool: String, crop_id: String) -> void:
	if result.ok:
		match tool:
			"sow": _feedback.text = "已播种%s" % Crops.definition(crop_id).name
			"water": _feedback.text = "已浇水"
			"harvest": _feedback.text = "%s +1 篮" % Crops.definition(result.reward_crop_id).name
	else:
		_feedback.text = {
			"occupied": "这一格已有作物", "empty": "这一格还没有作物", "mature": "作物已成熟，可以收获",
			"already_watered": "这一轮已经浇过水", "not_mature": "作物还在生长", "harvest_limit": "收获记录已满",
			"invalid_time": "系统时间暂不可用", "invalid_field": "没有选中田块", "invalid_cell": "请选择一格", "invalid_crop": "请选择作物"
		}.get(result.reason, "操作未完成")
	_fit_tag(_feedback)


func clear_feedback() -> void:
	_feedback.text = ""
	_feedback.hide()


func show_unlocks(item_ids: Array[String]) -> void:
	const Decorations = preload("res://farm/decoration_catalog.gd")
	for item_id: String in item_ids:
		_feedback.text += " · %s已解锁" % Decorations.ITEMS[item_id].name
	_fit_tag(_feedback)


func _label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 44)
	parent.add_child(button)
	return button


func _tag(label: Label, top: float, bottom: float) -> void:
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_top = top
	label.offset_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", FarmTheme.paper(FarmTheme.PAPER, 12))
	_fit_tag(label)


func _fit_tag(label: Label) -> void:
	var width: float = minf(760, FarmTheme.FONT.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x + 40)
	label.offset_left = -width * 0.5
	label.offset_right = width * 0.5
	label.visible = not label.text.is_empty()


func _update_clock() -> void:
	var local: Dictionary = Time.get_datetime_dict_from_system(false)
	if _preview_minutes >= 0:
		local.hour = _preview_minutes / 60
		local.minute = _preview_minutes % 60
	_clock.text = "%02d:%02d" % [local.hour, local.minute]
	_day_icon.texture = SUN if local.hour >= 6 and local.hour < 18 else MOON


func show_settings_issue(has_issue: bool) -> void:
	_settings.text = "设置 !" if has_issue else "设置"


func is_time_preview_open() -> bool:
	return _time_panel != null and _time_panel.visible
