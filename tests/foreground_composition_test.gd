extends SceneTree
## Native composition evidence at the user's chosen camera, with isolated state.
var scene: Node3D
var output: String
var before: bool = false
var failures: Array[String] = []


func _initialize() -> void:
	before = OS.get_cmdline_user_args().has("--before")
	output = ProjectSettings.globalize_path("res://../.local/verification/foreground-20260918/" + ("before" if before else "after"))
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	output = output.simplify_path()
	assert(output.replace("\\", "/").begins_with(ProjectSettings.globalize_path("res://../.local/").simplify_path().replace("\\", "/")+"/"))
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
	var initial: Dictionary = scene.settings_store.load_settings().settings
	initial.overview_mdeg = [43000.0,14000.0]
	expect(scene.settings_store.save(initial).ok,"Overview preference written before game startup")
	root.add_child(scene)
	scene.atmosphere.set_preview_hour(16.5)
	await create_timer(1.0).timeout
	if OS.get_cmdline_user_args().has("--fade-only"):
		scene.camera.restore_overview_angles(Vector2(27.5,10.0))
		await fade_checks(scene.camera.get_node("CameraForeground"))
		await finish({"scope": "foreground fades"})
		return
	expect(scene.camera.overview_view.x==43.0 and scene.camera.view.y==14.0,"Actual game startup restores saved overview angles")
	await overview_memory_checks(isolated.path_join("preferences"))
	scene.camera.restore_overview_angles(Vector2(27.5,10.0))
	await shot("01-overview.png")
	var frame: Node3D = scene.camera.get_node("CameraForeground")
	var triangles: int = 0
	var surfaces: int = 0
	for geometry: MeshInstance3D in frame.find_children("*", "MeshInstance3D", true, false):
		surfaces += geometry.mesh.get_surface_count()
		for index: int in geometry.mesh.get_surface_count():
			var indices: int = geometry.mesh.surface_get_array_index_len(index)
			triangles += (indices if indices > 0 else geometry.mesh.surface_get_array_len(index)) / 3
	var report := {"source_triangles": triangles, "surfaces": surfaces,
		"near_distance": scene.camera.attributes.dof_blur_near_distance,
		"blur_amount": scene.camera.attributes.dof_blur_amount, "camera": scene.camera.overview_parameters()}
	if not before:
		expect(frame.visible, "Foreground appears in overview")
		for field: Node3D in scene.farm.fields:
			var depths: Vector2 = scene.focus_detail.depth_range(scene.camera,field.global_transform,AABB(Vector3(-1.4,-.1,-1.15),Vector3(2.8,.75,2.3)))
			expect(scene.camera.attributes.dof_blur_near_distance <= depths.x, "Crop beds stay outside near blur")
		expect(frame._groups[0].node.visible and frame._groups[1].node.visible, "Both edges visible at selected overview")
		for group: Dictionary in frame._groups:
			expect(group.node.visible, "Foreground group appears at intended overview: " + str(group.node.name))
		for shore: String in ["ReedShoreLeft", "ReedShoreRight"]:
			for band: int in 3:
				expect(frame.get_node_or_null(shore+"/ReedBlades%d" % band) != null, "Curved reeds constructed: " + shore)
		for patch: Dictionary in frame._water_plants:
			expect(patch.node.global_position.y < -.35, "Scaled P2 lotus roots remain submerged through bobbing")
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
		# Sweep the old safe-rectangle boundary: no complete bank may blink out.
		for yaw: float in [-12.0, 0.0, 17.5, 27.5, 37.5, 50.0, 68.0]:
			scene.camera.view.x = yaw
			await process_frame
			await process_frame
			for group: Dictionary in frame._groups:
				expect(group.node.is_visible_in_tree(), "Orbit retains world foreground at yaw %s: %s" % [yaw, group.node.name])
			if yaw in [-12.0,68.0]: await shot("04-boundary-%s.png" % yaw)
		var landscape: Node3D = scene.get_node("Environment/DistantLandscape")
		scene.camera.view.x = 27.5
		await process_frame
		await process_frame
		var range_node: Node3D = landscape.get_node("NorthernHeadland")
		var mountain: Vector3 = range_node.global_transform * range_node.get_aabb().get_center()
		var start_pixel: Vector2 = scene.camera.unproject_position(mountain)
		scene.camera.view.x += 10.0
		await process_frame
		await process_frame
		expect((range_node.global_transform * range_node.get_aabb().get_center()).is_equal_approx(mountain), "Mountains stay anchored while orbiting")
		expect(absf(scene.camera.unproject_position(mountain).x-start_pixel.x)>30, "Yaw moves mountain silhouette across the image")
		scene.camera.view.x = 27.5
		scene.camera.view.y += 5.0
		await shot("04-pitch.png")
		expect((range_node.global_transform * range_node.get_aabb().get_center()).is_equal_approx(mountain), "Tilt does not move the mountain stage")
		scene.camera.view.y = scene.camera.overview_view.y
		await create_timer(.5).timeout
		var blur: float = scene.camera.attributes.dof_blur_amount
		scene.harvest_book.present(scene.farm_state.snapshot())
		scene.garden_album.begin_photo()
		await create_timer(.5).timeout
		expect(frame.is_visible_in_tree(), "Photo mode keeps overview foreground")
		expect(is_equal_approx(scene.camera.attributes.dof_blur_amount,blur), "Photo mode keeps chosen depth of field")
		scene.garden_album._layer.hide()
		await shot("04-photo-viewfinder.png")
		var viewfinder: Image = root.get_texture().get_image()
		scene.garden_album._layer.show()
		await scene.garden_album.take_photo()
		var photos: Array = scene.farm_state.snapshot().memories.photos
		expect(photos.size()==1, "Actual shutter saves a photo")
		if photos.size()==1:
			var saved: Image = scene.garden_album.files.texture(photos[0].id).get_image()
			saved.save_png(output.path_join("04-saved-photo.png"))
			var difference: float = 0.0
			var samples: int = 0
			for x: int in range(0, saved.get_width(), 8):
				for y: int in range(saved.get_height()/2, saved.get_height(), 8):
					var a: Color = saved.get_pixel(x,y)
					var b: Color = viewfinder.get_pixel(x,y)
					difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
					samples += 3
			expect(difference/samples<.025, "Saved foreground matches viewfinder pixels")
		scene.harvest_book.dismiss()
		scene._focus_field(0)
		var previous_coverage: float = 1.0
		for tick: int in 18:
			await process_frame
			var coverage: float = frame._meshes[0].get_instance_shader_parameter("foreground_visibility")
			expect(coverage<=previous_coverage,"Foreground coverage fades monotonically during focus")
			previous_coverage=coverage
			for mesh: MeshInstance3D in frame._meshes:
				expect(mesh.transparency==0.0,"Focus never switches foreground to transparent rendering")
			if tick in [0,3,7,12]:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("05-focus-transition-%02d.png"%tick))
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
		await fade_checks(frame)
	await finish(report)


func finish(report: Dictionary) -> void:
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


func fade_checks(frame: Node3D) -> void:
	await shot("fade-01-visible.png")
	for mode: String in ["quality", "inspection", "focus"]:
		if mode == "quality": scene.focus_detail.set_quality("low")
		elif mode == "inspection": scene._toggle_free_view()
		else: scene._focus_field(0)
		expect(frame.is_visible_in_tree(), mode + " keeps foreground visible when fade starts")
		await create_timer(.15).timeout
		var coverage: float = frame._meshes[0].get_instance_shader_parameter("foreground_visibility")
		expect(frame.is_visible_in_tree() and coverage > 0.0 and coverage < 1.0, mode + " has intermediate visibility")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("fade-02-"+mode+"-partial.png"))
		await create_timer(.5).timeout
		expect(not frame.visible, mode + " hides only after fade completes")
		if mode == "quality": scene.focus_detail.set_quality("standard")
		else: scene._return_overview()
		await create_timer(.15).timeout
		coverage = frame._meshes[0].get_instance_shader_parameter("foreground_visibility")
		expect(frame.is_visible_in_tree() and coverage > 0.0 and coverage < 1.0, mode + " fades back in")
		await create_timer(.5).timeout
		expect(is_equal_approx(frame._meshes[0].get_instance_shader_parameter("foreground_visibility"),1.0), mode + " restores full visibility")
	# A reversal must not reset to fully visible or disappear for a frame.
	scene.focus_detail.set_quality("low")
	await create_timer(.15).timeout
	var partial: float = frame._meshes[0].get_instance_shader_parameter("foreground_visibility")
	scene.focus_detail.set_quality("standard")
	expect(is_equal_approx(frame._meshes[0].get_instance_shader_parameter("foreground_visibility"),partial), "Reversal retains current visibility")
	await create_timer(.08).timeout
	var reversed: float = frame._meshes[0].get_instance_shader_parameter("foreground_visibility")
	expect(reversed > partial and reversed < 1.0, "Reversal continues smoothly toward visible")
	await shot("fade-03-restored.png")


func shot(filename: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))

func overview_memory_checks(preferences: String) -> void:
	var point := Vector2(800,720)
	for button: MouseButton in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
		var before_yaw: float = scene.camera.view.x
		var press := InputEventMouseButton.new()
		press.button_index=button;press.pressed=true;press.position=point
		Input.parse_input_event(press)
		await process_frame
		var motion := InputEventMouseMotion.new()
		motion.position=point+Vector2(65,0);motion.relative=Vector2(65,0)
		motion.button_mask=MOUSE_BUTTON_MASK_RIGHT if button==MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_MIDDLE
		Input.parse_input_event(motion)
		await process_frame
		press=press.duplicate();press.pressed=false;press.position=motion.position
		Input.parse_input_event(press)
		await process_frame
		expect(scene.camera.view.x<before_yaw,"Routed right/middle drag rotates the overview")
		var loaded: Dictionary = load("res://settings/settings_store.gd").new(preferences).load_settings()
		expect(loaded.ok and is_equal_approx(loaded.settings.overview_mdeg[0]/1000.0,scene.camera.view.x),"Mouse release durably records current overview")
	var remembered: Vector3 = scene.camera.overview_view
	scene._focus_field(0)
	await create_timer(.9).timeout
	scene.camera.drag(Vector2(30,0),false)
	scene._return_overview()
	await create_timer(.9).timeout
	expect(scene.camera.view.is_equal_approx(remembered),"Focus and overview restore the last overview, not the field orbit")
	scene.camera.drag(Vector2(-100000,0),false)
	expect(scene.camera.view.x==68.0,"Right orbit is bounded")
	scene.camera.drag(Vector2(100000,0),false)
	expect(scene.camera.view.x==-12.0,"Left orbit is bounded")
	scene._cancel_input()
	var reopened: Dictionary = load("res://settings/settings_store.gd").new(preferences).load_settings()
	var fresh: Camera3D = load("res://scenes/farm_camera.gd").new()
	root.add_child(fresh)
	fresh.restore_overview_angles(Vector2(reopened.settings.overview_mdeg[0],reopened.settings.overview_mdeg[1])/1000.0)
	expect(fresh.view.x==-12.0,"New camera restores persisted bounded view")
	fresh.queue_free()
	scene.camera.current=true
