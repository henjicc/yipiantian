extends SceneTree
## Real production plants and native frames; isolated saves, no MovieMaker timing.

const Farm = preload("res://farm/farm_state.gd")
const Store = preload("res://farm/farm_store.gd")
const Decoration = preload("res://farm/decoration_state.gd")
var scene: Node3D
var output_dir: String
var checks: int = 0
var failures: Array[String] = []
var now: float = 1800000000.0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_dir = arg.trim_prefix("--output=").replace("\\", "/")
	_run.call_deferred()


func _run() -> void:
	var allowed: String = ProjectSettings.globalize_path("res://../.local/").simplify_path().replace("\\", "/")
	if not output_dir.begins_with(allowed + "/") or DisplayServer.get_name() == "headless":
		push_error("A native window and isolated .local evidence directory are required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var store = Store.new(output_dir.path_join("farm-%d" % Time.get_ticks_usec()))
	store.load_state()
	var data: Dictionary = Farm.new(now).snapshot()
	data.harvested = {"greens": 10, "radish": 6}
	for index: int in 6:
		var field: Dictionary = data.fields[Farm.FIELD_IDS[index]]
		field.crop_id = "greens" if index % 2 == 0 else "radish"
		field.growth_seconds = 1800.0 if index % 2 == 0 else 5400.0
	var decorations = Decoration.new()
	decorations.unlock(data.harvested)
	decorations.place("pot", "ground_01", 0)
	decorations.place("flowerpot", "ground_02", 0)
	decorations.place("lantern", "hanging_01", 0)
	_expect(store.save(data, decorations.snapshot()).ok, "Isolated populated fixture saved")
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(store.directory)
	scene.settings_store = load("res://settings/settings_store.gd").new(store.directory.path_join("preferences"))
	scene.clock = func() -> float: return now
	root.add_child(scene)
	root.grab_focus()
	scene.atmosphere.set_preview_hour(16.5)
	await create_timer(1.5).timeout
	var snapshot: Dictionary = scene.farm_state.snapshot()
	var decoration_snapshot: Dictionary = scene.decoration_state.snapshot()
	_expect(_first_mesh(scene.decoration_layout._instances.flowerpot).get_meta("plant_wind_kind", "") == "flowerpot", "Loaded flowerpot has anchored foliage wind")
	_expect(_first_mesh(scene.get_node("Environment/EntranceTrellis")).get_meta("plant_wind_kind", "") == "trellis", "Courtyard mixed trellis uses foliage-only wind")
	var frame: Node3D = scene.camera.get_node("CameraForeground")
	_expect(frame.visible and scene.camera.attributes.dof_blur_near_enabled and not scene.camera.attributes.dof_blur_far_enabled, "Overview has near-only framing depth of field")
	var transforms: Array[Transform3D] = []
	var plants: Array[Node3D] = []
	for field: Node3D in scene.farm.fields:
		transforms.append(field.global_transform)
		_expect(field.get_node("Crops").get_child_count() == 16, "Each field has sixteen stable visual plants")
		for plant: Node3D in field.get_node("Crops").get_children():
			plants.append(plant)
			transforms.append(plant.global_transform)
	var tree: Node3D = scene.get_node("Environment/WestTree")
	var tree_transform: Transform3D = tree.global_transform
	var first: Image = await _shot("01-overview-wind-a")
	await create_timer(1.7).timeout
	var second: Image = await _shot("02-overview-wind-b")
	_expect(tree.global_transform == tree_transform, "Tree is not animated as a rigid pendulum")
	var cursor: int = 0
	for field: Node3D in scene.farm.fields:
		_expect(field.global_transform == transforms[cursor], "Wind never shifts field bodies")
		cursor += 1
		for plant: Node3D in field.get_node("Crops").get_children():
			_expect(plant.global_transform == transforms[cursor], "Crop root transform remains fixed")
			cursor += 1
	var crown_point: Vector2 = scene.camera.unproject_position(tree.global_position + Vector3(0, 2.5, 0))
	var crown_rect := Rect2i(Vector2i(crown_point) - Vector2i(80, 70), Vector2i(160, 140))
	var crown_difference: Dictionary = _difference(first, second, crown_rect)
	_expect(crown_difference.changed_pixels > 20, "Actual tree-crown pixels move with unchanged node transform")
	for index: int in 6:
		var point: Vector2 = scene.camera.unproject_position(scene.farm.fields[index].global_position + Vector3(0, 0.3, 0))
		_expect(scene._field_at(point) == index, "Camera foreground cannot capture a field ray")
	var mesh: MeshInstance3D = _first_mesh(plants[0])
	var source: StandardMaterial3D = mesh.mesh.surface_get_material(0)
	var animated: ShaderMaterial = mesh.get_active_material(0)
	_expect(source != null and animated.get_shader_parameter("color_texture") == source.albedo_texture, "Wind keeps original imported albedo texture")
	_expect(animated.get_shader_parameter("base_roughness") == source.roughness, "Wind keeps original roughness")
	scene._focus_field(0)
	await create_timer(0.9).timeout
	_expect(not frame.visible, "Foreground fades out before focused operation")
	var focused_first: Image = await _shot("03-focus-wind-a")
	await create_timer(1.8).timeout
	var focused_second: Image = await _shot("04-focus-wind-b")
	var plant_point: Vector2 = scene.camera.unproject_position(plants[5].global_position + Vector3(0, 0.25, 0))
	var crop_difference: Dictionary = _difference(focused_first, focused_second, Rect2i(Vector2i(plant_point) - Vector2i(42, 42), Vector2i(84, 84)))
	_expect(crop_difference.changed_pixels > 3, "Actual vegetable leaves move subtly in the focused image")
	scene._return_overview()
	await create_timer(0.9).timeout
	scene.focus_detail.set_depth_of_field(false)
	await create_timer(0.2).timeout
	_expect(frame.visible and not scene.camera.attributes.dof_blur_near_enabled and not scene.camera.attributes.dof_blur_far_enabled, "DOF preference disables blur without changing farm state")
	await _shot("05-overview-dof-off")
	scene.focus_detail.set_quality("low")
	await create_timer(0.4).timeout
	_expect(not frame.visible and not scene.camera.attributes.dof_blur_near_enabled, "Low quality avoids foreground geometry and depth blur")
	await _shot("06-low")
	scene.focus_detail.set_quality("standard")
	scene.focus_detail.set_depth_of_field(true)
	scene._focus_field(3)
	await create_timer(0.1).timeout
	scene._return_overview()
	await create_timer(0.1).timeout
	scene._focus_field(5)
	await create_timer(0.9).timeout
	_expect(scene.selected_field == 5 and not frame.visible, "Rapid camera changes leave the latest target unobscured")
	scene._begin_decoration()
	await create_timer(0.9).timeout
	_expect(not frame.visible and not scene.camera.attributes.dof_blur_near_enabled, "Arrangement keeps every slot free of camera foliage")
	scene.decoration_layout.select_item("flowerpot")
	scene.decoration_layout.preview_at("ground_03")
	_expect(is_instance_valid(scene.decoration_layout._preview), "Flowerpot move preview is created in a legal slot")
	if is_instance_valid(scene.decoration_layout._preview):
		_expect(_first_mesh(scene.decoration_layout._preview).get_meta("plant_wind_kind", "") == "flowerpot", "New flowerpot preview receives the same wind hook")
	scene.decoration_layout.cancel_preview()
	_expect(scene.decoration_state.snapshot() == decoration_snapshot, "Cancelling windy preview leaves placement state unchanged")
	await _shot("07-arrangement-clear")
	scene.decoration_layout.finish_mode()
	scene.atmosphere.set_preview_hour(21.0)
	await create_timer(0.9).timeout
	await _shot("08-night")
	_expect(scene.farm_state.snapshot() == snapshot, "Wind, foreground and quality never alter farm state")
	var report: Dictionary = {"checks": checks, "failures": failures, "crown_difference": crown_difference, "crop_difference": crop_difference, "render_size": [first.get_width(), first.get_height()], "clock": "fixed isolated farm UTC; visual shader TIME advances normally"}
	var file := FileAccess.open(output_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	scene.farm_audio.shutdown()
	await create_timer(0.1).timeout
	scene.free()
	await process_frame
	await process_frame
	print("PLANT_PRESENTATION checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child: Node in node.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


func _difference(a: Image, b: Image, requested: Rect2i) -> Dictionary:
	var area: Rect2i = requested.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	var changed: int = 0
	var maximum: float = 0.0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var difference: float = maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			maximum = maxf(maximum, difference)
			if difference > 0.015:
				changed += 1
	return {"rect": [area.position.x, area.position.y, area.size.x, area.size.y], "changed_pixels": changed, "max_channel_difference": maximum}


func _shot(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(output_dir.path_join(label + ".png"))
	return image


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
