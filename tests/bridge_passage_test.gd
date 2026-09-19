extends "res://../tests/bridge_layout_test.gd"
const Passage=preload("res://layout/bridge_passage.gd")
const IslandSpace=preload("res://layout/island_space.gd")

func rules_checks() -> void:
	var plan:=Plan.new();plan.construction.bridge=[5.4,-.1,11.0,.1,1.2,1]
	var combined: PackedVector2Array=Passage.outline(plan,.21)
	expect(not combined.is_empty(),"Both banks and bridge form one walkable outline")
	expect(Geometry2D.is_point_in_polygon(Vector2(8.2,0),combined),"Bridge center is walking ground")
	expect(not Geometry2D.is_point_in_polygon(Vector2(8.2,1.5),combined),"Water beside the bridge remains outside walking ground")
	var exit_block: Dictionary={"player_bench":IslandSpace.rectangle(Vector2(4.85,.42),Vector2(.2,.3))}
	expect(not Passage.approach_issue(plan,exit_block).is_empty(),"Full-width exit rejects a side obstruction even when center is open")
	for style: int in [0,1]:
		plan.construction.bridge[5]=style
		var obstacles: Array[PackedVector2Array]=plan.water_banks()
		obstacles.append_array(Passage.water_shapes(plan))
		expect(not Passage.water_crossing(plan,obstacles).is_empty(),"Current bridge style has an under-deck water passage: %d"%style)
		obstacles.append(IslandSpace.rectangle(Vector2(6.5,-2),Vector2(4,4)))
		expect(Passage.water_crossing(plan,obstacles).is_empty(),"A blocked water channel is rejected: %d"%style)

	plan.fields=[]
	plan.routes=[{"id":1,"kind":"road","points":[[4.7,-.1],[5.5,-.1]],"openings":[]}]
	var bridge: PackedVector2Array=Passage.strip(Vector2(5.4,-.1),Vector2(11,.1),1.2)
	var roads=preload("res://layout/player_routes.gd")
	expect(roads.placement_issue(plan,{"AdaptiveBridge":bridge}).is_empty(),"Road can meet the bridge entrance within its railings")
	plan.routes[0].kind="fence"
	expect(not roads.placement_issue(plan,{"AdaptiveBridge":bridge}).is_empty(),"Fence cannot replace a bridge entrance with a barrier")
	var block: Dictionary={"player_plant_0":IslandSpace.rectangle(Vector2(6.5,-2),Vector2(4,4))}
	expect(not Passage.plan_water_issue(plan,block).is_empty(),"Later construction preserves a water passage under the bridge")
	expect(Passage.plan_water_issue(plan,{}).is_empty(),"Open water remains available after an unrelated layout edit")

func _run() -> void:
	rules_checks()
	if OS.get_cmdline_user_args().has("--rules-only"):
		print("BRIDGE_PASSAGE_RULES checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1);return
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/bridge-passage-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var authored: bool=OS.get_cmdline_user_args().has("--authored-only") or OS.get_cmdline_user_args().has("--flocks-only")
	var layout: Dictionary=Plan.new().snapshot()
	if not authored: layout.construction.bridge=[5.4,-.1,11.0,.1,1.2,1]
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=Plan.from_snapshot(layout)
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	var environment: Node=scene.get_node("Environment")
	print("BRIDGE_CIRCULATION ",environment.circulation.issues," ",environment.circulation.endpoints)
	if not environment.circulation.issues.is_empty():
		for approach: PackedVector2Array in Construction.bridge_approaches(scene.courtyard_plan):
			for key: String in environment.layout_obstacles:
				if not Passage.is_bridge(key) and IslandSpace.overlaps(approach,environment.layout_obstacles[key]): print("BLOCKED_EXIT ",key," ",environment.layout_obstacles[key])

	expect(environment.circulation.issues.is_empty(),"Generated bridge connects the house and both full-width exits")
	if not environment.circulation.issues.is_empty(): await finish();return
	if OS.get_cmdline_user_args().has("--flocks-only"):
		await flock_checks();await finish();return
	await exercise_passage("stone" if authored else "arch")
	if authored: await finish();return
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	await choose_tool("lotus")
	expect(scene.island_builder.plant_preview.message.is_empty(),"Plant editing preserves the valid bridge water passage")
	await choose_tool("bridge")
	scene.camera.focus_point=Vector3(4,.13,0);await frames(10)
	var builder: Node=scene.island_builder
	builder._bridge_style.select(0);builder._bridge_style.item_selected.emit(0)
	if not await ready_draft() or not await apply(): await finish();return
	await terrain_ready();await click(builder._panel.find_child("Finish",true,false))
	await exercise_passage("flat")
	await finish()

func set_route(entry: Dictionary,space: RefCounted,start: Vector2,target: Vector2) -> void:
	entry.position=space.nearest(start);entry.space=space;entry.pose.ground=space.ground_height
	entry.node.position=Vector3(entry.position.x,space.ground_height(entry.position) if entry.kind=="hen" else -.25-scene.get_node("Environment/CourtyardAnimals").PROFILES[entry.kind].draft,entry.position.y)
	entry.velocity=Vector2.ZERO;entry.heading=atan2(target.x-entry.position.x,target.y-entry.position.y);entry.buddy=null;entry.interest=Vector2.INF;entry.stuck=0.0
	entry.route=space.path(entry.position,space.nearest(target));entry.waypoint=0;entry.state="walk" if entry.kind=="hen" else "swim"

func exercise_passage(label: String, region: RefCounted=null) -> void:
	var environment: Node=scene.get_node("Environment")
	var animals: Node=environment.get_node("CourtyardAnimals")
	var plan: RefCounted=scene.courtyard_plan
	var ends: Array[Vector3]=Construction.bridge_points(plan)
	var a:=Vector2(ends[0].x,ends[0].z);var b:=Vector2(ends[1].x,ends[1].z)
	var direction: Vector2=(b-a).normalized()
	expect(environment.circulation.endpoints.has("east_bank"),"Opposite bank has a real circulation destination")
	var path: PackedVector2Array=animals.yard.path(environment.circulation.endpoints.house,environment.circulation.endpoints.east_bank)
	expect(not path.is_empty(),"Actual animal navigation reaches the opposite bank")
	for i: int in path.size()-1: expect(animals.yard.clear_segment(path[i],path[i+1]),"Every crossing segment stays on supported unblocked ground")
	var hen: Dictionary=animals.interaction.find("YardHen1")
	animals.set_process(false)
	set_route(hen,animals.yard if region==null else region,a-direction*.4,b+direction*.65)
	expect(not hen.route.is_empty(),"Live hen gets a route across the bridge")
	var opposite: Dictionary={}
	var returned: bool=region==null
	if region!=null:
		opposite=animals.interaction.find("YardHen2")
		set_route(opposite,region,b+direction*.65,a-direction*.4)
		expect(not opposite.route.is_empty(),"Second hen gets an opposing route across the same bridge")
	var crossed: bool=false;var peak: float=-INF;var legal: bool=true;var pictured: bool=false
	var last_height: float=hen.node.position.y;var jump: float=0
	while scene.camera.is_transitioning(): await process_frame
	scene.focus_detail.set_depth_of_field(false);scene.camera.focus_point=Vector3(8.2,.4,0);scene.camera.view=Vector3(35,35,12)
	# Step the production actor and skeletal pose at 30 Hz, yielding rendered
	# frames throughout. Only destination and time source are controlled.
	for i: int in 1800:
		animals._process(1.0/30)
		legal=legal and hen.space.contains(hen.position)
		if not opposite.is_empty():
			legal=legal and opposite.space.contains(opposite.position) and hen.position.distance_to(opposite.position)>=hen.radius+opposite.radius-.005
			if opposite.position.distance_to(a-direction*.4)<.25:
				returned=true;opposite.route=PackedVector2Array();opposite.state="observe";opposite.timer=90.0
		peak=maxf(peak,hen.node.position.y)
		if i>0: jump=maxf(jump,absf(hen.node.position.y-last_height))
		last_height=hen.node.position.y
		if not pictured and hen.position.distance_to((a+b)*.5)<.3:
			await frames();await shot(label+"-hen-on-deck");pictured=true
			if label=="stone":
				scene.camera.view=Vector3(215,35,12);await frames();await shot(label+"-reverse")
				scene.camera.view=Vector3(35,35,12)
		if hen.position.distance_to(b+direction*.65)<.25:
			crossed=true;hen.route=PackedVector2Array();hen.state="observe";hen.timer=90.0
		if crossed and returned: break
		if i%60==0: await frames(1)
	print("HEN_CROSS ",label," crossed=",crossed," peak=",peak," jump=",jump," at=",hen.position)
	expect(jump<.12,"Bridge masonry joints do not drop the hen to ground level: "+label)
	expect(crossed and returned and legal and peak>.32,"Live hen crosses with feet rising onto the actual deck: "+label)
	expect(absf(animals.yard.ground_height(Vector2(12,-2))-ends[1].y)<.001,"Opposite bank keeps its own lower ground height")
	await shot(label+"-hen-arrived")
	var shapes: Array[PackedVector2Array]=[]
	for child: Node in environment.get_children():
		if child is Node3D: shapes.append_array(animals.water_shapes(child,plan))
	var crossing: PackedVector2Array=Passage.water_crossing(plan,shapes)
	expect(not crossing.is_empty(),"Actual banks, stones, boat and pillars leave a water crossing: "+label)
	if not crossing.is_empty():
		var goose: Dictionary=animals.interaction.find("LakeGoose1")
		set_route(goose,animals.water,crossing[0],crossing[1])
		var swam: bool=false;var passed_under: bool=false;var safe: bool=true
		var bridge: Node3D=environment.get_bridge()
		var deck: MeshInstance3D=bridge.find_children("*","MeshInstance3D",true,false)[0]
		var triangles: TriangleMesh=deck.mesh.generate_triangle_mesh()
		for i: int in 1000:
			animals._process(1.0/30)
			safe=safe and goose.space.contains(goose.position)
			var ray:=Vector3(goose.position.x,-.25,goose.position.y)
			var ceiling: Dictionary=triangles.intersect_segment(deck.to_local(ray),deck.to_local(ray+Vector3.UP*3))
			if not ceiling.is_empty():
				passed_under=true;safe=safe and deck.to_global(ceiling.position).y>=Passage.WATER_TOP-.001
				if i%30==0:
					scene.camera.focus_point=Vector3(goose.position.x,.05,goose.position.y);scene.camera.view=Vector3(8,15,7)
					await frames(2);await shot(label+"-goose-under")
			if goose.position.distance_to(crossing[1])<.25: swam=true;break
			if i%60==0: await frames(1)
		expect(swam and passed_under and safe,"Live goose swims under the bridge without entering low deck or pillars: "+label)
	# Leave the construction footprint free for the next style edit.
	if region==null:
		hen.position=hen.space.nearest(Vector2(0,4.8));hen.node.position=Vector3(hen.position.x,hen.space.ground_height(hen.position),hen.position.y);hen.route=PackedVector2Array();hen.state="observe"
	animals.set_process(true)

func ready_flock() -> bool:
	var started: int=Time.get_ticks_msec()
	while scene.island_builder._layout_check_pending():
		await process_frame
		if Time.get_ticks_msec()-started>20000: expect(false,"Cross-bank flock check finishes");return false
	var message: String=scene.island_builder.issue()
	expect(message.is_empty(),"Cross-bank flock accepted: "+message)
	return message.is_empty()

func flock_checks() -> void:
	var animals: Node=scene.get_node("Environment/CourtyardAnimals")
	var original: Dictionary=scene.farm_state.snapshot()
	original.animals.YardHen1.name="过桥鸡";original.animals.YardHen1.visits=3;original.animals.YardHen1.revision=3
	expect(scene.farm_state.restore_snapshot(original),"Named cross-bank hen fixture is valid");animals.interaction.profiles=original.animals.duplicate(true)
	var bird: Node3D=animals.interaction.find("YardHen1").node
	var blocker:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.16,.4,.16);blocker.mesh=box
	scene.add_child(blocker);blocker.position=Vector3(5.05,.3,-1.12);blocker.hide()
	expect(scene.decoration_layout.placement_issue(blocker,"bench","").contains("桥头"),"Later prop placement protects the full-width bridge exit")
	blocker.free()
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout;await choose_tool("hen")
	scene.camera.focus_point=Vector3(7,.13,0);scene.camera.view=Vector3(35,65,30);await frames(10)
	await drag(Vector3(4,.13,-2),Vector3(13,.13,2))
	if not await ready_flock() or not await apply(): return
	var builder: Node=scene.island_builder
	var saved: Dictionary=scene.farm_state.snapshot()
	expect(saved.layout.construction.flocks.hen.area==[4.0,-2.0,9.0,4.0],"Real drag saves a region spanning banks and bridge")
	expect(animals.interaction.find("YardHen1").node==bird and saved.animals.YardHen1.name=="过桥鸡","Cross-bank flock preserves the live bird and its identity")
	expect(not animals.flock_spaces.hen.contains(Vector2(8,1.8)),"Water inside the selection is never usable hen ground")
	await shot("region-preview-saved")
	await drag(Vector3(8,.13,0),Vector3(8,.13,1))
	builder.cancel_draft();await frames()
	expect(scene.farm_state.snapshot().layout==saved.layout and animals.preview_kind.is_empty(),"Cancelling region move restores saved cross-bank habitat")
	await click(builder._panel.find_child("DrawFlock",true,false))
	await drag(Vector3(7,.13,2),Vector3(9,.13,4))
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Open water still rejects a hen region")
	builder.cancel_draft();await frames()
	# Undo changes only the habitat, preserving later harvest and interaction.
	var later: Dictionary=scene.farm_state.snapshot();later.inventory.greens+=2;scene.farm_state.restore_snapshot(later);now+=120
	await click(builder._undo)
	while builder.busy: await process_frame
	expect(scene.courtyard_plan.construction.flocks.hen.area.is_empty() and scene.farm_state.snapshot().inventory==later.inventory,"Undo restores free range without reverting inventory")
	await drag(Vector3(4,.13,-2),Vector3(13,.13,2))
	if not await ready_flock() or not await apply(): return
	await click(builder._panel.find_child("Finish",true,false))
	await exercise_passage("stone-region",animals.flock_spaces.hen)
	await park_hens(animals)
	# Bridge replacement must retain the same region and rebuild its real floor.
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout;await choose_tool("bridge")
	scene.camera.focus_point=Vector3(4,.13,0);await frames(10)
	var ends: Array[Vector3]=Construction.bridge_points(scene.courtyard_plan)
	await drag(ends[1]+Vector3.UP*.12,Vector3(11,.13,.1))
	await drag(Construction.bridge_points(builder.candidate)[0]+Vector3.UP*.12,Vector3(5.4,.13,-.1))
	if not await ready_draft() or not await apply(): return
	await terrain_ready();await click(builder._panel.find_child("Finish",true,false))
	await exercise_passage("wood-region",animals.flock_spaces.hen)
	var stored: Dictionary=scene.farm_state.snapshot()
	var directory: String=scene.store.directory
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(directory);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	animals=scene.get_node("Environment/CourtyardAnimals")
	expect(scene.courtyard_plan.snapshot()==stored.layout and scene.farm_state.snapshot().animals.YardHen1==stored.animals.YardHen1,"Reopening preserves bridge, region and hen identity")
	var region: RefCounted=animals.flock_spaces.hen
	expect(not region.path(region.nearest(Vector2(5,-.1)),region.nearest(Vector2(11.7,.1))).is_empty(),"Reloaded flock region remains connected across both banks")

func park_hens(animals: Node) -> void:
	animals.set_process(false)
	var hens: Array[Dictionary]=[]
	for entry: Dictionary in animals.birds:
		if entry.kind=="hen": hens.append(entry)
	for i: int in hens.size(): set_route(hens[i],hens[i].space,hens[i].position,Vector2(12.1,.6+i*.8))
	var arrived: bool=false
	for step: int in 2100:
		animals._process(1.0/30)
		arrived=true
		for entry: Dictionary in hens:
			if entry.position.x<11.8: arrived=false
			else: entry.route=PackedVector2Array();entry.state="observe";entry.timer=90.0
		if arrived: break
		if step%60==0: await frames(1)
	expect(arrived,"Hens actually walk clear of the bridge before changing its structure")
	for entry: Dictionary in hens: entry.route=PackedVector2Array();entry.state="observe";entry.timer=30.0
	animals.set_process(true)
