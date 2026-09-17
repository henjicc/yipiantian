extends Node3D
## Two grounded near-bank fragments, with real world depth and camera parallax.
## Geometry is authored here; no cropped tree crowns or camera-facing leaf cards.
const PlantWind = preload("res://presentation/plant_wind.gd")
var _camera: Camera3D
var _fields: Array = []
var _slots: Array[Node3D] = []
var _groups: Array[Dictionary] = []
var _meshes: Array[MeshInstance3D] = []
var _wind := PlantWind.new()
var _amount: float = 0.0
var _wanted: bool = true
var _last_camera: Transform3D
var _last_size := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}

func configure(camera: Camera3D, fields: Array, environment: Node3D) -> void:
	_camera = camera
	_fields = fields.duplicate()
	for slot: Dictionary in environment.get_decoration_slots():
		_slots.append(environment.get_slot_marker(slot.id))
	# Detach transform inheritance, not scene ownership. The two banks are placed
	# once in world space: dolly/orbit must produce depth/parallax, not follow HUD.
	top_level = true
	global_transform = Transform3D.IDENTITY
	_rng.seed = 89173
	_add_bank(Vector2(0.08, 1.02), 0)
	_add_bank(Vector2(0.92, 1.03), 1)
	visible = false
	_update_frame()

func set_overview_visible(value: bool, immediate: bool = false) -> void:
	_wanted = value
	if immediate:
		_amount = 1.0 if value else 0.0
		visible = value

func _material(color: Color) -> StandardMaterial3D:
	if _materials.has(color):
		return _materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.94
	mat.metallic_specular = 0.12
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[color] = mat
	return mat

func _mesh(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	_meshes.append(instance)
	return instance

func _add_bank(screen_anchor: Vector2, side: int) -> void:
	var screen: Vector2 = screen_anchor * _camera.get_viewport().get_visible_rect().size
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var ray: Vector3 = _camera.project_ray_normal(screen)
	var ground: Vector3 = origin + ray * ((-0.18 - origin.y) / ray.y)
	var bank := Node3D.new()
	bank.name = "NearBankLeft" if side == 0 else "NearBankRight"
	add_child(bank)
	bank.position = ground
	bank.rotation.y = deg_to_rad(25.0)
	var stone_color := Color("6e7969")
	for i: int in 3:
		var packed: PackedScene = load("res://art/environment/modules/stone_%d.glb" % i)
		var rock: Node3D = packed.instantiate()
		bank.add_child(rock)
		rock.position = Vector3((i-1)*1.1, -.20 + i*.04, i*.22)
		rock.scale = Vector3(2.5, 2.8, 1.9)
		rock.rotation.y = .45*i
		for node: Node in rock.find_children("*", "MeshInstance3D", true, false):
			var geometry: MeshInstance3D = node
			geometry.material_override = _material(stone_color.lightened(i*.035))
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			geometry.lod_bias = 128.0
			_meshes.append(geometry)
	# Sparse connected branches emerge from the bank; varied leaf pitch/curvature
	# remains readable even with DOF disabled, rather than relying on blur to hide it.
	var stems := Node3D.new()
	bank.add_child(stems)
	for branch_index: int in (4 if side == 0 else 3):
		var base := Vector3(_rng.randf_range(-.5,.5), .12, _rng.randf_range(-.25,.25))
		var lean: float = -0.30 if side == 0 else 0.35
		var tip := base + Vector3(lean + branch_index*.16, (3.0 + branch_index*.35 if side == 0 else 1.7 + branch_index*.36), -.35 + branch_index*.29)
		var bend := Vector3(lean*1.4, .15, .24)
		var previous: Vector3 = base
		for segment: int in 6:
			var next: Vector3 = _branch_point(base, tip, bend, float(segment+1)/6.0)
			_add_stem(stems, previous, next, .018*(1.0-float(segment)*.11))
			previous = next
		for j: int in 7:
			var t: float = .24 + j*.105
			var joint: Vector3 = _branch_point(base,tip,bend,t)
			var angle: float = j*2.4 + branch_index*.8
			var direction := Vector3(cos(angle),.25+_rng.randf()*.22,sin(angle)*.7).normalized()
			var end: Vector3 = joint + direction * _rng.randf_range(.20,.43)
			_add_stem(stems,joint,end,.007)
			for leaf_index: int in 2:
				var leaf := _mesh(stems,_leaf_mesh(_rng.randf_range(.38,.60),_rng.randf_range(.10,.16)),_material(Color("5d7848").lightened(float(_rng.randi_range(0,2))*.08)),joint.lerp(end,.6+leaf_index*.4))
				var leaf_direction: Vector3 = (direction + Vector3(_rng.randf_range(-.3,.3),_rng.randf_range(-.35,.45),_rng.randf_range(-.3,.3))).normalized()
				leaf.quaternion = Quaternion(Vector3.UP,leaf_direction)
				leaf.rotate_object_local(Vector3.UP,_rng.randf_range(-.8,.8))
				leaf.set_meta("foreground_leaf",true)
	# Distinct lower grass layer sits 0.8m behind the branches.
	for j: int in 13:
		var grass := _mesh(bank,_leaf_mesh(_rng.randf_range(.45,.85),.032),_material(Color("72844f")),Vector3(_rng.randf_range(-1.15,1.15),.16,_rng.randf_range(-.7,-.3)))
		grass.rotation = Vector3(_rng.randf_range(-.3,.3),_rng.randf_range(-PI,PI),_rng.randf_range(-.5,.5))
		grass.set_meta("foreground_leaf",true)
	_merge_bank(bank)
	_groups.append({"node":bank,"anchor":ground})

func _merge_bank(bank: Node3D) -> void:
	# Fixed palette and static local transforms: one surface per material per bank.
	# Leaves keep the shared wind shader with the bank base as the stationary root.
	var surfaces: Dictionary = {}
	var moving: Dictionary = {}
	for node: Node in bank.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		var material: Material = mesh.material_override
		if not surfaces.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[material] = surface
			moving[material] = mesh.has_meta("foreground_leaf")
		surfaces[material].append_from(mesh.mesh,0,bank.global_transform.affine_inverse()*mesh.global_transform)
		_meshes.erase(mesh)
		mesh.get_parent().remove_child(mesh)
		mesh.free()
	for material: Material in surfaces:
		var merged: MeshInstance3D = _mesh(bank,surfaces[material].commit(),material,Vector3.ZERO)
		merged.lod_bias = 128.0
		if moving[material]:
			_wind.apply(merged,"grass")
			merged.set_instance_shader_parameter("wind_motion",Vector4(.006,.08,0.0,.002))

func _branch_point(base: Vector3, tip: Vector3, bend: Vector3, t: float) -> Vector3:
	return base.lerp(tip,t) + bend*sin(t*PI)

func _add_stem(parent: Node3D, a: Vector3, b: Vector3, radius: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius*.5
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 7
	var stem: MeshInstance3D = _mesh(parent,cylinder,_material(Color("6a6950")),(a+b)*.5)
	stem.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func _leaf_mesh(length: float, width: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in 10:
		var a: float = float(segment)/10.0
		var b: float = float(segment+1)/10.0
		for side: float in [-1.0,1.0]:
			var points: Array[Vector3] = [_leaf_point(a,0.0,length,width),_leaf_point(a,side,length,width),_leaf_point(b,side,length,width),_leaf_point(b,0.0,length,width)]
			for corner: int in [0,1,2,0,2,3]:
				surface.add_vertex(points[corner])
	surface.generate_normals()
	return surface.commit()

func _leaf_point(t: float, side: float, length: float, width: float) -> Vector3:
	var edge: float = pow(maxf(0.0,sin(t*PI)),.85) * width
	return Vector3(side*edge, t*length, sin(t*PI)*length*.16 - absf(side)*edge*.22)

func _process(delta: float) -> void:
	if _camera == null:return
	_amount = move_toward(_amount,1.0 if _wanted else 0.0,delta*3.5)
	visible = _amount > .001
	for mesh: MeshInstance3D in _meshes:mesh.transparency = 1.0 - _amount
	if visible:_update_frame()

func _update_frame() -> void:
	var size: Vector2 = _camera.get_viewport().get_visible_rect().size
	if size == _last_size and _camera.global_transform.is_equal_approx(_last_camera):return
	_last_camera = _camera.global_transform
	_last_size = size
	var safe := Rect2(Vector2(.27,.20),Vector2(.46,.54))
	for field: Node3D in _fields:
		for x: float in [-1.45,1.45]:
			for z: float in [-1.2,1.2]:
				var point: Vector3 = field.global_transform*Vector3(x,.55,z)
				if not _camera.is_position_behind(point):safe=safe.expand(_camera.unproject_position(point)/size)
	for marker: Node3D in _slots:
		if not _camera.is_position_behind(marker.global_position):safe=safe.expand(_camera.unproject_position(marker.global_position)/size)
	# Whole fragments retreat if an extreme pan/orbit carries their branch tips
	# across an operation area. No shader rectangle cuts natural leaf silhouettes.
	for group: Dictionary in _groups:
		var bank: Node3D = group.node
		var blocked: bool = false
		for h: float in [.0,1.2,2.1,3.2,4.3]:
			var point: Vector3 = bank.global_position + Vector3.UP*h
			if not _camera.is_position_behind(point):
				var uv: Vector2 = _camera.unproject_position(point)/size
				blocked = blocked or safe.grow(.04).has_point(uv)
		bank.visible = not blocked
