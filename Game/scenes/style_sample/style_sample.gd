extends Node3D
## Isolated art proof: no farm data, saving, or production camera dependencies.
const HOUSE_HIGH: PackedScene = preload("res://art/environment/house/house_high.glb")
const HOUSE_LOW: PackedScene = preload("res://art/environment/house/house_low.glb")
const CROP_HIGH: PackedScene = preload("res://art/crops/greens/greens_mature.glb")
const CROP_LOW: PackedScene = preload("res://scenes/style_sample/greens_sample_low.glb")
var camera: Camera3D
var sunlight: DirectionalLight3D
var atmosphere: Environment
var attributes_sample: CameraAttributesPractical
var high_group: Node3D
var low_group: Node3D
var target := Vector3(0.0, 0.4, 0.0)
var yaw: float = 28.0
var pitch: float = 30.0
var distance: float = 28.5
var rng := RandomNumberGenerator.new()
var demo_enabled: bool = false
var demo_time: float = 0.0

func _ready() -> void:
	rng.seed = 122
	_build_context()
	high_group = _build_assets(HOUSE_HIGH, CROP_HIGH)
	low_group = _build_assets(HOUSE_LOW, CROP_LOW)
	low_group.visible = false
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.far = 220.0
	add_child(camera)
	camera.current = true
	attributes_sample = CameraAttributesPractical.new()
	camera.attributes = attributes_sample
	_set_pose()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture(argument.trim_prefix("--capture-dir="))
		if argument == "--sample-demo":
			demo_enabled = true
			_verify_movie_size()

func _verify_movie_size() -> void:
	await RenderingServer.frame_post_draw
	var render_size: Vector2i = get_viewport().get_texture().get_image().get_size()
	print("STYLE_MOVIE window=",DisplayServer.window_get_size()," rendered=",render_size)
	assert(render_size == Vector2i(3840,2160))
	assert(DisplayServer.window_get_size() == Vector2i(3840,2160))

func _process(delta: float) -> void:
	if not demo_enabled:
		return
	demo_time += delta
	var overview := Vector4(28.0,30.0,28.5,0)
	var house_view := Vector4(28.0,23.0,15.5,0)
	var turned_view := Vector4(40.0,23.0,15.5,0)
	var crop_view := Vector4(35.0,35.0,8.0,0)
	var overview_target := Vector3(0,0.4,0)
	var house_target := Vector3(0.3,1.8,-3.4)
	var crop_target := Vector3(0,0.7,3)
	var view_now: Vector4 = overview
	target = overview_target
	if demo_time >= 4 and demo_time < 10:
		var blend: float = smoothstep(4,6,demo_time)
		view_now = overview.lerp(house_view,blend)
		target = overview_target.lerp(house_target,blend)
	elif demo_time >= 10 and demo_time < 17:
		view_now = house_view.lerp(turned_view,smoothstep(10,14,demo_time))
		target = house_target
	elif demo_time >= 17 and demo_time < 22:
		var blend: float = smoothstep(17,19,demo_time)
		view_now = turned_view.lerp(crop_view,blend)
		target = house_target.lerp(crop_target,blend)
	elif demo_time >= 22:
		var blend: float = smoothstep(22,24,demo_time)
		view_now = crop_view.lerp(overview,blend)
		target = crop_target.lerp(overview_target,blend)
	yaw = view_now.x
	pitch = view_now.y
	distance = view_now.z
	_set_pose()

func _mat(html: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(html)
	material.roughness = 0.97
	material.metallic_specular = 0.08
	return material

func _mesh(mesh: Mesh, position_at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position_at
	node.material_override = material
	add_child(node)
	return node

func _box(position_at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = dimensions
	return _mesh(box, position_at, material)

func _ellipsoid(position_at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.height = 1.0
	sphere.radius = 0.5
	sphere.radial_segments = 16
	sphere.rings = 8
	var node := _mesh(sphere, position_at, material)
	node.scale = dimensions
	return node

func _pole(position_at: Vector3, height: float, radius: float, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.height = height
	cylinder.top_radius = radius * 0.85
	cylinder.bottom_radius = radius
	cylinder.radial_segments = 10
	return _mesh(cylinder, position_at, material)

func _build_context() -> void:
	var stone := _mat("b5b29b")
	var wood := _mat("8c7657")
	var soil := _mat("86725a")
	var grass := _mat("929975")
	var water := _mat("9cbbb2")
	_box(Vector3(0,-0.65,0),Vector3(200,0.1,200),water)
	# Square-edged island and body, following the reference courtyard arrangement.
	_box(Vector3(0,-0.15,0),Vector3(14,0.7,13),grass)
	for row in 2:
		for col in 3:
			var centre := Vector3(-3.65 + col * 3.65,0.31,0.15 + row * 2.85)
			_box(centre,Vector3(3.05,0.20,2.20),soil)
			for side in [-1.0,1.0]:
				_box(centre+Vector3(0,0.025,side*1.14),Vector3(3.18,0.12,0.10),wood)
				_box(centre+Vector3(side*1.59,0.025,0),Vector3(0.10,0.12,2.38),wood)
	for x in 15:
		for z in 12:
			var p := Vector3(-6.3+x*0.90,0.25,-5.5+z*0.93)
			if p.z < -1.25 or p.z > 4.35 or x in [0,3,7,11,14]:
				var slab := _box(p,Vector3(0.79,0.08,0.80),stone)
				slab.rotation.y = rng.randf_range(-0.08,0.08)
	for i in 22:
		var x: float = -6.8 + i * 0.65
		for z in [-6.45,6.45]:
			_ellipsoid(Vector3(x,-0.05,z),Vector3(0.8,rng.randf_range(0.6,1.0),0.75),stone)
	for i in 18:
		var z: float = -5.8+i*0.68
		for x in [-6.9,6.9]:
			_ellipsoid(Vector3(x,-0.05,z),Vector3(0.75,rng.randf_range(0.6,1.0),0.8),stone)
	for x in [-6.0,-4.8,-3.6,-2.4,-1.2,0.0,1.2,2.4,3.6,4.8,6.0]:
		_pole(Vector3(x,0.77,5.0),1.2,0.06,wood)
	for y in [0.65,1.10]:
		_box(Vector3(0,y,5),Vector3(12.1,0.065,0.065),wood)
	# Bridge, boat and gate are intentionally size placeholders for 3.2.
	for i in 9:
		var x: float = 6.6+i*0.42
		var arch: float = sin(float(i)/8.0*PI)*0.85
		_box(Vector3(x,0.10+arch,-0.8),Vector3(0.45,0.32,1.7),stone)
		for z in [-1.65,0.05]:
			_pole(Vector3(x,0.60+arch,z),0.9,0.07,stone)
	var hull := _ellipsoid(Vector3(7.4,-0.25,4.3),Vector3(1.7,0.5,4.2),wood)
	hull.rotation.y = -0.25
	_box(Vector3(6.3,0.12,3.8),Vector3(1.4,0.15,3.0),wood)
	for x in [-6.1,-4.4]:
		_pole(Vector3(x,1.6,-0.7),2.8,0.10,wood)
	_box(Vector3(-5.25,3.05,-0.7),Vector3(2.3,0.25,1.2),wood)
	for p in [Vector3(-4.9,0,-3.8),Vector3(5.0,0,-4.6)]:
		_pole(p+Vector3(0,1.7,0),3.4,0.21,wood)
		for i in 6:
			_ellipsoid(p+Vector3(rng.randf_range(-1,1),3.5+rng.randf_range(0,1),rng.randf_range(-0.8,0.8)),Vector3(1.75,1.45,1.65),_mat("869477"))
	for band in 3:
		for i in 12:
			var p := Vector3(-65+i*12,-2.0,-17-band*9)
			_ellipsoid(p,Vector3(17,8+rng.randf_range(0,6),11),_mat(["acb9ad","bdc7b8","ccd0c0"][band]))
	atmosphere = Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color("d9ddce")
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("e6e9dd")
	atmosphere.ambient_light_energy = 0.40
	atmosphere.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	atmosphere.ssao_enabled = true
	atmosphere.ssao_radius = 0.65
	atmosphere.ssao_intensity = 0.65
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("d9dfd2")
	atmosphere.fog_density = 0.0015
	var world := WorldEnvironment.new()
	world.environment = atmosphere
	add_child(world)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52,-35,0)
	sunlight.light_color = Color("fff8ea")
	sunlight.light_energy = 0.80
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 75
	sunlight.light_angular_distance = 2.0
	add_child(sunlight)

func _build_assets(house_scene: PackedScene, crop_scene: PackedScene) -> Node3D:
	var group := Node3D.new()
	add_child(group)
	var house := house_scene.instantiate() as Node3D
	group.add_child(house)
	house.position = Vector3(0.7,0.23,-3.6)
	for row in 2:
		for col in 3:
			for plant in 12:
				var crop := crop_scene.instantiate() as Node3D
				group.add_child(crop)
				crop.position = Vector3(-4.7+col*3.65+(plant%4)*0.68,0.43,-0.48+row*2.85+(plant/4)*0.65)
				crop.rotation.y = float(plant)*0.83
	return group

func _set_pose() -> void:
	var direction := Vector3(sin(deg_to_rad(yaw))*cos(deg_to_rad(pitch)),sin(deg_to_rad(pitch)),cos(deg_to_rad(yaw))*cos(deg_to_rad(pitch)))
	camera.position = target + direction * distance
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		yaw = clampf(yaw-event.relative.x*0.15,-12,68)
		pitch = clampf(pitch+event.relative.y*0.15,24,58)
		_set_pose()
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		if event.keycode == KEY_SPACE:
			high_group.visible = not high_group.visible
			low_group.visible = not high_group.visible

func _shot(folder: String, shot_name: String) -> void:
	_set_pose()
	for frame in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: Error = get_viewport().get_texture().get_image().save_png(folder.path_join(shot_name+".png"))
	assert(result == OK)
	print("STYLE_CAPTURE ",shot_name," triangles=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

func _capture(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	await _shot(folder,"01-overview-high")
	high_group.visible = false
	low_group.visible = true
	await _shot(folder,"02-overview-low")
	high_group.visible = true
	low_group.visible = false
	target = Vector3(0.3,1.8,-3.4)
	distance = 15.5
	pitch = 23.0
	await _shot(folder,"03-house-front")
	yaw = 208
	await _shot(folder,"04-house-back")
	yaw = 28
	target = Vector3(0,0.7,3.0)
	distance = 8.0
	pitch = 35
	await _shot(folder,"05-crop-high")
	high_group.visible = false
	low_group.visible = true
	await _shot(folder,"06-crop-low")
	high_group.visible = true
	low_group.visible = false
	attributes_sample.dof_blur_far_enabled = true
	attributes_sample.dof_blur_far_distance = 9.7
	attributes_sample.dof_blur_far_transition = 5.0
	attributes_sample.dof_blur_near_enabled = true
	attributes_sample.dof_blur_near_distance = 5.2
	attributes_sample.dof_blur_near_transition = 2.0
	attributes_sample.dof_blur_amount = 0.045
	await _shot(folder,"07-crop-gentle-dof")
	yaw = 43
	await _shot(folder,"08-crop-rotated")
	attributes_sample.dof_blur_far_enabled = false
	attributes_sample.dof_blur_near_enabled = false
	target = Vector3(0,0.4,0)
	yaw = 28
	pitch = 30
	distance = 28.5
	sunlight.light_energy = 0.15
	sunlight.light_color = Color("a9c3dd")
	atmosphere.ambient_light_energy = 0.45
	atmosphere.ambient_light_color = Color("a5b8d5")
	atmosphere.background_color = Color("647b92")
	atmosphere.fog_light_color = Color("71889a")
	await _shot(folder,"09-overview-night")
	get_tree().quit()
