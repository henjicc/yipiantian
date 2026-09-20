extends "res://../tests/construction_catalog_test.gd"
const Geometry = preload("res://presentation/decoration_geometry.gd")
const Decorations = preload("res://farm/decoration_state.gd")
const IslandSpace = preload("res://layout/island_space.gd")

func ground_point(id: String, minimum_z: float=6.5, away: Vector2=Vector2.INF) -> Vector2:
	var environment: Node3D=scene.get_node("Environment")
	var prop: Node3D=Geometry.build(environment,id);scene.add_child(prop)
	for z: float in [minimum_z,minimum_z+.5,minimum_z+1,minimum_z+1.5]:
		for x: float in [1,1.5,2,2.5,3,.5,0]:
			var point:=Vector2(x,z)
			if away.is_finite() and point.distance_to(away)<1.1: continue
			var entry: Dictionary={"slot_id":"","position":[x,z],"quarter_turn":0}
			Geometry.pose(prop,entry,environment.plan)
			if not scene.decoration_layout.placement_issue(prop,id,"").is_empty(): continue
			entry.quarter_turn=1;Geometry.pose(prop,entry,environment.plan)
			if not scene.decoration_layout.placement_issue(prop,id,"").is_empty(): continue
			var pixel: Vector2=scene.camera.unproject_position(Vector3(x,.13,z))
			if not root.get_visible_rect().grow(-15).has_point(pixel) or scene.island_builder._panel.get_global_rect().has_point(pixel): continue
			prop.free();return point
	prop.free();return Vector2.INF

func point3(point: Vector2) -> Vector3:
	return Vector3(point.x,scene.courtyard_plan.ground_height,point.y)

func motion(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	event.window_id=root.get_window_id()
	var started: int=Time.get_ticks_usec();root.push_input(event,true)
	print("FREE_PROP_POINTER_US ",Time.get_ticks_usec()-started)
	await frames()

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/free-decoration-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	await drag(Vector3(0,.13,6),Vector3(3,.13,8.5))
	if not await apply(): await finish();return
	var builder: Node=scene.island_builder
	var decor: Node=scene.decoration_layout
	var env: Node=scene.get_node("Environment")
	await choose_tool("bench")
	var a: Vector2=ground_point("bench")
	expect(a.is_finite(),"New land has a supported free bench position")
	if not a.is_finite(): await finish();return
	var a_screen: Vector2=scene.camera.unproject_position(point3(a))
	await mouse(a_screen,true)
	expect(decor.has_preview() and decor.preview_position.is_equal_approx(a),"Pressed pointer immediately previews a real mesh on free ground")
	var preview_id: int=decor._preview.get_instance_id()
	await motion(scene.camera.unproject_position(point3(a+Vector2(.05,.04))))
	expect(decor._preview.get_instance_id()==preview_id and decor.preview_position.is_equal_approx(a),"Grid drag reuses the same mesh and snaps to half metre positions")
	await mouse(a_screen,false)
	await click(builder._decoration_snap)
	await drag(point3(a),point3(a+Vector2(.07,.09)))
	expect(decor.preview_position.distance_to(a+Vector2(.07,.09))<.005,"Unsnapped pointer drag preserves free offsets")
	await click(builder._decoration_rotate)
	expect(decor.preview_turn==1 and absf(decor._preview.rotation.y-PI/2)<.001,"Rotation changes actual prop pose")
	var grab_at: Vector2=scene.camera.unproject_position(decor._preview.global_position+Vector3.UP*.43)
	var grab_pose: Transform3D=decor._preview.global_transform
	await mouse(grab_at,true);await mouse(grab_at,false)
	expect(decor._preview.global_transform.is_equal_approx(grab_pose),"Grabbing the visible seat of a preview does not jump its ground position")
	await shot("01-free-preview")
	root.size=Vector2i(960,640);await frames()
	expect(root.get_visible_rect().encloses(builder._panel.get_global_rect()),"Free placement controls fit the minimum window")
	await shot("01-small-window")
	root.size=Vector2i(1600,900);await frames()
	var pending: Vector2=decor.preview_position
	var before: Dictionary=scene.decoration_state.snapshot()
	expect(not env.get_node("ExpansionGrass").object_footprints.is_empty(),"Grass excludes the actual preview footprint immediately")
	var path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocked"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocked/child")
	await click(builder._confirm)
	expect(scene.decoration_state.snapshot()==before and decor.has_preview() and builder._status.text.contains("未能保存"),"Failed save keeps free draft available for retry")
	scene.store.directory=path
	var scene_id: int=scene.get_instance_id()
	preview_id=decor._preview.get_instance_id()
	var started: int=Time.get_ticks_usec();builder._commit()
	print("FREE_PROP_COMMIT_US ",Time.get_ticks_usec()-started)
	expect(scene.get_instance_id()==scene_id and not decor.has_preview() and decor._instances.bench.get_instance_id()==preview_id,"Successful save adopts the preview without rebuilding scene or prop")
	var entry: Dictionary=scene.decoration_state.snapshot().bench
	expect(entry.slot_id.is_empty() and Vector2(entry.position[0],entry.position[1]).distance_to(pending)<.001 and entry.quarter_turn==1,"Free pose becomes the durable placement")
	var committed: Transform3D=decor._instances.bench.global_transform
	var bench_id: int=decor._instances.bench.get_instance_id()
	var committed_grass: Dictionary=env.get_node("ExpansionGrass")._tile_shapes.duplicate(true)
	await frames(4)
	await choose_tool("bench")
	await drag(point3(pending),point3(pending+Vector2(.5,0)))
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(not decor.has_preview() and decor._instances.bench.visible and decor._instances.bench.global_transform==committed,"Focus loss restores committed free position")
	expect(env.get_node("ExpansionGrass")._tile_shapes==committed_grass,"Cancelling restores the original grass distribution after local tile updates")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await choose_tool("bench")
	await drag(point3(Vector2(20,20)),point3(Vector2(20,20)))
	# Direct boundary preview covers support rejection even if the distant point projects outside the viewport.
	decor.preview_on_ground(Vector2(20,20));decor.confirm_preview()
	expect(decor.has_preview() and scene.decoration_state.snapshot().bench==entry and decor._message.contains("平地"),"Unsupported free placement cannot save")
	builder.cancel_draft()
	var route: PackedVector3Array=env.plan.paths[0]
	var midpoint: Vector3=route[0].lerp(route[1],.5)
	decor.preview_on_ground(Vector2(midpoint.x,midpoint.z));decor.confirm_preview()
	expect(decor.has_preview() and scene.decoration_state.snapshot().bench==entry and not decor.placement_issue(decor._preview,"bench","").is_empty(),"Free placement cannot cover an existing route")
	builder.cancel_draft()
	var fixture: Dictionary=scene.farm_state.snapshot()
	fixture.harvested.greens=20;fixture.harvested.radish=20;fixture.harvested.spinach=20
	scene.farm_state.restore_snapshot(fixture);scene.decoration_state.unlock(fixture.harvested);scene._save_farm()
	await choose_tool("flowerpot")
	var b: Vector2=ground_point("flowerpot",6.5,pending)
	expect(b.is_finite(),"A second free prop has a separate supported footprint")
	if not b.is_finite(): await finish();return
	await drag(point3(b),point3(b));await click(builder._confirm)
	expect(Decorations.is_placed(scene.decoration_state.snapshot().flowerpot) and decor._instances.bench.get_instance_id()==bench_id,"Adding another prop preserves the bench instance")
	await choose_tool("flowerpot")
	decor.preview_on_ground(pending);decor.confirm_preview()
	expect(decor.has_preview() and decor._message.contains("其他摆件"),"Free collision protects another player placed prop")
	builder.cancel_draft()
	now+=3600;scene.settle_farm();var farm_after: Dictionary=scene.farm_state.snapshot()
	await click(builder._undo)
	expect(not Decorations.is_placed(scene.decoration_state.snapshot().flowerpot) and scene.decoration_state.snapshot().bench==entry,"Undo removes only the last placement")
	expect(scene.farm_state.snapshot().inventory==farm_after.inventory and scene.farm_state.snapshot().fields==farm_after.fields,"Undo leaves current inventory and crop progress intact")
	scene.atmosphere.set_preview_hour(22)
	if not await place_at_visible_slot("lantern",["hanging_01","hanging_02","hanging_03","hanging_04"]): await finish();return
	var light: OmniLight3D=decor._preview.get_node("FarmLanternLight")
	expect(light.light_energy>0 and light.get_parent()==decor._preview,"Preview lamp lights its actual hanging position at night")
	var lamp_id: int=decor._preview.get_instance_id();var light_id: int=light.get_instance_id()
	await click(builder._decoration_rotate)
	expect(decor.preview_turn==1 and decor._preview.get_instance_id()==lamp_id and decor._preview.get_node("FarmLanternLight").get_instance_id()==light_id,"Lamp rotation keeps the actual light attached to the same preview")
	var hooks: Array[String]=["hanging_01","hanging_02","hanging_03","hanging_04"]
	for hook: String in hooks:
		if hook==decor.preview_slot or not decor._rings[hook].visible: continue
		var from: Vector2=scene.camera.unproject_position(decor._rings[decor.preview_slot].global_position)
		var to: Vector2=scene.camera.unproject_position(decor._rings[hook].global_position)
		await mouse(from,true);await motion(to);await mouse(to,false)
		expect(decor.preview_slot==hook and light.global_position.is_equal_approx(env.get_slot_marker(hook).global_position+Vector3(0,-.22,0)),"Dragging between hooks moves the existing preview light with its lamp")
		break
	await shot("02-lantern-preview")
	await click(builder._panel.find_child("Finish",true,false))
	expect(not builder.active and not decor.active and decor._instances.bench.get_instance_id()==bench_id,"Finish exits immediately and preserves unrelated props")
	var saved: Dictionary=scene.decoration_state.snapshot()
	expect(Store.new(path).load_state().decorations==saved,"Saved free coordinates survive JSON exactly")
	await shot("03-finished")
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(6)
	expect(scene.decoration_state.snapshot()==saved and scene.decoration_layout._instances.bench.global_transform.is_equal_approx(committed),"Actual reopened scene restores the free pose")
	var polygon: PackedVector2Array=scene.decoration_layout.ground_footprints().decoration_bench
	var routes_clear: bool=true
	for points: PackedVector3Array in scene.courtyard_plan.paths:
		for p: Vector3 in points:
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon): routes_clear=false
	expect(routes_clear,"Reopened procedural paths avoid saved free furniture")
	expect(not scene.get_node("Environment/ExpansionGrass").object_footprints.is_empty(),"Reopened grass retains saved prop exclusions")
	scene.atmosphere.set_preview_hour(11);await frames();await shot("04-reopened")
	scene.camera.focus_point=scene.decoration_layout._instances.bench.global_position+Vector3.UP*.2
	for side: int in 2:
		scene.camera.view=Vector3(20+180*side,35,4.5)
		await frames(8);await shot("05-bench-side-%d"%side)
	await finish()
