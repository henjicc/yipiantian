extends Control
## A metric plan view: edits only emit intent; no world or crop mutations.
signal field_selected(index: int)
signal field_moved(index: int, point: Vector2)
signal drag_finished
var plan: RefCounted
var obstacles: Dictionary = {}
var selected: int = 0
var invalid: Array[String] = []
var occupied: Dictionary = {}
var _bounds := Rect2(-16,-10,27,27)
var _scale: float = 1.0
var _origin := Vector2.ZERO
var _dragging: bool = false
var _offset := Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(400,340)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)

func present(value: RefCounted, blocks: Dictionary, index: int, issues: Array[String]) -> void:
	plan = value
	obstacles = blocks
	selected = index
	invalid = issues
	_bounds=plan.land_bounds().grow(1.5).expand(Vector2(10,4))
	queue_redraw()

func world_to_map(point: Vector2) -> Vector2:
	return _origin+(point-_bounds.position)*_scale

func _polygon(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points: result.append(world_to_map(point))
	return result

func _draw() -> void:
	draw_style_box(preload("res://ui/farm_theme.gd").paper(Color("c2d4cf"),16),Rect2(Vector2.ZERO,size))
	if plan == null: return
	# Scale follows the shore, never the dragged field, keeping its pointer stable.
	_scale = minf((size.x-32)/_bounds.size.x,(size.y-32)/_bounds.size.y)
	_origin = (size-_bounds.size*_scale)*.5
	draw_colored_polygon(_polygon(preload("res://layout/bank_geometry.gd").contour(plan.rim)),Color("b5af86"))
	draw_colored_polygon(_polygon(plan.plateau()),Color("c4cb9d"))
	for block: PackedVector2Array in obstacles.values():
		draw_colored_polygon(_polygon(block),Color("8b8976"))
	for path: PackedVector3Array in plan.paths:
		var line := PackedVector2Array()
		for p: Vector3 in path: line.append(world_to_map(Vector2(p.x,p.z)))
		if line.size()>1: draw_polyline(line,Color("efe8cc"),maxf(2,.4*_scale),true)
	for span: Dictionary in plan.fences:
		draw_line(world_to_map(Vector2(span.a.x,span.a.z)),world_to_map(Vector2(span.b.x,span.b.z)),Color("866d44"),2,true)
	var font: Font = get_theme_default_font()
	for i: int in plan.fields.size():
		var field: Dictionary = plan.fields[i]
		var polygon: PackedVector2Array = _polygon(plan.field_polygon(i))
		var bad: bool = false
		for issue: String in invalid:
			if issue.begins_with(field.id+":"): bad=true
		draw_colored_polygon(polygon,Color("b86550") if bad else Color("997955"))
		var pose: Transform3D = plan.field_transform(i)
		for cell: String in field.cells:
			var p: Vector3 = pose*plan.cell_position(field,cell)
			draw_circle(world_to_map(Vector2(p.x,p.z)),2.3,Color("dbe2b0") if occupied.get(field.id,[]).has(cell) else Color("baa482"))
		polygon.append(polygon[0])
		draw_polyline(polygon,Color("faf3d9") if i==selected else Color("735e43"),3 if i==selected else 1,true)
		var at: Vector2 = world_to_map(Vector2(field.position.x,field.position.z))
		draw_string(font,at+Vector2(-5,7),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff7dd"))
	for key: String in ["house","kitchen","bridge","mooring"]:
		var at: Vector3 = plan.anchors[key]
		var label: String = {"house":"居所","kitchen":"厨房","bridge":"桥","mooring":"泊位"}[key]
		draw_string(font,world_to_map(Vector2(at.x,at.z))+Vector2(-18,0),label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("454b3f"))

func _gui_input(event: InputEvent) -> void:
	if plan == null: return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			cancel_drag()
			accept_event()
			return
		_dragging=false
		if event.pressed:
			var point: Vector2 = (event.position-_origin)/_scale+_bounds.position
			for i: int in range(plan.fields.size()-1,-1,-1):
				if Geometry2D.is_point_in_polygon(point,plan.field_polygon(i)):
					selected=i
					_offset=Vector2(plan.fields[i].position.x,plan.fields[i].position.z)-point
					_dragging=true
					field_selected.emit(i)
					break
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			cancel_drag()
			return
		var point: Vector2=(event.position-_origin)/_scale+_bounds.position+_offset
		field_moved.emit(selected,point.snapped(Vector2.ONE*.1))
		accept_event()

func cancel_drag() -> void:
	var was_dragging: bool=_dragging
	_dragging=false
	if was_dragging: drag_finished.emit()

func is_dragging() -> bool:
	return _dragging
