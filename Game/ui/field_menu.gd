extends CanvasLayer
## Presentation only: the caller owns the captured cell and commits each action.
signal action_requested(tool: String, crop: String)
const Crops = preload("res://farm/crop_catalog.gd")
const ThemeFactory = preload("res://ui/farm_theme.gd")
var active: bool = false
var veil: Control
var cards: Control
var anchor: Vector2

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
	_clear()
	active = true
	veil.show()
	var view := get_viewport().get_visible_rect().size
	anchor = Vector2(clampf(point.x, 166, view.x-166), clampf(point.y, 160, view.y-55))
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
		button.picture = load("res://art/ui/crops/porch-%s.png" % id if id in ["sow","water"] else "res://art/ui/crops/%s.png" % id)
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

func present_seeds(point: Vector2) -> void:
	present(point, {"crop_id":"", "ground":"ready"})
	_show_seeds()

func _show_seeds() -> void:
	cards.hide()
	var panel := PanelContainer.new()
	panel.name = "Seeds"
	veil.add_child(panel)
	panel.position = Vector2(clampf(anchor.x-188, 8, get_viewport().get_visible_rect().size.x-384), maxf(8,anchor.y-290))
	var grid := GridContainer.new()
	grid.columns = 4
	panel.add_child(grid)
	for id: String in Crops.crop_ids():
		var button := Button.new()
		button.name = id
		button.text = Crops.definition(id).name
		button.icon = load(Crops.icon_path(id))
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = true
		button.custom_minimum_size = Vector2(92,84)
		button.add_theme_constant_override("icon_max_width",42)
		grid.add_child(button)
		button.pressed.connect(func() -> void: _choose("sow",id))
	_fit_seed_panel.call_deferred(panel)

func _fit_seed_panel(panel: PanelContainer) -> void:
	if not is_instance_valid(panel) or not panel.is_inside_tree(): return
	var view: Vector2 = get_viewport().get_visible_rect().size
	panel.reset_size()
	panel.position = Vector2(clampf(anchor.x-panel.size.x*.5,8,view.x-panel.size.x-8),clampf(anchor.y-panel.size.y-14,8,view.y-panel.size.y-56))
	veil.get_node("Cancel").position = Vector2(panel.position.x+panel.size.x*.5-36,panel.position.y+panel.size.y+8)

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
