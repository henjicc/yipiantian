extends SceneTree
## Exercise real exported skin through the production gait; toe edges must not stretch.
const Pose = preload("res://scenes/environment/bird_pose.gd")
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func skinned(vertices: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array, skin: Skin, skeleton: Skeleton3D) -> PackedVector3Array:
	var transforms: Array[Transform3D] = []
	for bind: int in skin.get_bind_count():
		transforms.append(skeleton.get_bone_global_pose(skeleton.find_bone(skin.get_bind_name(bind))) * skin.get_bind_pose(bind))
	var points := PackedVector3Array()
	var count: int = bones.size() / vertices.size()
	for i: int in vertices.size():
		var point := Vector3.ZERO
		for j: int in count:
			var offset: int = i * count + j
			point += (transforms[bones[offset]] * vertices[i]) * weights[offset]
		points.append(skeleton.to_global(point))
	return points

func run() -> void:
	root.size = Vector2i(1400, 1000)
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = .29
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.86,.88,.90)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	stage.add_child(light)
	var visual: bool = "--visual" in OS.get_cmdline_user_args()
	var output: String = ProjectSettings.globalize_path("res://../.local/verification/hen-skinning")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if visual: DirAccess.make_dir_recursive_absolute(output)
	for tier: String in ["high", "low"]:
		var bird: Node3D = load("res://art/environment/courtyard_life/hen_%s.glb" % tier).instantiate()
		stage.add_child(bird)
		var pose := Pose.new()
		pose.configure(bird, "hen")
		pose.ground = func(_p: Vector2) -> float: return 0.0
		var mesh: MeshInstance3D = bird.find_children("*", "MeshInstance3D", true, false)[0]
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var rest: PackedVector3Array = skinned(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], mesh.skin, pose.skeleton)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var edges: Array[Vector2i] = []
		# Bottom 18 mm includes toes, excludes the ankle's intended flexion.
		for face: int in range(0, indices.size(), 3):
			for j: int in 3:
				var a: int = indices[face+j]
				var b: int = indices[face+(j+1)%3]
				if rest[a].y < .018 and rest[b].y < .018 and rest[a].distance_to(rest[b]) > .0003:
					edges.append(Vector2i(a,b))
		assert(edges.size() > 100, "Missing toe coverage")
		var maximum: float = 1.0
		var minimum: float = 1.0
		for frame: int in 48:
			pose.phase = frame / 48.0
			pose.motion = 1.0
			pose.action = "walk"
			pose.update(1.0/60.0, 0.0, .23, "walk", frame/60.0)
			var points: PackedVector3Array = skinned(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], mesh.skin, pose.skeleton)
			for edge: Vector2i in edges:
				var ratio: float = points[edge.x].distance_to(points[edge.y]) / rest[edge.x].distance_to(rest[edge.y])
				maximum = maxf(maximum, ratio)
				minimum = minf(minimum, ratio)
			if visual and frame in [0, 12, 24, 36]:
				for side: int in [-1, 1]:
					camera.position = Vector3(side * .5, .21, .48)
					camera.look_at(Vector3(0,.07,.025))
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join("%s-%02d-%d.png" % [tier,frame,side]))
		print("HEN_SKINNING ", tier, " toe_edges=",edges.size()," length_ratio=",minimum,"..",maximum)
		if maximum > 1.03 or minimum < .97: failures.append(tier + " toes stretch during alternating steps")
		bird.queue_free()
		await process_frame
	print("HEN_SKINNING_PASS" if failures.is_empty() else "HEN_SKINNING_FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)
