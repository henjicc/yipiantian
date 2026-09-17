extends SceneTree
## Only the requested debug clock and development fullscreen startup boundary.
var scene: Node3D
var failures: Array[String] = []
var output: String

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../.local/verification/debug-time").simplify_path()
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = load("res://farm/farm_store.gd").new(output.path_join("farm"))
	scene.settings_store = load("res://settings/settings_store.gd").new(output.path_join("preferences"))
	scene.clock = func() -> float: return 1000.0
	root.add_child(scene)
	await create_timer(.5).timeout
	expect(root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "Development flag overrides default windowed preference with real fullscreen")
	var clock: Label = scene.hud.get_node("Layout/LocalClock")
	var panel: PanelContainer = scene.hud.get_node("Layout/DebugTimePreview")
	await pointer(clock.get_global_rect().get_center(), true)
	await pointer(clock.get_global_rect().get_center(), false)
	expect(panel.visible, "Clicking the clock opens its time slider")
	var slider: HSlider = panel.find_child("TimeSlider",true,false)
	var state: Dictionary = scene.farm_state.snapshot().duplicate(true)
	# Exercise a real slider drag: it must not also orbit or select a field.
	scene._toggle_free_view()
	var pose: Transform3D = scene.camera.transform
	var start := slider.get_global_rect().get_center()
	var end := start + Vector2(slider.size.x * .40, 0)
	await pointer(start, true)
	var motion := InputEventMouseMotion.new()
	motion.position=end; motion.relative=end-start; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	await process_frame
	await pointer(end, false)
	expect(slider.value > 1100 and scene.atmosphere.get_night_weight() > .5, "Dragging late in the day updates night lighting")
	expect(scene.camera.transform.is_equal_approx(pose) and scene.selected_field == -1, "Slider drag does not control camera or farm")
	var preview_text: String = clock.text
	await create_timer(1.1).timeout
	expect(clock.text == preview_text, "Clock timer does not overwrite preview time")
	await shot("night.png")
	slider.value = 720
	expect(scene.atmosphere.get_night_weight() == 0 and clock.text == "12:00", "Noon updates light and displayed time together")
	await shot("noon.png")
	var live: Button = panel.find_child("LiveTime",true,false)
	await pointer(live.get_global_rect().get_center(),true)
	await pointer(live.get_global_rect().get_center(),false)
	expect(scene.atmosphere._preview_hour == -1.0 and scene.hud._preview_minutes == -1, "Restore live time clears the session override")
	expect(scene.farm_state.snapshot()==state, "Light preview does not change crop progress or farm data")
	scene._open_menu()
	expect(not panel.visible, "Settings hides the debug time panel")
	scene.farm_audio.shutdown();scene.free()
	for failure: String in failures: push_error(failure)
	print("DEBUG_TIME_PREVIEW failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	root.push_input(event,true)
	await process_frame;await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(name))==OK,"Saved "+name)
