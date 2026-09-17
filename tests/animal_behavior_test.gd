extends SceneTree
## Real courtyard geometry and original rigs; no player save, no video capture.
var failures: Array[String] = []
var scene: Node3D
var output: String

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value and not failures.has(message): failures.append(message)

func _run() -> void:
	output = ProjectSettings.globalize_path("res://../.local/verification/animal-behavior")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1920, 1080)
	scene = load("res://scenes/main.tscn").instantiate()
	var isolated: String = output.path_join("session-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store = load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	root.add_child(scene)
	scene.get_node("Environment/CourtyardAnimals")._rng.seed = 9182026
	await process_frame
	var animals: Node3D = scene.get_node("Environment/CourtyardAnimals")
	while not animals.ready_for_motion: await process_frame
	animals.set_process(false)
	animals._rng.seed = 9182026
	print("ANIMAL_SPACES water=", animals.water.points.size(), " yard=", animals.yard.points.size())
	check(animals.birds.size() == 7, "All seven animals spawned")
	var traveled: Dictionary = {}
	var extents: Dictionary = {}
	var states: Dictionary = {}
	for entry: Dictionary in animals.birds:
		traveled[entry.node.name] = 0.0
		extents[entry.node.name] = Rect2(entry.position, Vector2.ZERO)
	var begin: int = Time.get_ticks_usec()
	for frame: int in 10800:
		var old: Array[Vector2] = []
		for entry: Dictionary in animals.birds: old.append(entry.position)
		animals._process(1.0 / 30.0)
		for i: int in animals.birds.size():
			var entry: Dictionary = animals.birds[i]
			var label: String = entry.node.name
			var distance: float = old[i].distance_to(entry.position)
			traveled[label] += distance
			extents[label] = (extents[label] as Rect2).expand(entry.position)
			states[entry.kind + "/" + entry.state] = true
			check(entry.space.contains(entry.position), label + " remains in navigable space")
			check(distance <= entry.speed / 30.0 + .00001, label + " never teleports")
			check(entry.node.transform.is_finite(), label + " valid pose")
			for j: int in range(i + 1, animals.birds.size()):
				var other: Dictionary = animals.birds[j]
				if other.space == entry.space: check(entry.position.distance_to(other.position) >= entry.radius + other.radius - .005, label + " separation")
		if frame % 900 == 0: await process_frame
	var elapsed: float = (Time.get_ticks_usec() - begin) / 1000.0
	for entry: Dictionary in animals.birds:
		var label: String = entry.node.name
		check(traveled[label] > 8.0, label + " moves across yard/lake")
		check((extents[label] as Rect2).size.length() > (2.0 if entry.kind == "hen" else 4.0), label + " range expanded")
		check(entry.recoveries < 15, label + " does not repeatedly stick at corners")
		print(label, " travel=", snappedf(traveled[label], .01), " area=", extents[label], " recovery=", entry.recoveries)
	for required: String in ["hen/peck", "hen/observe", "duck/probe", "duck/preen", "goose/probe", "goose/preen"]: check(states.has(required), "Behavior seen: " + required)
	print("ANIMAL_SIM_MS ", elapsed, " per_step_ms=", elapsed / 10800.0)
	if "--visual" in OS.get_cmdline_user_args():
		scene.atmosphere.set_preview_hour(14.25)
		scene.camera.set_free_view(true)
		for index: int in [5, 0, 3]:
			var entry: Dictionary = animals.birds[index]
			if index == 5:
				entry.position = animals.yard.nearest(Vector2(-1.66, 2.0))
				animals._choose(entry)
				check(not entry.route.is_empty(), "Near-view chicken has a reachable walk")
				entry.node.position = Vector3(entry.position.x, .13, entry.position.y)
				for frame: int in 90: animals._process(1.0 / 30.0)
			var center: Vector3 = entry.node.position + Vector3.UP * .17
			scene.camera.position = center + Vector3(1.0, .7, -.8)
			scene.camera.look_at(center)
			scene.camera.fov = 36
			scene.focus_detail.set_depth_of_field(false)
			for step: int in 3:
				for frame: int in 9: animals._process(1.0 / 30.0)
				print("POSE_SAMPLE ", entry.kind, " ", entry.state, " at=", entry.position, " phase=", entry.pose.phase)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%d.png" % [entry.kind, step]))
			if index == 5:
				scene.camera.position = center + Vector3(-1.25, .45, -1.5)
				scene.camera.look_at(center)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("hen-reverse.png"))
	print("ANIMAL_BEHAVIOR_PASS" if failures.is_empty() else "ANIMAL_BEHAVIOR_FAIL " + str(failures))
	scene.farm_audio.shutdown()
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

