extends RefCounted
## Shared pigment surfaces and interaction states for HUD and menus.

const FONT = preload("res://art/ui/fonts/汇文明朝体.ttf")
const Tokens = preload("res://ui/ui_tokens.gd")
const PAPER_FRAME_NORMAL: Texture2D = preload("res://art/ui/pigment/normal.png")
const PAPER_FRAME_HOVER: Texture2D = preload("res://art/ui/pigment/hover.png")
const PAPER_FRAME_PRESSED: Texture2D = preload("res://art/ui/pigment/pressed.png")
const PAPER_FRAME_DISABLED: Texture2D = preload("res://art/ui/pigment/disabled.png")
const PANEL: Texture2D = preload("res://art/ui/pigment/panel.png")
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
		theme.set_color("font_disabled_color", type, Tokens.MUTED)
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, framed_paper(PAPER_FRAME_NORMAL))
		theme.set_stylebox("hover", type, framed_paper(PAPER_FRAME_HOVER))
		theme.set_stylebox("pressed", type, framed_paper(PAPER_FRAME_PRESSED))
		theme.set_stylebox("disabled", type, framed_paper(PAPER_FRAME_DISABLED))
		var focus := StyleBoxFlat.new()
		focus.draw_center = false
		focus.border_color = Tokens.ACCENT
		focus.set_border_width_all(2)
		focus.set_corner_radius_all(13)
		focus.set_expand_margin_all(-3)
		theme.set_stylebox("focus", type, focus)
		theme.set_constant("h_separation", type, 8)
	theme.set_stylebox("panel", "PanelContainer", framed_paper())
	theme.set_stylebox("panel", "Panel", framed_paper())
	theme.set_stylebox("panel", "PopupMenu", framed_paper())
	theme.set_stylebox("hover", "PopupMenu", paper(Tokens.WASH_HOVER))
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


static func framed_paper(texture: Texture2D = PANEL) -> StyleBoxTexture:
	# Keep the antialiased corners intact and repeat the seamless edge cells.
	# Width changes the pigment tile count, never the corner/brush scale.
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = Tokens.CORNER_SLICE
	style.texture_margin_top = Tokens.CORNER_SLICE
	style.texture_margin_right = Tokens.CORNER_SLICE
	style.texture_margin_bottom = Tokens.CORNER_SLICE
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.content_margin_left = Tokens.INSET_X
	style.content_margin_right = Tokens.INSET_X
	style.content_margin_top = Tokens.INSET_Y
	style.content_margin_bottom = Tokens.INSET_Y
	return style


static func paper(color: Color = PAPER, radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = Tokens.INSET_X
	style.content_margin_right = Tokens.INSET_X
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.22, 0.24, 0.17, 0.16)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style
