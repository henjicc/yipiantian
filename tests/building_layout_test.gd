extends "res://../tests/island_construction_test.gd"
const Buildings=preload("res://layout/building_layout.gd")
const Space=preload("res://layout/island_space.gd")
var now: float=2000000.0

func ready_draft() -> bool:
	var started: int=Time.get_ticks_msec()
	while is_instance_valid(scene.island_builder.building_preview) and scene.island_builder.building_preview.pending:
		await process_frame
		if Time.get_ticks_msec()-started>25000: expect(false,"Building route validation finishes");return false
	var message: String=scene.island_builder.issue()
	if not message.is_empty() and is_instance_valid(scene.island_builder.building_preview):
		var preview: Node3D=scene.island_builder.building_preview
		for key: String in preview._obstacles:
			if Space.overlaps(preview.footprint,preview._obstacles[key]): print("BUILDING_NEAR ",key)
	expect(message.is_empty(),"Building draft accepted: "+message)
	return message.is_empty()

func motion(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	event.window_id=root.get_window_id()
	var started: int=Time.get_ticks_usec();root.push_input(event,true)
	print("BUILDING_POINTER_US ",Time.get_ticks_usec()-started);await frames()

func draft_at(id: String, at: Vector3, yaw: float=0) -> void:
	var builder: Node=scene.island_builder
	builder.draft.construction.buildings[id]=[at.x,at.z,yaw];builder._refresh();await frames()

func grass_inside(nodes: Array, polygon: PackedVector2Array) -> bool:
	for node: Node in nodes:
		var meshes: Array[Node]=node.find_children("*","MeshInstance3D",true,false)
		if node is MeshInstance3D: meshes.push_front(node)
		for mesh: MeshInstance3D in meshes:
			for surface: int in mesh.mesh.get_surface_count():
				for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var world: Vector3=mesh.global_transform*vertex
					if Geometry2D.is_point_in_polygon(Vector2(world.x,world.z),polygon): return true
	return false

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/building-layout-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var plan:=Plan.new()
	var construction: Dictionary=Construction.initial()
	construction.land=[[-5,4,5,5],[0,4,5,5],[-5,8,5,5],[0,8,5,5],[-9,3,5,5],[-9,7,5,5]]
	construction.land.append_array([[-5,12,5,3],[0,12,5,3],[4,4,3,5],[4,8,3,5],[4,12,3,3],[-10,3,5,5],[-10,7,5,5]])
	plan.apply_construction(construction)
	expect(Plan.from_snapshot(plan.snapshot())!=null,"Connected expanded island supports fixture")
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=plan
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	var fixture: Dictionary=scene.farm_state.snapshot()
	fixture.kitchen.stock.leaf_stir=1;fixture.kitchen.records.leaf_stir.made=1;fixture.kitchen.records.leaf_stir.last_crop="greens";fixture.kitchen.display="leaf_stir"
	fixture.kitchen.jobs.rack={"recipe":"root_dry","crop":"radish","start_utc":now,"finish_utc":now+90}
	expect(scene.farm_state.restore_snapshot(fixture),"Food fixture is valid durable kitchen state")
	scene.refresh_farm()
	scene.kitchen_display.refresh(fixture.kitchen);await frames(12)
	var decor: Dictionary=scene.decoration_state.snapshot()
	decor.lantern={"unlocked":true,"slot_id":"hanging_01","quarter_turn":1,"position":[]}
	expect(scene.decoration_state.restore_snapshot(decor),"Fixture has an attached house lantern")
	scene.decoration_layout.refresh_confirmed()
	var original: Dictionary=scene.farm_state.snapshot()
	var env: Node3D=scene.get_node("Environment")
	var house: Node3D=env.get_node("MainHouse")
	var porch: Node3D=env.get_node("PorchDeck")
	var tools: Node3D=env.get_node("DoorTools")
	var water_tool: Node3D=tools.tools.water
	var food: Node3D=scene.kitchen_display._contents.table
	var lamp: Node3D=scene.decoration_layout._instances.lantern
	var poses: Dictionary={"house":house.global_transform,"porch":porch.global_transform,"water":water_tool.global_transform,"food":food.global_transform}
	var instance_ids: Array=[scene.get_instance_id(),house.get_instance_id(),water_tool.get_instance_id(),food.get_instance_id(),env.get_node("CourtyardAnimals").get_instance_id()]
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	scene.camera.zoom(6);await create_timer(.6).timeout
	await choose_tool("house")
	var builder: Node=scene.island_builder
	expect(builder.tool=="house" and builder._building_actions.visible,"House catalog opens placement controls")
	if OS.get_cmdline_user_args().has("--edges-only"):
		await edge_checks(builder,poses.house);await finish();return
	await shot("00-original")
	var grab: Vector3=house.global_position+Vector3(0,2.4,0)
	var pointer: Vector2=builder.world_point(scene.camera.unproject_position(grab))
	var target:=Vector3(pointer.x,plan.ground_height,pointer.y+13.5)
	await mouse(scene.camera.unproject_position(grab),true)
	expect(builder._start.is_finite(),"Actual roof click grabs house")
	await motion(scene.camera.unproject_position(target))
	expect(house.global_position.distance_to(poses.house.origin)>10,"House moves before mouse release")
	var delta: Transform3D=house.global_transform*poses.house.affine_inverse()
	expect(porch.global_transform.is_equal_approx(delta*poses.porch) and water_tool.global_transform.is_equal_approx(delta*poses.water),"Porch and original usable tools follow live house")
	expect(food.global_transform.is_equal_approx(delta*poses.food),"Actual displayed dish follows its live table")
	expect(not lamp.visible and scene.decoration_layout._attachment_previews.lantern.global_position.is_equal_approx(builder.candidate.slots.hanging_01),"Attached lantern follows moved hook before release")
	expect(scene.farm_state.snapshot()==original,"Live move leaves crop and kitchen authority unchanged")
	await mouse(scene.camera.unproject_position(target),false)
	await click(builder._building_actions.get_node("RotateBuilding"))
	expect(builder.candidate.angles.house==15,"Rotation button turns entire house assembly")
	if not await ready_draft(): await shot("failure-house");await finish();return
	var clear_ground: PackedVector2Array=Geometry2D.offset_polygon(builder.building_preview._obstacles.MainHouse,-.2)[0]
	expect(not grass_inside([builder.building_preview.core,builder.building_preview.expansion],clear_ground),"Live grass stays outside the moved foundation")
	await shot("01-house-live")
	await click(builder._building_snap)
	grab=house.global_position+Vector3.UP*2.4
	await drag(grab,grab+Vector3(.15,0,0))
	expect(absf(builder.candidate.anchors.house.x-.8)<.001,"Free movement keeps sub-grid displacement")
	if not await ready_draft(): await finish();return
	await click(builder._panel.find_child("Cancel",true,false))
	expect(house.global_transform.is_equal_approx(poses.house) and food.global_transform.is_equal_approx(poses.food) and lamp.visible,"Cancel restores real assembly, food and lamp")
	await draft_at("house",Vector3(0,.13,1))
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Occupied crop area rejects the building")
	await draft_at("house",Vector3(17,.13,14))
	expect(builder.issue().contains("陆地") and builder._confirm.disabled,"Unsupported building footprint is rejected")
	await draft_at("house",Vector3(.8,.13,8.85),15)
	if not await ready_draft(): await finish();return
	var path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocked"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocked/child")
	await click(builder._confirm)
	expect(scene.farm_state.snapshot()==original and is_instance_valid(builder.building_preview) and builder._status.text.contains("未能保存"),"Failed save preserves authoritative state and retryable preview")
	scene.store.directory=path
	if not await apply(): await finish();return
	expect([scene.get_instance_id(),house.get_instance_id(),water_tool.get_instance_id(),food.get_instance_id(),env.get_node("CourtyardAnimals").get_instance_id()]==instance_ids,"Saving keeps main scene, house, tools, food and animals alive")
	expect(scene.farm_state.snapshot().kitchen==original.kitchen and scene.farm_state.snapshot().fields==original.fields,"Building save preserves kitchen jobs and crops")
	expect(env.circulation.issues.is_empty() and env.circulation.endpoints.house.y>10,"Moved entrance remains connected to actual paths")
	for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
		expect(mesh.gi_mode==GeometryInstance3D.GI_MODE_STATIC,"Committed house restores indirect-light geometry")
	await shot("02-house-saved")
	await choose_tool("kitchen")
	var kitchen: Node3D=env.get_node("Kitchen")
	var kitchen_pose: Transform3D=kitchen.global_transform
	var rack: Node3D=env.get_node("LivingDetails/SidePorchDryingRack")
	var rack_pose: Transform3D=rack.global_transform
	var drying_food: Node3D=scene.kitchen_display._contents.rack
	var drying_pose: Transform3D=drying_food.global_transform
	grab=kitchen.global_position+Vector3.UP*1.8
	pointer=builder.world_point(scene.camera.unproject_position(grab))
	await drag(grab,Vector3(pointer.x-2.5,plan.ground_height,pointer.y+13))
	expect(builder.candidate.anchors.kitchen.is_equal_approx(Vector3(-7,.115,8)),"Actual kitchen roof drag moves its assembly")
	await draft_at("kitchen",Vector3(-7,.115,8),-15)
	if not await ready_draft(): await shot("failure-kitchen");await finish();return
	delta=kitchen.global_transform*kitchen_pose.affine_inverse()
	expect(rack.global_transform.is_equal_approx(delta*rack_pose) and drying_food.global_transform.is_equal_approx(delta*drying_pose),"Kitchen carries drying rack and in-progress food")
	if not await apply(): await finish();return
	var saved: Dictionary=scene.farm_state.snapshot()
	var moved_house: Transform3D=house.global_transform
	var moved_kitchen: Transform3D=kitchen.global_transform
	var moved_water: Transform3D=water_tool.global_transform
	var moved_dish: Transform3D=food.global_transform
	await shot("03-kitchen-saved")
	await click(builder._undo)
	while builder.busy: await process_frame
	expect(scene.farm_state.snapshot().layout.construction.buildings.kitchen.is_empty(),"Undo commits the original kitchen pose: "+builder._status.text)
	expect(kitchen.global_transform.is_equal_approx(kitchen_pose) and house.global_transform.is_equal_approx(moved_house),"Undo restores only latest building")
	expect(scene.farm_state.snapshot().kitchen==original.kitchen,"Undo does not rewind kitchen state")
	await draft_at("kitchen",Vector3(-7,.115,8),-15)
	expect(builder.building_preview.pending,"Finish is requested while route check is pending")
	var started: int=Time.get_ticks_msec()
	await click(builder._panel.find_child("Finish",true,false))
	while builder.busy:
		await process_frame
		if Time.get_ticks_msec()-started>20000: expect(false,"Pending finish completes in bounded time");break
	print("BUILDING_PENDING_FINISH_MS ",Time.get_ticks_msec()-started)
	expect(not builder.active,"Finish exits building mode")
	expect(scene.farm_state.snapshot().layout==saved.layout,"One pending Finish click saves the final building pose")
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(20)
	expect(scene.farm_state.snapshot().layout==saved.layout,"Reopen retains exact building parameters")
	expect(scene.get_node("Environment/MainHouse").global_transform.is_equal_approx(moved_house) and scene.get_node("Environment/Kitchen").global_transform.is_equal_approx(moved_kitchen),"Reopen restores both actual building poses")
	expect(scene.get_node("Environment/DoorTools").tools.water.global_transform.is_equal_approx(moved_water),"Reopen reconstructs tools at saved porch")
	expect(scene.kitchen_display._contents.table.global_transform.is_equal_approx(moved_dish),"Reopen reconstructs food at saved table")
	scene.atmosphere.set_preview_hour(23);await frames(8);await shot("04-night-reopened")
	lamp=scene.decoration_layout._instances.lantern
	var light: OmniLight3D=lamp.get_node("FarmLanternLight")
	expect(light.visible and light.light_energy>0 and light.global_position.distance_to(scene.courtyard_plan.slots.hanging_01-Vector3.UP*.22)<.001,"Night lantern illuminates the moved hook")
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout;await choose_tool("kitchen")
	var kitchen_at: Vector3=scene.get_node("Environment/Kitchen").global_position+Vector3.UP*1.8
	expect(scene._scene_entry_at(scene.camera.unproject_position(kitchen_at))=="stove","Moved kitchen retains its actual scene entrance")
	root.size=Vector2i(960,640);await frames();await shot("05-small-window")
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Building controls fit minimum window")
	var focus_before: Vector3=scene.camera.focus_point
	scene.camera.drag(Vector2(0,-150),true)
	expect(scene.camera.focus_point.z>focus_before.z+2,"Construction camera can pan beyond the original courtyard")
	await finish()

func edge_checks(builder: Node, original_house: Transform3D) -> void:
	var env: Node3D=scene.get_node("Environment")
	var house: Node3D=env.get_node("MainHouse")
	var roof: Vector2=scene.camera.unproject_position(house.global_position+Vector3.UP*2.4)
	await mouse(roof,true);await mouse(roof,false)
	expect(builder.draft==scene.farm_state.snapshot().layout and not is_instance_valid(builder.building_preview),"A stationary roof click does not create a building edit")
	var pose: Transform3D=Buildings.pose(builder.candidate,"house")
	await drag(builder._building_handle(builder.candidate),Transform3D(Basis(Vector3.UP,deg_to_rad(15)),pose.origin)*Vector3(0,.08,4.3))
	expect(builder.candidate.angles.house==15,"Actual outer handle rotates building")
	builder.cancel_draft();await frames()
	var grab: Vector3=house.global_position+Vector3.UP*2.4
	await mouse(scene.camera.unproject_position(grab),true)
	var pointer: Vector2=builder.world_point(scene.camera.unproject_position(grab))
	await motion(scene.camera.unproject_position(Vector3(pointer.x,scene.courtyard_plan.ground_height,pointer.y+13.5)))
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT);await frames()
	expect(house.global_transform.is_equal_approx(original_house) and builder.draft==scene.farm_state.snapshot().layout,"Focus loss restores an unfinished building drag")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await draft_at("house",Vector3(.8,.13,8.85),15)
	expect(builder.building_preview.pending,"Fresh move schedules a background check")
	builder.cancel_draft();await choose_tool("kitchen")
	await draft_at("kitchen",Vector3(-7,.115,8),-15)
	if not await ready_draft(): return
	expect(house.global_transform.is_equal_approx(original_house) and env.get_node("Kitchen").position.is_equal_approx(Vector3(-7,.115,8)),"Retired house check cannot overwrite a newer kitchen preview")
	builder.cancel_draft();await choose_tool("house")
	await draft_at("house",Vector3(.8,.13,8.85),15)
	if not await ready_draft(): return
	if not await apply(): return
	var farm: Dictionary=scene.farm_state.snapshot()
	now+=45
	await click(builder._undo)
	while builder.busy: await process_frame
	expect(scene.farm_state.snapshot().layout.construction.buildings.house.is_empty() and house.global_transform.is_equal_approx(original_house),"House undo restores authored assembly and commits it: "+builder._status.text)
	if not scene.farm_state.snapshot().layout.construction.buildings.house.is_empty(): return
	expect(scene.farm_state.snapshot().inventory==farm.inventory and scene.farm_state.snapshot().kitchen==farm.kitchen,"Undo preserves inventory and running kitchen jobs after time advances")
	await draft_at("house",Vector3(.8,.13,8.85),15)
	if not await ready_draft(): return
	var clear_ground: PackedVector2Array=Geometry2D.offset_polygon(builder.building_preview._obstacles.MainHouse,-.2)[0]
	if not await apply(): return
	await choose_tool("land")
	await drag(Vector3(-8,.13,11),Vector3(-8,.13,13))
	expect(builder.draft.construction.land.size()>scene.farm_state.snapshot().layout.construction.land.size(),"Real brush adds land after moving a house")
	expect(not grass_inside(builder._shore._grass._tiles.values(),clear_ground),"Later land preview keeps grass outside moved house")
	if not await apply(): return
	expect(not grass_inside([env.get_node("ExpansionGrass")],clear_ground),"Later land save preserves building grass exclusion")
	var decorations: Dictionary=scene.decoration_state.snapshot();decorations.bench.unlocked=true
	expect(scene.decoration_state.restore_snapshot(decorations),"Bench fixture unlocked")
	scene.decoration_layout.refresh_confirmed();await choose_tool("bench")
	scene.decoration_layout.preview_on_ground(Vector2(-7,8));scene.decoration_layout.confirm_preview();await frames()
	expect(scene.decoration_state.snapshot().bench.position==[-7.0,8.0],"A separate player bench can be placed after the building move")
	expect(not grass_inside([env.get_node("ExpansionGrass")],clear_ground),"Prop-driven grass refresh retains building exclusion")
	await choose_tool("kitchen");await draft_at("kitchen",Vector3(-7,.115,8),-15)
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Building cannot displace the player's bench")
	builder.cancel_draft();await click(builder._panel.find_child("Finish",true,false));await create_timer(1).timeout
	var tool: Node3D=env.get_node("DoorTools").tools.water
	var point: Vector2=scene.camera.unproject_position(tool.global_position+Vector3.UP*.18)
	var hover:=InputEventMouseMotion.new();hover.position=point;root.push_input(hover,true);await frames()
	await mouse(point,true);await mouse(point,false)
	expect(scene.selected_tool=="water","Actual click on moved bucket still selects watering")
	scene._cancel_tool();scene.focus_detail.set_quality("high");scene.atmosphere.set_preview_hour(23);await frames(12)
	await shot("06-building-high-night")
