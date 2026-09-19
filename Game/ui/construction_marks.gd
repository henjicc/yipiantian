extends Node3D
## World-anchored controls retain a readable width at every camera distance.
const INK:=Color("414c3e")
const PAPER:=Color("f6edd9")
var _lines: Array[Dictionary]=[]
var _handles: Array[Dictionary]=[]
var _canvas: Control
var _view: Transform3D
var _projection: Projection

func _ready() -> void:
	var layer:=CanvasLayer.new();layer.layer=14;add_child(layer)
	_canvas=Control.new();layer.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_marks)
	_canvas.resized.connect(_canvas.queue_redraw)
	set_process(false)

func clear_marks() -> void:
	_lines.clear();_handles.clear();_canvas.queue_redraw();set_process(false)

func outline(points: PackedVector3Array,tint: Color,closed: bool=true) -> void:
	if points.size()<2: return
	_lines.append({"points":points,"tint":tint,"closed":closed})
	_canvas.queue_redraw();set_process(true)

func handle(at: Vector3,tint: Color) -> void:
	_handles.append({"at":at,"tint":tint})
	_canvas.queue_redraw();set_process(true)

func _process(_delta: float) -> void:
	var camera: Camera3D=get_viewport().get_camera_3d()
	if camera==null: return
	var projection: Projection=camera.get_camera_projection()
	if camera.global_transform!=_view or projection!=_projection:
		_view=camera.global_transform;_projection=projection;_canvas.queue_redraw()

func _draw_marks() -> void:
	var camera: Camera3D=get_viewport().get_camera_3d()
	if camera==null: return
	for line: Dictionary in _lines:
		var screen:=PackedVector2Array()
		for point: Vector3 in line.points:
			if camera.is_position_behind(point): screen.clear();break
			screen.append(camera.unproject_position(point))
		if screen.size()<2: continue
		if line.closed: screen.append(screen[0])
		_canvas.draw_polyline(screen,INK,5.0,true)
		_canvas.draw_polyline(screen,line.tint,2.5,true)
	for marker: Dictionary in _handles:
		if camera.is_position_behind(marker.at): continue
		var point: Vector2=camera.unproject_position(marker.at)
		_canvas.draw_circle(point,8.0,INK,true,-1,true)
		_canvas.draw_circle(point,6.0,PAPER,true,-1,true)
		_canvas.draw_circle(point,3.5,marker.tint,true,-1,true)
