extends SceneTree
## Real scene + real filesystem failures. All fixtures stay below .local/verification.

const Farm = preload("res://farm/farm_state.gd")
const Store = preload("res://farm/farm_store.gd")
var scene: Node3D
var folder: String
var now: float = 1800000000.0
var failures: Array[String] = []
var checks: int = 0
var captures: String = ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshots="):
			captures = arg.trim_prefix("--screenshots=")
	_run.call_deferred()


func _run() -> void:
	folder = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification/storage-scene-%d" % Time.get_ticks_usec())
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(captures)
	root.size = Vector2i(1280, 720)
	await _open_scene()
	var path: String = folder.path_join(Store.MAIN)
	var disk: Dictionary = Store.new(folder).load_state().farm
	_expect(disk.harvested.greens == 0, "First startup saves initial farm")
	await _click(scene.camera.unproject_position(scene.farm.fields[2].global_position + Vector3(0, 0.4, 0)))
	await create_timer(0.85).timeout
	await _click(scene.camera.unproject_position(scene.farm.fields[2].to_global(scene.farm.cell_center("cell_06"))))
	var harvest: Button = scene.get_node("HUD/Layout/FarmControls/Harvest")
	FileAccess.set_read_only_attribute(path, true)
	await _click(harvest.get_global_rect().get_center())
	_expect(scene.farm_state.snapshot().harvested.greens == 1, "Farm action succeeds in memory exactly once")
	_expect(Store.new(folder).load_state().farm.harvested.greens == 0, "Failed replace leaves previous saved reward")
	_expect(_overlay().visible and scene.get_node("HUD/Layout/SessionStatus").text == "尚未保存", "Save failure is visible and blocks unsafe further actions")
	await _capture("01-save-failed.png")
	scene.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await process_frame
	_expect(scene.is_inside_tree() and _overlay().visible, "Closing after save failure keeps the game open")
	_expect(_overlay().find_child("Exit", true, false).text.contains("未保存"), "Explicit discard exit truthfully says changes are unsaved")
	FileAccess.set_read_only_attribute(path, false)
	await _click(_overlay().find_child("Retry", true, false).get_global_rect().get_center())
	_expect(not _overlay().visible, "Successful retry dismisses failure state")
	_expect(Store.new(folder).load_state().farm.harvested.greens == 1, "Retry saves current result without a second reward")
	await _reopen_scene()
	_expect(scene.farm_state.snapshot().harvested.greens == 1 and scene.farm_state.get_cell("field_03", "cell_06").stage == "empty", "Recreated scene loads the already harvested cell")
	# Revisit after a long interval through the same injected UTC entrance.
	now += 100000.0
	await _reopen_scene()
	_expect(scene.farm_state.get_cell("field_04", "cell_06").stage == "mature" and scene.farm_state.snapshot().harvested.greens == 1, "Long offline visit matures crops without auto harvesting")
	var before_rollback: Dictionary = scene.farm_state.snapshot()
	now -= 200000.0
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_expect(scene.farm_state.snapshot() == before_rollback, "Focus return during rollback neither reverses growth nor rewinds baseline")
	# Corrupt main, retain actual previous validated backup, then recover using its visible UI button.
	await _close_scene()
	_write(path, "truncated{")
	await _open_scene()
	_expect(_overlay().visible and not scene.farm.visible, "Broken main cannot show a fake newly initialized farm")
	_expect(FileAccess.get_file_as_string(path) == "truncated{", "Startup failure preserves original bytes")
	await _capture("02-recovery-offer.png")
	await _click(_overlay().find_child("Recover", true, false).get_global_rect().get_center())
	_expect(not _overlay().visible and scene.farm.visible, "Explicit UI recovery restores usable farm")
	_expect(scene.farm_state.snapshot().harvested.greens == 1, "Recovery keeps saved totals")
	await _close_scene()
	var unsupported: String = JSON.stringify({"version": 99, "farm": before_rollback})
	_write(path, unsupported)
	await _open_scene()
	_expect(_overlay().visible and not _overlay().find_child("Recover", true, false).visible, "Newer format locks gameplay and hides downgrade recovery")
	await _click(_overlay().find_child("Retry", true, false).get_global_rect().get_center())
	_expect(FileAccess.get_file_as_string(path) == unsupported, "Retry load cannot overwrite a newer-format file")
	await _capture("03-unsupported.png")
	await _close_scene()
	for message: String in failures:
		push_error(message)
	print("FARM_STORAGE_SCENE_TEST checks=%d failures=%d directory=%s" % [checks, failures.size(), folder])
	quit(0 if failures.is_empty() else 1)


func _open_scene() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(folder)
	scene.settings_store = load("res://settings/settings_store.gd").new(scene.store.directory.path_join("preferences"))
	scene.clock = func() -> float: return now
	root.add_child(scene)
	await create_timer(0.4).timeout


func _close_scene() -> void:
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame


func _reopen_scene() -> void:
	await _close_scene()
	await _open_scene()


func _overlay() -> Control:
	return scene.get_node("HUD/Layout/StorageOverlay")


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	await process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event)
		await physics_frame
		await process_frame


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)
	file.close()


func _capture(filename: String) -> void:
	if captures.is_empty():
		return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(captures.path_join(filename)) == OK, "Save storage-state screenshot")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
