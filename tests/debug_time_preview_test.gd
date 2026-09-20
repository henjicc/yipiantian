extends SceneTree
## Only the requested debug clock and development fullscreen startup boundary.
var scene: Node3D
var failures: Array[String] = []
var output: String

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../.local/verification/debug-time-%d" % Time.get_ticks_usec()).simplify_path()
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
	var clock: Label = scene.hud._clock
	var basket_title: String = scene.hud._harvested.text
	var basket_detail: String = scene.hud._harvest_detail.text
	scene.hud._harvested.text = "菜篮 · 99999"
	scene.hud._harvest_detail.text = "累计收获 99999 篮"
	for window_size: Vector2i in [Vector2i(960,600), Vector2i(3840,2160)]:
		root.mode = Window.MODE_WINDOWED
		root.size = window_size
		await process_frame
		await process_frame
		for badge: Control in [scene.hud.get_node("Layout/OpenBasket"), scene.hud.get_node("Layout/TimeBadge")]:
			var frame: Rect2 = badge.get_global_rect()
			expect(root.get_visible_rect().encloses(frame), "Status badge fits viewport")
			expect(frame.encloses(badge.picture.get_global_rect()) and frame.encloses(badge.title_label.get_global_rect()), "Badge contains both icon and title")
			expect(badge.picture.get_global_rect().end.x < badge.title_label.get_global_rect().position.x, "Fixed icon slot cannot overlap title")
			var copy: Control = badge.title_label.get_parent()
			expect(absf(badge.picture.get_global_rect().get_center().y-copy.get_global_rect().get_center().y)<1.0, "Icon and text block share vertical center")
			expect(badge.picture.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Icon aspect ratio is preserved")
	root.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	scene.hud._harvested.text = basket_title
	scene.hud._harvest_detail.text = basket_detail
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
	await pointer(clock.get_global_rect().get_center(), true)
	await pointer(clock.get_global_rect().get_center(), false)
	expect(not panel.visible, "Whole time badge also toggles the preview closed")
	await shot("hud-clean.png")
	await pointer(clock.get_global_rect().get_center(), true)
	await pointer(clock.get_global_rect().get_center(), false)
	var live: Button = panel.find_child("LiveTime",true,false)
	await pointer(live.get_global_rect().get_center(),true)
	await pointer(live.get_global_rect().get_center(),false)
	expect(scene.atmosphere._preview_hour == -1.0 and scene.hud._preview_minutes == -1, "Restore live time clears the session override")
	expect(scene.farm_state.snapshot()==state, "Light preview does not change crop progress or farm data")
	scene._open_menu()
	expect(not panel.visible, "Settings hides the debug time panel")
	var ui_size: Vector2 = root.get_texture().get_size()
	scene.game_menu._resolution.select(1)
	scene.game_menu._resolution.item_selected.emit(1)
	await process_frame
	expect(is_equal_approx(root.scaling_3d_scale, 1080.0/root.size.y), "1080p choice controls actual 3D buffer scale")
	expect(root.get_texture().get_size()==ui_size, "3D resolution never lowers UI output resolution")
	expect("1920 × 1080" in scene.game_menu._resolution_info.text, "UI reports actual low-resolution 3D dimensions")
	scene.game_menu._resolution.select(0)
	scene.game_menu._resolution.item_selected.emit(0)
	expect(root.scaling_3d_scale==1.0, "Native restores pixel-for-pixel 3D rendering")
	await shot("settings-native-4k.png")
	var quality: OptionButton = scene.game_menu._quality
	await pointer(quality.get_global_rect().get_center(),true)
	await pointer(quality.get_global_rect().get_center(),false)
	await shot("dropdown-4k.png")
	quality.get_popup().hide()
	scene.farm_audio.shutdown();scene.free()
	await process_frame
	await process_frame
	for failure: String in failures: push_error(failure)
	print("DEBUG_TIME_PREVIEW failures=%d" % failures.size())
	print("DEBUG_TIME_SCREENSHOTS "+output)
	quit(0 if failures.is_empty() else 1)

func pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	root.push_input(event,true)
	await process_frame;await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(name))==OK,"Saved "+name)
