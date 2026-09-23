extends SceneTree
var failures: Array[String] = []
var output: String

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool,message: String) -> void:
	if not condition: failures.append(message); push_error(message)

func _run() -> void:
	root.size = Vector2i(1600,1000)
	output = ProjectSettings.globalize_path("res://../.local/verification/procedural-lab")
	DirAccess.make_dir_recursive_absolute(output)
	var scene: Node3D = load("res://scenes/procedural_lab/procedural_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	await create_timer(2).timeout
	expect(scene.world.counts.get("rack",0)>0,"default offers a rack to inspect")
	expect(scene.world.bridge_targets.size()==2,"default offers connected bridges")
	await capture("overview")
	await click_button(scene.focus_bridge)
	expect(scene.inspect_mode=="bridge","bridge button responds to real pointer input")
	await create_timer(.3).timeout
	await capture("bridge")
	scene.yaw += PI
	scene._update_camera()
	await capture("bridge-reverse")
	scene.yaw -= PI
	await click_button(scene.focus_rack)
	expect(scene.inspect_mode=="rack","rack button responds to real pointer input")
	await create_timer(.3).timeout
	await capture("rack")
	scene.yaw += PI
	scene._update_camera()
	await capture("rack-reverse")
	scene.seed_input.text = "交互验证-42"
	scene.controls.count.value = 5
	scene.controls.bridge_width.value = 2.2
	scene.controls.rack_length.value = 4
	scene.controls.rack_height.value = 2.8
	await click_button(scene.generate_button)
	while scene.busy: await process_frame
	expect(scene.current_plan.seed=="交互验证-42" and scene.current_plan.islands.size()==5,"seed field and controls regenerate actual scene")
	scene.focus("all")
	await capture("five-islands")
	var previous: Node3D = scene.world
	scene.seed_input.text = "   "
	scene.generate_button.pressed.emit()
	await process_frame
	expect(scene.world==previous and "请输入" in scene.status.text,"blank seed preserves the current scene")
	scene.overlay_check.button_pressed = true
	expect(scene.world.markers.visible,"planning overlay toggles")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = Vector2(1100,500)
	Input.parse_input_event(down)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(1150,520); motion.relative = Vector2(50,20); motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	var before: float = scene.yaw
	Input.parse_input_event(motion)
	await process_frame
	expect(not is_equal_approx(before,scene.yaw),"viewport drag rotates camera")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = Vector2(120,180)
	Input.parse_input_event(up)
	await process_frame
	expect(scene.dragging==0,"release over UI ends scene drag")
	scene.dragging = 1
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(scene.dragging==0,"focus loss cancels drag")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP; wheel.pressed = true; wheel.position = Vector2(1100,500)
	var zoom_before: float = scene.desired_distance
	root.push_input(wheel,true)
	await process_frame
	expect(scene.desired_distance<zoom_before,"mouse wheel zooms the scene")
	scene.overlay_check.button_pressed = false
	scene.seed_input.text = "水乡-2026"
	scene._preset(1)
	while scene.busy: await process_frame
	expect(scene.current_plan.links.is_empty() and scene.focus_bridge.disabled,"single island disables bridge inspection")
	root.size = Vector2i(1100,760)
	await create_timer(.4).timeout
	await capture("small-window")
	root.size = Vector2i(3840,2160)
	await create_timer(.4).timeout
	expect(root.scaling_3d_scale<=.501,"4K window keeps 3D at the 1080p cap")
	await capture("4k-window")
	print("PROCEDURAL_LAB_SCENE_TEST failures=%d output=%s"%[failures.size(),output])
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func click_button(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func capture(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(file+".png"))==OK,"screenshot saved")
