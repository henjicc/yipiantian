extends CanvasLayer
## Arrangement controls emit intent; confirmed state lives in DecorationState.

signal item_requested(item_id: String)
signal rotate_requested
signal confirm_requested
signal cancel_requested
signal finish_requested
signal remove_requested
signal courtyard_requested

const Catalog = preload("res://farm/decoration_catalog.gd")
const FarmTheme = preload("res://ui/farm_theme.gd")
const ItemCard = preload("res://ui/item_card.gd")
var _items: Dictionary = {}
var _status: Label
var _confirm: Button
var _rotate: Button
var _cancel: Button
var _remove: Button


func _ready() -> void:
	layer = 9
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = FarmTheme.create()
	var box := VBoxContainer.new()
	box.name = "Controls"
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -250
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_stylebox_override("normal", FarmTheme.paper(FarmTheme.PAPER, 12))
	box.add_child(_status)
	var items := HBoxContainer.new()
	items.alignment=BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 10)
	box.add_child(items)
	for item_id: String in Catalog.IDS:
		var button := ItemCard.new()
		items.add_child(button)
		button.configure(Catalog.ITEMS[item_id].name,load("res://art/ui/decorations/%s.png"%item_id),Vector2(108,116),18)
		button.name = item_id.capitalize()
		button.toggle_mode = true
		button.pressed.connect(func() -> void: item_requested.emit(item_id))
		_items[item_id] = button
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	var courtyard := _button(actions, "整理田地", "arrange")
	courtyard.name = "Courtyard"
	courtyard.pressed.connect(func() -> void: courtyard_requested.emit())
	_rotate = _button(actions, "旋转", "rotate")
	_rotate.name = "Rotate"
	_rotate.pressed.connect(func() -> void: rotate_requested.emit())
	_confirm = _button(actions, "确认布置", "confirm")
	_confirm.name = "Confirm"
	_confirm.pressed.connect(func() -> void: confirm_requested.emit())
	_cancel = _button(actions, "取消移动", "cancel")
	_cancel.name = "Cancel"
	_cancel.pressed.connect(func() -> void: cancel_requested.emit())
	_remove = _button(actions,"收起摆件","store")
	_remove.name="Remove"
	_remove.pressed.connect(func() -> void: remove_requested.emit())
	var finish := _button(actions, "完成", "finish")
	finish.name = "Finish"
	finish.pressed.connect(func() -> void: finish_requested.emit())
	hide()


func present(items: Dictionary, selected: String, preview_slot: String, can_confirm: bool, message: String, traveling: bool) -> void:
	_status.text = message
	for item_id: String in Catalog.IDS:
		var button: ItemCard = _items[item_id]
		var item: Dictionary = items[item_id]
		button.show_state(not item.slot_id.is_empty(),item.unlocked)
		button.disabled = traveling
		button.set_pressed_no_signal(selected == item_id)
	_confirm.disabled = traveling or not can_confirm
	_rotate.disabled = traveling or preview_slot.is_empty() or Catalog.allowed_turns(preview_slot).size() < 2
	_cancel.disabled = selected.is_empty()
	_remove.disabled=traveling or selected.is_empty() or items.get(selected,{}).get("slot_id","").is_empty()


func _button(parent: Control, text: String, icon: String) -> Button:
	var button := ItemCard.new()
	parent.add_child(button)
	button.configure(text,load("res://art/ui/actions/%s.svg"%icon),Vector2(108,64),16)
	return button
