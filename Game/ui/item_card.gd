extends Button
## Shared picture-above-caption treatment for actual crop, tool and item choices.
var _picture: TextureRect
var _caption: Label
var _badge: Label
var _available: bool = true

func configure(label: String, texture: Texture2D, dimensions: Vector2 = Vector2(66,84), font_size: int = 16) -> void:
	custom_minimum_size = dimensions
	_picture = TextureRect.new()
	_picture.name = "Icon"
	_picture.texture = texture
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.offset_left = 7
	_picture.offset_right = -7
	_picture.offset_top = 4
	_picture.offset_bottom = -29
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.text = label
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size",font_size)
	add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -29
	_caption.offset_bottom = -5
	_badge = Label.new()
	_badge.name = "State"
	_badge.position = Vector2(7,3)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_font_size_override("font_size",12)
	add_child(_badge)

func show_state(placed: bool, available: bool) -> void:
	_available = available
	_badge.text = "已摆放" if placed else ("未解锁" if not available else "")
	queue_redraw()

func _draw() -> void:
	if _caption == null: return
	var mode: int = get_draw_mode()
	var color_name: String = "font_color"
	if disabled: color_name = "font_disabled_color"
	elif mode in [BaseButton.DRAW_PRESSED,BaseButton.DRAW_HOVER_PRESSED]: color_name = "font_pressed_color"
	elif mode == BaseButton.DRAW_HOVER: color_name = "font_hover_color"
	var color: Color = get_theme_color(color_name,"Button")
	_caption.add_theme_color_override("font_color",color)
	_badge.add_theme_color_override("font_color",color)
	_picture.modulate.a = .35 if not _available else (.45 if disabled else 1.0)
