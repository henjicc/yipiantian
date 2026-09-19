extends SceneTree
## Actual farm lighting, isolated save, no user input or player data changes.

const Store = preload("res://farm/farm_store.gd")
const Farm = preload("res://farm/farm_state.gd")
const Decorations = preload("res://farm/decoration_state.gd")
var output: String = ""
var failures: Array[String] = []
var checks: int = 0
var scene: Node3D


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)


func _run() -> void:
	var folder: String = ProjectSettings.globalize_path("res://../.local/verification/night-lighting-%d" % Time.get_ticks_usec())
	var store = Store.new(folder)
	_expect(store.load_state().kind == "missing", "Fixture starts without player data")
	var farm: Dictionary = Farm.new(1800000000.0).snapshot()
	farm.harvested.greens = 10
	farm.harvested.radish = 6
	farm.harvested.spinach = 1
	var decorations = Decorations.new()
	decorations.unlock(farm.harvested)
	_expect(decorations.place("lantern", "hanging_01", 0).ok, "Fixture includes a placed lantern")
	_expect(store.save(farm, decorations.snapshot()).ok, "Isolated scene fixture saved")
	root.size = Vector2i(1920,1080)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = store
	scene.settings_store = load("res://settings/settings_store.gd").new(folder.path_join("preferences"))
	scene.clock = func() -> float: return 1800000000.0
	root.add_child(scene)
	await create_timer(.5).timeout
	var courtyard: Node3D = scene.get_node("Environment")
	var living: Node3D = courtyard.get_node("LivingDetails")
	var lamps: Array[Node] = living.find_children("PathLanternLight", "OmniLight3D", true, false)
	var placed: Array[Node] = scene.find_children("FarmLanternLight", "OmniLight3D", true, false)
	_expect(lamps.size() == 3 and placed.size() == 1, "Three permanent path lamps coexist with the placed lantern")
	_expect(courtyard.circulation.issues.is_empty(), "Raised lamp posts preserve the courtyard walking network: " + str(courtyard.circulation.issues))
	for lamp: OmniLight3D in lamps:
		_expect(lamp.global_position.y > courtyard.plan.ground_height+2.2, "Light source is above crop height")
		var id: String = String(lamp.get_parent().name)
		_expect(courtyard.layout_obstacles.has(id), "Lamp post participates in real obstacle geometry")
		if courtyard.layout_obstacles.has(id):
			for index: int in courtyard.plan.fields.size():
				_expect(Geometry2D.intersect_polygons(courtyard.layout_obstacles[id],courtyard.plan.field_polygon(index)).is_empty(), "Lamp post stays outside plantable soil")
	var state_before: Dictionary = scene.farm_state.snapshot()
	for hour: float in [14.0,18.5,22.0,14.0]:
		scene.atmosphere.set_preview_hour(hour)
		await create_timer(.3).timeout
		var strength: float = scene.atmosphere.get_night_weight()
		for lamp: OmniLight3D in living._lantern_lights + placed:
			_expect(lamp.visible == (strength > 0.0), "Clock switches actual lights, including night-to-day return")
			_expect((lamp.light_energy > 0.0) == (strength > 0.0), "Daylight emits no artificial lamp energy")
		for mesh: MeshInstance3D in living._lantern_meshes:
			_expect(is_equal_approx(mesh.get_instance_shader_parameter("lantern_warmth"),strength), "Paper emission follows the same clock as illumination")
		await _capture("hour-%04d-overview" % int(hour*100))
	_expect(scene.farm_state.snapshot() == state_before, "Lighting changes do not mutate farm progress")
	scene.atmosphere.set_preview_hour(22.0)
	for quality: String in ["low","standard"]:
		scene.focus_detail.set_quality(quality)
		for lamp: OmniLight3D in lamps:
			_expect(lamp.shadow_enabled == (quality == "standard"), "Quality switches local lamp shadows")
			_expect(lamp.light_energy > 0.0 and lamp.visible, "Low quality keeps useful night illumination")
		await _capture("night-" + quality)
	# Inspect the actual terrain from opposite sides as well as the game overview.
	scene.camera.set_process(false)
	scene.camera.attributes.dof_blur_near_enabled = false
	scene.camera.attributes.dof_blur_far_enabled = false
	scene.camera.fov = 45
	for index: int in lamps.size():
		var centre: Vector3 = lamps[index].get_parent().global_position + Vector3(0,1.45,0)
		for sign_value: float in [1.0,-1.0]:
			scene.camera.position = centre + Vector3(2.3*sign_value,1.2,3.5*sign_value)
			scene.camera.look_at(centre)
			for hour: float in [14.0,22.0]:
				scene.atmosphere.set_preview_hour(hour)
				await _capture("lamp-%d-%s-%02d" % [index,"front" if sign_value > 0 else "back",int(hour)])
	var renderer: String = RenderingServer.get_current_rendering_method()
	scene.queue_free()
	scene = null
	await process_frame
	await process_frame
	for failure: String in failures: push_error(failure)
	print("NIGHT_LIGHTING_TEST checks=%d failures=%d renderer=%s output=%s" % [checks,failures.size(),renderer,output])
	quit(0 if failures.is_empty() else 1)


func _capture(label: String) -> void:
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	await create_timer(.25).timeout
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK, "Saved " + label)
