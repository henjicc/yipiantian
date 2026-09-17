extends CanvasLayer
## Cursor art and the carried crop/tool are presentation only; never receive input.

var badge: TextureRect
var _active: bool = false
var _key: String = ""
var _cursor_texture: ImageTexture


func _ready() -> void:
	layer = 100
	var source: Image = load("res://art/ui/crops/pointer.png").get_image()
	source.resize(48, 48, Image.INTERPOLATE_LANCZOS)
	_cursor_texture = ImageTexture.create_from_image(source)
	badge = TextureRect.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size = Vector2(52, 52)
	add_child(badge)
	badge.hide()


func show_tool(tool: String, crop_id: String, point: Vector2) -> void:
	var active: bool = not tool.is_empty()
	if active != _active:
		_active = active
		Input.set_custom_mouse_cursor(_cursor_texture if active else null, Input.CURSOR_ARROW, Vector2(11, 8) if active else Vector2.ZERO)
	badge.visible = active
	if not active:
		return
	var key: String = crop_id if tool == "sow" else tool
	if key != _key:
		_key = key
		badge.texture = load("res://art/ui/crops/%s.png" % key)
	var limit: Vector2 = get_viewport().get_visible_rect().size - badge.size
	badge.position = (point + Vector2(25, 24)).clamp(Vector2.ZERO, limit)


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)
