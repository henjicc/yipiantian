extends RefCounted
## One small theme for this game's HUD and menus, not a component library.

const FONT = preload("res://art/ui/fonts/NotoSerifCJKsc-Regular.otf")
const INK := Color("4b493d")
const PAPER := Color("f4ecd9")
const EDGE := Color("ac9978")
const LEAF := Color("526b50")


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 20
	for type: String in ["Label", "Button", "OptionButton", "CheckButton", "CheckBox", "RichTextLabel", "PopupMenu"]:
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_pressed_color", type, PAPER)
		theme.set_color("font_disabled_color", type, Color("8b877a"))
	for type: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, paper())
		theme.set_stylebox("hover", type, paper(Color("e9dfc6")))
		theme.set_stylebox("pressed", type, paper(LEAF))
		theme.set_stylebox("disabled", type, paper(Color("e8e2d4")))
		var focus: StyleBoxFlat = paper()
		focus.draw_center = false
		focus.border_color = Color("826846")
		focus.set_border_width_all(3)
		theme.set_stylebox("focus", type, focus)
		theme.set_constant("h_separation", type, 8)
	theme.set_stylebox("panel", "PanelContainer", paper())
	theme.set_stylebox("panel", "Panel", paper())
	theme.set_stylebox("panel", "PopupMenu", paper())
	theme.set_stylebox("hover", "PopupMenu", paper(Color("e2d9bd")))
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_constant("v_separation", "PopupMenu", 16)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 10)
	var track: StyleBoxFlat = paper(Color("d4ccb8"), 4)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var filled: StyleBoxFlat = paper(LEAF, 4)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	return theme


static func paper(color: Color = PAPER, radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.22, 0.24, 0.17, 0.16)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style
