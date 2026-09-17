extends SceneTree
## One scene pass: actual shore support, world-space neighbors, near/far tiers,
## background composition and paired evidence; isolated from the player's save.
var scene: Node3D
var failures: Array[String] = []
var output := ProjectSettings.globalize_path("res://../.local/verification/archipelago-20260918/after")

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,900)
	scene = load("res://scenes/main.tscn").instantiate()
	var isolated := output.path_join("session-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store = load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	root.add_child(scene)
	scene.atmosphere.set_preview_hour(16.5)
	await create_timer(1.0).timeout
	var world: Node3D = scene.get_node("Environment")
	var neighbors: Node3D = world.get_node("NeighborIslets")
	expect(neighbors._islets.size()==10,"Five new unique islands augment the existing five")
	var planting_count := 0
	for entry: Dictionary in neighbors._islets:
		expect(entry.node.scale.is_equal_approx(Vector3.ONE),"Perspective alone determines apparent island size")
		expect(entry.plants.shoreline_points.size()>20,"Actual shoreline sampled: "+str(entry.node.name))
		expect(entry.plants.clump_count>10,"Marsh plants frame each island")
		planting_count+=entry.plants.clump_count
	var stage: Node3D = world.get_node("DistantLandscape")
	expect(stage.get_child_count()==5,"Unique silhouettes replace the repeated strips")
	var east: Node3D
	var main_bank: Node3D
	for node: Node in world.get_children():
		if node.get_meta("bank_role", "") == "east": east=node
		if node.get_meta("bank_role", "") == "main": main_bank=node
	expect(east!=null and main_bank!=null,"New rounded banks used at runtime")
	# Sample both edges and centre of the actual bridge exit, beyond the deck.
	var bridge_basis := Basis(Vector3.UP,deg_to_rad(-9.0))
	for side: float in [-.73,0.0,.73]:
		var p := Vector3(8.1,-.04,-.15)+bridge_basis*Vector3(2.47,0,side)
		var height: float = support_height(east,p)
		expect(height>.07 and height<.17,"East bridge exit has dry supporting terrain: "+str(p))
	for field: Node3D in scene.farm.fields:
		for x: float in [-1.4,1.4]:
			for z: float in [-1.1,1.1]:
				var p: Vector3 = field.global_position+Vector3(x,0,z)
				expect(absf(support_height(main_bank,p)-.13)<.003,"Cultivation plateau preserved")
	await shot("01-overview.png")
	var far_limit: float = scene.camera.attributes.dof_blur_far_distance
	var far_transition: float = scene.camera.attributes.dof_blur_far_transition
	var far_depth: float = (-scene.camera.global_basis.z).dot(neighbors.get_node("WillowMeadow").global_position-scene.camera.global_position)
	expect(far_transition<50.0 and far_depth>far_limit+far_transition,"Far islands actually reach the defocus band")
	for field: Node3D in scene.farm.fields:
		var depths: Vector2 = scene.focus_detail.depth_range(scene.camera,field.global_transform,AABB(Vector3(-1.4,-.1,-1.15),Vector3(2.8,.75,2.3)))
		expect(depths.y<far_limit,"Farming remains inside the clear band")
	var original_pose: Transform3D = scene.camera.global_transform
	scene.camera.set_process(false)
	scene.focus_detail.set_depth_of_field(false)
	await look("02-bridge-near.png",Vector3(12.0,2.1,5.5),Vector3(10.5,.2,.15))
	await look("03-bridge-reverse.png",Vector3(11.8,2.6,-4.5),Vector3(10.5,.2,.15))
	await look("04-rounded-shore.png",Vector3(0,1.4,10.6),Vector3(0,-.1,6.3))
	await look("05-willow-islet.png",Vector3(-12,4.0,7),neighbors.get_node("WillowNeighbor").global_position+Vector3.UP)
	expect(not neighbors._islets[0].distant,"Approach restores full source geometry")
	await look("06-bamboo-islet.png",Vector3(-17,4.1,-4),neighbors.get_node("BambooNeighbor").global_position+Vector3.UP)
	await look("07-cottage-islet.png",Vector3(14,3.8,-7),neighbors.get_node("EasternCottage").global_position+Vector3.UP)
	for key: String in ["RiceHamlet","MulberryCourt","BambooInlet","CanalCourts","WillowMeadow"]:
		var island: Node3D = neighbors.get_node(key)
		await look("07-"+key+".png",island.global_position+Vector3(8,5,13),island.global_position+Vector3.UP)
	scene.camera.global_transform = original_pose
	scene.camera.set_process(true)
	scene.focus_detail.set_depth_of_field(true)
	await create_timer(.5).timeout
	expect(neighbors._islets[3].distant and neighbors._islets[4].distant,"Far islets select the authored low tier")
	scene.atmosphere.set_preview_hour(21.0)
	await shot("08-night.png")
	scene.atmosphere.set_preview_hour(11.2)
	root.size = Vector2i(3840,2160)
	await shot("09-4k-day.png")
	scene.focus_detail.set_depth_of_field(false)
	await create_timer(1.2).timeout
	await shot("09-4k-dof-off.png")
	scene.focus_detail.set_depth_of_field(true)
	await create_timer(1.2).timeout
	for yaw: float in [17.5,37.5]:
		scene.camera.view.x=yaw
		await shot("10-orbit-%s.png"%yaw)
	scene.camera.view.x=27.5
	await create_timer(.3).timeout
	scene.focus_detail.set_quality("low")
	await process_frame
	for entry: Dictionary in neighbors._islets: expect(entry.low.visible and not entry.high.visible,"Low quality respects authored tier")
	scene.focus_detail.set_quality("standard")
	await create_timer(.3).timeout
	expect(neighbors._islets[0].high.visible,"Returning quality recovers near detail")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await create_timer(.5).timeout
	var measurements: Array[Dictionary] = []
	for enabled: bool in [false,true]:
		neighbors.get_node("OpenWaterTrapa").visible=enabled
		for index: int in neighbors._islets.size():
			neighbors._islets[index].plants.visible=enabled
			if index>=5: neighbors._islets[index].node.visible=enabled
		await create_timer(.6).timeout
		var gpu: Array[float] = []
		var primitives: Array[float] = []
		for index: int in 90:
			await RenderingServer.frame_post_draw
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			primitives.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		gpu.sort();primitives.sort()
		measurements.append({"new_geometry_enabled":enabled,"gpu_median_ms":gpu[45],"gpu_p95_ms":gpu[85],"drawn_triangles":primitives[45]})
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),false)
	var report := {"failures":failures,"camera":scene.camera.overview_parameters(),"islets":neighbors._islets.size(),"plant_clumps":planting_count,"background_cards":stage.get_child_count(),"far_transition":far_transition,"far_limit":far_limit,"measurements":measurements,"device":RenderingServer.get_video_adapter_name(),"foreground":scene.window_activity.is_foreground(),"note":"Short same-instance 4K renderer sample; other applications may contend. Not a foreground gameplay performance certification."}
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	scene.farm_audio.shutdown()
	await create_timer(.3).timeout
	scene.queue_free();await process_frame
	print("ISLAND_WORLD_PASS "+str(report) if failures.is_empty() else "ISLAND_WORLD_FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func support_height(node: Node3D, point: Vector3) -> float:
	var result: float = -INF
	if node is MeshInstance3D:
		var faces: PackedVector3Array = node.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(point+Vector3.UP*2,point-Vector3.UP*2,node.global_transform*faces[i],node.global_transform*faces[i+1],node.global_transform*faces[i+2])
			if hit != null: result=maxf(result,hit.y)
	for child: Node in node.get_children():
		if child is Node3D: result=maxf(result,support_height(child,point))
	return result

func look(filename: String, eye: Vector3, target: Vector3) -> void:
	scene.camera.global_position=eye
	scene.camera.look_at(target)
	await shot(filename)

func shot(filename: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))
