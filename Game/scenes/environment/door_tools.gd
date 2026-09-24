extends Node3D
## Scene props own their appearance and identity, never farm state.
const CHAIR = preload("res://art/characters/farmer/chair.glb")
var chair: Node3D
var tools: Dictionary = {}
var _hovered: String = ""
var _outline: ShaderMaterial
var _hint_outline: ShaderMaterial
var _chair_hint: bool = false

func _ready() -> void:
	var environment: Node3D = get_parent()
	var pose := Transform3D(Basis(Vector3.UP,deg_to_rad(environment.plan.angles.veranda)),environment.plan.anchors.veranda)
	chair = CHAIR.instantiate()
	chair.name = "RestChair"
	add_child(chair)
	chair.position = pose * Vector3(-.90,.30,.05)
	chair.rotation.y = deg_to_rad(environment.plan.angles.veranda) - PI*.5
	tools["rest"] = chair
	# All working props are at the open front of the porch, clear of the door.
	for item: Array in [
		["harvest",Vector3(-2.25,.28,.28),0.0,0.0],
		["weed",Vector3(-1.55,.28,.22),90.0,-45.0],
		["water",Vector3(.65,.28,.24),0.0,0.0],
		["till",Vector3(1.38,.28,.34),0.0,-26.0]]:
		var resource_path: String = "res://art/characters/farmer/hoe.glb" if item[0] == "till" else "res://art/tools/%s.glb" % item[0]
		var prop: Node3D = load(resource_path).instantiate()
		prop.name = item[0]
		add_child(prop)
		prop.position = pose * item[1]
		prop.basis = pose.basis * Basis(Vector3.RIGHT,deg_to_rad(item[3])) * Basis(Vector3.UP,deg_to_rad(item[2]))
		if item[0] == "till":
			# The previous approved hoe has a baked-in lateral lean.
			prop.basis = pose.basis * Basis(Vector3.RIGHT,deg_to_rad(-20)) * Basis(Vector3.UP,PI*.5) * Basis(Vector3.FORWARD,deg_to_rad(18))
		_ground(prop,pose.origin.y+.28)
		tools[item[0]] = prop
	_outline = ShaderMaterial.new()
	_outline.shader = preload("res://scenes/environment/tool_outline.gdshader")
	_hint_outline = _outline.duplicate()
	_hint_outline.set_shader_parameter("width", .022)
	_hint_outline.set_shader_parameter("tint", Color(1.0, .88, .42))

func _ground(prop: Node3D, floor_y: float) -> void:
	var bottom: float = INF
	for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
		for surface: int in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				bottom = minf(bottom, mesh.to_global(point).y)
	if is_finite(bottom): prop.global_position.y += floor_y-bottom

func tool_for_mesh(mesh: MeshInstance3D) -> String:
	for id: String in tools:
		if tools[id].is_ancestor_of(mesh) or tools[id]==mesh: return id
	return ""

func set_hover(id: String) -> void:
	if not tools.has(id): id = ""
	if _hovered == id: return
	_hovered = id
	_refresh_outline()

func set_chair_hint(enabled: bool) -> void:
	if _chair_hint == enabled: return
	_chair_hint = enabled
	_refresh_outline()

func _refresh_outline() -> void:
	for tool: String in tools:
		for mesh: MeshInstance3D in tools[tool].find_children("*","MeshInstance3D",true,false):
			mesh.material_overlay = _hint_outline if tool == "rest" and _chair_hint else (_outline if tool == _hovered else null)

func may_hit(camera: Camera3D, point: Vector2) -> bool:
	var start: Vector3 = camera.project_ray_origin(point)
	var end: Vector3 = start + camera.project_ray_normal(point)*camera.far
	for prop: Node3D in tools.values():
		for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			if mesh.mesh.get_aabb().intersects_segment(inverse*start,inverse*end)!=null: return true
	return false
