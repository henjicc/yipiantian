extends CanvasLayer
## Presentation only: the caller owns the captured cell and commits each action.
signal action_requested(tool: String, crop: String)

const Crops = preload("res://farm/crop_catalog.gd")
const ThemeFactory = preload("res://ui/farm_theme.gd")
const PAPER_TEXTURE: Texture2D = preload("res://art/ui/pigment/wash-tile.png")
const CROPS_PER_RING: int = 6
const PAPER := ThemeFactory.PAPER
const CELADON := ThemeFactory.Tokens.WASH_HOVER
const CELADON_EDGE := ThemeFactory.LEAF
const INK := ThemeFactory.INK

var active: bool = false
var veil: Control
var cards: Control
var anchor: Vector2
var _trellis: bool = false


class Petal extends Button:
	var polygon := PackedVector2Array()
	var caption: String
	var picture: Texture2D
	var center: Vector2

	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point, polygon)

	func _draw() -> void:
		var over: bool = is_hovered() and not disabled
		var color := CELADON if over else PAPER
		if disabled:
			color = ThemeFactory.Tokens.DISABLED
		var paper_uvs := PackedVector2Array()
		for point: Vector2 in polygon:
			paper_uvs.append(point / 216.0)
		draw_colored_polygon(polygon, color, paper_uvs, PAPER_TEXTURE)
		var edge := polygon.duplicate()
		edge.append(polygon[0])
		draw_polyline(edge, CELADON_EDGE if over else ThemeFactory.EDGE, 1.4, true)
		if picture:
			draw_texture_rect(picture, Rect2(center - Vector2(24, 31), Vector2(48, 48)), false, Color(1, 1, 1, .45 if disabled else 1.0))
		var font: Font = ThemeFactory.FONT
		var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(font, center + Vector2(-width * .5, 35), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)

	func _ready() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)


class RingSegment extends Button:
	var polygon := PackedVector2Array()
	var caption: String
	var picture: Texture2D
	var center: Vector2
	var ring_index: int = 0
	var font_size: int = 19
	var icon_size: float = 60.0

	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point, polygon)

	func _draw() -> void:
		var over: bool = is_hovered() and not disabled
		var fill := CELADON if over else PAPER
		if disabled:
			fill = ThemeFactory.Tokens.DISABLED
		var paper_uvs := PackedVector2Array()
		for point: Vector2 in polygon:
			paper_uvs.append(point / 216.0)
		draw_colored_polygon(polygon, fill, paper_uvs, PAPER_TEXTURE)
		var edge := polygon.duplicate()
		edge.append(polygon[0])
		draw_polyline(edge, CELADON_EDGE if over else ThemeFactory.EDGE, 1.8 if over else 1.4, true)
		var font: Font = ThemeFactory.FONT
		if picture:
			var icon_rect := Rect2(center + Vector2(-icon_size * .5, -icon_size * .68), Vector2(icon_size, icon_size))
			draw_texture_rect(picture, icon_rect, false, Color(1, 1, 1, .45 if disabled else 1.0))
			var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, center + Vector2(-width * .5, icon_size * .62), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
		else:
			var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, center + Vector2(-width * .5, font_size * .35), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
	func _ready() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)


class RingFrame extends Control:
	var center: Vector2
	var outer_radius: float
	var ring_boundaries := PackedFloat32Array()

	func _draw() -> void:
		draw_circle(center, outer_radius + 2.0, PAPER, true, -1.0, true)
		draw_arc(center, outer_radius + 2.0, 0.0, TAU, 512, ThemeFactory.EDGE, 1.2, true)
		for radius: float in ring_boundaries:
			draw_arc(center, radius, 0.0, TAU, 512, ThemeFactory.EDGE, 1.0, true)


func _ready() -> void:
	layer = 18
	veil = Control.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.theme = ThemeFactory.create()
	add_child(veil)
	veil.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			veil.accept_event()
			if event.pressed:
				dismiss())
	get_viewport().size_changed.connect(dismiss)
	veil.hide()


func present(point: Vector2, cell: Dictionary) -> void:
	_trellis = cell.get("field_id", "") == "trellis"
	_clear()
	active = true
	veil.show()
	var view := get_viewport().get_visible_rect().size
	anchor = Vector2(clampf(point.x, 166, view.x - 166), clampf(point.y, 160, view.y - 110))
	cards = Control.new()
	veil.add_child(cards)
	cards.position = anchor - Vector2(160, 160)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var harvest: bool = cell.get("stage", "") == "mature"
	var till: bool = cell.get("ground", "ready") == "rough"
	var entries: Array = [["harvest" if harvest else "sow", "收获" if harvest else "播种"], ["water", "浇水"], ["till" if till else "weed", "开垦" if till else "除草"]]
	for i: int in 3:
		var id: String = entries[i][0]
		var button := Petal.new()
		button.name = id
		button.caption = entries[i][1]
		button.size = Vector2(320, 180)
		button.flat = true
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.focus_mode = Control.FOCUS_NONE
		var start: float = PI + i * PI / 3.0
		var finish: float = PI + (i + 1) * PI / 3.0
		button.polygon = _ring_polygon(Vector2(160, 160), 36.0, 150.0, start, finish)
		button.center = Vector2(160, 160) + Vector2.from_angle((start + finish) * .5) * 99
		button.picture = load("res://art/ui/crops/porch-sow.png" if id == "sow" else "res://art/ui/crops/%s.png" % id)
		var empty: bool = cell.get("crop_id", "").is_empty()
		button.disabled = (id == "sow" and (not empty or cell.get("ground", "ready") != "ready")) or (id == "water" and (empty or harvest or cell.get("watered", false))) or (id in ["weed", "till"] and (not empty or cell.get("ground", "ready") != ("weedy" if id == "weed" else "rough")))
		cards.add_child(button)
		button.pressed.connect(func() -> void:
			if id == "sow":
				_show_seeds()
			else:
				_choose(id, ""))
	_add_cancel_button(anchor, 72.0)


func present_seeds(point: Vector2, trellis: bool = false) -> void:
	present(point, {"crop_id": "", "ground": "ready", "field_id": "trellis" if trellis else ""})
	_show_seeds()


func _show_seeds(_page: int = 0) -> void:
	var point: Vector2 = anchor
	_clear()
	var ids: Array[String] = Crops.seeds(_trellis)
	if ids.is_empty():
		dismiss()
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var ring_count: int = ceili(ids.size() / float(CROPS_PER_RING))
	var outer_radius: float = clampf(minf(view.x, view.y) * (.27 if ring_count == 1 else .31), 190.0 if ring_count == 1 else 220.0, 238.0 if ring_count == 1 else 282.0)
	var extent: float = outer_radius + 6.0
	anchor = Vector2(clampf(point.x, extent, view.x - extent), clampf(point.y, extent, view.y - extent))
	cards = Control.new()
	cards.name = "Seeds"
	cards.size = Vector2.ONE * extent * 2.0
	cards.position = anchor - Vector2.ONE * extent
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(cards)
	var center := Vector2.ONE * extent
	var center_radius: float = outer_radius * .18
	var crop_inner: float = center_radius
	var crop_outer: float = outer_radius
	var ring_gap: float = 0.0
	var band_width: float = (crop_outer - crop_inner - ring_gap * (ring_count - 1)) / ring_count
	var frame := RingFrame.new()
	frame.name = "Frame"
	frame.size = cards.size
	frame.center = center
	frame.outer_radius = outer_radius
	for ring_index: int in ring_count:
		frame.ring_boundaries.append(crop_inner + ring_index * (band_width + ring_gap))
		frame.ring_boundaries.append(crop_inner + ring_index * (band_width + ring_gap) + band_width)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_child(frame)
	for ring_index: int in ring_count:
		var first: int = ring_index * CROPS_PER_RING
		var ring_ids: Array[String] = ids.slice(first, mini(first + CROPS_PER_RING, ids.size()))
		var inner_radius: float = crop_inner + ring_index * (band_width + ring_gap)
		var outer_ring_radius: float = inner_radius + band_width
		_add_crop_ring(ring_ids, center, inner_radius, outer_ring_radius, outer_radius, ring_index)
	_add_cancel_button(anchor, center_radius * 2.0)


func _add_crop_ring(ids: Array[String], center: Vector2, inner_radius: float, outer_radius: float, menu_radius: float, ring_index: int) -> void:
	var count: int = ids.size()
	if count == 0:
		return
	var step: float = TAU / count
	var start_offset: float = -PI * .5 - step * .5 + (step * .5 if ring_index % 2 == 1 else 0.0)
	for i: int in count:
		var id: String = ids[i]
		var start: float = start_offset + i * step
		var finish: float = start_offset + (i + 1) * step
		var button := RingSegment.new()
		button.name = id
		button.caption = Crops.definition(id).name
		button.picture = load(Crops.icon_path(id))
		button.size = cards.size
		button.flat = true
		button.ring_index = ring_index
		button.font_size = maxi(15, roundi(18.0 * menu_radius / 282.0))
		button.icon_size = clampf((outer_radius - inner_radius) * .48, 32.0, 48.0)
		button.polygon = _ring_polygon(center, inner_radius, outer_radius, start, finish)
		button.center = center + Vector2.from_angle((start + finish) * .5) * ((inner_radius + outer_radius) * .5)
		_configure_ring_button(button)
		cards.add_child(button)
		button.pressed.connect(_choose.bind("sow", id))


func _configure_ring_button(button: RingSegment) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _ring_polygon(center: Vector2, inner_radius: float, outer_radius: float, start: float, finish: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var samples: int = maxi(48, ceili(absf(finish - start) * 96.0))
	for step: int in samples + 1:
		polygon.append(center + Vector2.from_angle(lerpf(start, finish, float(step) / samples)) * outer_radius)
	for step: int in samples + 1:
		polygon.append(center + Vector2.from_angle(lerpf(finish, start, float(step) / samples)) * inner_radius)
	return polygon


func _add_cancel_button(at: Vector2, diameter: float) -> void:
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "取消"
	cancel.position = at - Vector2.ONE * diameter * .5
	cancel.size = Vector2.ONE * diameter
	cancel.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color: Color = ThemeFactory.Tokens.WASH_PRESSED if state == "pressed" else (ThemeFactory.Tokens.DISABLED if state == "disabled" else (CELADON if state == "hover" else PAPER))
		var style: StyleBoxFlat = ThemeFactory.paper(color, roundi(diameter * .5))
		style.set_border_width_all(1)
		style.shadow_size = 0
		cancel.add_theme_stylebox_override(state, style)
	veil.add_child(cancel)
	cancel.pressed.connect(dismiss)


func _choose(tool: String, crop: String) -> void:
	if not active:
		return
	dismiss()
	action_requested.emit(tool, crop)


func _clear() -> void:
	for child: Node in veil.get_children():
		veil.remove_child(child)
		child.queue_free()


func dismiss() -> void:
	active = false
	if veil:
		veil.hide()
