extends SceneTree
## Main-mode integration: temporary framing must never replace the user's overview.

const Store = preload("res://farm/farm_store.gd")
const Preferences = preload("res://settings/settings_store.gd")
var scene: Node3D
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var folder: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(".local/verification/decoration-framing-%d" % Time.get_ticks_usec())
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(folder.path_join("farm"))
	scene.settings_store = Preferences.new(folder.path_join("preferences"))
	scene.clock = func() -> float: return 1800000000.0
	root.add_child(scene)
	await create_timer(.2).timeout
	var initial: Dictionary = scene.farm_state.snapshot()
	scene.camera.drag(Vector2(18, -5), false)
	scene.camera.drag(Vector2(12, 7), true)
	var original_point: Vector3 = scene.camera.focus_point
	var original_view: Vector3 = scene.camera.view
	scene._focus_field(0)
	await create_timer(.85).timeout
	scene._select_cell("cell_01")
	scene._return_overview()
	# Enter immediately while the return tween is still at its focused starting pose.
	scene._begin_decoration()
	_expect(scene.decoration_layout.active and scene.selected_field == -1 and scene.selected_cell.is_empty(), "Entering from a returning focus clears farm selection")
	await create_timer(.85).timeout
	var arrangement_point: Vector3 = scene.camera.focus_point
	_expect(not arrangement_point.is_equal_approx(original_point), "Arrangement uses its temporary framing")
	scene.decoration_layout.cancel_preview()
	_expect(scene.decoration_layout.active and scene.camera.focus_point.is_equal_approx(arrangement_point), "Cancelling a preview keeps arrangement framing")
	scene._open_menu()
	_expect(scene.game_menu.visible and scene.decoration_layout.active, "Settings temporarily covers the current arrangement mode")
	scene._request_menu_close()
	_expect(not scene.game_menu.visible and scene.camera.focus_point.is_equal_approx(arrangement_point), "Closing settings preserves arrangement framing")
	await _escape()
	await create_timer(.85).timeout
	_expect(not scene.decoration_layout.active, "Escape with no preview finishes arrangement")
	_expect(scene.camera.focus_point.is_equal_approx(original_point) and scene.camera.view.is_equal_approx(original_view), "Finishing restores the original overview destination, not an interrupted focus")
	# Re-enter during the restoration tween; repeated finish must remain harmless.
	scene._begin_decoration()
	scene.decoration_layout.finish_mode()
	scene._begin_decoration()
	await create_timer(.85).timeout
	scene.decoration_layout.finish_mode()
	scene.decoration_layout.finish_mode()
	await create_timer(.85).timeout
	_expect(scene.camera.focus_point.is_equal_approx(original_point) and scene.camera.view.is_equal_approx(original_view), "Rapid re-entry and repeated finish do not accumulate offsets")
	scene._begin_decoration()
	scene._reset_view()
	await create_timer(.85).timeout
	_expect(not scene.decoration_layout.active and scene.selected_cell.is_empty(), "Reset ends arrangement and leaves no selected cell")
	_expect(scene.camera.focus_point.is_equal_approx(scene.camera.DEFAULT_POINT) and scene.camera.view.is_equal_approx(scene.camera.DEFAULT_VIEW), "Reset reaches the normal default composition")
	scene._begin_decoration()
	await create_timer(.85).timeout
	scene._return_overview()
	await create_timer(.85).timeout
	_expect(not scene.decoration_layout.active and scene.camera.view.is_equal_approx(scene.camera.DEFAULT_VIEW), "Explicit overview exits temporary framing")
	_expect(scene.farm_state.snapshot() == initial, "Mode and framing changes never alter farm data")
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	print("DECORATION_FRAMING_SCENE_TEST checks=%d failures=%d evidence=%s" % [checks, failures.size(), folder])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _escape() -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = down
		root.push_input(event)
		await process_frame


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
