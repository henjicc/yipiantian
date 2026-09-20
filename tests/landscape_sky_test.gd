extends SceneTree
## Renderer-level checks for the sky's angular projection and actual shore mesh.
var failures: Array[String] = []
var output: String
var camera: Camera3D

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../.local/verification/landscape-sky")
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func capture(label: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(output.path_join(label+".png"))
	return image

func difference(a: Image, b: Image) -> float:
	var total: float = 0.0
	var count: int = 0
	for x: int in range(0,a.get_width(),8):
		for y: int in range(0,a.get_height(),8):
			var ca: Color = a.get_pixel(x,y)
			var cb: Color = b.get_pixel(x,y)
			total += absf(ca.r-cb.r)+absf(ca.g-cb.g)+absf(ca.b-cb.b)
			count += 3
	return total/count

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1024,576)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	scene.add_child(sun)
	var landscape: Node3D = load("res://scenes/environment/layered_landscape.gd").new()
	scene.add_child(landscape)
	var atmosphere: Node = load("res://atmosphere/day_night.gd").new()
	scene.add_child(atmosphere)
	atmosphere.configure(sun,environment)
	atmosphere.set_backdrop_material(landscape.material)
	atmosphere.set_preview_hour(12.0)
	atmosphere.set_process(false)
	RenderingServer.global_shader_parameter_set("courtyard_haze_strength",0.28)
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0,5,0)
	camera.fov = 40
	camera.current = true
	for land: MeshInstance3D in landscape.get_children():
		var bounds: AABB = land.get_aabb()
		if not str(land.name).ends_with("Headland"):
			expect(bounds.size.y>5, "Painted hills have independent visible silhouettes")
			var fixed: Transform3D = land.global_transform
			camera.rotation_degrees.y += 20
			await process_frame
			expect(land.global_transform==fixed, "Painted hill does not billboard with the camera")
			continue
		expect(bounds.size.x>10 and bounds.size.z>10 and bounds.size.y<2, "Real shore stays low below painted hills: "+str(land.name))
		expect(bounds.position.y<-.25 and bounds.end.y>0, "Shore crosses shared lake level: "+str(land.name))
		var arrays: Array = land.mesh.surface_get_arrays(0)
		var up: int = 0
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
			if normal.y>0: up+=1
		expect(up==arrays[Mesh.ARRAY_NORMAL].size(), "Terrain normals face upward: "+str(land.name))
	landscape.hide()
	camera.rotation_degrees = Vector3(0,27.5,0)
	var original: Image = await capture("01-sky-overview-direction")
	camera.position += Vector3(12,4,-8)
	var translated: Image = await capture("02-translated-same-direction")
	expect(difference(original,translated)<.001, "Infinite sky has no translation parallax")
	camera.far = 10
	var short_clip: Image = await capture("03-short-far-plane")
	expect(difference(translated,short_clip)<.001, "Sky has no finite support or far-plane clipping")
	camera.far = 600
	camera.rotation_degrees.y += 20
	var rotated: Image = await capture("04-rotated")
	expect(difference(original,rotated)>.002, "Turning reveals another mountain silhouette")
	camera.rotation_degrees.y = 179.99
	var left: Image = await capture("05-wrap-left")
	camera.rotation_degrees.y = -179.99
	var right: Image = await capture("06-wrap-right")
	expect(difference(left,right)<.003, "Panorama wraps continuously across 180 degrees")
	landscape.show()
	camera.position = Vector3(0,6,0)
	camera.rotation_degrees = Vector3(-3,27.5,0)
	var misty: Image = await capture("07-shores-mist")
	RenderingServer.global_shader_parameter_set("courtyard_haze_strength",0.0)
	var clear: Image = await capture("07-shores-clear")
	expect(difference(misty,clear)>.002, "World haze changes actual shore rendering")
	RenderingServer.global_shader_parameter_set("courtyard_haze_strength",0.28)
	for yaw: float in [27.5,117.5,207.5,297.5]:
		camera.rotation_degrees = Vector3(-3,yaw,0)
		await capture("07-shores-%s"%yaw)
	atmosphere.set_preview_hour(21.0)
	expect(landscape.get_node("SinglePeak").material_override.get_shader_parameter("atmosphere_tint")==landscape.material.get_shader_parameter("atmosphere_tint"), "Painted hills share the night sky palette")
	await capture("08-night")
	scene.queue_free()
	await process_frame
	print("LANDSCAPE_SKY_PASS" if failures.is_empty() else "LANDSCAPE_SKY_FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
