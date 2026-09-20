extends SceneTree
## Real input routing plus a geometric fixture for off-centre surface orbit.
var checks: int = 0
var failures: Array[String] = []
var output: String
var scene: Node3D


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()


func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)


func _run() -> void:
	assert(output.begins_with(ProjectSettings.globalize_path("res://../.local/").simplify_path()))
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1920,1080)
	await _damping_checks()
	await _geometry_checks()
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = load("res://farm/farm_store.gd").new(output.path_join("farm"))
	scene.settings_store = load("res://settings/settings_store.gd").new(output.path_join("preferences"))
	scene.clock = func() -> float: return 1000.0
	root.add_child(scene)
	scene.atmosphere.set_preview_hour(16.5)
	await create_timer(.5).timeout
	var camera: FarmCamera = scene.camera
	var state: Dictionary = scene.farm_state.snapshot().duplicate(true)
	await shot("01-initial.png")
	var start: float = camera.view.z
	camera.zoom(-4.0)
	expect(is_equal_approx(camera.view.z,start), "Zoom does not teleport on wheel admission")
	camera.set_process(false)
	for frame: int in 90: camera._process(1.0/60.0)
	expect(is_equal_approx(camera.view.z,start-4), "Damped zoom settles at exact target")
	camera.zoom(-1); camera.zoom(-1); camera.zoom(-1)
	for frame: int in 90: camera._process(1.0/60.0)
	expect(is_equal_approx(camera.view.z,start-7), "Rapid wheel ticks accumulate instead of losing distance")
	camera.set_process(true)
	await shot("02-overview-zoomed.png")
	camera.zoom(100)
	await create_timer(1.05).timeout
	expect(is_equal_approx(camera.view.z,start), "Overview cannot retreat beyond its initial pose")
	scene._focus_field(0)
	await create_timer(.85).timeout
	camera.zoom(100)
	await create_timer(1.05).timeout
	expect(is_equal_approx(camera.view.z,10.4), "Focused mode cannot retreat past its entry distance")
	camera.zoom(-100)
	await create_timer(1.05).timeout
	expect(is_equal_approx(camera.view.z,8.5), "Forward zoom retains near safety bound")
	scene._return_overview()
	await create_timer(.85).timeout
	expect(is_equal_approx(camera.view.z,start), "Returning restores overview distance")
	# Actual routed wheel input also works in arrangement mode.
	scene._begin_decoration()
	await create_timer(.85).timeout
	var point := root.get_visible_rect().size * .5
	await button(point, true, MOUSE_BUTTON_WHEEL_UP)
	await create_timer(1.05).timeout
	expect(camera.view.z < 31.0, "Arrangement mode admits wheel zoom")
	camera.zoom(100)
	await create_timer(1.05).timeout
	expect(is_equal_approx(camera.view.z,31.0), "Arrangement wheel cannot retreat past its framing pose")
	scene._return_overview()
	await create_timer(.85).timeout
	scene._toggle_free_view()
	await process_frame
	var old_pose := camera.global_transform
	await button(point, true, MOUSE_BUTTON_RIGHT)
	await motion(point+Vector2(90,40), Vector2(90,40), MOUSE_BUTTON_MASK_RIGHT)
	await button(point+Vector2(90,40), false, MOUSE_BUTTON_RIGHT)
	expect(camera.global_basis.is_equal_approx(old_pose.basis) and not camera.global_position.is_equal_approx(old_pose.origin), "Routed right drag pans without rotating or exiting")
	old_pose = camera.global_transform
	await button(point, true, MOUSE_BUTTON_MIDDLE)
	await motion(point+Vector2(45,-20), Vector2(45,-20), MOUSE_BUTTON_MASK_MIDDLE)
	await button(point+Vector2(45,-20), false, MOUSE_BUTTON_MIDDLE)
	expect(camera.global_basis.is_equal_approx(old_pose.basis) and not camera.global_position.is_equal_approx(old_pose.origin), "Routed middle drag pans")
	# Aim at the house wall/roof, not the farm physics proxy or scene centre.
	point = camera.unproject_position(Vector3(0,2.5,-3))
	await button(point, true, MOUSE_BUTTON_LEFT)
	var pivot: Vector3 = camera._free_pivot
	var projected := camera.unproject_position(pivot)
	var radius := camera.global_position.distance_to(pivot)
	old_pose = camera.global_transform
	await motion(point+Vector2(100,30),Vector2(100,30),MOUSE_BUTTON_MASK_LEFT)
	expect(not camera.global_basis.is_equal_approx(old_pose.basis), "Routed left drag orbits")
	expect(absf(camera.global_position.distance_to(pivot)-radius)<.001 and camera.unproject_position(pivot).distance_to(projected)<.05, "Clicked off-centre point remains fixed on screen throughout orbit")
	expect(scene._picks.is_empty() and scene.selected_field == -1, "Free orbit never admits farm picking")
	# A release consumed by UI must still end the gesture.
	var ui_point: Vector2 = scene.hud.get_node("Layout/FarmControls/Settings").get_global_rect().get_center()
	await button(ui_point,false,MOUSE_BUTTON_LEFT)
	old_pose = camera.global_transform
	await motion(point,Vector2(60,30),0)
	expect(camera.global_transform.is_equal_approx(old_pose), "Release over GUI cannot leave a stuck camera drag")
	await shot("03-free-orbit.png")
	await button(point,true,MOUSE_BUTTON_LEFT)
	scene._notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	old_pose = camera.global_transform
	await motion(point,Vector2(60,30),MOUSE_BUTTON_MASK_LEFT)
	expect(camera.global_transform.is_equal_approx(old_pose), "Window exit cancels left orbit")
	await button(point,false,MOUSE_BUTTON_LEFT)
	scene._open_menu()
	old_pose = camera.global_transform
	await button(point,true,MOUSE_BUTTON_WHEEL_UP)
	await create_timer(1.05).timeout
	expect(camera.global_transform.is_equal_approx(old_pose), "Settings intercept scrolling without moving camera")
	scene._request_menu_close()
	await button(point,true,MOUSE_BUTTON_WHEEL_UP)
	await create_timer(1.05).timeout
	expect(not camera.global_position.is_equal_approx(old_pose.origin), "Free view wheel moves smoothly forward")
	scene._return_overview()
	await create_timer(.85).timeout
	expect(not camera.free_view and is_equal_approx(camera.view.z,start), "Exiting free view restores normal zoom")
	expect(scene.farm_state.snapshot()==state, "Navigation never mutates farm state")
	await shot("04-returned.png")
	scene.farm_audio.shutdown(); scene.free()
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("CAMERA_NAVIGATION_TEST checks=%d failures=%d" % [checks,failures.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)



func _damping_checks() -> void:
	# Match physical time and input across frame rates; compare visible movement,
	# not tween implementation. The old restart-on-every-tick curve fails here.
	for free: bool in [false, true]:
		var distances: Array[float] = []
		for fps: int in [30, 60, 144]:
			var camera := FarmCamera.new()
			root.add_child(camera)
			camera.set_process(false)
			camera.set_free_view(free)
			var origin := camera.position
			var forward := camera.basis.z
			wheel(camera, free, -.6)
			var before: float = zoom_distance(camera, free, origin, forward)
			camera._process(.1)
			var position: float = zoom_distance(camera, free, origin, forward)
			camera._process(.001)
			var speed_before: float = absf(zoom_distance(camera, free, origin, forward)-position)/.001
			wheel(camera, free, -.6)
			position = zoom_distance(camera, free, origin, forward)
			camera._process(.001)
			var speed_after: float = absf(zoom_distance(camera, free, origin, forward)-position)/.001
			expect(speed_before>0 and speed_after>speed_before*.95, "New wheel tick preserves ongoing speed: free=%s fps=%d" % [free,fps])
			for frame: int in fps: camera._process(1.0/fps)
			var finish: float = zoom_distance(camera, free, origin, forward)
			expect(absf((before-finish)-1.2)<.001, "Wheel settles without lost input or overshoot")
			wheel(camera, free, .6)
			for frame: int in fps: camera._process(1.0/fps)
			expect(absf(zoom_distance(camera,free,origin,forward)-finish-.6)<.001, "Reverse input settles in opposite direction")
			wheel(camera,free,-.6)
			for frame: int in int(fps*.5): camera._process(1.0/fps)
			distances.append(zoom_distance(camera,free,origin,forward))
			camera.cancel_zoom()
			var canceled := camera.transform
			camera._process(.5)
			expect(camera.transform.is_equal_approx(canceled), "Canceled zoom leaves no residual drift")
			camera.free()
		for distance: float in distances:
			expect(absf(distance-distances[0])<.0001, "Damping agrees at 30/60/144 Hz")
	await process_frame

func wheel(camera: FarmCamera, free: bool, amount: float) -> void:
	if free: camera._zoom_free(amount)
	else: camera.zoom(amount)

func zoom_distance(camera: FarmCamera, free: bool, origin: Vector3, forward: Vector3) -> float:
	return (camera.position-origin).dot(forward) if free else camera.view.z

func _geometry_checks() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := FarmCamera.new(); world.add_child(camera)
	camera.set_free_view(true)
	camera.position=Vector3(0,2,10); camera.look_at(Vector3(0,1,0))
	var box := MeshInstance3D.new(); box.mesh=BoxMesh.new(); box.position=Vector3(2,1,0); box.scale=Vector3(2,2,2); world.add_child(box)
	var surface := Vector3(2,1,1)
	var point := camera.unproject_position(surface)
	var picker = load("res://scenes/camera_surface_pick.gd").new()
	var hit: Vector3 = picker.pick(camera,point,10)
	expect(hit.distance_to(surface)<.001, "Click uses true transformed mesh surface rather than bounds centre")
	box.hide()
	hit = picker.pick(camera,point,7)
	expect(hit.distance_to(camera.project_position(point,7))<.001, "Empty-space click uses stable view plane; invisible mesh is ignored")
	var multi := MultiMeshInstance3D.new(); multi.multimesh=MultiMesh.new(); multi.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multi.multimesh.mesh=box.mesh; multi.multimesh.instance_count=1
	multi.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(2,1,0))); world.add_child(multi)
	surface=Vector3(2,1,.5); point=camera.unproject_position(surface)
	expect(picker.pick(camera,point,10).distance_to(surface)<.001, "Instanced geometry is also a real orbit target")
	var press := InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=point
	camera.free_input(press)
	var radius := camera.global_position.distance_to(surface)
	var turn := InputEventMouseMotion.new();turn.relative=Vector2(400,100000)
	camera.free_input(turn)
	expect(camera.global_position.is_finite() and absf(camera.global_basis.z.y)<1.0 and absf(camera.global_position.distance_to(surface)-radius)<.001, "Extreme orbit stays finite and avoids pole flip")
	world.free()
	await process_frame


func button(point: Vector2, pressed: bool, index: MouseButton) -> void:
	var event := InputEventMouseButton.new(); event.position=point; event.global_position=point
	event.button_index=index;event.pressed=pressed;event.window_id=root.get_window_id()
	Input.parse_input_event(event)
	await process_frame; await process_frame


func motion(point: Vector2, relative: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new();event.position=point;event.global_position=point;event.relative=relative;event.button_mask=mask;event.window_id=root.get_window_id()
	Input.parse_input_event(event)
	await process_frame; await process_frame


func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(name))==OK,"Saved "+name)
