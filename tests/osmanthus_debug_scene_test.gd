extends SceneTree
## Real scene, isolated saves: living-tree geometry and debug camera admission/exit.
var scene: Node3D
var output: String
var checks: int = 0
var failures: Array[String] = []

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
	scene=load("res://scenes/main.tscn").instantiate()
	scene.store=load("res://farm/farm_store.gd").new(output.path_join("save"))
	scene.settings_store=load("res://settings/settings_store.gd").new(output.path_join("preferences"))
	root.add_child(scene)
	scene.atmosphere.set_preview_hour(16.5)
	await create_timer(1.0).timeout
	var tree: Node3D = scene.get_node("Environment/WestTree")
	var leaves: MultiMeshInstance3D = scene.get_node("Environment/OsmanthusLeaves")
	expect(tree.get_child(0).scene_file_path.contains("osmanthus"), "New osmanthus is actually used in the scene")
	expect(leaves.multimesh.instance_count > 0 and leaves.multimesh.instance_count <= 16, "Falling petals have a bounded shared instance budget")
	expect(not leaves._anchors.is_empty(), "Emission points come from the real canopy")
	for geometry: GeometryInstance3D in scene.find_children("*","GeometryInstance3D",true,false):
		expect(geometry.lod_bias > 0.0,"Scene geometry never forces the coarsest LOD: " + str(geometry.get_path()))
	expect(not leaves.is_processing() and leaves.multimesh.use_custom_data, "Petals use continuous render-time motion without per-frame CPU uploads")
	for i: int in leaves.multimesh.instance_count:
		var p: Vector3 = leaves.multimesh.get_instance_transform(i).origin
		expect(leaves.custom_aabb.has_point(p), "Animated culling bounds contain the canopy emission point")
	await shot("01-overview.png")
	var button: Button = scene.hud.get_node("Layout/DebugFreeCamera")
	button.pressed.emit()
	await process_frame
	expect(scene.camera.free_view, "Visible free-view button enables debug camera")
	expect(scene.selected_field == -1 and scene.selected_cell.is_empty(), "Entering inspection cancels crop selection")
	var origin: Vector3 = scene.camera.position
	scene.camera.move_free(Vector3(1,1,0),20.0)
	expect(scene.camera.position.distance_to(origin) > 19.9, "Free camera can move beyond normal orbit bounds")
	var press := InputEventMouseButton.new(); press.button_index=MOUSE_BUTTON_RIGHT;press.pressed=true
	scene._input(press);scene._unhandled_input(press)
	var motion := InputEventMouseMotion.new();motion.relative=Vector2(150,40)
	var old_rotation: Vector3=scene.camera.rotation
	var old_position: Vector3=scene.camera.position
	scene._unhandled_input(motion)
	expect(old_rotation.is_equal_approx(scene.camera.rotation) and not old_position.is_equal_approx(scene.camera.position) and scene.camera.free_view, "Right drag pans without invoking overview cancellation")
	scene._notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	old_rotation=scene.camera.rotation
	old_position=scene.camera.position
	scene._unhandled_input(motion)
	expect(old_rotation.is_equal_approx(scene.camera.rotation) and old_position.is_equal_approx(scene.camera.position), "Leaving window cancels camera gesture")
	scene._open_menu()
	expect(not scene.camera.free_input_enabled, "Modal blocks free-camera movement")
	scene._request_menu_close()
	expect(scene.camera.free_input_enabled, "Closing modal restores free-camera control")
	var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=Vector2(960,540)
	scene._unhandled_input(click)
	expect(scene._picks.is_empty(), "Free-camera clicks do not enter farm picking")
	await create_timer(.25).timeout
	expect(not scene.camera.get_node("CameraForeground").visible and not scene.camera.attributes.dof_blur_far_enabled, "Inspection is not obscured by decorative framing or depth blur")
	scene.camera.position=Vector3(-1.8,3.8,10.2);scene.camera.look_at(Vector3(-6.05,1.8,4.3));scene.camera.fov=40
	await shot("02-tree-front.png")
	await create_timer(1.1).timeout
	await shot("03-tree-front-motion.png")
	scene.get_node("Environment").set_asset_detail("WestTree",true)
	await shot("03b-tree-authored-low.png")
	scene.get_node("Environment").set_asset_detail("WestTree",false)
	scene.camera.position=Vector3(-11.8,3.8,.3);scene.camera.look_at(Vector3(-6.05,1.8,4.3))
	await shot("04-tree-back.png")
	scene.camera.position=Vector3(-10.2,2.3,8.4);scene.camera.look_at(Vector3(-6.05,1.8,4.3))
	await shot("05-tree-side.png")
	scene.atmosphere.set_preview_hour(21)
	await shot("06-tree-night.png")
	var escape := InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
	scene._input(escape)
	await create_timer(.85).timeout
	expect(not scene.camera.free_view, "Escape exits free view")
	scene._reset_view()
	await create_timer(.85).timeout
	expect(scene.camera.view.is_equal_approx(scene.camera.DEFAULT_VIEW), "Reset restores the normal camera")
	# Avoid leaving this test's manual lens change in the default capture.
	scene.camera.fov=29
	scene.atmosphere.set_preview_hour(16.5)
	await shot("07-returned.png")
	scene.farm_audio.shutdown();scene.free()
	print("OSMANTHUS_DEBUG_TEST checks=%d failures=%d" % [checks,failures.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func shot(name: String) -> void:
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(name)) == OK, "Saved " + name)
