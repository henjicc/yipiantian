extends SceneTree

var scene: Node3D
var failures: Array[String] = []
var output: String


func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../.local/verification/camera-tuning")
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
	var copied: Variant = JSON.parse_string(DisplayServer.clipboard_get())
	var matches: bool = copied is Dictionary and copied.size() == tuned.size()
	for key: String in tuned:
		matches = matches and copied is Dictionary and copied.has(key) and is_equal_approx(float(copied[key]), float(tuned[key]))
	expect(matches, "Copied JSON reproduces the displayed camera parameters")
	DisplayServer.clipboard_set(previous_clipboard)
	var state: Dictionary = scene.farm_state.snapshot().duplicate(true)
	await click(camera.unproject_position(scene.farm.fields[0].global_position))
	expect(not camera.focused and scene.farm_state.snapshot() == state, "Open panel blocks world actions")
	panel.hide()
	scene._focus_field(0)
	await create_timer(.85).timeout
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
