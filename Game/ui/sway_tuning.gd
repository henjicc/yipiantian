extends PanelContainer
const FarmTheme = preload("res://ui/farm_theme.gd")
var camera: FarmCamera
var _sliders: Dictionary = {}
var _numbers: Dictionary = {}

func _ready() -> void:
	name = "SwayTuning"
	position = Vector2(18,70)
	custom_minimum_size = Vector2(370,480)
	theme = FarmTheme.create()
	mouse_force_pass_scroll_events = false
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "手持镜头晃动"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_button(header,"收起").pressed.connect(hide)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350,360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(fields)
	for field: Array in camera.sway_motion.FIELDS:
		var key: String = field[0]
		var row := HBoxContainer.new()
		fields.add_child(row)
		var label := Label.new()
		label.text = field[1]
		label.custom_minimum_size.x = 130
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = field[2]
		slider.max_value = field[3]
		slider.step = field[4]
		slider.custom_minimum_size = Vector2(125,36)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var number := Label.new()
		number.custom_minimum_size.x = 48
		row.add_child(number)
		_sliders[key] = slider
		_numbers[key] = number
		slider.value_changed.connect(func(value: float) -> void:
			camera.sway_motion.parameters[key] = value
			number.text = "%.2f" % value)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_button(actions,"恢复默认").pressed.connect(func() -> void:
		camera.sway_motion.reset()
		_sync())
	_button(actions,"复制参数").pressed.connect(func() -> void:
		DisplayServer.clipboard_set(JSON.stringify(camera.sway_motion.parameters,"\t")))
	visibility_changed.connect(func() -> void:
		camera.sway_preview = visible
		camera.note_activity())
	hide()

func present() -> void:
	_sync()
	show()

func _sync() -> void:
	for key: String in _sliders:
		_sliders[key].set_value_no_signal(camera.sway_motion.parameters[key])
		_numbers[key].text = "%.2f" % camera.sway_motion.parameters[key]

func _button(parent: Control, title: String) -> Button:
	var button := Button.new()
	button.text = title
	parent.add_child(button)
	return button
