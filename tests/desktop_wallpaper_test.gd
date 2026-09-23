extends SceneTree
## Real Windows host round-trip against an isolated farm, no Explorer restart.
const FarmStore = preload("res://farm/farm_store.gd")
const SettingsStore = preload("res://settings/settings_store.gd")
var scene: Node3D
var failures: Array[String] = []
var evidence: String

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition: failures.append(message)

func _run() -> void:
	evidence = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(".local/verification/desktop-%d" % Time.get_unix_time_from_system())
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = FarmStore.new(evidence.path_join("farm"))
	scene.settings_store = SettingsStore.new(evidence.path_join("preferences"))
	root.add_child(scene)
	await create_timer(2).timeout
	var controller: Node = scene.desktop_wallpaper
	check(controller.available(), "Standalone native host found")
	var before: Dictionary = scene.farm_state.snapshot()
	var original_size: Vector2i = root.size
	var original_position: Vector2i = root.position
	scene._open_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(evidence.path_join("settings.png"))
	for cycle: int in 2:
		scene._enter_wallpaper()
		for tick: int in 100:
			await create_timer(0.1).timeout
			if controller.active: break
		check(controller.active, "Native desktop attached cycle %d" % cycle)
		if not controller.active: break
		# The menu dismissal is animated; wait for its next covered 2 FPS frame.
		await create_timer(0.6).timeout
		check(not scene.hud.visible and not scene.game_menu.visible, "Wallpaper hides gameplay UI")
		check(root.gui_disable_input, "Wallpaper never handles desktop clicks")
		var stream := FileAccess.open(evidence.path_join("active.json"), FileAccess.WRITE)
		stream.store_string(JSON.stringify({"pid": OS.get_process_id(), "host": controller._host.pid,
			"hwnd": DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), "cycle": cycle}))
		stream.close()
		await create_timer(3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence.path_join("wallpaper-%d.png" % cycle))
		scene.window_activity.set_wallpaper_visible(true)
		check(Engine.max_fps == 30, "Visible wallpaper cap is 30 fps without focus")
		if cycle == 0:
			controller.set_interacting(true)
			for tick: int in 100:
				await create_timer(0.1).timeout
				if controller.interacting and not controller.busy: break
			check(controller.interacting and Engine.max_fps == 60, "Interactive desktop is capped at 60 fps")
			controller.set_interacting(false)
			for tick: int in 100:
				await create_timer(0.1).timeout
				if not controller.interacting and not controller.busy: break
			check(not controller.interacting and Engine.max_fps == 30, "Desktop observation resumes at 30 fps")
		scene.window_activity.set_wallpaper_visible(false)
		check(Engine.max_fps == 2, "Covered wallpaper keeps settlement alive at 2 fps")
		controller.restore()
		for tick: int in 100:
			await create_timer(0.1).timeout
			if not controller.active and controller._host.is_empty(): break
		check(not controller.active and not controller.busy and controller._host.is_empty(), "Restore terminates host")
		check(root.size == original_size and root.position == original_position, "Original window bounds restored")
		check(scene.hud.visible and not root.gui_disable_input, "Gameplay UI and input restored")
		check(scene.farm_state.snapshot().inventory == before.inventory, "Switching modes never changes inventory")
		scene._open_menu()
	print("DESKTOP_TEST_RESULT failures=%d evidence=%s" % [failures.size(), evidence])
	scene._request_exit()
	if not failures.is_empty(): quit(1)
