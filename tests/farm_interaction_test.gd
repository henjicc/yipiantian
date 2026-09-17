extends SceneTree

var scene: Node3D
var now: float = 1800000000.0
var checks: int = 0
var failures: Array[String] = []
var capture_dir: String = ""
var actions: int = 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			capture_dir = argument.trim_prefix("--screenshots=")
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.clock = func() -> float: return now
	var isolated: String = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification/grid-input-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store = load("res://settings/settings_store.gd").new(scene.store.directory.path_join("preferences"))
	root.add_child(scene)
	root.grab_focus()
	scene.farm_changed.connect(func(_result: Dictionary) -> void: actions += 1)
	await create_timer(0.6).timeout
	var baseline: Dictionary = scene.farm_state.snapshot()
	_expect(scene.farm.field_id(0) == "field_01", "Visual field retains stable identity")
	_expect(scene.farm.fields[0].get_node("Crops").get_child_count() == 0, "Empty cells have no crop placeholders")
	await _capture("01-overview.png")
	await _click(_point(0))
	_expect(scene.selected_field == 0 and scene.selected_cell.is_empty() and scene.farm_state.snapshot() == baseline, "Overview click only focuses a field")
	await _click(_point(0, "cell_01"))
	await create_timer(0.85).timeout
	_expect(scene.selected_cell.is_empty() and scene.farm_state.snapshot() == baseline, "Travel clicks never become a cell action after landing")
	_expect(_control("Sow").disabled, "No selected cell means no available farm action")
	# Every empty cell is a real soil target, independent of plant colliders.
	for cell_id: String in scene.farm_state.CELL_IDS:
		await _click(_point(0, cell_id))
		_expect(scene.selected_cell == cell_id, "Native soil ray selects exact empty cell " + cell_id)
	await _click(_point(0, "cell_01"))
	_expect(scene.farm_state.snapshot() == baseline, "Selecting empty soil never sows")
	await _tool("Sow")
	_expect(_cell(0, "cell_01").crop_id == "greens" and _cell(0, "cell_01").stage == "sprout", "Sow button immediately acts on the selected cell")
	_expect(actions == 1 and scene.selected_cell == "cell_01" and scene.selected_tool.is_empty(), "Action retains selected cell without an armed world tool")
	var crop_root: Node3D = scene.farm.fields[0].get_node("Crops")
	var first_instance: int = crop_root.get_node("cell_01").get_instance_id()
	scene.settle_farm()
	_expect(crop_root.get_node("cell_01").get_instance_id() == first_instance, "Unchanged cell stage retains its crop node")
	await _button(_point(0, "cell_01"), true, MOUSE_BUTTON_LEFT, true)
	await _button(_point(0, "cell_01"), false)
	_expect(actions == 1, "Double world click cannot replay a farm action")
	await _click(_point(0, "cell_02"))
	await _choose_radish()
	await _tool("Sow")
	_expect(_cell(0, "cell_02").crop_id == "radish" and _cell(0, "cell_01").crop_id == "greens", "Adjacent cells genuinely mix two selected crops")
	_expect(crop_root.get_child_count() == 2, "Only the two planted cells contain real stage resources")
	var neighbor_instance: int = crop_root.get_node("cell_02").get_instance_id()
	await _click(_point(0, "cell_01"))
	await _tool("Water")
	_expect(_cell(0, "cell_01").watered and is_equal_approx(_cell(0, "cell_01").progress, .2), "Water button boosts only the selected cell")
	_expect(not _cell(0, "cell_02").watered and _cell(0, "cell_02").progress == 0.0, "Neighbor growth and watering remain independent")
	_expect(scene.farm._soil_meshes.field_01.cell_01.material_override != scene.farm._soil_meshes.field_01.cell_02.material_override, "Wet soil belongs to one cell, not the whole field")
	await _capture("02-mixed-watered.png")
	var watered: Dictionary = scene.farm_state.snapshot()
	await _tool("Water")
	_expect(scene.farm_state.snapshot() == watered and actions == 3, "Repeated watering cannot alter state")
	_expect(_feedback() == "这一轮已经浇过水", "Invalid action gives truthful feedback")
	await _key(KEY_ESCAPE)
	_expect(scene.selected_cell.is_empty() and scene.selected_field == 0, "Escape clears cell selection first")
	await _key(KEY_ESCAPE)
	await create_timer(.85).timeout
	_expect(scene.selected_field == -1, "Escape then returns to overview")
	await _click(_point(0))
	await create_timer(.85).timeout
	await _click(_point(0, "cell_01"))
	await _tool("Harvest")
	_expect(scene.farm_state.snapshot() == watered and _feedback() == "作物还在生长", "Premature selected-cell harvest is rejected")
	now += 270.0
	scene.settle_farm()
	_expect(_cell(0, "cell_01").stage == "young" and _cell(0, "cell_02").stage == "sprout", "Mixed stages follow their independent crop clocks")
	_expect(crop_root.get_node("cell_02").get_instance_id() == neighbor_instance, "One cell's stage change never rebuilds its neighbor")
	await _capture("03-independent-stages.png")
	now += 1170.0
	scene.settle_farm()
	await _tool("Harvest")
	_expect(_cell(0, "cell_01").stage == "empty" and scene.farm_state.snapshot().harvested.greens == 1, "Harvest clears one cell and rewards one basket")
	_expect(_cell(0, "cell_02").crop_id == "radish" and crop_root.get_child_count() == 1, "Harvest keeps the neighboring planted cell")
	var harvested: Dictionary = scene.farm_state.snapshot()
	await _tool("Harvest")
	_expect(scene.farm_state.snapshot() == harvested and actions == 4, "Repeated empty-cell harvest cannot duplicate reward")
	# Cross-cell releases, dragged clicks and world-to-GUI releases select nothing.
	var p: Vector2 = _point(0, "cell_01")
	await _button(p, true)
	await _button(_point(0, "cell_02"), false)
	_expect(scene.selected_cell == "cell_01", "Cross-cell press/release never switches target")
	await _button(_point(0, "cell_02"), true)
	await _motion(_point(0, "cell_02") + Vector2(45, 0), Vector2(45, 0))
	await _button(_point(0, "cell_02"), false)
	_expect(scene.selected_cell == "cell_01", "Dragged click cannot pick another cell")
	await _button(p, true)
	await _motion(_control("Sow").get_global_rect().get_center(), Vector2.ZERO)
	await _button(_control("Sow").get_global_rect().get_center(), false)
	_expect(scene.farm_state.snapshot() == harvested, "A world press released over Sow does not activate the button")
	await _motion(_control("Sow").get_global_rect().get_center(), Vector2.ZERO)
	await _button(_control("Sow").get_global_rect().get_center(), true)
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _button(_control("Sow").get_global_rect().get_center(), false)
	_expect(scene.farm_state.snapshot() == harvested, "Focus loss invalidates a held toolbar press")
	# A new focus clears the selected cell; movement never replays held selection.
	scene._focus_field(1)
	await _button(_point(1, "cell_01"), true)
	await create_timer(.85).timeout
	await _button(_point(1, "cell_01"), false)
	_expect(scene.selected_cell.is_empty() and scene.farm_state.snapshot() == harvested, "Press admitted during travel cannot select after landing")
	await _click(_point(1, "cell_01"))
	var view_before: Vector3 = scene.camera.view
	await _button(_point(1), true, MOUSE_BUTTON_MIDDLE)
	await _motion(_point(1), Vector2(25, -10))
	await _button(_point(1), false, MOUSE_BUTTON_MIDDLE)
	_expect(not scene.camera.view.is_equal_approx(view_before), "Middle drag still orbits")
	var point_before: Vector3 = scene.camera.focus_point
	await _button(_point(1), true, MOUSE_BUTTON_MIDDLE)
	await _motion(_point(1), Vector2(12, 8), true)
	await _button(_point(1), false, MOUSE_BUTTON_MIDDLE)
	_expect(not scene.camera.focus_point.is_equal_approx(point_before), "Shift-middle drag still pans")
	var distance_before: float = scene.camera.view.z
	await _button(_point(1), true, MOUSE_BUTTON_WHEEL_UP)
	_expect(scene.camera.view.z < distance_before and scene.farm_state.snapshot() == harvested, "Camera manipulation never farms")
	await _button(_point(1), true, MOUSE_BUTTON_RIGHT)
	await _button(_point(1), false, MOUSE_BUTTON_RIGHT)
	_expect(scene.selected_cell.is_empty() and scene.selected_field == 1, "Right click clears cell before returning the field")
	root.size = Vector2i(960, 600)
	await create_timer(.3).timeout
	var rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for control: Control in scene.get_node("HUD/Layout/FarmControls").get_children():
		_expect(rect.encloses(control.get_global_rect()), "Farm control fits compact window: " + control.name)
	await _capture("04-compact.png")
	# Reopen through the real saved snapshot: two species are independent persisted data.
	var stored: Dictionary = load("res://farm/farm_store.gd").new(isolated).load_state().farm
	_expect(stored.fields.field_01.cells.cell_01.crop_id == "" and stored.fields.field_01.cells.cell_02.crop_id == "radish" and stored.harvested.greens == 1, "Disk state keeps per-cell harvest and neighboring crop")
	for failure: String in failures:
		push_error(failure)
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.free()
	await process_frame
	await process_frame
	print("FARM_INTERACTION_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _choose_radish() -> void:
	var choice: OptionButton = _control("CropChoice")
	await _click(choice.get_global_rect().get_center())
	_expect(choice.get_popup().visible, "Actual crop menu opens beside Sow")
	await _key(KEY_ESCAPE, choice.get_popup())
	_expect(not choice.get_popup().visible and scene.selected_cell == "cell_02", "Popup Escape closes menu without clearing selected cell")
	await _click(choice.get_global_rect().get_center())
	for step: int in 2:
		if choice.get_popup().get_focused_item() != 1:
			await _key(KEY_DOWN, choice.get_popup())
	await _key(KEY_ENTER, choice.get_popup())
	_expect(scene.selected_crop == "radish", "Real crop menu updates seed intent")


func _cell(index: int, cell_id: String) -> Dictionary:
	return scene.farm_state.get_cell(scene.farm.field_id(index), cell_id)


func _point(index: int, cell_id: String = "") -> Vector2:
	var local: Vector3 = Vector3(0, .08, 0) if cell_id.is_empty() else scene.farm.cell_center(cell_id)
	return scene.camera.unproject_position(scene.farm.fields[index].to_global(local))


func _control(control_name: String) -> Control:
	return scene.get_node("HUD/Layout/FarmControls/" + control_name)


func _feedback() -> String:
	return scene.get_node("HUD/Layout/Feedback").text


func _tool(control_name: String) -> void:
	await _click(_control(control_name).get_global_rect().get_center())


func _button(point: Vector2, down: bool, button_index: MouseButton = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.pressed = down
	event.button_index = button_index
	event.double_click = double
	# Native popups read Input's held-button state when they open. Parsing through
	# Input updates that state; Viewport.push_input alone does not model a real mouse.
	event.window_id = root.get_window_id()
	Input.parse_input_event(event)
	await physics_frame
	await process_frame


func _click(point: Vector2) -> void:
	await _motion(point, Vector2.ZERO)
	await _button(point, true)
	await _button(point, false)


func _motion(point: Vector2, relative: Vector2, shift: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	event.shift_pressed = shift
	event.window_id = root.get_window_id()
	Input.parse_input_event(event)
	await process_frame


func _key(code: Key, target: Window = null) -> void:
	if target == null:
		target = root
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.window_id = target.get_window_id()
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	event.window_id = target.get_window_id()
	Input.parse_input_event(event)
	await process_frame


func _capture(filename: String) -> void:
	if capture_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_dir)
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join(filename)) == OK, "Save viewport screenshot")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
