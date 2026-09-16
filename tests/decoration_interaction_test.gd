extends SceneTree
## Full scene, real UI/input dispatch, isolated save root; no player data or clock changes.

const Farm = preload("res://farm/farm_state.gd")
const Decorations = preload("res://farm/decoration_state.gd")
const Store = preload("res://farm/farm_store.gd")
var scene: Node3D
var folder: String
var captures: String = ""
var now: float = 1800000000.0
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			captures = argument.trim_prefix("--screenshots=")
	_run.call_deferred()


func _run() -> void:
	folder = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification/decoration-input-%d" % Time.get_ticks_usec())
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(captures)
	var farm := Farm.new(now)
	var data: Dictionary = farm.snapshot()
	data.harvested = {"greens": 10, "radish": 6}
	farm.restore_snapshot(data)
	var decoration := Decorations.new()
	decoration.unlock(data.harvested)
	var store := Store.new(folder)
	store.load_state()
	store.save(farm.snapshot(), decoration.snapshot())
	root.size = Vector2i(1280, 720)
	await _open_scene()
	_expect(scene.decoration_layout != null, "Production courtyard and arrangement controller are present")
	var asset_keys: Array = scene.get_node("Environment").get_asset_keys()
	_expect(asset_keys.has("MainHouse") and asset_keys.has("EntranceTrellis") and asset_keys.has("CoveredBoat"), "Formal courtyard architecture reaches all required landmarks")
	if scene.decoration_layout == null:
		_finish()
		return
	var initial_farm: Dictionary = scene.farm_state.snapshot()
	await _click(scene.camera.unproject_position(scene.farm.fields[0].global_position))
	await create_timer(0.85).timeout
	await _click(scene.get_node("HUD/Layout/FarmControls/Sow").get_global_rect().get_center())
	await _enter()
	var visibility_begin: int = Time.get_ticks_usec()
	var visibility: Dictionary = {}
	for slot_id: String in Decorations.Catalog.SLOT_TYPES:
		visibility[slot_id] = scene.decoration_layout._slot_visible(slot_id)
	print("DECORATION_VISIBILITY warm_usec=%d slots=%s" % [Time.get_ticks_usec() - visibility_begin, visibility])
	_expect(scene.selected_field == -1 and scene.selected_tool.is_empty(), "Entering arrangement returns overview and cancels tool")
	await _click(scene.camera.unproject_position(scene.farm.fields[0].global_position))
	_expect(scene.farm_state.snapshot() == initial_farm, "Field click in arrangement cannot sow or focus")
	var initial_decor: Dictionary = scene.decoration_state.snapshot()
	var saved: String = FileAccess.get_file_as_string(folder.path_join(Store.MAIN))
	await _choose("Pot")
	await _slot("ground_01")
	_expect(scene.decoration_layout.preview_slot == "ground_01" and scene.decoration_state.snapshot() == initial_decor, "World target creates preview without committing")
	await _control("Rotate")
	_expect(scene.decoration_layout.preview_turn == 1, "Rotate affects pending orientation")
	await _control("Cancel")
	_expect(scene.decoration_state.snapshot() == initial_decor and FileAccess.get_file_as_string(folder.path_join(Store.MAIN)) == saved, "Cancel leaves original state and save bytes untouched")
	await _choose("Pot")
	await _slot("ground_01")
	await _control("Confirm")
	_expect(Store.new(folder).load_state().decorations.pot.slot_id == "ground_01", "Confirm saves placement")
	await _choose("Pot")
	await _slot("ground_02")
	await _key(KEY_ESCAPE)
	_expect(scene.decoration_state.snapshot().pot.slot_id == "ground_01" and scene.decoration_layout.active, "Escape cancels movement before leaving arrangement")
	_expect(scene.decoration_layout.get("_instances").pot.visible, "Cancelled move restores original visible object")
	await _choose("Flowerpot")
	_expect(not scene.decoration_layout.get("_rings").ground_01.visible, "Occupied slot is not offered to another item")
	await _slot("ground_02")
	await _control("Confirm")
	for target: String in ["ground_03", "ground_04"]:
		await _choose("Pot")
		await _slot(target)
		await _control("Confirm")
		_expect(scene.decoration_state.snapshot().pot.slot_id == target, "Multiple actual ground slots can be used")
	for target: String in ["hanging_01", "hanging_02", "hanging_03", "hanging_04"]:
		await _choose("Lantern")
		await _slot(target)
		_expect(scene.decoration_layout.preview_slot == target, "Each hanging marker is reached through viewport input")
		if target == "hanging_02":
			await _capture("01-hanging-preview.png")
		await _control("Confirm")
		_expect(scene.decoration_state.snapshot().lantern.slot_id == target, "Confirmed lantern move keeps stable slot ID")
	await _capture("02-all-decorated.png")
	var confirmed: Dictionary = scene.decoration_state.snapshot()
	await _choose("Pot")
	await _slot("ground_03")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	_expect(not scene.decoration_layout.active and scene.decoration_state.snapshot() == confirmed, "Losing focus discards preview and leaves confirmed placement")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await _enter()
	await _choose("Pot")
	await _slot("ground_03")
	FileAccess.set_read_only_attribute(folder.path_join(Store.MAIN), true)
	await _control("Confirm")
	_expect(scene.get_node("HUD/Layout/StorageOverlay").visible and not scene.decoration_layout.active, "Placement save failure leaves truthful blocked state")
	_expect(Store.new(folder).load_state().decorations == confirmed, "Failed save does not replace disk placement")
	FileAccess.set_read_only_attribute(folder.path_join(Store.MAIN), false)
	var retry: Button = scene.get_node("HUD/Layout/StorageOverlay").find_child("Retry", true, false)
	await _click(retry.get_global_rect().get_center())
	_expect(Store.new(folder).load_state().decorations.pot.slot_id == "ground_03" and scene.farm_state.snapshot() == initial_farm, "Retry saves current placement without farming or repeat unlocks")
	var final: Dictionary = scene.decoration_state.snapshot()
	await _close_scene()
	await _open_scene()
	_expect(scene.decoration_state.snapshot() == final and scene.farm_state.snapshot() == initial_farm, "New scene restores decorations and harvest exactly")
	await _capture("03-reopened.png")
	await _close_scene()
	_finish()


func _open_scene() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(folder)
	scene.clock = func() -> float: return now
	root.add_child(scene)
	await process_frame
	await physics_frame


func _close_scene() -> void:
	root.remove_child(scene)
	scene.queue_free()
	await process_frame


func _enter() -> void:
	await _click(scene.get_node("HUD/Layout/ViewControls/Decorate").get_global_rect().get_center())
	await create_timer(0.85).timeout
	_expect(scene.decoration_layout.active, "Arrangement entry is a working UI action")


func _choose(name: String) -> void:
	await _control(name)


func _control(name: String) -> void:
	var button: Button = scene.decoration_layout.hud.find_child(name, true, false)
	await _click(button.get_global_rect().get_center())


func _slot(id: String) -> void:
	var marker: Node3D = scene.decoration_layout.get_node(NodePath(id))
	await _click(scene.camera.unproject_position(marker.global_position))


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await physics_frame
		await process_frame


func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	await process_frame


func _capture(filename: String) -> void:
	if not captures.is_empty():
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(captures.path_join(filename)) == OK, "Save actual arrangement screenshot")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print("DECORATION_INTERACTION_TEST checks=%d failures=%d directory=%s" % [checks, failures.size(), folder])
	quit(0 if failures.is_empty() else 1)
