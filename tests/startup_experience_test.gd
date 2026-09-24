extends SceneTree
## Real startup, staged scene construction, preset intent and isolated preference
## failure/reopen. Captures use the actual renderer; no desktop attachment.
const Settings = preload("res://settings/settings_store.gd")
const Store = preload("res://farm/farm_store.gd")
const Presets = preload("res://settings/graphics_presets.gd")
const Benchmark = preload("res://settings/startup_benchmark.gd")
var folder: String
var checks: int = 0
var failures: Array[String] = []
var scene: Node3D
var wallpaper_requests: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	folder = ProjectSettings.globalize_path("res://../.local/verification/startup-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	_test_policy()
	var startup: Node = load("res://scenes/startup.tscn").instantiate()
	startup.settings_store = Settings.new(folder.path_join("preferences"))
	startup.farm_store = Store.new(folder.path_join("farm"))
	root.add_child(startup)
	current_scene = startup
	await process_frame
	await _capture("loading.png")
	while not startup._choices.visible: await process_frame
	scene = startup.farm_scene
	_expect(scene.startup_complete and scene._loaded, "Staged construction produces the real usable farm")
	_expect(not FileAccess.file_exists(folder.path_join("preferences/settings.json")), "Measurement does not save settings before player choice")
	_expect(startup._tier_labels[0].text == "低" and startup._tier_labels[2].text == "高", "First-choice slider follows low/medium/high order")
	await _capture("first-choice.png")
	await _key(KEY_HOME)
	_expect(startup._selected == "low", "Slider Home selects the leftmost low tier")
	await _key(KEY_RIGHT)
	_expect(startup._selected == "standard", "Slider arrow moves exactly one tier")
	# A real I/O failure must keep the choice screen and permit a retry.
	DirAccess.make_dir_recursive_absolute(folder.path_join("preferences/settings.pending.json"))
	startup._slider.value = 0
	startup._continue.pressed.emit()
	while startup._starting: await process_frame
	_expect(startup._choices.visible and "未能保存" in startup._status.text, "First-choice write failure remains actionable")
	DirAccess.remove_absolute(folder.path_join("preferences/settings.pending.json"))
	startup._continue.pressed.emit()
	await startup.tree_exited
	await process_frame
	_expect(current_scene == scene and scene.is_processing_input(), "Finishing transfers input and current-scene ownership")
	_expect(scene.settings_values.quality == "low" and not scene.settings_values.dof_enabled, "Manual choice overrides the recommendation")
	var menu: Node = scene.game_menu
	scene._open_menu()
	menu._show_page(1)
	await create_timer(.3).timeout
	_expect(menu._quality.selected == 2, "Saved low preset is identified correctly")
	menu._dof.button_pressed = true
	_expect(menu._quality.selected == 3 and scene.focus_detail.get_settings().dof_enabled, "Low preset allows independent DOF and becomes custom")
	_choose(menu._graphics.shadows, 0)
	_expect(scene.focus_detail.get_settings().shadows == "high" and scene.focus_detail.get_settings().quality == "low", "Shadows no longer force scene detail")
	_choose(menu._quality, 0)
	while scene._high_quality_pending: await process_frame
	_expect(scene.settings_values.lighting == "high" and scene.camera.get_world_3d().environment.sdfgi_enabled, "High preset applies real high lighting")
	_choose(menu._graphics.quality, 2)
	_expect(scene.camera.get_world_3d().environment.sdfgi_enabled and menu._quality.selected == 3, "Detail override preserves high lighting")
	_choose(menu._quality, 1)
	_expect(not scene.camera.get_world_3d().environment.sdfgi_enabled, "Medium preset disables expensive high lighting")
	for height: int in [720, 1080, 1440, 2160]:
		root.size = Vector2i(height * 16 / 9, height)
		await process_frame
		menu._choose_preset(2)
		_expect(root.scaling_3d_scale * height <= 720.1, "Low preset respects its actual pixel budget at %dp" % height)
	root.size = Vector2i(960, 600)
	await process_frame
	await process_frame
	_expect(root.get_visible_rect().encloses(menu.get_node("Modal/Paper").get_global_rect()), "Scrollable settings fit the minimum window")
	await _capture("settings-minimum.png")
	# Observe intent, disconnecting the actual host to avoid attaching the desktop.
	menu.wallpaper_requested.disconnect(scene._enter_wallpaper)
	menu.wallpaper_requested.connect(func() -> void: wallpaper_requests += 1)
	menu._wallpaper.pressed.emit()
	_expect(wallpaper_requests == 0 and menu._wallpaper_confirmation.visible, "Wallpaper click only opens confirmation")
	await _capture("wallpaper-confirmation.png")
	scene._request_menu_close()
	_expect(menu.visible and not menu._wallpaper_confirmation.visible and wallpaper_requests == 0, "Escape/back cancels confirmation and stays in settings")
	menu._wallpaper.pressed.emit()
	menu._wallpaper_confirmation.get_node("Column/Actions/Confirm").pressed.emit()
	_expect(wallpaper_requests == 1, "Confirmation emits exactly one wallpaper request")
	menu.set_wallpaper_mode(true)
	menu._wallpaper.pressed.emit()
	_expect(wallpaper_requests == 2 and not menu._wallpaper_confirmation.visible, "Ending desktop interaction needs no new confirmation")
	var expected: Dictionary = scene.settings_values.duplicate(true)
	while scene.get_node("Environment")._terrain_refreshing: await process_frame
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	var reopen: Node = load("res://scenes/startup.tscn").instantiate()
	reopen.settings_store = Settings.new(folder.path_join("preferences"))
	reopen.farm_store = Store.new(folder.path_join("farm"))
	root.add_child(reopen)
	current_scene = reopen
	await reopen.tree_exited
	scene = current_scene
	_expect(scene.settings_values == expected, "Later startup restores custom preferences without another choice or benchmark")
	while scene.get_node("Environment")._terrain_refreshing: await process_frame
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	print("STARTUP_EXPERIENCE_TEST checks=%d failures=%d directory=%s" % [checks, failures.size(), folder])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _test_policy() -> void:
	var activity: Node = load("res://atmosphere/window_activity.gd").new()
	root.add_child(activity)
	activity._active = true
	activity.set_startup_benchmark(true)
	_expect(Engine.max_fps == 0, "Short test removes the gameplay cap only in the foreground")
	activity.set_startup_benchmark(false)
	_expect(Engine.max_fps == 60, "Short test restores the gameplay cap")
	activity._active = false
	activity.set_startup_benchmark(true)
	_expect(Engine.max_fps == 15, "Measurement mode never removes background throttling")
	activity.free()
	for height: int in [720, 1080, 1440, 2160]:
		var previous: float = INF
		for tier: String in Presets.ORDER:
			var preset: Dictionary = Presets.values(tier, height)
			var pixels: float = minf(float(preset.resolution), height)
			if preset.fsr != "off": pixels = height / (1.5 if preset.fsr == "quality" else 2.0)
			_expect(pixels <= previous, "Lower tiers never increase render height")
			previous = pixels
	_expect(Presets.recommend(RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU, 16 * 1024 * 1024 * 1024, 8, 1920 * 1080) == "low", "Integrated graphics starts conservatively")
	_expect(Presets.recommend(RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, 16 * 1024 * 1024 * 1024, 8, 1920 * 1080) == "standard", "Unknown discrete graphics is not assumed high end")
	var stable: Array[float] = []
	for i: int in 80: stable.append(16.0)
	_expect(Benchmark.summarize(stable).ok, "Stable real-frame timing is admitted")
	for i: int in 30: stable.append(150.0)
	_expect(not Benchmark.summarize(stable).ok, "Unstable timing cannot produce a confident recommendation")
	_expect(not Benchmark.summarize([16.0, 16.0]).ok, "Insufficient samples are rejected")


func _choose(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(filename))


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		root.push_input(event)
		await process_frame
