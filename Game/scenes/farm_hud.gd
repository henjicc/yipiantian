extends CanvasLayer
## UI owns presentation and emits intent; it never changes farm state.

signal palette_requested(palette: String)
signal cancel_tool_requested
signal tool_requested(tool: String)
signal tool_press_started(tool: String)
signal crop_requested(crop_id: String)
signal retry_requested
signal recovery_requested
signal exit_requested
signal settings_requested
signal preview_hour_requested(hour: float)
signal time_preview_opened
signal basket_requested
signal construction_requested

const Crops = preload("res://farm/crop_catalog.gd")
const FarmTheme = preload("res://ui/farm_theme.gd")
const INK := FarmTheme.INK
var _basket: Button
var _settings: Button
var _tools: HBoxContainer
var _tool_row: HBoxContainer
var _palette: String = ""
var _decorating: bool = false
var _row_tweens: Dictionary = {}
var _row_open: Dictionary = {}
var _crop_row: HBoxContainer
var _crop_buttons: Dictionary = {}
var _buttons: Dictionary = {}
var _storage_overlay: ColorRect
var _storage_message: Label
var _retry: Button
var _recover: Button
var _exit: Button
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
	_build_farm_controls(root)
	if OS.is_debug_build() and OS.has_feature("editor"):
		_build_time_preview(root)
	_build_storage_overlay(root)


func _build_farm_controls(root: Control) -> void:
	_tools = HBoxContainer.new()
	_tools.name = "FarmControls"
	root.add_child(_tools)
	_tools.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tools.offset_left = -380
	_tools.offset_right = 380
	_tools.offset_top = -66
	_tools.offset_bottom = -18
	_tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_tools.add_theme_constant_override("separation", 8)
	_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: Array in [["sow", "种植", "Sow"], ["tools", "工具", "Tools"]]:
		var entry := _toolbar_button(item[1], "res://art/ui/toolbar/plant.png" if item[0] == "sow" else "res://art/ui/toolbar/tools.png")
		entry.name = item[2]
		entry.toggle_mode = true
		entry.pressed.connect(func() -> void: palette_requested.emit(item[0]))
	_basket = _toolbar_button("菜篮", "res://art/ui/toolbar/basket.png")
	_basket.name = "OpenBasket"
	_basket.pressed.connect(func() -> void: basket_requested.emit())
	var build := _toolbar_button("建设", "res://art/ui/toolbar/build.png")
	build.name = "BuildIsland"
	build.pressed.connect(func() -> void: construction_requested.emit())
	_settings = _toolbar_button("设置", "res://art/ui/toolbar/settings.png")
	_settings.name = "Settings"
	_settings.pressed.connect(func() -> void: settings_requested.emit())
	var cancel := _toolbar_button("取消", "res://art/ui/toolbar/cancel.png")
	cancel.name = "CancelTool"
	cancel.pressed.connect(func() -> void: cancel_tool_requested.emit())
	cancel.hide()
	_crop_row = _choice_row(root, "CropChoices", Crops.crop_ids().size() * 36.0)
	for crop_id: String in Crops.crop_ids():
		var card := _choice_card(_crop_row, crop_id, Crops.definition(crop_id).name, load(Crops.icon_path(crop_id)))
		card.pressed.connect(func() -> void: crop_requested.emit(crop_id))
		_crop_buttons[crop_id] = card
	_tool_row = _choice_row(root, "ToolChoices", 145)
	for item: Array in [["water", "浇水"], ["harvest", "收获"], ["weed", "除草"], ["till", "开垦"]]:
		var button := _choice_card(_tool_row, item[0].capitalize(), item[1], load("res://art/ui/crops/%s.png" % item[0]))
		button.button_down.connect(func() -> void: tool_press_started.emit(item[0]))
		button.pressed.connect(func() -> void: tool_requested.emit(item[0]))
		_buttons[item[0]] = button


func _choice_card(parent: Control, card_name: String, text: String, texture: Texture2D) -> Button:
	var card := preload("res://ui/item_card.gd").new()
	card.name = card_name
	card.toggle_mode = true
	parent.add_child(card)
	card.configure(text,texture)
	return card


func _choice_row(root: Control, row_name: String, half_width: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	root.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -half_width
	row.offset_right = half_width
	row.offset_top = -164
	row.offset_bottom = -80
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate.a = 0.0
	row.hide()
	_row_open[row] = false
	return row


func _animate_row(row: Control, opened: bool) -> void:
	if _row_open[row] == opened:
		return
	_row_open[row] = opened
	if _row_tweens.has(row):
		_row_tweens[row].kill()
	if opened and not row.visible:
		row.offset_top = -152
		row.offset_bottom = -68
	row.show()
	var tween := create_tween().set_parallel(true)
	_row_tweens[row] = tween
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(row, "modulate:a", 1.0 if opened else 0.0, .18)
	tween.tween_property(row, "offset_top", -164.0 if opened else -152.0, .22)
	tween.tween_property(row, "offset_bottom", -80.0 if opened else -68.0, .22)
	if not opened:
		tween.chain().tween_callback(row.hide)


func _sync_rows() -> void:
	_animate_row(_crop_row, not _decorating and _palette == "sow")
	_animate_row(_tool_row, not _decorating and _palette == "tools")


func _exit_tree() -> void:
	for tween: Tween in _row_tweens.values():
		tween.kill()
	_row_tweens.clear()
	_row_open.clear()


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
		preview_hour_requested.emit(value / 60.0))
	var actions := HBoxContainer.new()
	box.add_child(actions)
	var live := _button(actions, "恢复实时", 160)
	live.name = "LiveTime"
	live.pressed.connect(func() -> void:
		_preview_minutes = -1
		_sync_time_slider()
		preview_hour_requested.emit(-1.0))
	_button(actions, "收起", 110).pressed.connect(hide_time_preview)
	_time_panel.hide()


func _toggle_time_preview() -> void:
	if _time_panel == null: _build_time_preview(get_node("Layout"))
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
	var style := FarmTheme.framed_paper()
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


func show_storage_issue(kind: String, unsaved: bool) -> void:
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
	_storage_overlay.hide()


func show_decoration_mode(active: bool) -> void:
	_decorating = active
	_tools.get_node("Sow").visible = not active
	_tools.get_node("Tools").visible = not active
	_tools.get_node("CancelTool").visible = not active and _tools.get_node("CancelTool").visible
	_sync_rows()


func show_state(_cell: Dictionary, _harvested: Dictionary, tool: String, crop_id: String, traveling: bool, _field_index: int = -1, palette: String = "", _inventory: Dictionary = {}) -> void:
	_palette = palette
	for id: String in _crop_buttons:
		var card: Button = _crop_buttons[id]
		card.disabled = traveling or palette != "sow"
		card.set_pressed_no_signal(tool == "sow" and id == crop_id)
	for tool_id: String in _buttons:
		var button: Button = _buttons[tool_id]
		button.disabled = traveling or palette != "tools"
		button.set_pressed_no_signal(tool_id == tool)
	for entry: String in ["Sow", "Tools"]:
		var button: Button = _tools.get_node(entry)
		button.disabled = traveling
		button.set_pressed_no_signal(palette == ("sow" if entry == "Sow" else "tools"))
	_tools.get_node("CancelTool").visible = not _decorating and not tool.is_empty()
	_sync_rows()


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
	FarmTheme.pointer_focus(button)
	parent.add_child(button)
	return button


func show_settings_issue(has_issue: bool) -> void:
	_settings.text = "设置 !" if has_issue else "设置"


func is_time_preview_open() -> bool:
	return _time_panel != null and _time_panel.visible

func _toolbar_button(caption: String, icon_path: String) -> Button:
	var button := _button(_tools, caption, 104)
	button.icon = load(icon_path)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", 28)
	button.add_theme_constant_override("h_separation", 6)
	_fit_toolbar_button(button)
	return button


func _fit_toolbar_button(button: Button) -> void:
	var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
	# Expanded icons do not contribute to Button minimum width; reserve their slot.
	button.custom_minimum_size.x = maxf(112.0, text_width + 70.0)


func set_workarea(area: Vector4) -> void:
	var root: Control = $Layout
	root.anchor_left = area.x
	root.anchor_top = area.y
	root.anchor_right = area.z
	root.anchor_bottom = area.w
