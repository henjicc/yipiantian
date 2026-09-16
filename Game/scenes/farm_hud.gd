extends CanvasLayer
## UI owns presentation and emits intent; it never changes farm state.

signal tool_requested(tool: String)
signal crop_requested(crop_id: String)
signal overview_requested
signal reset_requested

const Crops = preload("res://farm/crop_catalog.gd")
const INK := Color("465650")
var _status: Label
var _harvested: Label
var _feedback: Label
var _tool_status: Label
var _tools: HBoxContainer
var _crop: OptionButton
var _buttons: Dictionary = {}


func _ready() -> void:
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	root.theme = theme
	var title := _label(root, "我有一片田", 26)
	title.position = Vector2(30, 22)
	_status = _label(root, "全景", 19)
	_status.name = "FieldStatus"
	_status.position = Vector2(30, 65)
	var session := _label(root, "试玩中 · 进度尚未保存", 14)
	session.name = "SessionStatus"
	session.position = Vector2(30, 96)
	_harvested = _label(root, "", 18)
	_harvested.name = "Harvested"
	_harvested.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_harvested.offset_left = -330
	_harvested.offset_right = -30
	_harvested.offset_top = 30
	_harvested.offset_bottom = 60
	_harvested.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feedback = _label(root, "", 19)
	_feedback.name = "Feedback"
	_feedback.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_feedback.offset_left = -380
	_feedback.offset_right = 380
	_feedback.offset_top = -196
	_feedback.offset_bottom = -168
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_status = _label(root, "", 17)
	_tool_status.name = "ToolStatus"
	_tool_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tool_status.offset_left = -380
	_tool_status.offset_right = 380
	_tool_status.offset_top = -161
	_tool_status.offset_bottom = -133
	_tool_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tools = HBoxContainer.new()
	_tools.name = "FarmControls"
	root.add_child(_tools)
	_tools.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tools.offset_left = -296
	_tools.offset_right = 296
	_tools.offset_top = -120
	_tools.offset_bottom = -74
	_tools.add_theme_constant_override("separation", 10)
	_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crop = OptionButton.new()
	_crop.name = "CropChoice"
	_crop.custom_minimum_size = Vector2(166, 44)
	_style_button(_crop)
	for crop_id: String in Crops.crop_ids():
		_crop.add_item(Crops.definition(crop_id).name)
	_crop.item_selected.connect(func(index: int) -> void: crop_requested.emit(Crops.crop_ids()[index]))
	_tools.add_child(_crop)
	for item: Array in [["sow", "播种"], ["water", "浇水"], ["harvest", "收获"]]:
		var button := _button(_tools, item[1], 132)
		button.name = item[0].capitalize()
		button.toggle_mode = true
		button.pressed.connect(func() -> void: tool_requested.emit(item[0]))
		_buttons[item[0]] = button
	var bar := HBoxContainer.new()
	bar.name = "ViewControls"
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -148
	bar.offset_right = 148
	bar.offset_top = -60
	bar.offset_bottom = -16
	bar.add_theme_constant_override("separation", 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button(bar, "全景", 142).pressed.connect(func() -> void: overview_requested.emit())
	_button(bar, "视角复位", 142).pressed.connect(func() -> void: reset_requested.emit())


func show_state(field: Dictionary, harvested: Dictionary, tool: String, crop_id: String, traveling: bool) -> void:
	_harvested.text = "青菜 %d 篮  ·  白萝卜 %d 篮" % [harvested.greens, harvested.radish]
	_tools.visible = not field.is_empty()
	_crop.select(Crops.crop_ids().find(crop_id))
	_crop.disabled = traveling
	for tool_id: String in _buttons:
		var button: Button = _buttons[tool_id]
		button.disabled = traveling
		button.set_pressed_no_signal(tool == tool_id)
	if field.is_empty():
		_status.text = "全景"
		_tool_status.text = ""
		return
	var title: String = "第 %d 块田" % int(field.id.trim_prefix("field_"))
	if field.stage == "empty":
		_status.text = title + " · 空田"
	else:
		var stage_name: String = {"sprout": "幼芽", "young": "幼株", "mature": "可收获"}[field.stage]
		_status.text = "%s · %s · %s" % [title, Crops.definition(field.crop_id).name, stage_name]
		if field.stage != "mature":
			_status.text += " · 约 %d 分钟" % maxi(1, ceili(field.remaining_seconds / 60.0))
			if field.watered:
				_status.text += " · 已浇水"
	_tool_status.text = "镜头移动中" if traveling else ("" if tool.is_empty() else "已选%s · 点击当前田块" % {"sow": "播种", "water": "浇水", "harvest": "收获"}[tool])


func show_result(result: Dictionary, tool: String, crop_id: String) -> void:
	if result.ok:
		match tool:
			"sow": _feedback.text = "已播种%s" % Crops.definition(crop_id).name
			"water": _feedback.text = "已浇水"
			"harvest": _feedback.text = "%s +1 篮" % Crops.definition(result.reward_crop_id).name
	else:
		_feedback.text = {
			"occupied": "田里已有作物", "empty": "这块田还没有作物", "mature": "作物已成熟，可以收获",
			"already_watered": "这一轮已经浇过水", "not_mature": "作物还在生长", "harvest_limit": "收获记录已满",
			"invalid_time": "系统时间暂不可用", "invalid_field": "没有选中田块", "invalid_crop": "请选择作物"
		}.get(result.reason, "操作未完成")


func clear_feedback() -> void:
	_feedback.text = ""


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
	_style_button(button)
	parent.add_child(button)
	return button


func _style_button(button: BaseButton) -> void:
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("354c3d"))
	button.add_theme_color_override("font_pressed_color", Color("f5eddc"))
	button.add_theme_color_override("font_disabled_color", Color("888a7b"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f0e8d4")
		if state == "hover":
			style.bg_color = Color("e0dcc1")
		elif state == "pressed":
			style.bg_color = Color("527664")
		style.set_corner_radius_all(14)
		style.border_color = Color("9d9b7c")
		style.set_border_width_all(2 if state == "focus" else 1)
		button.add_theme_stylebox_override(state, style)
