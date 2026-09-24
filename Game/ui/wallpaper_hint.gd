extends CanvasLayer
## A chair-anchored hint. Observation mode receives only the host's already
## filtered desktop pointer, so its buttons must not enable global GUI input.
signal dismissed(permanently: bool)

const FarmTheme = preload("res://ui/farm_theme.gd")
const MESSAGE: String = "点击这里可以开启\n桌面壁纸时的交互"
var _camera: Camera3D
var _chair: Node3D
var _panel: PanelContainer
var _label: Label
var _buttons: Array[Button] = []
var _tail: Polygon2D
var _press: Vector2 = Vector2.INF
var _pressed_action: int = -1
var _area := Vector4(0, 0, 1, 1)


func _ready() -> void:
	layer = 25
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = FarmTheme.create()
	add_child(root)
	_tail = Polygon2D.new()
	_tail.color = FarmTheme.PAPER
	root.add_child(_tail)
	_panel = PanelContainer.new()
	_panel.name = "Bubble"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size.x = 330
	root.add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_label = Label.new()
	_label.text = MESSAGE
	_label.custom_minimum_size.x = 298
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_label)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(actions)
	for title: String in ["不再提示", "关闭"]:
		var button := Button.new()
		button.text = title
		button.custom_minimum_size.y = 36
		button.add_theme_font_size_override("font_size", 17)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		actions.add_child(button)
		_buttons.append(button)
	dismiss()


func present(camera: Camera3D, chair: Node3D) -> void:
	_camera = camera
	_chair = chair
	_label.text = MESSAGE
	cancel_pointer()
	show()
	set_process(true)
	_process(0.0)


func dismiss() -> void:
	hide()
	set_process(false)
	cancel_pointer()


func show_save_failure() -> void:
	_label.text = MESSAGE + "\n未能保存，请再点“不再提示”重试。"


func set_workarea(area: Vector4) -> void:
	_area = area


func _process(_delta: float) -> void:
	var anchor: Vector3 = _chair.global_position + Vector3.UP * .55
	var screen: Rect2 = get_viewport().get_visible_rect()
	var at: Vector2 = _camera.unproject_position(anchor)
	var on_screen: bool = not _camera.is_position_behind(anchor) and screen.has_point(at)
	_panel.visible = on_screen
	_tail.visible = on_screen
	if not on_screen: return
	var minimum := Vector2(_area.x, _area.y) * screen.size + Vector2(12, 12)
	var maximum := Vector2(_area.z, _area.w) * screen.size - Vector2(12, 12)
	var below: bool = at.y - _panel.size.y - 32 < minimum.y
	var origin := Vector2(at.x - _panel.size.x * .5, at.y + 32 if below else at.y - _panel.size.y - 32)
	origin = origin.clamp(minimum, (maximum - _panel.size).max(minimum))
	_panel.position = origin
	var join := Vector2(clampf(at.x, origin.x + 18, origin.x + _panel.size.x - 18), origin.y if below else origin.y + _panel.size.y)
	_tail.polygon = PackedVector2Array([join - Vector2(9, 0), at, join + Vector2(9, 0)])


func contains(point: Vector2) -> bool:
	return visible and _panel.visible and _panel.get_global_rect().has_point(point)


func move_pointer(point: Vector2) -> void:
	for button: Button in _buttons:
		var state: String = "hover" if contains(point) and button.get_global_rect().has_point(point) else "normal"
		button.add_theme_stylebox_override("normal", _panel.get_theme_stylebox(state, "Button"))


func pointer_button(point: Vector2, pressed: bool) -> bool:
	if pressed:
		if not contains(point): return false
		_press = point
		_pressed_action = -1
		for index: int in _buttons.size():
			if _buttons[index].get_global_rect().has_point(point): _pressed_action = index
		return true
	var consumed: bool = _press.is_finite()
	var action: int = _pressed_action
	var clicked: bool = consumed and _press.distance_to(point) < 7.0 and contains(point)
	cancel_pointer()
	if clicked and action >= 0 and _buttons[action].get_global_rect().has_point(point):
		dismissed.emit(action == 0)
	return consumed or contains(point)


func cancel_pointer() -> void:
	_press = Vector2.INF
	_pressed_action = -1
	move_pointer(Vector2.INF)
