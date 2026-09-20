extends RefCounted
## One small theme for this game's HUD and menus, not a component library.

const FONT = preload("res://art/ui/fonts/汇文明朝体.ttf")
const PAPER_FRAME_NORMAL: Texture2D = preload("res://art/ui/radial_menu/paper-wood-frame-gongbi-tiled.png")
const PAPER_FRAME_HOVER: Texture2D = preload("res://art/ui/radial_menu/paper-wood-frame-gongbi-tiled-hover.png")
const PAPER_FRAME_PRESSED: Texture2D = preload("res://art/ui/radial_menu/paper-wood-frame-gongbi-tiled-pressed.png")
const PAPER_FRAME_DISABLED: Texture2D = preload("res://art/ui/radial_menu/paper-wood-frame-gongbi-tiled-disabled.png")
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
		theme.set_stylebox("normal", type, framed_paper(PAPER_FRAME_NORMAL))
		theme.set_stylebox("hover", type, framed_paper(PAPER_FRAME_HOVER))
		theme.set_stylebox("pressed", type, framed_paper(PAPER_FRAME_PRESSED))
		theme.set_stylebox("disabled", type, framed_paper(PAPER_FRAME_DISABLED))
		theme.set_stylebox("focus", type, framed_paper(PAPER_FRAME_HOVER))
		theme.set_constant("h_separation", type, 8)
	theme.set_stylebox("panel", "PanelContainer", framed_paper(PAPER_FRAME_NORMAL))
	theme.set_stylebox("panel", "Panel", framed_paper(PAPER_FRAME_NORMAL))
	theme.set_stylebox("panel", "PopupMenu", framed_paper(PAPER_FRAME_NORMAL))
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


static func framed_paper(texture: Texture2D = PAPER_FRAME_NORMAL) -> StyleBoxTexture:
	# Keep the antialiased corners intact and repeat the seamless edge cells.
	# Button width now changes the tile count instead of stretching the wood grain.
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 20.0
	style.texture_margin_top = 20.0
	style.texture_margin_right = 20.0
	style.texture_margin_bottom = 20.0
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


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
