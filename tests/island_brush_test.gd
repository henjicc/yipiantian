extends "res://../tests/island_construction_test.gd"

func move_world(point: Vector3) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=scene.camera.unproject_position(point);event.window_id=root.get_window_id()
	event.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true);await frames(2)

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/island-brush-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	var before: Vector3=scene.camera.view
	await click(scene.hud.get_node("Layout/BuildIsland"))
	expect(scene.camera.is_transitioning(),"Entry uses an active camera transition")
	expect(scene.camera.view.y>before.y and scene.camera.view.y<65,"Intermediate view is between overview and overhead")
	await shot("01-camera-moving")
	await create_timer(1).timeout
	expect(is_equal_approx(scene.camera.view.y,65),"Camera settles at overhead construction angle")
	await shot("02-overhead")
	var original: Dictionary=scene.farm_state.snapshot()
	var plants: Array[Vector3]=scene.get_node("Environment")._floater_origins.duplicate()
	await mouse(scene.camera.unproject_position(Vector3(0,.13,6)),true)
	await move_world(Vector3(0,.13,7))
	var first: Dictionary=scene.island_builder.draft.duplicate(true)
	expect(first.construction.land.size()>1,"Held brush grows a continuous stroke before release")
	expect(is_instance_valid(scene.island_builder._shore) and not scene.get_node("Environment/MainBank").visible,"Actual bank mesh is shown during drag")
	await shot("03-held-growing")
	var start: int=Time.get_ticks_msec()
	await move_world(Vector3(0,.13,8.5))
	await move_world(Vector3(2.5,.13,8.5))
	print("BRUSH_TWO_MOVES_MS ",Time.get_ticks_msec()-start)
	var brush: Node=scene.island_builder
	expect(brush.draft.construction.land.size()>first.construction.land.size(),"Turning retains earlier painted land")
	expect(Geometry2D.is_point_in_polygon(Vector2(0,7),brush.candidate.rim) and Geometry2D.is_point_in_polygon(Vector2(2,8.5),brush.candidate.rim),"Stroke follows both legs of an L")
	expect(scene.get_node("Environment")._floater_origins!=plants,"Nearby lotus clumps move before mouse release")
	expect(scene.farm_state.snapshot()==original,"Unconfirmed stroke leaves authority unchanged")
	expect(brush._shore._surfaces[0].mesh!=null,"Continuous shore triangulates")
	await shot("04-held-foliage")
	brush._focus_lost();await frames()
	expect(brush.draft==original.layout,"Focus loss cancels unfinished stroke")
	expect(scene.get_node("Environment")._floater_origins==plants,"Focus loss restores the exact plant anchors")
	expect(scene.get_node("Environment/MainBank").visible,"Cancelling restores original bank")
	await mouse(scene.camera.unproject_position(Vector3(2.5,.13,8.5)),false)
	await drag(Vector3(15,.13,12),Vector3(16,.13,12))
	expect(brush.draft==original.layout,"Starting in isolated water cannot create detached land")
	await drag(Vector3(0,.13,6),Vector3(0,.13,8.5))
	await drag(Vector3(0,.13,8.5),Vector3(2.5,.13,8.5))
	var persisted: Dictionary=brush.candidate.snapshot()
	var planned_plants: Array[Vector3]=brush.candidate.lily_coves.duplicate()
	await shot("05-brush-ready")
	var house_id: int=scene.get_node("Environment/MainHouse").get_instance_id()
	var grass: Node3D=brush._shore._grass
	expect(grass.get_child_count()>0,"Grass is visible before saving")
	var grass_tiles: Dictionary=grass._tiles.duplicate()
	start=Time.get_ticks_msec()
	await click(brush._panel.find_child("Finish",true,false))
	var elapsed: int=Time.get_ticks_msec()-start
	print("FINISH_INPUT_MS ",elapsed)
	expect(elapsed<700 and not brush.active,"Finish saves and closes without a scene reload")
	expect(scene.get_node("Environment/MainHouse").get_instance_id()==house_id,"Existing scene objects are retained")
	expect(scene.get_node("Environment/ExpansionGrass")._tiles==grass_tiles,"Visible preview grass tiles become final grass without regeneration")
	expect(scene.courtyard_plan.snapshot()==persisted,"Finish persists the painted shape")
	expect(scene.courtyard_plan.lily_coves==planned_plants,"Confirmed plants match the live candidate")
	expect(scene.farm_state.snapshot().fields==original.fields,"Painting retains every crop")
	for span: Dictionary in scene.courtyard_plan.fences:
		expect(span.a.z<6.8 and span.b.z<6.8,"No fence is generated on the new land")
	var refresh_start: int=Time.get_ticks_msec()
	var previous_frame: int=refresh_start
	var max_frame: int=0
	while scene.get_node("Environment")._terrain_refreshing:
		await process_frame
		var now: int=Time.get_ticks_msec()
		max_frame=maxi(max_frame,now-previous_frame);previous_frame=now
		if now-refresh_start>30000: expect(false,"Terrain refresh completes");break
	print("REFRESH_MS ",Time.get_ticks_msec()-refresh_start," MAX_FRAME_MS ",max_frame)
	expect(max_frame<250,"Background shore updates do not stall a frame")
	expect(not scene.get_node("Environment/CourtyardAnimals").water.contains(Vector2(0,8)),"Animals cannot swim through painted land")
	await shot("06-saved")
	scene._begin_construction("land");await create_timer(1).timeout
	await drag(Vector3(2.5,.13,8.5),Vector3(4,.13,8.5))
	var second: Dictionary=brush.candidate.snapshot()
	var normal_path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	await click(brush._panel.find_child("Finish",true,false))
	expect(brush.active and not brush.busy and brush._status.text.contains("未能保存"),"Failed Finish keeps the draft open and retryable")
	expect(scene.farm_state.snapshot().layout==persisted,"Failed Finish leaves authoritative land unchanged")
	scene.store.directory=normal_path
	await click(brush._panel.find_child("Finish",true,false))
	expect(not brush.active and scene.farm_state.snapshot().layout==second,"Retry saves exactly the requested second stroke")
	# Undo while the previous background refresh is still pending: late results
	# must not overwrite the latest shoreline or navigation.
	scene._begin_construction("land");await create_timer(1).timeout
	await click(brush._undo)
	expect(scene.farm_state.snapshot().layout==persisted,"Undo restores the first painted shape in place")
	expect(scene.get_node("Environment/MainHouse").get_instance_id()==house_id,"Undo also retains the scene")
	brush.finish()
	refresh_start=Time.get_ticks_msec()
	while scene.get_node("Environment")._terrain_refreshing:
		await process_frame
		if Time.get_ticks_msec()-refresh_start>30000: expect(false,"Latest background refresh completes");break
	expect(scene.get_node("Environment/CourtyardAnimals").ready_for_motion,"Animals resume after the latest terrain refresh")
	var restored: Dictionary=Store.new(normal_path).load_state()
	expect(restored.ok and restored.farm.layout==persisted,"Undo is durable on disk")
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(normal_path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene;await frames(6)
	expect(scene.courtyard_plan.snapshot()==persisted,"Reopening restores the same painted island")
	expect(scene.get_node("Environment/ExpansionGrass").get_child_count()>0,"Reopening retains new-land grass")
	for span: Dictionary in scene.courtyard_plan.fences:
		expect(span.a.z<6.8 and span.b.z<6.8,"Reopening does not generate extension fences")
	await shot("07-reopened")
	print("BRUSH_EVIDENCE "+folder)
	await finish()
