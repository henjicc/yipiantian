extends SceneTree
## Formal-scene visual evidence at the exact reference dimensions, isolated from player saves.

const Farm = preload("res://farm/farm_state.gd")
const Crops = preload("res://art/crops/crop_visual_catalog.gd")
var scene: Node3D
var captures: String = ""
var failures: Array[String] = []
var checks: int = 0
var now: float = 1800000000.0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			captures = argument.trim_prefix("--screenshots=")
	_run.call_deferred()


func _run() -> void:
	if captures.is_empty():
		push_error("An isolated screenshot destination is required.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(captures)
	root.size = Vector2i(1680, 941)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.clock = func() -> float: return now
	scene.store = load("res://farm/farm_store.gd").new(captures.path_join("save-%d" % Time.get_ticks_usec()))
	scene.settings_store = load("res://settings/settings_store.gd").new(scene.store.directory.path_join("preferences"))
	root.add_child(scene)
	await physics_frame
	# Match the presentation clock in evidence without changing the OS or farm time.
	for child: Node in scene.hud.get_children():
		if child is Timer and child.timeout.is_connected(Callable(scene.hud, "_update_clock")):
			child.stop()
	_set_hour(12.0)
	await create_timer(1.25).timeout
	await _capture("01-initial-day.png")
	var data: Dictionary = scene.farm_state.snapshot()
	for index in 6:
		var id: String = Farm.FIELD_IDS[index]
		data.fields[id].crop_id = "greens" if index < 3 else "radish"
		data.fields[id].growth_seconds = [0.0, 0.6, 1.0][index % 3] * (1800.0 if index < 3 else 5400.0)
		data.fields[id].watered = false
	_expect(scene.farm_state.restore_snapshot(data), "Six-stage fixture obeys production state schema")
	scene.refresh_farm()
	await _capture("02-all-six-stages.png")
	for index in 6:
		var body: StaticBody3D = scene.farm.fields[index]
		var field: Dictionary = scene.farm_state.get_field(Farm.FIELD_IDS[index])
		var plants: Node3D = body.get_node("Crops")
		_expect(plants.get_child_count() == 16 and body.get_meta("field_id") == field.id, "Stable field identity with sixteen independently grouped plants")
		var plant: Node3D = plants.get_child(0)
		_expect(plant.scene_file_path == Crops.scene_path(field.crop_id, field.stage) and plant.scale == Vector3.ONE, "Correct formal stage resource at authored meter scale")
		_expect(is_equal_approx(plant.position.y, scene.farm.FIELD_SIZE.y / 2.0 - Crops.planting_depth(field.crop_id, field.stage)), "Formal crop uses fixed soil planting depth")
		var point: Vector3 = body.global_position + Vector3(0, 0.3, 0)
		var ray := PhysicsRayQueryParameters3D.create(scene.camera.global_position, point, 1)
		_expect(scene.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == body, "Field collision remains independent of stage mesh")
	# Compare the same composition at full crop density without changing first-save defaults.
	var mature: Dictionary = data.duplicate(true)
	for index in 6:
		mature.fields[Farm.FIELD_IDS[index]].growth_seconds = 1800.0 if index < 3 else 5400.0
	_expect(scene.farm_state.restore_snapshot(mature), "Maximum-density visual fixture preserves the farm schema")
	scene.refresh_farm()
	await _capture("02b-all-mature.png")
	_set_hour(16.5)
	await create_timer(1.0).timeout
	await _capture("02c-golden-hour.png")
	await create_timer(3.0).timeout
	await _capture("02d-golden-hour-motion.png")
	_set_hour(12.0)
	_expect(scene.farm_state.restore_snapshot(data), "Restore the six-stage fixture after maximum-density comparison")
	scene.refresh_farm()
	for index in [0, 2, 3, 5]:
		scene._focus_field(index)
		await create_timer(0.85).timeout
		await _capture("03-focus-%02d.png" % (index + 1))
	scene.camera.drag(Vector2(-300, 160), false)
	scene.camera.drag(Vector2(800, 800), true)
	scene.camera.zoom(-100)
	await _capture("04-focus-limit.png")
	scene._reset_view()
	await create_timer(0.85).timeout
	scene.camera.drag(Vector2(600, -600), false)
	scene.camera.zoom(100)
	await _capture("05-overview-limit.png")
	scene._reset_view()
	await create_timer(0.85).timeout
	_set_hour(21.0)
	await _capture("06-night.png")
	for failure: String in failures:
		push_error(failure)
	print("COMPLETE_SCENE_TEST checks=%d failures=%d screenshots=%s" % [checks, failures.size(), captures])
	root.remove_child(scene)
	scene.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(captures.path_join(filename)) == OK, "Write formal-scene evidence")


func _set_hour(hour: float) -> void:
	scene.atmosphere.set_preview_hour(hour)
	var minutes: int = int(round(hour * 60.0)) % 1440
	scene.hud._clock.text = "%02d:%02d" % [floori(minutes / 60.0), minutes % 60]
	scene.hud._day_icon.texture = scene.hud.SUN if minutes >= 360 and minutes < 1080 else scene.hud.MOON


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
