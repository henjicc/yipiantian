extends Button
## One measured icon/text layout: children never compete with the button hit area.
const FarmTheme = preload("res://ui/farm_theme.gd")
const Tokens = FarmTheme.Tokens
var picture: TextureRect
var title_label: Label
var detail_label: Label
var _layout: MarginContainer


func _init() -> void:
	FarmTheme.pointer_focus(self)
	add_theme_stylebox_override("normal", FarmTheme.framed_paper())
	_layout = MarginContainer.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		_layout.add_theme_constant_override("margin_" + side, Tokens.INSET_X)
	for side: String in ["top", "bottom"]:
		_layout.add_theme_constant_override("margin_" + side, Tokens.INSET_Y)
	add_child(_layout)
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.GAP)
	_layout.add_child(row)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2.ONE * Tokens.ICON_SIZE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var copy := VBoxContainer.new()
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation", 0)
	row.add_child(copy)
	title_label = _label(copy, 24)
	detail_label = _label(copy, 16)
	detail_label.add_theme_color_override("font_color", Tokens.MUTED)
	detail_label.hide()
	_layout.minimum_size_changed.connect(update_minimum_size)


func _get_minimum_size() -> Vector2:
	return _layout.get_combined_minimum_size() if is_instance_valid(_layout) else Vector2.ZERO


func _label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Tokens.INK)
	parent.add_child(label)
	return label
