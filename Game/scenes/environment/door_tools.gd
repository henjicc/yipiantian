extends Node3D
## Scene props own their appearance and identity, never farm state.
const HOE = preload("res://art/characters/farmer/hoe.glb")
const CHAIR = preload("res://art/characters/farmer/chair.glb")
var hoe: Node3D
var chair: Node3D
var tools: Dictionary = {}
var _hovered: String = ""
var _outline: ShaderMaterial

func _ready() -> void:
	var environment: Node3D = get_parent()
	var pose := Transform3D(Basis(Vector3.UP,deg_to_rad(environment.plan.angles.veranda)),environment.plan.anchors.veranda)
	hoe = HOE.instantiate()
	hoe.name = "DoorHoe"
	add_child(hoe)
	hoe.position = pose * Vector3(1.78,.28,.48)
	# The generated handle already leans sideways. Correct that baked-in lean
	# before turning its blade toward the porch, rather than tilting the root blindly.
	hoe.basis = pose.basis * Basis(Vector3.UP, PI*.5) * Basis(Vector3.FORWARD, deg_to_rad(18))
	_ground(hoe, pose.origin.y + .28)
	_lean_against_rail(pose)
	chair = CHAIR.instantiate()
	chair.name = "RestChair"
	add_child(chair)
	chair.position = pose * Vector3(-.90,.30,.10)
	chair.rotation.y = deg_to_rad(environment.plan.angles.veranda) - PI*.5
	tools["weed"] = hoe
	for item: Array in [["sow","seed_basket",Vector3(-1.95,.28,-.03)], ["water","watering_can",Vector3(1.02,.28,-.03)]]:
		var prop: Node3D = load("res://art/characters/farmer/%s.glb" % item[1]).instantiate()
		prop.name = item[1]
		add_child(prop)
		prop.position = pose * item[2]
		prop.rotation.y = deg_to_rad(environment.plan.angles.veranda)
		tools[item[0]] = prop
	_outline = ShaderMaterial.new()
	_outline.shader = preload("res://scenes/environment/tool_outline.gdshader")

func _lean_against_rail(porch: Transform3D) -> void:
	# Match the actual handle surface at the upper rail (y=.95, z=.38,
	# radius=.033), so a regenerated model cannot silently float or cut through it.
	var forward_edge: float = -INF
	for mesh: MeshInstance3D in hoe.find_children("*","MeshInstance3D",true,false):
		var to_porch: Transform3D = porch.affine_inverse() * mesh.global_transform
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for index: int in range(0,faces.size(),3):
			for edge: int in 3:
				var a: Vector3 = to_porch * faces[index+edge]
				var b: Vector3 = to_porch * faces[index+(edge+1)%3]
				if (a.y-.95)*(b.y-.95)>0 or is_equal_approx(a.y,b.y): continue
				forward_edge = maxf(forward_edge,a.lerp(b,(.95-a.y)/(b.y-a.y)).z)
	if is_finite(forward_edge): hoe.position += porch.basis * Vector3(0,0,.345-forward_edge)

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
	for tool: String in tools:
		for mesh: MeshInstance3D in tools[tool].find_children("*","MeshInstance3D",true,false):
			mesh.material_overlay = _outline if tool==id else null

func may_hit(camera: Camera3D, point: Vector2) -> bool:
	var start: Vector3 = camera.project_ray_origin(point)
	var end: Vector3 = start + camera.project_ray_normal(point)*camera.far
	for prop: Node3D in tools.values():
		for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			if mesh.mesh.get_aabb().intersects_segment(inverse*start,inverse*end)!=null: return true
	return false
