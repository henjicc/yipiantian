extends Node3D
## Interaction/preview only; accepted paths live in the lab's generation inputs.
const Kit = preload("res://scenes/procedural_lab/railing_kit.gd")
const EXTENT: float = 7.0
var lab: Node3D
var enabled: bool = false
var active: bool = false
var stroke: Array = []
var preview: Node3D
var pending: bool = false
var last_preview_ms: int = 0
var last_plan: Dictionary = {}

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if active and pending and Time.get_ticks_msec()-last_preview_ms >= 100:
		_refresh()

func handle_input(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		lab.status.text="已取消这次画线"
		return true
	if event is InputEventMouseMotion:
		_sample(event.position)
		return true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _point(event.position) == null or _over_ui(event.position):
				cancel()
				lab.status.text="已取消：请在地面内松开画笔"
			else:
				_sample(event.position,true)
				if not active: return true
				_refresh()
				var result: Dictionary = last_plan
				var accepted: Array = stroke.duplicate(true)
				cancel()
				if result.has("error"): lab.status.text=result.error
				else: lab.accept_stroke(accepted)
		return true
	return false

func handle_unhandled(event: InputEvent) -> bool:
	if not enabled or lab.busy: return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		lab.draw_button.button_pressed=false
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if lab.seed_input.text.strip_edges().is_empty():
			lab.status.text="请输入文字或数字种子"
			return true
		var point: Variant = _point(event.position)
		if point != null:
			active=true; stroke=[]; lab.dragging=0
			lab.desired_distance=lab.distance
			set_process(true)
			_sample(event.position)
			lab.status.text="正在画线 · 松开生成 · Esc 取消"
		return true
	return false

func cancel() -> void:
	active=false; pending=false; stroke=[]; last_plan={}
	set_process(false)
	if is_instance_valid(preview): preview.free()
	preview=null
	_show_previous(true)

func _sample(screen: Vector2,force: bool=false) -> void:
	if _over_ui(screen):
		cancel(); lab.status.text="已取消：画线进入了操作面板"
		return
	var point: Variant = _point(screen)
	if point == null:
		# Do not bridge across an excursion outside the drawing stage.
		cancel()
		lab.status.text="已取消：画线超出了地面"
		return
	var at: Vector2 = point
	if stroke.is_empty() or at.distance_to(Vector2(stroke[-1][0],stroke[-1][1])) >= (.015 if force else .08):
		if stroke.size() >= 1024:
			cancel(); lab.status.text="笔画过长，请缩短后重画"
			return
		stroke.append([at.x,at.y]); pending=true

func _point(screen: Vector2) -> Variant:
	var p: Dictionary = lab.current_plan.settings
	var origin: Vector3 = lab.camera.project_ray_origin(screen)
	var direction: Vector3 = lab.camera.project_ray_normal(screen)
	var divisor: float = direction.y-p.slope*direction.x
	if absf(divisor) < .0001: return null
	var t: float = (lab._stage_height(p)+.13+p.slope*origin.x-origin.y)/divisor
	if t <= 0: return null
	var point: Vector3 = origin+direction*t
	if absf(point.x) > EXTENT-.2 or absf(point.z) > EXTENT-.2: return null
	return Vector2(point.x,point.z)

func _over_ui(screen: Vector2) -> bool:
	return lab.panel.get_global_rect().has_point(screen) or lab.draw_button.get_parent().get_global_rect().has_point(screen)

func _refresh() -> void:
	pending=false; last_preview_ms=Time.get_ticks_msec()
	var options: Dictionary = lab.current_plan.settings.duplicate(true)
	options.stroke=stroke
	last_plan=Kit.plan(lab.seed_input.text,options,"railing")
	if is_instance_valid(preview): preview.free()
	preview=Node3D.new(); add_child(preview)
	preview.position.y=lab._stage_height(options)
	if not last_plan.has("error"):
		preview.add_child(Kit.build(last_plan))
		_show_previous(false)
	else: _show_previous(true)
	if stroke.size() < 2: return
	# A flat ribbon remains readable at the lab's reduced rendering resolution.
	var ribbon := ImmediateMesh.new()
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(stroke.size()-1):
		var a := Vector3(stroke[i][0],0,stroke[i][1])
		var b := Vector3(stroke[i+1][0],0,stroke[i+1][1])
		var side: Vector3 = (b-a).normalized().cross(Vector3.UP)*.025
		for vertex: Vector3 in [a-side,b-side,a+side,a+side,b-side,b+side]:
			vertex.y=Kit.ground(vertex.x,options.slope)+.025
			ribbon.surface_add_vertex(vertex)
	ribbon.surface_end()
	var line := MeshInstance3D.new()
	line.mesh=ribbon
	var material := StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.albedo_color=Color("d49064") if last_plan.has("error") else Color("91d8ba")
	line.material_override=material
	preview.add_child(line)

func _show_previous(show: bool) -> void:
	if not is_instance_valid(lab.world): return
	for holder: Node3D in lab.world.get_children(): holder.get_child(0).visible=show
