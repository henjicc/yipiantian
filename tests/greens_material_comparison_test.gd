extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _click(scene: Node, caption: String) -> void:
	for node: Node in scene.find_children("*","Button",true,false):
		var button := node as Button
		if button.text != caption: continue
		var motion := InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		root.push_input(motion,true)
		for pressed: bool in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = motion.position
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
			await process_frame
		return
	assert(false,"Missing button " + caption)

func _run() -> void:
	root.size = Vector2i(1600,900)
	var scene: Node3D = load("res://development/greens_material_comparison.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var moving_a: Image = root.get_texture().get_image()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var moving_b: Image = root.get_texture().get_image()
	assert(_changed(moving_a,moving_b,0) > 20 and _changed(moving_a,moving_b,1) > 20,"Both plants must visibly move")
	await _click(scene,"风动开／关")
	assert(not scene.wind_enabled)
	await RenderingServer.frame_post_draw
	var still_a: Image = root.get_texture().get_image()
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	var still_b: Image = root.get_texture().get_image()
	assert(_changed(still_a,still_b,0) == 0 and _changed(still_a,still_b,1) == 0,"Disabled wind must leave both plants still")
	await _click(scene,"复位")
	assert(scene.wind_enabled)
	await _click(scene,"向右转")
	assert(is_equal_approx(scene.yaw,PI/6.0))
	assert(scene.plants[0].rotation.is_equal_approx(scene.plants[1].rotation))
	await _click(scene,"向左转")
	assert(is_zero_approx(scene.yaw))
	await _click(scene,"切换光照")
	assert(scene.light_index == 1)
	await _click(scene,"法线开／关")
	assert(not scene.normals_enabled)
	await _click(scene,"切换配色")
	assert(scene.use_generated_color)
	await _click(scene,"复位")
	assert(scene.light_index == 0 and scene.normals_enabled and not scene.use_generated_color)
	var original_transform: Transform3D = scene.cameras[0].transform
	await _drag(MOUSE_BUTTON_LEFT,Vector2(300,400),Vector2(90,35))
	assert(not scene.cameras[0].transform.is_equal_approx(original_transform))
	assert(scene.cameras[0].transform.is_equal_approx(scene.cameras[1].transform))
	var target: Vector3 = scene.view_target
	await _drag(MOUSE_BUTTON_MIDDLE,Vector2(1150,400),Vector2(50,-20))
	assert(not scene.view_target.is_equal_approx(target))
	assert(scene.cameras[0].transform.is_equal_approx(scene.cameras[1].transform))
	var size: float = scene.view_size
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(1100,400)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel,true)
	await process_frame
	assert(scene.view_size < size and is_equal_approx(scene.cameras[0].size,scene.cameras[1].size))
	await _click(scene,"冷暖对比")
	assert(not scene.fresh_enabled and scene.dragging == 0)
	await _click(scene,"复位")
	assert(scene.fresh_enabled and scene.cameras[0].transform.is_equal_approx(original_transform))
	scene.queue_free()
	await process_frame
	await process_frame
	print("MATERIAL_COMPARISON_CONTROLS_OK rendered wind on/off both sides, buttons, left orbit, middle pan, wheel zoom, synchronized cameras, reset")
	quit()

func _changed(a: Image, b: Image, side: int) -> int:
	var count := 0
	for y: int in range(180,700,2):
		for x: int in range(100+side*800,700+side*800,2):
			var delta: Color = a.get_pixel(x,y)-b.get_pixel(x,y)
			if maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b))) > .01: count += 1
	return count

func _drag(button: int, start: Vector2, delta: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = start
	down.button_index = button
	down.pressed = true
	root.push_input(down,true)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = start+delta
	motion.relative = delta
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(motion,true)
	await process_frame
	down.position = start+delta
	down.pressed = false
	root.push_input(down,true)
	await process_frame
