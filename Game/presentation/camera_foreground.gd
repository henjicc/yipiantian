extends Node3D
## Layered, textured near-shore scenery rooted outside the two lower frame edges.
## Instances stay in world space so orbit and dolly retain real parallax.
const PlantWind = preload("res://presentation/plant_wind.gd")
const ROOT := "res://art/environment/"
var _camera: Camera3D
var _groups: Array[Dictionary] = []
var _meshes: Array[MeshInstance3D] = []
var _wind := PlantWind.new()
var _amount: float = 0.0
var _wanted: bool = true
var _materials: Dictionary = {}
var _water_plants: Array[Dictionary] = []
var _motion_time: float = 0.0


func configure(camera: Camera3D) -> void:
	_camera = camera
	top_level = true
	global_transform = Transform3D.IDENTITY
	# Bases extend beyond the image, instead of exposing two complete floating pads.
	_add_bank(Vector2(.055, 1.10), 0)
	_add_bank(Vector2(.945, 1.11), 1)
	_add_reed_shore(Vector2(.265, 1.015), 0)
	_add_reed_shore(Vector2(.735, 1.035), 1)
	_add_floating_patch(Vector2(.43, .90), 1.30, 124.0)
	_add_floating_patch(Vector2(.64, .86), 1.10, 247.0)
	visible = false


func set_overview_visible(value: bool, immediate: bool = false) -> void:
	_wanted = value
	if immediate:
		_amount = 1.0 if value else 0.0
		visible = value


func _add_bank(screen_anchor: Vector2, side: int) -> void:
	var screen: Vector2 = screen_anchor * _camera.get_viewport().get_visible_rect().size
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var ray: Vector3 = _camera.project_ray_normal(screen)
	var ground: Vector3 = origin + ray * ((-.18 - origin.y) / ray.y)
	var bank := Node3D.new()
	bank.name = "NearBankLeft" if side == 0 else "NearBankRight"
	add_child(bank)
	bank.position = ground
	bank.rotation.y = atan2(_camera.global_basis.z.x, _camera.global_basis.z.z)
	var inward: float = 1.0 if side == 0 else -1.0
	# A tall broken stone shoulder and smaller, lower water-edge stones. Preserve
	# the original atlas and mesh, rather than flattening everything into one paint.
	for item: Array in [
		[4, Vector3(-.6, -.40, .6), Vector3(4.8, 5.0, 4.4), 25.0],
		[0, Vector3(1.0, -.22, -.15), Vector3(3.8, 4.1, 3.2), 112.0],
		[3, Vector3(2.0, -.23, .9), Vector3(3.0, 2.4, 2.8), 68.0],
		[2, Vector3(.5, -.24, -1.05), Vector3(2.9, 3.0, 2.9), 140.0],
	]:
		var point: Vector3 = item[1]
		point.x *= inward
		_instance(bank, "modules/stone_%d.glb" % item[0], point, item[2], item[3] * inward)
	if side == 0:
		# The taller left mass enters from the side; the crown is not a leaf-card cutout.
		_instance(bank, "osmanthus/osmanthus_high.glb", Vector3(-.5,.22,.0), Vector3.ONE*1.30, 45, "osmanthus")
		_instance(bank, "bamboo/bamboo_high.glb", Vector3(1.0,.30,.2), Vector3.ONE*.78, 20, "bamboo")
	else:
		_instance(bank, "bamboo/bamboo_high.glb", Vector3(-.4,.24,.15), Vector3.ONE*1.12, -25, "bamboo")
		_instance(bank, "osmanthus/osmanthus_high.glb", Vector3(.25,.10,1.0), Vector3.ONE*.70, -40, "osmanthus")
	# Several small clumps at different depths soften stone/plant joins, with
	# sparse pale flower heads rather than uniformly packed tall branches.
	for index: int in 5:
		var point := Vector3(inward*(.25+index*.36), .36 if index < 3 else .12, -.65+index*.35)
		_instance(bank, "flowers/flowers_high.glb", point, Vector3.ONE*(1.5+index*.12), 31+index*67, "flowers")
	for index: int in 3:
		_instance(bank, "bamboo/bamboo_high.glb", Vector3(inward*(.4+index*.65), .10, .8+index*.3), Vector3.ONE*(.36+index*.07), 80+index*71, "bamboo")
	_groups.append({"node": bank, "anchor": ground, "height": 4.8})


func _water_point(uv: Vector2) -> Vector3:
	var pixel: Vector2 = uv * _camera.get_viewport().get_visible_rect().size
	var origin: Vector3 = _camera.project_ray_origin(pixel)
	var ray: Vector3 = _camera.project_ray_normal(pixel)
	return origin + ray * ((-.25-origin.y)/ray.y)


func _add_reed_shore(uv: Vector2, side: int) -> void:
	var shore := Node3D.new()
	shore.name = "ReedShoreLeft" if side == 0 else "ReedShoreRight"
	add_child(shore)
	shore.position = _water_point(uv)
	shore.rotation.y = atan2(_camera.global_basis.z.x, _camera.global_basis.z.z)
	var direction: float = -1.0 if side == 0 else 1.0
	# The broad base continues below the frame; a lower broken tip reaches toward
	# the open channel. This is not a new island with its whole perimeter exposed.
	for index: int in 4:
		_instance(shore, "modules/stone_%d.glb" % [0,3,1,4][index],
			Vector3(direction*(index*.65-.6), -.32, .4+index*.16),
			Vector3(2.5,2.3 if index == 3 else 1.4,2.2), 38+index*57)
	var random := RandomNumberGenerator.new()
	random.seed = 917680 + side
	for band: int in 3:
		var leaves := SurfaceTool.new()
		leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Dense at the bank, irregular open tips above: thin, curved blades rather
		# than another scaled bamboo/tree silhouette.
		for blade: int in 34:
			var base := Vector3(random.randf_range(-1.15,1.15), random.randf_range(.03,.12), random.randf_range(.0,.85))
			var angle: float = random.randf_range(0,TAU)
			var length: float = random.randf_range(1.1,2.4) * (1.0 if side == 0 else .78)
			var width: float = random.randf_range(.045,.085)
			var outward := Vector3(cos(angle),0,sin(angle))
			var across := Vector3(-sin(angle),0,cos(angle))
			var bend: float = random.randf_range(.28,.65)
			for segment: int in 12:
				for half: float in [-1.0,1.0]:
					var a: float = segment/12.0
					var b: float = (segment+1)/12.0
					var corners: Array[Vector2] = [Vector2(a,0),Vector2(a,half),Vector2(b,half),Vector2(b,0)]
					# The blade ends in one tip; omit its otherwise collapsed triangle.
					var indices: Array = [0,1,2] if segment == 11 else [0,1,2,0,2,3]
					for corner: int in indices:
						var t: float = corners[corner].x
						var edge: float = corners[corner].y
						var taper: float = sin(PI*(.10+.90*t))
						var point: Vector3 = base + Vector3.UP*length*(t-.22*t*t*t) + outward*length*bend*t*t
						point += across*edge*width*taper + outward*absf(edge)*width*taper*.20
						var tangent := Vector3.UP*(1.0-.66*t*t) + outward*2.0*bend*t
						leaves.set_normal(tangent.cross(across+outward*half*.20).normalized())
						leaves.add_vertex(point)
		var mesh := MeshInstance3D.new()
		mesh.name = "ReedBlades%d" % band
		leaves.index()
		mesh.mesh = leaves.commit()
		var material := ShaderMaterial.new()
		material.shader = preload("res://scenes/environment/pigment.gdshader")
		material.set_shader_parameter("base_color", [Color("617341"),Color("778049"),Color("9a905b")][band])
		material.set_shader_parameter("wash_scale", 10.0)
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shore.add_child(mesh)
		_meshes.append(mesh)
		_wind.apply(mesh,"grass")
		mesh.set_instance_shader_parameter("haze_exempt",1.0)
		mesh.set_instance_shader_parameter("wind_motion",Vector4(.035,.10,0,.007))
	_groups.append({"node": shore, "anchor": shore.position, "height": 1.95})


func _add_floating_patch(uv: Vector2, size: float, yaw: float) -> void:
	var patch := Node3D.new()
	patch.name = "ForegroundLily%d" % _water_plants.size()
	add_child(patch)
	# The existing P2 asset's root sits 0.15 m below the floating leaves. Scale
	# that immersion with the model so its stem does not hang above the water.
	patch.position = _water_point(uv) - Vector3.UP*.15*size
	_instance(patch,"lotus/lotus_high.glb",Vector3.ZERO,Vector3.ONE*size,yaw,"lotus")
	_water_plants.append({"node": patch, "origin": patch.position})


func _instance(parent: Node3D, path: String, at: Vector3, size: Vector3, yaw: float, plant: String = "") -> void:
	var model: Node3D = (load(ROOT + path) as PackedScene).instantiate()
	parent.add_child(model)
	model.position = at
	model.scale = size
	model.rotation.y = deg_to_rad(yaw)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.lod_bias = 1.0
		for surface: int in mesh.mesh.get_surface_count():
			var source: StandardMaterial3D = mesh.get_active_material(surface)
			var key: int = source.get_instance_id()
			if not _materials.has(key):
				var material: StandardMaterial3D = source.duplicate()
				material.albedo_color *= Color(.72,.76,.68) if not plant.is_empty() else Color(.70,.73,.68)
				material.roughness = .96
				material.metallic_specular = .10
				_materials[key] = material
			mesh.set_surface_override_material(surface,_materials[key])
		_meshes.append(mesh)
	if not plant.is_empty():
		_wind.apply(model,plant)
		# Framing plants are near the lens, not distant islands in the lake mist.
		for mesh: Node in model.find_children("*", "MeshInstance3D", true, false):
			mesh.set_instance_shader_parameter("haze_exempt",1.0)


func _process(delta: float) -> void:
	if _camera == null: return
	_amount = move_toward(_amount,1.0 if _wanted else 0.0,delta*3.5)
	visible = _amount > .001
	if visible:
		_motion_time += delta
		for index: int in _water_plants.size():
			var patch: Dictionary = _water_plants[index]
			var phase: float = _motion_time*.72+index*1.7
			patch.node.position = patch.origin + Vector3(sin(phase)*.014,sin(phase*.8)*.012,cos(phase)*.009)
			patch.node.rotation.z = sin(phase*.8)*.012
	for mesh: MeshInstance3D in _meshes:
		mesh.transparency = 1.0 - _amount
	# World-space scenery uses normal depth occlusion and frustum clipping.
	# Never hide a whole bank because a projected sample crosses the farm.
