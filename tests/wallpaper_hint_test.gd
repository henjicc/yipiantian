extends SceneTree
## Exercise real hint UI and host-message routing in isolated storage without
## attaching to the user's desktop or installing another native input hook.
const Settings = preload("res://settings/settings_store.gd")
const Store = preload("res://farm/farm_store.gd")
var scene: Node3D
var folder: String
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	folder = ProjectSettings.globalize_path("res://../.local/verification/wallpaper-hint-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(folder.path_join("farm"))
	scene.settings_store = Settings.new(folder.path_join("preferences"))
	root.add_child(scene)
	current_scene = scene
	await create_timer(.5).timeout
	scene._open_menu()
	await create_timer(.3).timeout
	var menu: Node = scene.game_menu
	_expect(menu._tabs[0].text == "显示" and menu._pages[0].visible, "Settings opens on Display")
	_expect(menu._wallpaper.text == "设为壁纸" and menu._wallpaper.get_parent() == menu._close.get_parent() and menu._wallpaper.get_parent() == menu._quit.get_parent(), "Wallpaper is a peer footer action")
	await _capture("settings.png")
	var host: Node = scene.desktop_wallpaper
	var hint: Node = scene.wallpaper_hint
	_expect(not hint.visible, "No bubble before confirmed desktop attachment")
	host._receive("ATTACHED")
	await create_timer(.4).timeout
	_expect(hint.visible and scene.get_node("Environment/DoorTools")._chair_hint, "Successful attachment shows anchored bubble and chair outline")
	_expect(root.gui_disable_input and not host.interacting, "Hint never enables gameplay input in observation mode")
	await _capture("chair-hint.png")
	var close_at: Vector2 = hint._buttons[1].get_global_rect().get_center()
	_button(close_at, true)
	host._receive("LEAVE")
	_button(close_at, false)
	_expect(hint.visible, "Leaving desktop cancels a pending bubble click")
	_button(close_at, true)
	_button(close_at + Vector2(20, 0), false)
	_expect(hint.visible, "A drag across the bubble does not close it")
	_click(close_at)
	_expect(not hint.visible and not scene.get_node("Environment/DoorTools")._chair_hint, "Close removes both bubble and highlight")
	_expect(not scene.settings_values.wallpaper_hint_dismissed and not scene._wallpaper_click.is_finite(), "Close stays temporary and cannot activate the scene underneath")
	host.active = false
	scene._wallpaper_changed(false)
	host._receive("ATTACHED")
	await process_frame
	_expect(hint.visible, "Temporary close allows the next wallpaper entry to show the hint")
	host._receive("INTERACTIVE")
	_expect(not hint.visible and not scene.get_node("Environment/DoorTools")._chair_hint, "Starting interaction clears guidance")
	host._receive("OBSERVING")
	_expect(not hint.visible, "Ending interaction does not nag again in the same wallpaper session")
	host.active = false
	scene._wallpaper_changed(false)
	host._receive("ATTACHED")
	await process_frame
	DirAccess.make_dir_recursive_absolute(folder.path_join("preferences/settings.pending.json"))
	_click(hint._buttons[0].get_global_rect().get_center())
	_expect(hint.visible and "未能保存" in hint._label.text and not scene.settings_values.wallpaper_hint_dismissed, "Failed opt-out remains visible and retryable")
	DirAccess.remove_absolute(folder.path_join("preferences/settings.pending.json"))
	await process_frame
	_click(hint._buttons[0].get_global_rect().get_center())
	_expect(not hint.visible and scene.settings_values.wallpaper_hint_dismissed, "Retry saves permanent dismissal")
	var loaded: Dictionary = Settings.new(folder.path_join("preferences")).load_settings()
	_expect(loaded.ok and loaded.settings.wallpaper_hint_dismissed, "Permanent dismissal survives reading preferences from disk")
	host.active = false
	scene._wallpaper_changed(false)
	scene.settings_values = loaded.settings
	host._receive("ATTACHED")
	_expect(not hint.visible, "Saved preference suppresses guidance on subsequent entries")
	host.active = false
	scene._wallpaper_changed(false)
	# Validate anchoring against the real camera and minimum window work area.
	root.size = Vector2i(960, 600)
	hint.set_workarea(Vector4(0, 0, 1, .92))
	hint.present(scene.camera, scene.get_node("Environment/DoorTools").chair)
	await create_timer(.2).timeout
	_expect(Rect2(Vector2(12, 12), root.get_visible_rect().size * Vector2(1, .92) - Vector2(24, 24)).encloses(hint._panel.get_global_rect()), "Hint stays inside the minimum window and above taskbar")
	await _capture("chair-hint-minimum.png")
	hint.dismiss()
	var invalid: Dictionary = loaded.settings.duplicate(true)
	invalid.wallpaper_hint_dismissed = "true"
	_expect(not Settings.valid_settings(invalid), "Opt-out accepts only boolean preference values")
	while scene.get_node("Environment")._terrain_refreshing: await process_frame
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	print("WALLPAPER_HINT_TEST checks=%d failures=%d directory=%s" % [checks, failures.size(), folder])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _button(point: Vector2, pressed: bool) -> void:
	var normalized: Vector2 = point / root.get_visible_rect().size
	scene.desktop_wallpaper._receive("BUTTON 1 %d %.8f %.8f 1 0" % [int(pressed), normalized.x, normalized.y])


func _click(point: Vector2) -> void:
	_button(point, true)
	_button(point, false)


func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(filename))


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
