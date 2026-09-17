extends SceneTree
const Plan = preload("res://layout/courtyard_plan.gd")
const Bank = preload("res://layout/bank_geometry.gd")
var failures: Array[String] = []
var output := ProjectSettings.globalize_path("res://../.local/verification/layout-banks")

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var plan := Plan.new()
	var expanded_scene: bool = "--expanded" in OS.get_cmdline_user_args()
	if expanded_scene:
		plan.expand_shore(2.6,3.0)
		output = output.path_join("expanded")
		DirAccess.make_dir_recursive_absolute(output)
	var expanded: PackedVector2Array = plan.rim.duplicate()
	for i: int in expanded.size():
		expanded[i] += Vector2(minf(expanded[i].x,0)*.3,maxf(expanded[i].y,0)*.3)
	var irregular: PackedVector2Array = expanded.duplicate()
	irregular[10] += Vector2(0,1.2)
	irregular[12] += Vector2(-1,.5)
	for shape: PackedVector2Array in [plan.rim, expanded, irregular, plan.east_rim]:
		_check_mesh(Bank.build(shape), .13)
	_check_mesh(Bank.build(irregular,.19,1.4), .19)
	# Real scene checks cover semantic bank discovery, water contacts and farm support.
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.courtyard_plan = plan
	var isolated: String = output.path_join("session-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store = load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	root.add_child(scene)
	await process_frame
	await process_frame
	var world: Node3D = scene.get_node("Environment")
	var main_bank: Node3D = world.get_node("MainBank")
	var east: Node3D = world.get_node("EastBank")
	expect(world._shore_sources.has(main_bank) and world._shore_sources.has(east), "Both generated banks feed water contacts")
	for field: Node3D in scene.farm.fields:
		for x: float in [-1.4,1.4]:
			for z: float in [-1.1,1.1]:
				expect(absf(_height(main_bank,field.to_global(Vector3(x,0,z)))-.13)<.003, "Field corners stay supported")
	var bridge: Transform3D = Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles.bridge)),plan.anchors.bridge)
	for side: float in [-.73,0,.73]:
		var h: float = _height(east,bridge * Vector3(2.47,0,side))
		expect(h>.07 and h<.17, "Bridge exit remains supported")
	var animals: Node3D = world.get_node("CourtyardAnimals")
	var leaves: MultiMeshInstance3D = world.get_node("OsmanthusLeaves")
	expect(not leaves._anchors.is_empty(),"Leaf emission follows the relocated canopy")
	expect(leaves.global_position.is_equal_approx(world.get_node("WestTree").global_position),"Leaf emitter remains attached to tree")
	expect(animals.ready_for_motion and animals.birds.size()==7,"Animals rebuild on procedural terrain")
	expect(not animals.water.contains(Vector2.ZERO), "Generated island blocks swimming")
	for tree: Dictionary in plan.trees:
		var instance: Node3D = world.get_node(tree.id)
		expect(instance.position.is_equal_approx(tree.at),"Tree follows shared position")
		expect(instance.scale.is_equal_approx(Vector3.ONE*float(tree.size)),"Tree scale does not stretch with land")
	expect(scene.camera.overview_point.is_equal_approx(plan.camera_point),"Camera frames selected layout")
	if expanded_scene:
		expect(plan.rim[0].x < -9.0 and plan.rim[10].y > 9.0,"Expansion changes land geometry")
		expect(plan.haze_region.z > 10.8 and plan.haze_region.w > 10,"Clear haze region grows with land")
		expect(world.get_node("MainHouse").position.is_equal_approx(Vector3(.65,.13,-4.65)),"Expansion preserves house anchor")
	for p: Vector2 in animals.yard.points:
		expect(Geometry2D.is_point_in_polygon(p,plan.plateau()),"Walking cannot leave the plateau")
	if "--visual" in OS.get_cmdline_user_args():
		root.size = Vector2i(1600,900)
		scene.atmosphere.set_preview_hour(14.25)
		await _shot("overview.png")
		scene.camera.set_process(false)
		scene.focus_detail.set_depth_of_field(false)
		for shot: Dictionary in [
			{"name":"shore-front.png","eye":Vector3(0,1.4,13.6 if expanded_scene else 10.6),"at":Vector3(0,-.1,9.3 if expanded_scene else 6.3)},
			{"name":"bridge-front.png","eye":Vector3(12,2.1,5.5),"at":Vector3(10.5,.2,.15)},
			{"name":"bridge-reverse.png","eye":Vector3(11.8,2.6,-4.5),"at":Vector3(10.5,.2,.15)}]:
			scene.camera.global_position=shot.eye
			scene.camera.look_at(shot.at)
			await _shot(shot.name)
	scene.queue_free()
	await process_frame
	await process_frame
	print("BANK_LAYOUT_PASS" if failures.is_empty() else "BANK_LAYOUT_FAIL " + str(failures))
	quit(0 if failures.is_empty() else 1)

func _check_mesh(mesh: ArrayMesh, height: float) -> void:
	expect(mesh != null,"Controlled contour produces mesh")
	if mesh == null: return
	var data: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var edges: Dictionary = {}
	var directed: Dictionary = {}
	for i: int in range(0,indices.size(),3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i+1]]
		var c: Vector3 = vertices[indices[i+2]]
		var face_normal: Vector3 = (c-a).cross(b-a)
		expect(face_normal.length()>.0000001,"No zero-area triangles")
		if is_equal_approx(a.y,height) and is_equal_approx(b.y,height) and is_equal_approx(c.y,height):
			expect(face_normal.y>0,"Plateau winding faces up")
		for k: int in 3:
			var start: int = indices[i+k]
			var end: int = indices[i+(k+1)%3]
			var edge := Vector2i(mini(start,end),maxi(start,end))
			edges[edge] = edges.get(edge,0)+1
			directed[edge] = directed.get(edge,0)+(1 if start<end else -1)
	for edge: Vector2i in edges:
		expect(edges[edge]==2 and directed[edge]==0,"Closed manifold with consistent winding")
	for normal: Vector3 in normals:
		expect(normal.is_finite() and absf(normal.length()-1)<.001,"Finite smooth normals")
	print("BANK_GEOMETRY ",vertices.size()," vertices, ",indices.size()/3," triangles; height=",height)

func _height(node: Node3D, point: Vector3) -> float:
	var result: float = -INF
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i: int in range(0,faces.size(),3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(point+Vector3.UP*2,point-Vector3.UP*2,mesh.global_transform*faces[i],mesh.global_transform*faces[i+1],mesh.global_transform*faces[i+2])
			if hit != null: result=maxf(result,hit.y)
	return result

func _shot(filename: String) -> void:
	await create_timer(.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))
