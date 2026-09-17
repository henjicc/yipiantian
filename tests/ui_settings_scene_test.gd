extends SceneTree
## UI intent, world-input isolation and real preference failures on the final scene.

const FarmStore = preload("res://farm/farm_store.gd")
const SettingsStore = preload("res://settings/settings_store.gd")
var scene: Node3D
var folder: String
var now: float = 1800000000.0
var checks: int = 0
var failures: Array[String] = []
var captures: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			captures = argument.trim_prefix("--screenshots=")
	_run.call_deferred()


func _run() -> void:
	folder = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(".local/verification/ui-scene-%d" % Time.get_ticks_usec())
	root.size = Vector2i(1280, 720)
	await _open_scene()
	_expect(scene._loaded and not scene.game_menu.visible, "First launch opens the playable farm directly")
	_expect(root.min_size == Vector2i(960, 600), "The actual Window enforces the minimum size")
	var initial: Dictionary = scene.farm_state.snapshot()
	await _capture("01-overview.png")
	await _click(scene.camera.unproject_position(scene.farm.fields[2].global_position + Vector3(0, 0.4, 0)))
	await create_timer(0.85).timeout
	await _click(scene.camera.unproject_position(scene.farm.fields[2].to_global(scene.farm.cell_center("cell_06"))))
	await _capture("01b-focus.png")
	_expect(scene.selected_cell == "cell_06" and scene.selected_tool.is_empty(), "Mature cell can be inspected without arming a tool")
	await _click(scene.get_node("HUD/Layout/ViewControls/Settings").get_global_rect().get_center())
	_expect(scene.game_menu.visible and scene.selected_tool.is_empty(), "Settings opens its modal without executing the selected cell")
	await _click(scene.camera.unproject_position(scene.farm.fields[0].global_position + Vector3(0, 0.4, 0)))
	_expect(scene.farm_state.snapshot() == initial, "Clicking through the settings modal cannot harvest")
	_expect(scene.selected_field == 2, "Clicking an uncovered neighbor behind the modal cannot change selection")
	scene.game_menu._sliders.master.value = 0
	_expect(scene.farm_audio.get_volumes().master == 0.0, "Actual audio owner receives master mute")
	scene.game_menu._quality.select(1)
	scene.game_menu._quality.item_selected.emit(1)
	_expect(scene.focus_detail.get_settings().quality == "low", "Quality control reaches actual focus controller")
	scene.game_menu._dof.button_pressed = false
	_expect(not scene.focus_detail.get_settings().dof_enabled and scene.selected_field == 2, "DOF toggles without losing field selection")
	await _capture("02-settings.png")
	scene.game_menu._show_page(1)
	await _capture("03-controls.png")
	scene.game_menu._show_page(2)
	await _capture("04-sources.png")
	await _cancel_key()
	_expect(not scene.game_menu.visible and scene.selected_field == 2, "Escape closes modal before returning the camera")
	var preferences: Dictionary = SettingsStore.new(folder.path_join("preferences")).load_settings().settings
	_expect(preferences.master == 0.0 and preferences.quality == "low" and not preferences.dof_enabled, "Closing saves chosen preferences")
	_expect(scene.farm_state.snapshot() == initial, "Menu lifecycle never initializes or changes farm progress")
	await _reopen_scene()
	_expect(scene.farm_audio.get_volumes().master == 0.0 and scene.focus_detail.get_settings().quality == "low", "Revisit applies stored audio and quality")
	_expect(scene.farm_state.snapshot() == initial, "Revisit restores the same farm")
	await _click(scene.get_node("HUD/Layout/ViewControls/Settings").get_global_rect().get_center())
	var preference_file: String = folder.path_join("preferences/settings.json")
	var old_bytes: String = FileAccess.get_file_as_string(preference_file)
	FileAccess.set_read_only_attribute(preference_file, true)
	scene.game_menu._sliders.music.value = 25
	await _click(scene.game_menu._save.get_global_rect().get_center())
	_expect(scene.game_menu.visible and "未能保存" in scene.game_menu._status.text, "Settings failure remains distinct and truthful")
	_expect(not scene._save_failed, "Preference failure does not block farm storage")
	_expect(FileAccess.get_file_as_string(preference_file) == old_bytes, "Preference replacement failure retains committed bytes")
	await _capture("05-settings-failed.png")
	FileAccess.set_read_only_attribute(preference_file, false)
	await _click(scene.game_menu._save.get_global_rect().get_center())
	_expect("已保存" in scene.game_menu._status.text, "Explicit settings retry reports confirmed save")
	await _cancel_key()
	_expect(not scene.game_menu.visible, "Successful retry restores normal modal return")
	# Missing or unreadable preferences do not affect a valid existing farm.
	await _close_scene()
	_write(preference_file, "broken settings {")
	await _open_scene()
	_expect(scene._loaded and scene.farm_state.snapshot() == initial, "Corrupt preferences leave farm progress usable")
	_expect(scene.farm_audio.get_volumes().master == SettingsStore.DEFAULTS.master, "Corrupt preferences apply reasonable defaults")
	_expect(FileAccess.get_file_as_string(preference_file) == "broken settings {", "Startup never overwrites a corrupt preference original")
	await _click(scene.get_node("HUD/Layout/ViewControls/Settings").get_global_rect().get_center())
	_expect("设置" in scene.game_menu._status.text and not scene.game_menu._status.text.is_empty(), "Preference load failure is visible inside settings")
	await _click(scene.game_menu._save.get_global_rect().get_center())
	_expect(SettingsStore.new(folder.path_join("preferences")).load_settings().ok, "Explicit save repairs preferences after preserving original")
	await _cancel_key()
	# Modal does not pause the farm's injected UTC clock.
	await _click(scene.get_node("HUD/Layout/ViewControls/Settings").get_global_rect().get_center())
	now += 100000.0
	scene.settle_farm()
	_expect(scene.game_menu.visible and scene.farm_state.get_cell("field_04", "cell_06").stage == "mature", "Reality-time growth continues while settings are open")
	for dimensions: Vector2i in [Vector2i(960, 600), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]:
		root.size = dimensions
		await process_frame
		await process_frame
		_expect(root.get_visible_rect().encloses(scene.game_menu.get_node("Modal/Paper").get_global_rect()), "Settings layout fits %s" % str(dimensions))
		await _capture("06-settings-%dx%d.png" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	scene._request_menu_close()
	scene.atmosphere.set_preview_hour(22.0)
	await create_timer(0.4).timeout
	await _capture("07-night-readability.png")
	scene.atmosphere.set_preview_hour(11.0)
	scene._begin_decoration()
	await create_timer(0.9).timeout
	await _capture("08-decoration.png")
	await _click(scene.get_node("HUD/Layout/ViewControls/Settings").get_global_rect().get_center())
	var farm_file: String = folder.path_join("farm/farm.json")
	FileAccess.set_read_only_attribute(farm_file, true)
	_expect(not scene._save_farm(), "Real farm save can fail while the settings modal is open")
	_expect(not scene.game_menu.visible and scene.get_node("HUD/Layout/StorageOverlay").visible, "Farm save failure dismisses the menu and exposes its own recovery choices")
	for step: int in 5:
		for down: bool in [true, false]:
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.pressed = down
			root.push_input(tab)
			await process_frame
		_expect(scene.get_node("HUD/Layout/StorageOverlay").is_ancestor_of(root.gui_get_focus_owner()), "Storage failure retains keyboard focus inside its recovery choices")
	await _capture("09-farm-failure-over-menu.png")
	FileAccess.set_read_only_attribute(farm_file, false)
	scene._retry_storage()
	_expect(not scene._save_failed and not scene.get_node("HUD/Layout/StorageOverlay").visible, "Farm save retry restores the underlying game")
	await _close_scene()
	print("UI_SETTINGS_SCENE_TEST checks=%d failures=%d directory=%s" % [checks, failures.size(), folder])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _open_scene() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = FarmStore.new(folder.path_join("farm"))
	scene.settings_store = SettingsStore.new(folder.path_join("preferences"))
	scene.clock = func() -> float: return now
	root.add_child(scene)
	await create_timer(0.4).timeout


func _close_scene() -> void:
	# Audio mixing releases stopped playback objects on a later frame in headless runs.
	scene.farm_audio.shutdown()
	await create_timer(0.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame


func _reopen_scene() -> void:
	await _close_scene()
	await _open_scene()


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await physics_frame
		await process_frame


func _cancel_key() -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func _capture(filename: String) -> void:
	if captures.is_empty():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(captures)
	root.get_texture().get_image().save_png(captures.path_join(filename))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
