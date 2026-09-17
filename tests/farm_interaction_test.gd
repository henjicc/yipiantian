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
	var isolated: String = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification/scene-save-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store = load("res://settings/settings_store.gd").new(scene.store.directory.path_join("preferences"))
	root.add_child(scene)
	scene.farm_changed.connect(func(_result: Dictionary) -> void: actions += 1)
	await create_timer(0.6).timeout
	var baseline: Dictionary = scene.farm_state.snapshot()
	_expect(scene.farm.field_id(0) == "field_01", "Visual field has stable identity")
	_expect(scene.farm.fields[0].get_node("Crops").get_child_count() == 0, "Empty farm state shows empty land")
	await _capture("01-overview.png")
	await _click(_point(0))
	_expect(scene.selected_field == 0 and scene.farm_state.snapshot() == baseline, "Overview click only focuses")
	# Clicks during movement may focus another field, but never perform farm work.
	await _click(_point(0))
	await create_timer(0.85).timeout
	_expect(scene.farm_state.snapshot() == baseline, "Travel clicks are not replayed when camera settles")
	await _tool("Sow")
	_expect(scene.selected_tool == "sow" and scene.farm_state.snapshot() == baseline, "Selecting a tool never applies it")
	await _click(_point(0))
	await _button(_point(0), true, MOUSE_BUTTON_LEFT, true)
	await _button(_point(0), false)
	_expect(_field(0).crop_id == "greens" and _field(0).stage == "sprout", "Real input sows the whole field")
	_expect(actions == 1 and scene.selected_tool == "", "Double click produces only one successful action")
	var crop_root: Node3D = scene.farm.fields[0].get_node("Crops")
	var crop_instance: int = crop_root.get_child(0).get_instance_id()
	scene.settle_farm()
	_expect(crop_root.get_child(0).get_instance_id() == crop_instance, "Unchanged stages retain existing crop nodes")
	await _tool("Water")
	await _click(_point(0))
	_expect(_field(0).watered and is_equal_approx(_field(0).progress, 0.2), "Real input applies one watering boost")
	await _capture("02-watered.png")
	var watered: Dictionary = scene.farm_state.snapshot()
	await _tool("Water")
	await _click(_point(0))
	_expect(scene.farm_state.snapshot() == watered and actions == 2, "Repeated watering does not mutate state")
	_expect(_feedback() == "这一轮已经浇过水", "Invalid watering gives truthful feedback")
	await _key(KEY_ESCAPE)
	_expect(scene.selected_tool == "" and scene.selected_field == 0, "Escape first cancels tool")
	await _key(KEY_ESCAPE)
	await create_timer(0.85).timeout
	_expect(scene.selected_field == -1, "Escape then returns to overview")
	await _click(_point(0))
	await create_timer(0.85).timeout
	await _tool("Harvest")
	await _click(_point(0))
	_expect(scene.farm_state.snapshot() == watered and _feedback() == "作物还在生长", "Premature harvest is rejected through UI")
	await _button(_point(0), true, MOUSE_BUTTON_RIGHT)
	await _button(_point(0), false, MOUSE_BUTTON_RIGHT)
	_expect(scene.selected_tool == "" and scene.selected_field == 0, "Right click cancels tool before overview")
	# An injected UTC boundary advances the same production settlement path, without clock changes or disk I/O.
	now += 270.0
	scene.settle_farm()
	_expect(_field(0).stage == "young", "Stage threshold updates the visible young crop")
	await _capture("03-young.png")
	now += 1170.0
	scene.settle_farm()
	_expect(_field(0).stage == "mature", "Mature state follows elapsed UTC and watering")
	await _capture("04-mature.png")
	await _tool("Harvest")
	await _click(_point(0))
	_expect(_field(0).stage == "empty" and scene.farm_state.snapshot().harvested.greens == 1, "Harvest clears field and yields one basket")
	_expect(crop_root.get_child_count() == 0, "Harvest removes stage visuals")
	await _capture("05-harvested.png")
	var harvested: Dictionary = scene.farm_state.snapshot()
	await _tool("Harvest")
	await _click(_point(0))
	_expect(scene.farm_state.snapshot() == harvested and actions == 3, "Repeated harvest cannot duplicate reward")
	await _tool("Sow")
	var p: Vector2 = _point(0)
	await _button(p, true)
	await _motion(p + Vector2(45, 0), Vector2(45, 0))
	await _button(p, false)
	_expect(scene.farm_state.snapshot() == harvested, "Dragging across a field cannot sow")
	# Releasing on a different field, or on GUI, cancels the originating world gesture.
	scene.camera.zoom(5.0)
	await process_frame
	await _button(_point(0), true)
	await _button(_point(1), false)
	_expect(scene.farm_state.snapshot() == harvested and scene.selected_field == 0, "Different press/release targets perform no action or focus")
	await _button(_point(0), true)
	await _motion(_control("Water").get_global_rect().get_center(), Vector2.ZERO)
	await _button(_control("Water").get_global_rect().get_center(), false)
	_expect(scene.farm_state.snapshot() == harvested, "Release over UI cannot perform world action")
	await _button(_point(0), true)
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _button(_point(0), false)
	_expect(scene.farm_state.snapshot() == harvested and scene.selected_tool == "", "Focus loss cancels gesture and tool")
	await _tool("Sow")
	# Isolate the camera boundary while a tool remains armed. Input is still dispatched
	# through the real world hit test; only tween timing is controlled by the fixture.
	scene.camera.focus_field(scene.farm.fields[0].global_position)
	await _button(_point(0), true)
	await create_timer(0.85).timeout
	await _button(_point(0), false)
	_expect(scene.farm_state.snapshot() == harvested and scene.selected_tool == "sow", "Press during travel is rejected even when released after landing")
	await _click(_point(1))
	_expect(scene.selected_field == 1 and scene.selected_tool == "" and scene.farm_state.snapshot() == harvested, "Changing fields cancels old tool without sowing")
	await _click(_point(2))
	await create_timer(0.85).timeout
	_expect(scene.selected_field == 2 and scene.farm_state.snapshot() == harvested, "Rapid field changes keep latest selection without farm actions")
	# Held input admitted in a transition cannot become valid once it ends.
	scene._focus_field(1)
	await _button(_point(1), true)
	await create_timer(0.85).timeout
	await _tool("Sow")
	await _button(_point(1), false)
	_expect(scene.farm_state.snapshot() == harvested, "Old held press cannot execute a newly selected tool")
	# Real middle-button route preserves orbit, pan and zoom, with no planting side effects.
	var view_before: Vector3 = scene.camera.view
	await _button(_point(1), true, MOUSE_BUTTON_MIDDLE)
	await _motion(_point(1), Vector2(25, -10))
	await _button(_point(1), false, MOUSE_BUTTON_MIDDLE)
	_expect(not scene.camera.view.is_equal_approx(view_before), "Middle drag adjusts orbit through real input")
	var point_before: Vector3 = scene.camera.focus_point
	await _button(_point(1), true, MOUSE_BUTTON_MIDDLE)
	await _motion(_point(1), Vector2(12, 8), true)
	await _button(_point(1), false, MOUSE_BUTTON_MIDDLE)
	_expect(not scene.camera.focus_point.is_equal_approx(point_before), "Shift-middle drag pans through real input")
	var distance_before: float = scene.camera.view.z
	await _button(_point(1), true, MOUSE_BUTTON_WHEEL_UP)
	_expect(scene.camera.view.z < distance_before and scene.farm_state.snapshot() == harvested, "Wheel zoom has no farming side effects")
	# The native crop selector must be usable; choose the second crop using actual GUI keyboard events.
	if scene.camera.is_transitioning():
		await scene.camera.motion_finished
	await process_frame
	await _click(_control("CropChoice").get_global_rect().get_center())
	var choice: OptionButton = _control("CropChoice")
	_expect(choice.get_popup().visible, "Crop choice opens its actual popup")
	await _key(KEY_ESCAPE, choice.get_popup())
	_expect(not choice.get_popup().visible and scene.selected_field == 1, "Escape closes crop popup before returning from the field")
	_expect(scene.farm_state.snapshot() == harvested, "Popup cancellation has no farming effect")
	await _click(choice.get_global_rect().get_center())
	# Mouse-opened menus initially focus no item: navigate the real popup, not its selection signal.
	for step in 2:
		if choice.get_popup().get_focused_item() != 1:
			await _key(KEY_DOWN, choice.get_popup())
	await _key(KEY_ENTER, choice.get_popup())
	_expect(scene.selected_crop == "radish", "Popup selection updates crop intent")
	await _tool("Sow")
	await _click(_point(1))
	_expect(_field(1).crop_id == "radish", "Selected crop reaches the authoritative sow action")
	root.size = Vector2i(960, 600)
	await create_timer(0.3).timeout
	var rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for control: Control in scene.get_node("HUD/Layout/FarmControls").get_children():
		_expect(rect.encloses(control.get_global_rect()), "Farm control remains inside compact window: " + control.name)
	for control: Control in scene.get_node("HUD/Layout/ViewControls").get_children():
		_expect(rect.encloses(control.get_global_rect()), "View control remains inside compact window: " + control.text)
	await _capture("06-compact.png")
	for failure: String in failures:
		push_error(failure)
	print("FARM_INTERACTION_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _field(index: int) -> Dictionary:
	return scene.farm_state.get_field(scene.farm.field_id(index))


func _point(index: int) -> Vector2:
	return scene.camera.unproject_position(scene.farm.fields[index].global_position + Vector3(0, 0.4, 0))


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
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_dir.path_join(filename)) == OK, "Save viewport screenshot")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
