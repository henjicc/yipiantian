extends Node
## Window mode uses a composite hardware cursor; wallpaper keeps the system arrow and draws only the carried item.

var _system_pointer: bool = false
var _carried_item: TextureRect
var _pointer_position: Vector2 = Vector2.INF
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
	_refresh_carried_item()
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
	if _system_pointer: return
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


func set_system_pointer(enabled: bool) -> void:
	_system_pointer = enabled
	_pointer_position = Vector2.INF
	if enabled and _carried_item == null:
		var canvas := CanvasLayer.new()
		canvas.layer = 100
		add_child(canvas)
		_carried_item = TextureRect.new()
		_carried_item.name = "CarriedItem"
		_carried_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_carried_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_carried_item.size = Vector2(48, 48)
		canvas.add_child(_carried_item)
	_refresh_carried_item()
	if enabled:
		for shape: Input.CursorShape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
			Input.set_custom_mouse_cursor(null, shape)
	else:
		_apply_cursor()


func update_pointer(position: Vector2) -> void:
	_pointer_position = position
	_refresh_carried_item()


func _refresh_carried_item() -> void:
	if _carried_item == null: return
	_carried_item.visible = _system_pointer and _pointer_position.is_finite() and not _key.is_empty()
	if not _carried_item.visible: return
	var path: String = "res://art/ui/crops/%s.png" % _key
	if _carried_item.texture == null or _carried_item.texture.resource_path != path:
		_carried_item.texture = load(path)
	var view: Vector2 = get_viewport().get_visible_rect().size
	var point: Vector2 = _pointer_position + Vector2(22, 26)
	if point.x + 48 > view.x: point.x = _pointer_position.x - 54
	if point.y + 48 > view.y: point.y = _pointer_position.y - 54
	_carried_item.position = point.clamp(Vector2.ZERO, (view-Vector2(48,48)).max(Vector2.ZERO))
