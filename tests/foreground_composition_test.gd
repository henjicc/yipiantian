extends SceneTree
## Native composition evidence at the user's chosen camera, with isolated state.
var scene: Node3D
var output: String
var before: bool = false
var failures: Array[String] = []


func _initialize() -> void:
	before = OS.get_cmdline_user_args().has("--before")
	output = ProjectSettings.globalize_path("res://../.local/verification/foreground-20260918/" + ("before" if before else "after"))
	_run.call_deferred()


func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,900)
	scene = load("res://scenes/main.tscn").instantiate()
	var isolated := output.path_join("session-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store = load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	root.add_child(scene)
	scene.atmosphere.set_preview_hour(16.5)
	await create_timer(1.0).timeout
	await shot("01-overview.png")
	var frame: Node3D = scene.camera.get_node("CameraForeground")
	var triangles: int = 0
	var surfaces: int = 0
	for geometry: MeshInstance3D in frame.find_children("*", "MeshInstance3D", true, false):
		surfaces += geometry.mesh.get_surface_count()
		for index: int in geometry.mesh.get_surface_count():
			triangles += geometry.mesh.surface_get_array_index_len(index) / 3
	var report := {"source_triangles": triangles, "surfaces": surfaces,
		"near_distance": scene.camera.attributes.dof_blur_near_distance,
		"blur_amount": scene.camera.attributes.dof_blur_amount, "camera": scene.camera.overview_parameters()}
	if not before:
		expect(frame.visible, "Foreground appears in overview")
		for field: Node3D in scene.farm.fields:
			var depths: Vector2 = scene.focus_detail.depth_range(scene.camera,field.global_transform,AABB(Vector3(-1.4,-.1,-1.15),Vector3(2.8,.75,2.3)))
			expect(scene.camera.attributes.dof_blur_near_distance <= depths.x, "Crop beds stay outside near blur")
		expect(frame._groups[0].node.visible and frame._groups[1].node.visible, "Both edges visible at selected overview")
		scene.atmosphere.set_preview_hour(7.2)
		await shot("02-morning.png")
		scene.focus_detail.set_depth_of_field(false)
		await create_timer(.6).timeout
		await shot("03-dof-off.png")
		expect(not scene.camera.attributes.dof_blur_near_enabled, "Depth preference is respected")
		scene.focus_detail.set_depth_of_field(true)
		scene.atmosphere.set_preview_hour(16.5)
		for yaw: float in [17.5,37.5]:
			scene.camera.view.x = yaw
			await shot("04-yaw-%s.png" % yaw)
		scene.camera.view.x = 27.5
		scene._focus_field(0)
		await create_timer(1.0).timeout
		expect(not frame.visible, "Foreground leaves focused farming unobstructed")
		await shot("05-focused.png")
		scene._return_overview()
		await create_timer(1.0).timeout
		root.size = Vector2i(960,600)
		await shot("06-compact.png")
		root.size = Vector2i(3840,2160)
		await shot("07-4k.png")
		scene.atmosphere.set_preview_hour(21.0)
		await shot("08-night.png")
		scene.focus_detail.set_quality("low")
		await create_timer(.5).timeout
		expect(not frame.visible, "Low quality retains foreground opt-out")
		scene.focus_detail.set_quality("standard")
		scene._toggle_free_view()
		await process_frame
		expect(not frame.visible, "Free inspection hides framing scenery")
	report["failures"] = failures
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	scene.farm_audio.shutdown()
	await create_timer(.3).timeout
	scene.queue_free()
	await process_frame
	print("FOREGROUND_PASS " + str(report) if failures.is_empty() else "FOREGROUND_FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)


func shot(filename: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))
