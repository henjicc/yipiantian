extends PanelContainer
## Development-only overview composition controls; camera owns the session pose.
signal depth_of_field_changed(enabled: bool, strength: float)
signal fog_strength_changed(strength: float)

const FarmTheme = preload("res://ui/farm_theme.gd")
const FIELDS: Array = [
	["pitch", "俯角", 5.0, 60.0, 0.5],
	["yaw", "左右角度", -90.0, 90.0, 0.5],
	["distance", "距离", 16.0, 45.0, 0.1],
	["fov", "视野", 15.0, 60.0, 0.5],
	["target_x", "中心左右", -6.0, 6.0, 0.05],
	["target_y", "中心高度", -2.0, 5.0, 0.05],
	["target_z", "中心前后", -6.0, 6.0, 0.05],
]
var camera: FarmCamera
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _copy: Button
var _dof_toggle: CheckBox
var _dof_slider: HSlider
var _dof_value: Label
var _fog_slider: HSlider
var _fog_value: Label


func _ready() -> void:
	name = "CameraTuning"
	position = Vector2(18, 106)
	custom_minimum_size.x = 320
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	theme = FarmTheme.create()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Label.new()
	title.text = "全景相机"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_button(heading, "收起").pressed.connect(hide)
	for field: Array in FIELDS:
		var key: String = field[0]
		var row := HBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.text = field[1]
		label.add_theme_font_size_override("font_size", 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var number := Label.new()
		number.add_theme_font_size_override("font_size", 18)
		row.add_child(number)
		_values[key] = number
		var slider := HSlider.new()
		slider.name = key
		slider.min_value = field[2]
		slider.max_value = field[3]
		slider.step = field[4]
		slider.custom_minimum_size = Vector2(284, 20)
		slider.mouse_force_pass_scroll_events = false
		column.add_child(slider)
		_sliders[key] = slider
		slider.value_changed.connect(func(_value: float) -> void: _apply())
	var dof_row := HBoxContainer.new()
	column.add_child(dof_row)
	_dof_toggle = CheckBox.new()
	_dof_toggle.text = "景深模糊"
	_dof_toggle.add_theme_font_size_override("font_size", 18)
	_dof_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dof_row.add_child(_dof_toggle)
	_dof_value = Label.new()
	_dof_value.add_theme_font_size_override("font_size", 18)
	dof_row.add_child(_dof_value)
	_dof_slider = HSlider.new()
	_dof_slider.name = "DepthOfFieldStrength"
	_dof_slider.max_value = 300
	_dof_slider.step = 1
	_dof_slider.custom_minimum_size = Vector2(284, 20)
	_dof_slider.mouse_force_pass_scroll_events = false
	column.add_child(_dof_slider)
	_dof_toggle.toggled.connect(func(_enabled: bool) -> void: _apply_dof())
	_dof_slider.value_changed.connect(func(_value: float) -> void: _apply_dof())
	var fog_row := HBoxContainer.new()
	column.add_child(fog_row)
	var fog_label := Label.new()
	fog_label.text = "远景雾气"
	fog_label.add_theme_font_size_override("font_size", 18)
	fog_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fog_row.add_child(fog_label)
	_fog_value = Label.new()
	_fog_value.add_theme_font_size_override("font_size", 18)
	fog_row.add_child(_fog_value)
	_fog_slider = HSlider.new()
	_fog_slider.name = "FogStrength"
	_fog_slider.max_value = 100
	_fog_slider.step = 1
	_fog_slider.custom_minimum_size = Vector2(284, 20)
	_fog_slider.mouse_force_pass_scroll_events = false
	column.add_child(_fog_slider)
	_fog_slider.value_changed.connect(func(value: float) -> void:
		_fog_value.text = "%d%%" % roundi(value)
		fog_strength_changed.emit(value / 100.0)
		_copy.text = "复制参数")
	var presets := HBoxContainer.new()
	column.add_child(presets)
	_button(presets, "原角度").pressed.connect(func() -> void: _preset(28.0))
	_button(presets, "低角度").pressed.connect(func() -> void: _preset(22.0))
	_copy = _button(column, "复制参数")
	_copy.pressed.connect(func() -> void:
		var parameters: Dictionary = camera.overview_parameters()
		parameters.dof_enabled = _dof_toggle.button_pressed
		parameters.dof_strength = _dof_slider.value / 100.0
		parameters.fog_strength = _fog_slider.value / 100.0
		DisplayServer.clipboard_set(JSON.stringify(parameters, "\t"))
		_copy.text = "已复制")
	hide()


func present(settings: Dictionary) -> void:
	camera.preview_overview(camera.overview_parameters())
	_dof_toggle.set_pressed_no_signal(settings.dof_enabled)
	_dof_slider.set_value_no_signal(settings.dof_strength * 100.0)
	_fog_slider.set_value_no_signal(settings.fog_strength * 100.0)
	_fog_value.text = "%d%%" % roundi(_fog_slider.value)
	_dof_toggle.disabled = false
	_dof_toggle.text = "景深模糊"
	_sync_dof()
	_sync()
	show()


func _sync_dof() -> void:
	_dof_slider.editable = _dof_toggle.button_pressed and not _dof_toggle.disabled
	_dof_value.text = "%d%%" % roundi(_dof_slider.value)


func _apply_dof() -> void:
	_sync_dof()
	depth_of_field_changed.emit(_dof_toggle.button_pressed, _dof_slider.value / 100.0)
	_copy.text = "复制参数"


func _preset(pitch: float) -> void:
	camera.preview_overview({"yaw": 25.0, "pitch": pitch, "distance": 28.0, "fov": 29.0,
		"target_x": 0.0, "target_y": 0.85, "target_z": 0.0})
	_sync()


func _sync() -> void:
	var parameters: Dictionary = camera.overview_parameters()
	for key: String in _sliders:
		_sliders[key].set_value_no_signal(parameters[key])
		_values[key].text = "%.2f" % parameters[key]
	_copy.text = "复制参数"


func _apply() -> void:
	var parameters: Dictionary = {}
	for key: String in _sliders:
		parameters[key] = _sliders[key].value
		_values[key].text = "%.2f" % parameters[key]
	camera.preview_overview(parameters)
	_copy.text = "复制参数"


func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button
