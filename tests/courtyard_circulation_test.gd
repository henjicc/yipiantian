extends SceneTree
const Plan = preload("res://layout/courtyard_plan.gd")
const Circulation = preload("res://layout/courtyard_circulation.gd")
var failures: Array[String] = []
var output := ProjectSettings.globalize_path("res://../.local/verification/circulation")

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool,message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	# Two free raster samples may straddle geometry; the entire edge must be
	# removed from the route search, rather than rejecting its chosen route.
	var corner: RefCounted=load("res://scenes/environment/animal_space.gd").new()
	corner.configure(Rect2(0,0,2,2),.01)
	corner.block(PackedVector2Array([Vector2(.78,.85),Vector2(.84,.85),Vector2(.81,.91)]))
	corner.bake()
	var detour: PackedVector2Array=corner.path(Vector2(.8,.48),Vector2(.8,1.28))
	expect(not detour.is_empty(),"Thin obstacle between free samples still permits a safe detour")
	for i: int in range(detour.size()-1): expect(corner.clear_segment(detour[i],detour[i+1]),"Detour never crosses the thin obstacle")
	corner.block(PackedVector2Array([Vector2(-1,.85),Vector2(3,.85),Vector2(3,.91),Vector2(-1,.91)]))
	corner.bake()
	expect(corner.path(Vector2(.8,.48),Vector2(.8,1.28)).is_empty(),"Disconnected thin wall never returns an infinite-cost route")
	root.size=Vector2i(1600,900)
	var expanded: bool = "--expanded" in OS.get_cmdline_user_args()
	output=output.path_join("expanded" if expanded else "original")
	DirAccess.make_dir_recursive_absolute(output)
	var plan := Plan.new()
	if expanded:
		plan.expand_shore(2.6,3.0)
		plan.fields[0].position=Vector3(-8,.2,1)
		plan.fields[0].yaw=8.0
		var extra: Dictionary=plan.fields[2].duplicate(true)
		extra.id="field_07"
		extra.position=Vector3(-3.3,.2,6.9)
		plan.fields.append(extra)
	var scene: Node3D=load("res://scenes/main.tscn").instantiate()
	scene.courtyard_plan=plan
	var isolated: String=output.path_join("session-%d"%Time.get_ticks_usec())
	scene.store=load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store=load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame
	var world: Node3D=scene.get_node("Environment")
	var circulation: RefCounted=world.circulation
	print("CIRCULATION issues=",circulation.issues," endpoints=",circulation.endpoints," paths=",plan.paths.size()," fences=",plan.fences.size())
	expect(circulation.issues.is_empty(),"All doors, landing and field edges have connected routes")
	var placements: Array[String]=Circulation.field_placement_issues(plan,world.layout_obstacles)
	print("PLACEMENT issues=",placements)
	expect(placements.is_empty(),"Current fields clear real buildings and supported land")
	for key: String in ["YardWaterVats","YardGroundTrays","YardSeedFrames","YardMelonPile","YardBasketStack","YardBucket","YardFirewood","YardJarCluster"]:
		var polygon: PackedVector2Array=world.layout_obstacles[key]
		expect(Geometry2D.clip_polygons(polygon,plan.plateau()).is_empty(),"Moved prop remains supported: "+key)
		for other: String in world.layout_obstacles:
			if other==key or not (other in ["Kitchen","PorchDeck","MainHouse","EntranceTrellis","SidePorchDryingRack"] or other.begins_with("Yard")): continue
			expect(Geometry2D.intersect_polygons(polygon,world.layout_obstacles[other]).is_empty(),"Moved prop clears furniture and structures: "+key+" / "+other)
	for route: PackedVector3Array in plan.paths:
		for i: int in range(route.size()-1):
			expect(circulation.road.clear_segment(Vector2(route[i].x,route[i].z),Vector2(route[i+1].x,route[i+1].z)),"Every rendered path segment clears expanded obstacles")
	var animals: Node3D=world.get_node("CourtyardAnimals")
	expect(animals.ready_for_motion and animals.yard.points.size()>500,"Fence geometry does not block whole yard as one convex hull")
	for span: Dictionary in plan.fences:
		expect(span.a.distance_to(span.b)<1.5,"Fence beams have bounded post spacing")
		var a:=Vector2(span.a.x,span.a.z)
		var b:=Vector2(span.b.x,span.b.z)
		for route: PackedVector3Array in plan.paths:
			for i: int in range(route.size()-1):
				expect(Circulation.segment_distance(a,b,Vector2(route[i].x,route[i].z),Vector2(route[i+1].x,route[i+1].z))>=.549,"Fence leaves every path crossing open")
		var midpoint: Vector2=(a+b)*.5
		expect(not animals.yard.contains(midpoint),"Real fence spans block hen movement")
	for key: String in circulation.endpoints:
		expect(animals.yard.contains(circulation.endpoints[key]),"Landmark route remains passable for hens: "+key)
		expect(not animals.yard.path(circulation.endpoints.house,circulation.endpoints[key]).is_empty(),"Hens can reach each connected landmark: "+key)
	var broken: RefCounted=Plan.from_snapshot(plan.snapshot())
	broken.fields[0].position=broken.fields[1].position
	expect(not Circulation.field_placement_issues(broken,world.layout_obstacles).is_empty(),"Overlapping edit is rejected")
	broken.fields[0].position=Vector3(25,.2,25)
	expect(not Circulation.field_placement_issues(broken,world.layout_obstacles).is_empty(),"Off-island edit is rejected")
	var shading: Node3D=world.get_node("ContactShading")
	var ground_pool: Decal=shading.get_node("ContactPool13")
	for span: Dictionary in plan.fences:
		var local: Vector3=ground_pool.to_local(span.a)
		expect(absf(local.x)<ground_pool.size.x*.5 and absf(local.z)<ground_pool.size.z*.5,"All fence feet covered by contact decal bounds")
	if "--visual" in OS.get_cmdline_user_args():
		scene.atmosphere.set_preview_hour(14.25)
		await shot("overview.png")
		scene.camera.set_process(false)
		scene.focus_detail.set_depth_of_field(false)
		for item: Dictionary in [{"name":"bridge-gate.png","eye":Vector3(9,5,7),"at":Vector3(4,.2,1)},{"name":"garden-gate.png","eye":Vector3(-10,4,-1),"at":Vector3(-5,.2,1)}]:
			scene.camera.global_position=item.eye
			scene.camera.look_at(item.at)
			await shot(item.name)
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	print("CIRCULATION_PASS" if failures.is_empty() else "CIRCULATION_FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func shot(filename: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))
