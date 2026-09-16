extends CanvasLayer
## Arrangement controls emit intent; confirmed state lives in DecorationState.

signal item_requested(item_id: String)
signal rotate_requested
signal confirm_requested
signal cancel_requested
signal finish_requested

const Catalog = preload("res://farm/decoration_catalog.gd")
const FarmHUD = preload("res://scenes/farm_hud.gd")
var _items: Dictionary = {}
var _status: Label
var _confirm: Button
var _rotate: Button
var _cancel: Button


func _ready() -> void:
	layer = 9
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
	var box := VBoxContainer.new()
	box.name = "Controls"
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -350
	box.offset_right = 350
	box.offset_top = -198
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", FarmHUD.INK)
	box.add_child(_status)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 10)
	box.add_child(items)
	for item_id: String in Catalog.IDS:
		var button := _button(items, item_id, 226)
		button.name = item_id.capitalize()
		button.toggle_mode = true
		button.pressed.connect(func() -> void: item_requested.emit(item_id))
		_items[item_id] = button
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	_rotate = _button(actions, "旋转", 132)
	_rotate.name = "Rotate"
	_rotate.pressed.connect(func() -> void: rotate_requested.emit())
	_confirm = _button(actions, "确认布置", 132)
	_confirm.name = "Confirm"
	_confirm.pressed.connect(func() -> void: confirm_requested.emit())
	_cancel = _button(actions, "取消移动", 132)
	_cancel.name = "Cancel"
	_cancel.pressed.connect(func() -> void: cancel_requested.emit())
	var finish := _button(actions, "完成", 132)
	finish.name = "Finish"
	finish.pressed.connect(func() -> void: finish_requested.emit())
	hide()


func present(items: Dictionary, selected: String, preview_slot: String, can_confirm: bool, message: String, traveling: bool) -> void:
	_status.text = message
	for item_id: String in Catalog.IDS:
		var button: Button = _items[item_id]
		var item: Dictionary = items[item_id]
		button.text = Catalog.ITEMS[item_id].name + (" · 已摆放" if not item.slot_id.is_empty() else "") if item.unlocked else Catalog.ITEMS[item_id].name + "\n" + Catalog.requirement(item_id)
		button.disabled = traveling
		button.set_pressed_no_signal(selected == item_id)
	_confirm.disabled = traveling or not can_confirm
	_rotate.disabled = traveling or preview_slot.is_empty() or Catalog.allowed_turns(preview_slot).size() < 2
	_cancel.disabled = selected.is_empty()


func _button(parent: Control, text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 48)
	FarmHUD._style_button(button)
	parent.add_child(button)
	return button
