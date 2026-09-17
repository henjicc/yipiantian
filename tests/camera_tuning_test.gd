extends SceneTree

var scene: Node3D
var failures: Array[String] = []
var output: String


func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../.local/verification/dof-tuning")
	_run.call_deferred()


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 900)
	scene = load("res://scenes/main.tscn").instantiate()
	var isolated := output.path_join("session-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store = load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	root.add_child(scene)
	scene.atmosphere.set_preview_hour(16.5)
	await create_timer(.5).timeout
	await shot("01-lower.png")
	var camera: FarmCamera = scene.camera
	var panel: PanelContainer = scene.camera_tuning
	scene._select_crop("spinach")
	await click(scene.hud.get_node("Layout/DebugCameraTuning").get_global_rect().get_center())
	expect(panel.visible and scene.selected_tool.is_empty(), "Opening panel cancels armed farming")
	if OS.get_cmdline_user_args().has("--fog-regression"):
		panel._dof_slider.value = 0
		panel.hide()
		scene.atmosphere.set_preview_hour(11.0)
		panel._fog_slider.value = 0
		await shot("fog-fixed-00.png")
		var clear_image: Image = root.get_texture().get_image()
		panel._fog_slider.value = 100
		await shot("fog-fixed-100.png")
		var fog_image: Image = root.get_texture().get_image()
		for island: String in ["FarWillow", "FarBamboo"]:
			var node: Node3D = scene.get_node("Environment/NeighborIslets/"+island)
			var point: Vector2 = camera.unproject_position(node.global_position+Vector3(0,1.2,0))
			var change: float = colour_change(clear_image,fog_image,Vector2i(point))
			expect(change > .04, "Fog visibly affects actual rendered island: "+island)
			print("FOG_ISLAND_PIXEL_CHANGE ",island," ",change)
		panel._fog_slider.value = 55
		await shot("fog-fixed-55.png")
		panel._dof_slider.value = 300
		await create_timer(1.1).timeout
		root.size = Vector2i(3840,2160)
		await shot("dof-edge-fixed-4k.png")
		var held_amount: float = camera.attributes.dof_blur_amount
		scene._focus_field(0)
		for index: int in 18:
			await create_timer(.05).timeout
			expect(camera.attributes.dof_blur_far_enabled and is_equal_approx(camera.attributes.dof_blur_amount,held_amount), "Focus transition never clears or weakens DOF")
			check_clear_fields("continuous focus")
		await shot("dof-continuous-focus.png")
		scene._return_overview()
		for index: int in 18:
			await create_timer(.05).timeout
			expect(camera.attributes.dof_blur_far_enabled and is_equal_approx(camera.attributes.dof_blur_amount,held_amount), "Return transition never clears or weakens DOF")
			check_clear_fields("continuous return")
		camera.zoom(-3.0)
		await create_timer(.8).timeout
		await shot("fog-fixed-zoom.png")
		expect(camera.get_world_3d().environment.fog_depth_begin > scene.focus_detail.protected_depth_range().y, "Farm remains outside fog when zooming")
		scene.farm_audio.shutdown()
		await create_timer(.3).timeout
		scene.queue_free()
		await process_frame
		await process_frame
		print("FOG_REGRESSION_PASS" if failures.is_empty() else str(failures))
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--quick-atmosphere"):
		panel._dof_slider.value = 300
		panel._fog_slider.value = 100
		await create_timer(1.2).timeout
		expect(camera.attributes.dof_blur_amount > .3, "Extended slider reaches three times previous blur ceiling")
		var environment: Environment = camera.get_world_3d().environment
		expect(is_equal_approx(environment.fog_density,.98), "Fog slider reaches renderer")
		expect(environment.fog_depth_begin > scene.focus_detail.protected_depth_range().y, "Fog begins beyond all fields")
		check_clear_fields("extended blur")
		panel._fog_slider.value = 0
		await process_frame
		await process_frame
		expect(not environment.fog_enabled, "Zero disables depth haze")
		panel._fog_slider.value = 55
		panel._dof_slider.value = 150
		await create_timer(.6).timeout
		await shot("06-stronger-blur-fog-panel.png")
		expect(root.get_visible_rect().encloses(panel.get_global_rect()), "Expanded panel fits viewport")
		scene.free()
		await process_frame
		print("ATMOSPHERE_TUNING_PASS" if failures.is_empty() else str(failures))
		quit(0 if failures.is_empty() else 1)
		return
	var original_pose: Transform3D = camera.transform
	panel._dof_slider.value = 0
	await create_timer(.7).timeout
	expect(not camera.attributes.dof_blur_far_enabled, "Zero strength disables visible blur")
	panel.hide()
	await shot("dof-00.png")
	panel._dof_slider.value = 35
	await create_timer(.7).timeout
	var soft_amount: float = camera.attributes.dof_blur_amount
	await shot("dof-35.png")
	panel._dof_slider.value = 100
	await create_timer(.8).timeout
	expect(camera.attributes.dof_blur_amount > soft_amount and soft_amount > 0, "Slider continuously changes actual renderer blur")
	expect(camera.transform.is_equal_approx(original_pose), "Blur tuning never resets camera pose")
	check_clear_fields("maximum blur overview")
	await shot("dof-100.png")
	panel._dof_toggle.button_pressed = false
	await create_timer(.2).timeout
	expect(not camera.attributes.dof_blur_far_enabled and not scene.settings_values.dof_enabled, "Panel switch shares main settings preference")
	panel._dof_toggle.button_pressed = true
	panel._dof_slider.value = 65
	scene._apply_settings()
	expect(is_equal_approx(scene.focus_detail.get_settings().dof_strength,.65), "Applying unrelated settings preserves session strength")
	scene._toggle_camera_tuning()
	expect(panel._dof_slider.value == 65, "Reopening retains displayed strength")
	panel._preset(28.0)
	panel.hide()
	await shot("02-original.png")
	scene._toggle_camera_tuning()
	panel._preset(22.0)
	await shot("03-panel.png")
	var slider: HSlider = panel._sliders.pitch
	var before: Transform3D = camera.transform
	await click(slider.get_global_rect().get_center())
	expect(not camera.transform.is_equal_approx(before) and camera.view.y > 30, "Slider input changes actual camera pose")
	panel._sliders.pitch.value = 20.0
	panel._sliders.distance.value = 30.0
	panel._sliders.fov.value = 32.0
	panel._sliders.target_y.value = 1.2
	var tuned: Dictionary = camera.overview_parameters()
	var previous_clipboard: String = DisplayServer.clipboard_get()
	await click(panel._copy.get_global_rect().get_center())
	# Avoid racing OS clipboard consumers immediately after a change event.
	# Observe the user's paste-time result, not a read in the same input frame.
	await create_timer(.4).timeout
	var copied: Variant = JSON.parse_string(DisplayServer.clipboard_get())
	var matches: bool = copied is Dictionary and copied.size() == tuned.size() + 3
	matches = matches and is_equal_approx(float(copied.get("fog_strength",-1)), .55)
	matches = matches and copied.get("dof_enabled") == true and is_equal_approx(float(copied.get("dof_strength",-1)),.65)
	for key: String in tuned:
		matches = matches and copied is Dictionary and copied.has(key) and is_equal_approx(float(copied[key]), float(tuned[key]))
	expect(matches, "Copied JSON reproduces the displayed camera parameters")
	DisplayServer.clipboard_set(previous_clipboard)
	var state: Dictionary = scene.farm_state.snapshot().duplicate(true)
	await click(camera.unproject_position(scene.farm.fields[0].global_position))
	expect(not camera.focused and scene.farm_state.snapshot() == state, "Open panel blocks world actions")
	panel.hide()
	scene._focus_field(0)
	for frame: int in 12:
		await create_timer(.04).timeout
		check_clear_fields("focus transition")
	await create_timer(.85).timeout
	check_clear_fields("focused view")
	await shot("dof-focus.png")
	scene.camera.zoom(-100)
	await create_timer(.6).timeout
	check_clear_fields("focused zoom")
	scene._return_overview()
	await create_timer(.85).timeout
	expect(camera.view.is_equal_approx(Vector3(25,20,30)) and camera.focus_point.is_equal_approx(Vector3(0,1.2,0)), "Focus and return retain tuned overview")
	camera.zoom(100)
	await create_timer(.8).timeout
	expect(is_equal_approx(camera.view.z,30), "Zoom-out bound uses tuned distance")
	scene._reset_view()
	await create_timer(.85).timeout
	expect(camera.overview_parameters() == tuned and is_equal_approx(camera.fov,32), "Reset preserves session composition")
	scene._toggle_camera_tuning()
	panel._preset(22)
	scene.settings_values.quality = "low"
	scene._apply_settings()
	panel.hide()
	scene._toggle_camera_tuning()
	expect(not panel._dof_slider.editable and panel._dof_toggle.disabled, "Low quality visibly disables DOF tuning")
	scene.settings_values.quality = "standard"
	scene._apply_settings()
	panel.hide()
	scene._toggle_camera_tuning()
	expect(panel._dof_slider.editable and panel._dof_slider.value == 65, "Standard restores retained slider value")
	root.size = Vector2i(960,600)
	await process_frame
	await shot("04-compact.png")
	expect(root.get_visible_rect().encloses(panel.get_global_rect()), "Panel fits compact logical viewport")
	root.size = Vector2i(3840,2160)
	await process_frame
	await shot("05-4k.png")
	expect(root.get_visible_rect().encloses(panel.get_global_rect()), "Panel fits 4K logical viewport")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	expect(not panel.visible, "Escape closes tuning panel")
	scene.farm_audio.shutdown()
	await create_timer(.3).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	print("CAMERA_TUNING_PASS" if failures.is_empty() else "CAMERA_TUNING_FAIL: " + str(failures))
	quit(0 if failures.is_empty() else 1)


func check_clear_fields(context: String) -> void:
	var attributes: CameraAttributesPractical = scene.camera.attributes
	if not attributes.dof_blur_far_enabled:
		return
	var forward: Vector3 = -scene.camera.global_basis.z
	for field: Node3D in scene.farm.fields:
		var boxes: Array[Dictionary] = [{"transform": field.global_transform, "bounds": AABB(Vector3(-1.4,-.1,-1.15),Vector3(2.8,.75,2.3))}]
		for mesh: MeshInstance3D in field.get_node("Crops").find_children("*","MeshInstance3D",true,false):
			if mesh.mesh != null and mesh.is_visible_in_tree():
				boxes.append({"transform": mesh.global_transform,"bounds":mesh.get_aabb()})
		for box: Dictionary in boxes:
			for corner: int in 8:
				var depth: float = forward.dot(box.transform * box.bounds.get_endpoint(corner) - scene.camera.global_position)
				if depth < scene.camera.near:
					continue
				expect(depth >= attributes.dof_blur_near_distance and depth <= attributes.dof_blur_far_distance, "All soil and crop corners remain sharp: " + context)


func colour_change(before: Image, after: Image, at: Vector2i) -> float:
	var total: float = 0.0
	var count: int = 0
	for x: int in range(at.x-5,at.x+6):
		for y: int in range(at.y-5,at.y+6):
			if x < 0 or y < 0 or x >= before.get_width() or y >= before.get_height():
				continue
			var a: Color = before.get_pixel(x,y)
			var b: Color = after.get_pixel(x,y)
			total += Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
			count += 1
	return total/maxf(1.0,count)


func click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await physics_frame


func shot(filename: String) -> void:
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))
