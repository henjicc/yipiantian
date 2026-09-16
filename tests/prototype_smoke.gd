extends SceneTree

var scene: Node3D
var failures: Array[String] = []
var capture_dir: String = ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			capture_dir = argument.trim_prefix("--screenshots=")
	_run.call_deferred()


func _run() -> void:
	# Give offscreen runs the same viewport geometry as the interactive window.
	root.size = Vector2i(1280, 720)
	scene = load("res://scenes/main.tscn").instantiate()
	var isolated: String = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification/scene-save-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	root.add_child(scene)
	await create_timer(0.5).timeout
	var camera: Camera3D = scene.camera
	_expect(scene.farm.fields.size() == 6, "Six independently selectable fields")
	await _capture("overview.png")
	var initial_point: Vector3 = camera.focus_point
	var initial_view: Vector3 = camera.view
	# Exercise the real input path and physics ray, not just the focus helper.
	var screen_point: Vector2 = camera.unproject_position(scene.farm.fields[4].global_position + Vector3(0, 0.4, 0))
	await _click(screen_point)
	_expect(scene.selected_field == 4, "World click focuses the intended field")
	await create_timer(0.9).timeout
	_expect(camera.focused, "Camera enters focus mode")
	await _capture("focus.png")
	# The full view button goes through GUI hit testing and must not select a field behind it.
	var button: Button = scene.get_node("HUD/Layout/ViewControls").get_child(0)
	await _click(button.get_global_rect().get_center())
	await create_timer(0.9).timeout
	_expect(scene.selected_field == -1 and not camera.focused, "GUI overview button clears field selection")
	_expect(camera.focus_point.is_equal_approx(initial_point) and camera.view.is_equal_approx(initial_view), "Overview pose restored")
	# Moving between press and release must not turn a drag into a click.
	await _send_button(screen_point, true)
	var motion := InputEventMouseMotion.new()
	motion.position = screen_point + Vector2(40, 0)
	motion.relative = Vector2(40, 0)
	root.push_input(motion)
	await _send_button(screen_point, false)
	_expect(scene.selected_field == -1, "Dragging does not focus a field")
	await _send_button(screen_point, true)
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await _send_button(screen_point, false)
	_expect(scene.selected_field == -1, "Focus loss cancels a pending click")
	# A later field click replaces an unfinished camera transition; it does not queue.
	await _click(screen_point)
	var other: Vector2 = camera.unproject_position(scene.farm.fields[0].global_position + Vector3(0, 0.4, 0))
	await _click(other)
	await create_timer(0.9).timeout
	_expect(scene.selected_field == 0, "Latest field selection wins during camera travel")
	scene._return_overview()
	scene._focus_field(1)
	await create_timer(0.9).timeout
	scene._return_overview()
	await create_timer(0.9).timeout
	_expect(camera.focus_point.is_equal_approx(initial_point) and camera.view.is_equal_approx(initial_view), "Refocus during return preserves the overview destination")
	camera.drag(Vector2(25, -10), false)
	camera.drag(Vector2(12, 8), true)
	camera.zoom(-1.0)
	var adjusted_point: Vector3 = camera.focus_point
	var adjusted_view: Vector3 = camera.view
	await _click(camera.unproject_position(scene.farm.fields[2].global_position + Vector3(0, 0.4, 0)))
	await create_timer(0.9).timeout
	scene._return_overview()
	await create_timer(0.9).timeout
	_expect(camera.focus_point.is_equal_approx(adjusted_point) and camera.view.is_equal_approx(adjusted_view), "Adjusted overview position, angle and zoom restored")
	scene._reset_view()
	await create_timer(0.9).timeout
	_expect(camera.view.is_equal_approx(initial_view), "Reset recovers the initial camera")
	root.size = Vector2i(960, 600)
	await create_timer(0.2).timeout
	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for control in scene.get_node("HUD/Layout/ViewControls").get_children():
		_expect(viewport_rect.encloses(control.get_global_rect()), "View controls remain inside a smaller window")
	await _capture("compact.png")
	for failure in failures:
		push_error(failure)
	print("PROTOTYPE_SMOKE failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _send_button(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = down
	root.push_input(event)
	await physics_frame
	await process_frame


func _click(point: Vector2) -> void:
	await _send_button(point, true)
	await _send_button(point, false)


func _capture(filename: String) -> void:
	if capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(capture_dir.path_join(filename))
	_expect(error == OK, "Save native viewport screenshot")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
