extends SceneTree
## Authored boat clearance through its motion envelope, and rendered contact/lighting evidence.
var scene: Node3D
var output: String
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	if output.is_empty() or DisplayServer.get_name()=="headless":
		push_error("Native rendering and a dedicated output directory are required")
		quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080); root.content_scale_size=root.size
	scene=load("res://scenes/main.tscn").instantiate()
	scene.store=load("res://farm/farm_store.gd").new(output.path_join("save"))
	scene.settings_store=load("res://settings/settings_store.gd").new(output.path_join("preferences"))
	scene.clock=func() -> float: return 1800000000.0
	root.add_child(scene); root.grab_focus()
	scene.atmosphere.set_preview_hour(16.5)
	await create_timer(.8).timeout
	var courtyard: Node3D=scene.get_node("Environment")
	var boat: Node3D=courtyard.get_node("CoveredBoat")
	var water: ShaderMaterial=courtyard.get_water_surface().material_override
	_expect(water.get_shader_parameter("shore_contacts_enabled") == true, "Clock material preserves the courtyard's actual shoreline")
	var shoreline: Texture2D = water.get_shader_parameter("shore_distance")
	_expect(shoreline != null and shoreline.get_image().get_format() == Image.FORMAT_RF, "Main water receives a metric contact field")
	var baseline: Dictionary=scene.farm_state.snapshot()
	await shot("01-overview")
	var trellis: Node3D=courtyard.get_node("EntranceTrellis")
	var growing_axis: Vector3=trellis.basis.x.normalized()
	_expect(absf(growing_axis.dot(Vector3.FORWARD))>.999,"Long growing row is parallel to the west fence")
	_expect(_points(trellis).size()>0 and courtyard.has_node("GroundCover/ClimbingBed"),"The new frame has a real contiguous planting bed")
	var gate_count: int=0
	var rock_hulls: Array[PackedVector2Array]=[]
	for child: Node in courtyard.get_children():
		if not child is Node3D: continue
		if child.scene_file_path.ends_with("entrance_canopy.glb"): gate_count+=1
		if child.scene_file_path.get_file().begins_with("stone_") and not child.scene_file_path.ends_with("stone_bridge.glb"):
			rock_hulls.append(_hull(_points(child)))
	_expect(gate_count==0,"Requested entrance gate is absent")
	scene.camera.set_process(false)
	scene.focus_detail.set_depth_of_field(false)
	scene.camera.fov=40
	scene.camera.position=Vector3(12,6,10);scene.camera.look_at(Vector3(8.3,0,4.2))
	courtyard.set_process(false)
	var boat_points: PackedVector3Array=_points(boat.get_child(0),boat)
	var collisions: int=0
	var transform_failures: int=0
	# 60 seconds covers several independent heave/roll/pitch periods.
	for step: int in 240:
		courtyard._process(.25)
		var world_points := PackedVector3Array()
		for point: Vector3 in boat_points: world_points.append(boat.global_transform*point)
		var hull: PackedVector2Array=_hull(world_points)
		for rock: PackedVector2Array in rock_hulls:
			if not Geometry2D.intersect_polygons(hull,rock).is_empty(): collisions+=1
		var mask_transform: Transform3D=water.get_shader_parameter("world_to_boat")
		if not mask_transform.is_equal_approx(boat.global_transform.affine_inverse()): transform_failures+=1
		if step in [0,7,15,23,31,47]: await shot("02-boat-motion-%03d" % step)
	_expect(collisions==0,"Boat's full projected envelope never intersects any shore stone over 60 seconds (%d overlaps)" % collisions)
	_expect(transform_failures==0,"Water exclusion follows the moving hull without a stale frame")
	scene.camera.position=Vector3(-2.8,2,9.4);scene.camera.look_at(Vector3(-5.7,-.1,6.25));scene.camera.fov=32
	await shot("03-lotus-shadow")
	scene.camera.position=Vector3(3,6,9);scene.camera.look_at(Vector3(-3.7,.7,.3));scene.camera.fov=40
	await shot("04-ground-trellis")
	scene.atmosphere.set_preview_hour(12); await shot("05-noon")
	scene.atmosphere.set_preview_hour(6.5); await shot("06-dawn")
	scene.atmosphere.set_preview_hour(22); await shot("07-night")
	# Compare actual rendered contacts, not merely an enabled Environment flag.
	scene.atmosphere.set_preview_hour(13)
	scene.camera.fov=34
	scene.camera.position=Vector3(4.4,2.6,1.8);scene.camera.look_at(Vector3(2,.45,-2.35))
	var environment: Environment=scene.get_node("WorldEnvironment").environment
	environment.ssao_enabled=false
	# Sky radiance and SSIL need rendered frames after night->day/camera changes.
	# A .15 s wait is only two frames under the normal background 15 fps cap.
	for frame: int in 12: await RenderingServer.frame_post_draw
	await shot("08-contact-off")
	var without_ao: Image=root.get_texture().get_image()
	environment.ssao_enabled=true
	for frame: int in 12: await RenderingServer.frame_post_draw
	await shot("09-contact-on")
	var with_ao: Image=root.get_texture().get_image()
	# Fixed camera: basket foot after the porch-table clearance fix, and left post.
	# The former basket region (820,503) now contains bare decking.
	for region: Rect2i in [Rect2i(1005,570,100,26),Rect2i(389,339,40,26)]:
		var darkening: float=0.0
		for y: int in range(region.position.y,region.end.y):
			for x: int in range(region.position.x,region.end.x):
				darkening+=without_ao.get_pixel(x,y).get_luminance()-with_ao.get_pixel(x,y).get_luminance()
		darkening/=region.get_area()
		_expect(darkening>.012 and darkening<.20,"Contact darkening is visible but does not crush the surface: %.4f" % darkening)
	_expect(scene.farm_state.snapshot()==baseline,"Visual updates and movement leave all 96 crop cells untouched")
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"motion_seconds":60,"rock_envelopes":rock_hulls.size(),"boat_rock_overlaps":collisions},"\t"))
	scene.farm_audio.shutdown();scene.free();await process_frame
	print("SURFACE_INTEGRATION checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _points(node: Node3D, relative_to: Node3D=null) -> PackedVector3Array:
	var result := PackedVector3Array()
	if node is MeshInstance3D:
		var transform: Transform3D=node.global_transform
		if relative_to!=null: transform=relative_to.global_transform.affine_inverse()*transform
		for surface: int in node.mesh.get_surface_count():
			for point: Vector3 in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: result.append(transform*point)
	for child: Node in node.get_children():
		if child is Node3D: result.append_array(_points(child,relative_to))
	return result

func _hull(points: PackedVector3Array) -> PackedVector2Array:
	var flat := PackedVector2Array()
	for point: Vector3 in points: flat.append(Vector2(point.x,point.z))
	return Geometry2D.convex_hull(flat)

func shot(label: String) -> void:
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"Capture "+label)

func _expect(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);push_error(label)
