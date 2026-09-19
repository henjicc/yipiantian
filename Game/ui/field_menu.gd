extends CanvasLayer
## Presentation only: the caller owns the captured cell and commits each action.
signal action_requested(tool: String, crop: String)
const Crops = preload("res://farm/crop_catalog.gd")
const ThemeFactory = preload("res://ui/farm_theme.gd")
var active: bool = false
var veil: Control
var cards: Control
var anchor: Vector2
var _trellis: bool=false

class Petal extends Button:
	var polygon := PackedVector2Array()
	var caption: String
	var picture: Texture2D
	var center: Vector2
	func _has_point(point: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(point, polygon)
	func _draw() -> void:
		var over: bool = is_hovered() and not disabled
		var color := Color("dce3cd") if over else Color("f4ecd9")
		if disabled: color = Color("c8c3b4")
		draw_colored_polygon(polygon, color)
		var edge := polygon.duplicate(); edge.append(polygon[0])
		draw_polyline(edge, Color("6f7953") if over else Color("a48c66"), 2.0, true)
		if picture:
			draw_texture_rect(picture, Rect2(center - Vector2(24, 31), Vector2(48,48)), false, Color(1,1,1,.45 if disabled else 1.0))
		var font: Font = ThemeFactory.FONT
		var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(font, center + Vector2(-width*.5, 35), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("4b493d"))
	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

func _ready() -> void:
	layer = 18
	veil = Control.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.theme = ThemeFactory.create()
	add_child(veil)
	veil.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			veil.accept_event()
			if event.pressed: dismiss())
	get_viewport().size_changed.connect(dismiss)
	veil.hide()

func present(point: Vector2, cell: Dictionary) -> void:
	_trellis=cell.get("field_id","")=="trellis"
	_clear()
	active = true
	veil.show()
	var view := get_viewport().get_visible_rect().size
	anchor = Vector2(clampf(point.x, 166, view.x-166), clampf(point.y, 160, view.y-110))
	cards = Control.new()
	veil.add_child(cards)
	cards.position = anchor - Vector2(160,160)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var harvest: bool = cell.get("stage", "") == "mature"
	var till: bool = cell.get("ground", "ready") == "rough"
	var entries: Array = [["harvest" if harvest else "sow", "收获" if harvest else "播种"], ["water", "浇水"], ["till" if till else "weed", "开垦" if till else "除草"]]
	for i: int in 3:
		var id: String = entries[i][0]
		var button := Petal.new()
		button.name = id
		button.caption = entries[i][1]
		button.size = Vector2(320,180)
		button.flat = true
		for state: String in ["normal","hover","pressed","disabled","focus"]:
			button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		button.focus_mode = Control.FOCUS_NONE
		var start: float = PI + i*PI/3.0 + .025
		var finish: float = PI + (i+1)*PI/3.0 - .025
		for step: int in 25:
			button.polygon.append(Vector2(160,160) + Vector2.from_angle(lerpf(start,finish,step/24.0))*150)
		for step: int in 25:
			button.polygon.append(Vector2(160,160) + Vector2.from_angle(lerpf(finish,start,step/24.0))*44)
		button.center = Vector2(160,160) + Vector2.from_angle((start+finish)*.5)*99
		button.picture = load("res://art/ui/crops/porch-sow.png" if id == "sow" else "res://art/ui/crops/%s.png" % id)
		var empty: bool = cell.get("crop_id", "").is_empty()
		button.disabled = (id=="sow" and (not empty or cell.get("ground", "ready")!="ready")) or (id=="water" and (empty or harvest or cell.get("watered",false))) or (id in ["weed","till"] and (not empty or cell.get("ground", "ready") != ("weedy" if id=="weed" else "rough")))
		cards.add_child(button)
		button.pressed.connect(func() -> void:
			if id=="sow": _show_seeds()
			else: _choose(id, ""))
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "取消"
	cancel.position = anchor + Vector2(-36,10)
	cancel.size = Vector2(72,34)
	veil.add_child(cancel)
	cancel.pressed.connect(dismiss)

func present_seeds(point: Vector2, trellis: bool=false) -> void:
	present(point, {"crop_id":"", "ground":"ready", "field_id":"trellis" if trellis else ""})
	_show_seeds()

func present_tools(point: Vector2) -> void:
	present(point, {})
	_choice_fan(["water", "harvest", "weed", "till"], false)

func _show_seeds(page: int = 0) -> void:
	_choice_fan(Crops.seeds(_trellis).slice(page * 4, page * 4 + 4), true)
	var pages: int = ceili(Crops.seeds(_trellis).size() / 4.0)
	for step: int in [-1, 1]:
		var button := Button.new()
		button.name = "Previous" if step < 0 else "Next"
		button.text = "‹" if step < 0 else "›"
		button.position = anchor + Vector2(-100 if step < 0 else 58, 10)
		button.size = Vector2(42, 34)
		button.disabled = page + step < 0 or page + step >= pages
		veil.add_child(button)
		button.pressed.connect(func() -> void: _show_seeds(page + step))

func _choice_fan(ids: Array, seeds: bool) -> void:
	var point: Vector2 = anchor
	_clear()
	var view: Vector2 = get_viewport().get_visible_rect().size
	anchor = Vector2(clampf(point.x, 196, view.x - 196), clampf(point.y, 196, view.y - 110))
	cards = Control.new()
	cards.name = "Seeds" if seeds else "Tools"
	cards.position = anchor - Vector2(190, 190)
	cards.size = Vector2(380, 190)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(cards)
	var labels: Dictionary = {"water":"浇水", "harvest":"收获", "weed":"除草", "till":"开垦"}
	for i: int in ids.size():
		var id: String = ids[i]
		var button := Petal.new()
		button.name = id
		button.caption = Crops.definition(id).name if seeds else labels[id]
		button.picture = load(Crops.icon_path(id) if seeds else "res://art/ui/crops/%s.png" % id)
		button.size = cards.size
		button.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var start: float = PI + i * PI / ids.size() + .025
		var finish: float = PI + (i + 1) * PI / ids.size() - .025
		for step: int in 25:
			button.polygon.append(Vector2(190, 190) + Vector2.from_angle(lerpf(start, finish, step / 24.0)) * 184)
		for step: int in 25:
			button.polygon.append(Vector2(190, 190) + Vector2.from_angle(lerpf(finish, start, step / 24.0)) * 48)
		button.center = Vector2(190, 190) + Vector2.from_angle((start + finish) * .5) * 120
		cards.add_child(button)
		button.pressed.connect(func() -> void: _choose("sow" if seeds else id, id if seeds else ""))
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "取消"
	cancel.position = anchor + Vector2(-36, 10)
	cancel.size = Vector2(72, 34)
	veil.add_child(cancel)
	cancel.pressed.connect(dismiss)

func _choose(tool: String, crop: String) -> void:
	if not active: return
	dismiss()
	action_requested.emit(tool,crop)

func _clear() -> void:
	for child: Node in veil.get_children():
		veil.remove_child(child)
		child.queue_free()

func dismiss() -> void:
	active = false
	if veil: veil.hide()
