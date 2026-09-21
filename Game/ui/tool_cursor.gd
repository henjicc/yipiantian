extends Node
## Arrow and carried item share one hardware cursor, so motion never waits for a frame.

var _wallpaper_item: TextureRect
var _wallpaper: bool = false
var _wallpaper_position: Vector2 = Vector2.INF
var _key: String = ""
var _cursor_texture: ImageTexture
var _cursor_pixels: int = 0
var _textures: Dictionary = {}


func _ready() -> void:
	get_viewport().size_changed.connect(_resize_cursor)
	_resize_cursor()


func show_tool(tool: String, crop_id: String) -> void:
	var key: String = (crop_id if tool == "sow" else tool) if not tool.is_empty() else ""
	if key == _key:
		return
	_key = key
	_update_wallpaper_item()
	_apply_cursor()


func _resize_cursor() -> void:
	# 96 logical pixels for the composite must fit Windows/Godot's 256px limit.
	var pixels: int = clampi(roundi(64.0 * get_viewport().get_stretch_transform().get_scale().x), 48, 170)
	if pixels == _cursor_pixels:
		return
	_cursor_pixels = pixels
	_textures.clear()
	_apply_cursor()


func _apply_cursor() -> void:
	if not _textures.has(_key):
		var scale: float = float(_cursor_pixels) / 64.0
		var arrow: Image = load("res://art/ui/crops/pointer.png").get_image()
		arrow.convert(Image.FORMAT_RGBA8)
		arrow.resize(_cursor_pixels, _cursor_pixels, Image.INTERPOLATE_LANCZOS)
		var composite: Image = arrow
		if not _key.is_empty():
			composite = Image.create_empty(roundi(96 * scale), roundi(88 * scale), false, Image.FORMAT_RGBA8)
			var item: Image = load("res://art/ui/crops/%s.png" % _key).get_image()
			item.convert(Image.FORMAT_RGBA8)
			var item_pixels: int = roundi(48 * scale)
			item.resize(item_pixels, item_pixels, Image.INTERPOLATE_LANCZOS)
			composite.blend_rect(item, Rect2i(Vector2i.ZERO, item.get_size()), Vector2i(roundi(44 * scale), roundi(35 * scale)))
			composite.blend_rect(arrow, Rect2i(Vector2i.ZERO, arrow.get_size()), Vector2i.ZERO)
		_textures[_key] = ImageTexture.create_from_image(composite)
	_cursor_texture = _textures[_key]
	var hotspot: Vector2 = Vector2(11, 8) * float(_cursor_pixels) / 48.0
	for shape: Input.CursorShape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(_cursor_texture, shape, hotspot)


func _exit_tree() -> void:
	for shape: Input.CursorShape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(null, shape)
	_textures.clear()


func set_wallpaper_pointer(enabled: bool, position: Vector2) -> void:
	_wallpaper = enabled
	_wallpaper_position = position
	if enabled and _wallpaper_item == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_wallpaper_item = TextureRect.new()
		_wallpaper_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wallpaper_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_wallpaper_item.size = Vector2(48, 48)
		layer.add_child(_wallpaper_item)
	_update_wallpaper_item()


func _update_wallpaper_item() -> void:
	if _wallpaper_item == null: return
	_wallpaper_item.visible = _wallpaper and _wallpaper_position.is_finite() and not _key.is_empty()
	if _wallpaper_item.visible:
		_wallpaper_item.position = _wallpaper_position + Vector2(24, 28)
		_wallpaper_item.texture = load("res://art/ui/crops/%s.png" % _key)
