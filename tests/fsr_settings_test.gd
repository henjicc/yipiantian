extends SceneTree
## Real Forward+ rendering, menu intent and preference reload in isolated storage.
const FarmStore = preload("res://farm/farm_store.gd")
const SettingsStore = preload("res://settings/settings_store.gd")
var scene: Node3D
var folder: String
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	folder = ProjectSettings.globalize_path("res://../.local/verification/fsr-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1920, 1080)
	await _open()
	_expect(RenderingServer.get_current_rendering_method() == "forward_plus", "Test uses the real supported renderer")
	_expect(scene.settings_values.fsr == "off", "FSR remains opt-in")
	scene._open_menu()
	scene.game_menu._show_page(0)
	for index: int in [1, 2, 3]:
		_choose(scene.game_menu._fsr, index)
		await create_timer(.4).timeout
		_expect(root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 and root.msaa_3d == Viewport.MSAA_DISABLED, "Preset enables FSR2 without duplicate MSAA")
		_expect(is_equal_approx(root.scaling_3d_scale, [0.0, 1.0 / 1.5, 1.0 / 1.7, .5][index]), "Preset uses its output-relative scale")
	_expect(scene.game_menu._resolution.disabled, "Inactive manual resolution is visibly disabled")
	await _capture("settings.png")
	_choose(scene.game_menu._graphics.quality, 0)
	_choose(scene.game_menu._graphics.lighting, 0)
	_choose(scene.game_menu._graphics.antialiasing, 2)
	await create_timer(.5).timeout
	_expect(scene.focus_detail.get_settings().quality == "high" and root.msaa_3d == Viewport.MSAA_DISABLED, "Deferred high quality keeps FSR antialiasing")
	_choose(scene.game_menu._fsr, 0)
	_expect(root.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR and root.msaa_3d == Viewport.MSAA_4X and not scene.game_menu._resolution.disabled, "Turning FSR off restores high-quality MSAA and manual resolution")
	_choose(scene.game_menu._quality, 1)
	_choose(scene.game_menu._fsr, 2)
	root.size = Vector2i(2560, 1440)
	await create_timer(.4).timeout
	_expect(is_equal_approx(root.scaling_3d_scale, 1.0 / 1.7), "Window resizing retains FSR scale")
	_choose(scene.game_menu._fsr, 0)
	_expect(is_equal_approx(root.scaling_3d_scale, .75) and root.msaa_3d == Viewport.MSAA_2X, "Turning off restores the saved 1080p cap after resize")
	_choose(scene.game_menu._fsr, 2)
	scene._request_menu_close()
	await create_timer(.3).timeout
	await _capture("farm-balanced.png")
	await _close()
	await _open()
	_expect(scene.settings_values.fsr == "balanced" and root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 and is_equal_approx(root.scaling_3d_scale, 1.0 / 1.7), "Reopening restores saved FSR in the actual viewport")
	await _close()
	print("FSR_SETTINGS_TEST checks=%d failures=%d directory=%s" % [checks, failures.size(), folder])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _open() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = FarmStore.new(folder.path_join("farm"))
	scene.settings_store = SettingsStore.new(folder.path_join("preferences"))
	root.add_child(scene)
	await create_timer(.5).timeout


func _close() -> void:
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame


func _choose(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(filename))


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
