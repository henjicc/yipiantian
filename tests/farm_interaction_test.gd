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
	root.size = Vector2i(1600, 900)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.clock = func() -> float: return now
	var isolated: String = ProjectSettings.globalize_path("res://../.local/verification/autumn-input-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store = load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	root.add_child(scene)
	scene.farm_changed.connect(func(_result: Dictionary) -> void: actions += 1)
	await create_timer(.8).timeout
	scene.atmosphere.set_preview_hour(10.0)
	var ids: Array[String] = scene.Crops.crop_ids()
	_expect(ids.size() == 12, "Twelve available crops")
	var initial: Dictionary = scene.farm_state.snapshot()
	_expect(not scene.hud.get_node("Layout/CropChoices").visible and not scene.hud.get_node("Layout/ToolChoices").visible, "Choice rows start collapsed")
	for absent: String in ["FieldStatus", "ToolStatus", "SessionStatus", "Feedback"]:
		_expect(not scene.hud.has_node("Layout/"+absent), "No routine hint panel: "+absent)
	await _click(_control("Sow").get_global_rect().get_center())
	_expect(scene.selected_tool.is_empty(), "Opening seeds never arms or plants before choosing")
	await create_timer(.3).timeout
	await _capture("00-seed-palette.png")
	await _choose("spinach")
	_expect(scene.selected_tool == "sow" and scene.selected_field == -1, "Select seeds before selecting any land")
	await _motion(_point(0,"cell_01"), Vector2.ZERO)
	_expect(scene.hover_field == 0 and scene.hover_cell.is_empty(), "Overview hover selects only the whole field")
	_expect(scene.farm_state.snapshot() == initial, "Hover never modifies farm state")
	_expect(scene.tool_cursor._key == "spinach" and scene.tool_cursor._cursor_texture.get_width() > scene.tool_cursor._cursor_pixels, "Carried crop shares hardware cursor texture")
	var distance: float = scene.camera.view.z
	await _button(_point(0,"cell_01"), true, MOUSE_BUTTON_WHEEL_DOWN)
	_expect(scene.selected_crop == "lettuce" and scene.camera.view.z == distance, "Armed wheel changes seeds rather than zoom")
	await _click(_point(0,"cell_01"))
	_expect(actions == 0 and scene.camera.focused and not scene.field_menu.active, "Overview click focuses without farming")
	await _camera_settled()
	await _choose("lettuce")
	await _click(_point(0,"cell_01"))
	_expect(_cell(0,"cell_01").crop_id == "lettuce" and actions == 1, "Focused click plants selected crop")
	_expect(scene.selected_tool == "sow", "Successful sow stays armed")
	await _click(_point(0,"cell_02"))
	_expect(_cell(0,"cell_02").crop_id == "lettuce" and actions == 2, "Continuous planting works in next cell")
	await _click(_point(0,"cell_02"))
	_expect(actions == 2 and _cell(0,"cell_02").crop_id == "lettuce", "Occupied target cannot overwrite crop")
	await _tool("Water")
	_expect(not scene.field_menu.active and scene.selected_tool == "water", "Tool fan closes after equipping water")
	await _capture("00-tool-palette.png")
	_expect(not _cell(0,"cell_01").watered, "Selecting water never acts on prior target")
	await _click(_point(0,"cell_01"))
	_expect(_cell(0,"cell_01").watered and is_equal_approx(_cell(0,"cell_01").progress,.25), "Water applies species-specific boost to clicked cell")
	await _click(_point(0,"cell_01"))
	_expect(actions == 3 and is_equal_approx(_cell(0,"cell_01").progress,.25), "Repeated water is a no-op")
	await _button(_point(0,"cell_01"), true, MOUSE_BUTTON_RIGHT)
	await _button(_point(0,"cell_01"), false, MOUSE_BUTTON_RIGHT)
	_expect(scene.selected_tool.is_empty() and scene.selected_palette.is_empty(), "Right click closes palette and disarms")
	await create_timer(.3).timeout
	_expect(not scene.hud.get_node("Layout/ToolChoices").visible, "Cancelled toolbar finishes hiding")
	await _button(_point(0,"cell_01"), true, MOUSE_BUTTON_WHEEL_UP)
	await create_timer(.45).timeout
	_expect(scene.camera.view.z < distance, "Disarmed wheel restores damped zoom")
	await _choose("celery")
	var before: Dictionary = scene.farm_state.snapshot()
	await _button(_point(0,"cell_03"), true)
	await _button(_point(0,"cell_04"), false)
	_expect(scene.farm_state.snapshot() == before, "Cross-cell release never plants")
	await _button(_point(0,"cell_03"), true)
	await _motion(_point(0,"cell_03") + Vector2(30,0), Vector2(30,0))
	await _button(_point(0,"cell_03"), false)
	_expect(scene.farm_state.snapshot() == before, "Dragged click never plants")
	await _motion(scene.hud.get_node("Layout/FarmControls/Tools").get_global_rect().get_center(),Vector2.ZERO)
	_expect(scene.hover_cell.is_empty() and scene.tool_cursor._key.is_empty(), "UI clears world preview and carried badge")
	await _button(_point(0,"cell_03"),true)
	await _motion(scene.hud.get_node("Layout/FarmControls/Tools").get_global_rect().get_center(),Vector2.ZERO)
	await _button(scene.hud.get_node("Layout/FarmControls/Tools").get_global_rect().get_center(),false)
	_expect(scene.farm_state.snapshot() == before, "World-to-UI release cannot farm")
	await _choose("carrot")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await physics_frame
	_expect(scene.selected_tool.is_empty() and scene.tool_cursor._key.is_empty(), "Focus loss clears armed cursor and gestures")
	scene._focus_field(0)
	await create_timer(.9).timeout
	await _choose("garlic")
	await _click(_point(0,"cell_03"))
	_expect(_cell(0,"cell_03").crop_id == "garlic", "Focused view supports new allium")
	await _key(KEY_ESCAPE)
	_expect(scene.selected_tool.is_empty(), "Escape cancels seeds")
	await _capture("01-new-tools.png")
	# Seed all twelve species through authoritative actions, then verify exact saved state.
	for i: int in ids.size():
		scene.farm_state.sow("field_02",scene.farm_state.CELL_IDS[i],ids[i],now)
		scene.farm_state.water("field_02",scene.farm_state.CELL_IDS[i],now)
	scene.refresh_farm()
	scene._save_farm()
	var disk: Dictionary = load("res://farm/farm_store.gd").new(isolated).load_state()
	_expect(disk.ok and disk.farm == scene.farm_state.snapshot(), "All twelve species and water states roundtrip")
	# Short, isolated authoring preview of all three stages. Does not touch player saves.
	var fixture: Dictionary = scene.farm_state.snapshot()
	for field_index: int in 3:
		for i: int in ids.size():
			var cell: Dictionary = fixture.fields[scene.farm.field_id(field_index)].cells[scene.farm_state.CELL_IDS[i]]
			cell.crop_id = ids[i]
			cell.growth_seconds = scene.Crops.definition(ids[i]).duration_seconds * [0.0,.5,1.0][field_index]
			cell.watered = false
	scene.farm_state.restore_snapshot(fixture)
	scene.refresh_farm()
	scene.focus_detail.set_depth_of_field(false)
	for field_index: int in 3:
		scene._focus_field(field_index)
		await create_timer(.9).timeout
		scene.camera.zoom(-2.8)
		await _camera_settled()
		await _motion(_point(field_index,"cell_06"),Vector2.ZERO)
		await _capture("02-stage-%d.png" % field_index)
	for id: String in ids:
		var mesh_root: Node3D = scene.farm.fields[2].get_node("Crops").get_node(scene.farm_state.CELL_IDS[ids.find(id)])
		_expect(mesh_root != null, "Visible mature model: " + id)
	scene._select_tool("harvest")
	await _click(_point(2,"cell_06"))
	_expect(_cell(2,"cell_06").stage == "empty" and scene.farm_state.snapshot().harvested.coriander == 1, "New crop harvest rewards correct species")
	scene._cancel_tool()
	# Near-root and reverse views exercise thin leaves and soil contact at inspection scale.
	var camera_transform: Transform3D = scene.camera.transform
	scene.camera.set_process(false)
	var target: Vector3 = scene.farm.fields[2].global_position + Vector3(0,.2,0)
	scene.camera.position = target + Vector3(.6,2.1,2.4)
	scene.camera.look_at(target)
	await create_timer(.3).timeout
	await _capture("03-close-mature.png")
	scene.camera.position = target + Vector3(-.8,1.5,-2.3)
	scene.camera.look_at(target)
	await create_timer(.3).timeout
	await _capture("03-close-reverse.png")
	scene.camera.transform = camera_transform
	scene.camera.set_process(true)
	scene.camera.drag(Vector2(320,0),false)
	await create_timer(.3).timeout
	await _capture("03-reverse-mature.png")
	scene._toggle_free_view()
	before = scene.farm_state.snapshot()
	await _click(_point(2,"cell_04"))
	_expect(scene.farm_state.snapshot() == before and scene.selected_tool.is_empty(), "Free camera cannot farm")
	scene._return_overview()
	await create_timer(.9).timeout
	root.size = Vector2i(960,600)
	await create_timer(.3).timeout
	await _choose("spinach")
	var viewport: Rect2 = root.get_visible_rect()
	scene.field_menu.present_seeds(Vector2(950,20))
	for card: Control in [scene.field_menu.cards]:
		_expect(viewport.encloses(card.get_global_rect()), "Crop card fits compact window: "+card.name)
	await _capture("04-compact.png")
	await _click(scene.field_menu.veil.get_node("Cancel").get_global_rect().get_center())
	await _click(_control("CancelTool").get_global_rect().get_center())
	await create_timer(.3).timeout
	_expect(scene.selected_palette.is_empty() and not scene.hud.get_node("Layout/CropChoices").visible, "Cancel button hides active row")
	root.size = Vector2i(3840,2160)
	await create_timer(.3).timeout
	_expect(root.content_scale_size == Vector2i(1600,900) and scene.tool_cursor._cursor_pixels >= 150, "4K UI and enlarged hardware cursor share scale")
	await _choose("celery")
	await _motion(_point(0,"cell_04"),Vector2.ZERO)
	await _capture("05-4k-palette.png")
	for failure: String in failures: push_error(failure)
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.free()
	await process_frame
	print("FARM_INTERACTION_TEST checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)


func _camera_settled() -> void:
	var deadline: int = Time.get_ticks_msec() + 4000
	while scene.camera.is_transitioning() and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(not scene.camera.is_transitioning(), "Camera settles before farming")


func _choose(id: String) -> void:
	await _camera_settled()
	if not scene.field_menu.active:
		await _click(_control("Sow").get_global_rect().get_center())
	for page: int in 3:
		if scene.field_menu.cards.has_node(id): break
		await _click(scene.field_menu.veil.get_node("Next").get_global_rect().get_center())
	var petal: Control = scene.field_menu.cards.get_node(id)
	await _click(petal.global_position + petal.center)


func _cell(index: int, cell_id: String) -> Dictionary:
	return scene.farm_state.get_cell(scene.farm.field_id(index), cell_id)


func _point(index: int, cell_id: String = "") -> Vector2:
	var local: Vector3 = Vector3(0, .08, 0) if cell_id.is_empty() else scene.farm.cell_position(index,cell_id)
	return scene.camera.unproject_position(scene.farm.fields[index].to_global(local))


func _control(control_name: String) -> Control:
	return scene.get_node("HUD/Layout/FarmControls/" + control_name)


func _tool(control_name: String) -> void:
	await _click(_control("Tools").get_global_rect().get_center())
	var petal: Control = scene.field_menu.cards.get_node(control_name.to_lower())
	await _click(petal.global_position + petal.center)


func _button(point: Vector2, down: bool, button_index: MouseButton = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.pressed = down
	event.button_index = button_index
	event.double_click = double
	# Inject viewport-local coordinates; no native popups or OS cursor/focus changes.
	event.window_id = root.get_window_id()
	root.push_input(event, true)
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
	root.push_input(event, true)
	await physics_frame
	await process_frame


func _key(code: Key, target: Window = null) -> void:
	if target == null:
		target = root
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.window_id = target.get_window_id()
	root.push_input(event, true)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	event.window_id = target.get_window_id()
	root.push_input(event, true)
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
