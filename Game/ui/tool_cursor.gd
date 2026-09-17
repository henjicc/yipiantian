extends CanvasLayer
## Cursor art and the carried crop/tool are presentation only; never receive input.

var badge: TextureRect
var _active: bool = false
var _key: String = ""
var _cursor_texture: ImageTexture
var _cursor_pixels: int = 0


func _ready() -> void:
	layer = 100
	get_viewport().size_changed.connect(_resize_cursor)
	_resize_cursor()
	badge = TextureRect.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size = Vector2(56, 56)
	add_child(badge)
	badge.hide()


func show_tool(tool: String, crop_id: String, point: Vector2) -> void:
	var active: bool = not tool.is_empty()
	if active != _active:
		_active = active
		_apply_cursor()
	badge.visible = active
	if not active:
		return
	var key: String = crop_id if tool == "sow" else tool
	if key != _key:
		_key = key
		badge.texture = load("res://art/ui/crops/%s.png" % key)
	var limit: Vector2 = get_viewport().get_visible_rect().size - badge.size
	badge.position = (point + Vector2(38, 34)).clamp(Vector2.ZERO, limit)


func _resize_cursor() -> void:
	# Hardware cursors use physical pixels; UI uses the project's logical canvas.
	var pixels: int = clampi(roundi(64.0 * get_viewport().get_stretch_transform().get_scale().x), 48, 256)
	if pixels == _cursor_pixels:
		return
	_cursor_pixels = pixels
	var source: Image = load("res://art/ui/crops/pointer.png").get_image()
	source.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
	_cursor_texture = ImageTexture.create_from_image(source)
	if _active:
		_apply_cursor()


func _apply_cursor() -> void:
	var hotspot: Vector2 = Vector2(11, 8) * float(_cursor_pixels) / 48.0
	Input.set_custom_mouse_cursor(_cursor_texture if _active else null, Input.CURSOR_ARROW, hotspot if _active else Vector2.ZERO)


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)
