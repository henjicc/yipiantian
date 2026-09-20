extends RefCounted
## Shared pigment surfaces and interaction states for HUD and menus.

const FONT = preload("res://art/ui/fonts/汇文明朝体.ttf")
const Tokens = preload("res://ui/ui_tokens.gd")
const PigmentStyle = preload("res://ui/pigment_style.gd")
const INK := Tokens.INK
const PAPER := Tokens.PAPER
const EDGE := Tokens.EDGE
const LEAF := Tokens.LEAF


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 20
	for type: String in ["Label", "Button", "OptionButton", "CheckButton", "CheckBox", "RichTextLabel", "PopupMenu"]:
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_disabled_color", type, Tokens.MUTED)
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, framed_paper(Tokens.WASH))
		theme.set_stylebox("hover", type, framed_paper(Tokens.WASH_HOVER))
		theme.set_stylebox("pressed", type, framed_paper(Tokens.WASH_PRESSED, true))
		theme.set_stylebox("hover_pressed", type, framed_paper(Tokens.WASH_PRESSED, true))
		theme.set_stylebox("disabled", type, framed_paper(Tokens.DISABLED))
		var focus := StyleBoxFlat.new()
		focus.draw_center = false
		focus.border_color = LEAF
		focus.set_border_width_all(1)
		focus.set_corner_radius_all(10)
		focus.set_expand_margin_all(-4)
		theme.set_stylebox("focus", type, focus)
		theme.set_constant("h_separation", type, 8)
	theme.set_stylebox("panel", "PanelContainer", framed_paper())
	theme.set_stylebox("panel", "Panel", framed_paper())
	var popup := framed_paper()
	popup.content_margin_left = 6
	popup.content_margin_right = 6
	popup.content_margin_top = 6
	popup.content_margin_bottom = 6
	theme.set_stylebox("panel", "PopupMenu", popup)
	var highlight := paper(Tokens.WASH_HOVER, 3)
	highlight.shadow_size = 0
	highlight.set_border_width_all(0)
	theme.set_stylebox("hover", "PopupMenu", highlight)
	theme.set_constant("arrow_margin", "OptionButton", 16)
	theme.set_constant("modulate_arrow", "OptionButton", 1)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_constant("v_separation", "PopupMenu", 16)
	theme.set_constant("separation", "VBoxContainer", Tokens.GAP)
	theme.set_constant("separation", "HBoxContainer", Tokens.GAP)
	var track: StyleBoxFlat = paper(Tokens.TRACK, 4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = paper(LEAF, 4)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	for state: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
		theme.set_icon(state, "HSlider", preload("res://art/ui/pigment/slider-thumb.png"))
	for type: String in ["VScrollBar", "HScrollBar"]:
		for state: String in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
			var bar := paper(Tokens.TRACK if state == "scroll" else LEAF, 3)
			bar.shadow_size = 0
			bar.set_border_width_all(0)
			for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				bar.set_content_margin(side, 3)
			theme.set_stylebox(state, type, bar)
	return theme


static func framed_paper(fill: Color = PAPER, selected: bool = false) -> StyleBox:
	var style := PigmentStyle.new()
	style.fill = fill
	style.edge = EDGE
	style.selected = selected
	style.content_margin_left = Tokens.INSET_X
	style.content_margin_right = Tokens.INSET_X
	style.content_margin_top = Tokens.INSET_Y
	style.content_margin_bottom = Tokens.INSET_Y
	return style


static func configure_option(button: OptionButton) -> void:
	for index: int in button.item_count:
		button.get_popup().set_item_as_radio_checkable(index, false)
	pointer_focus(button)


static func pointer_focus(button: BaseButton) -> void:
	# Pointer activation need not leave a keyboard-navigation ring behind.
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed:
			button.release_focus.call_deferred())


static func paper(color: Color = PAPER, radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.corner_detail = 24
	style.content_margin_left = Tokens.INSET_X
	style.content_margin_right = Tokens.INSET_X
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.22, 0.24, 0.17, 0.16)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style
