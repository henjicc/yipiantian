extends "res://../tests/island_brush_test.gd"
const Support=preload("res://layout/land_support.gd")

func wait_for_terrain() -> void:
	await frames()
	var started: int=Time.get_ticks_msec()
	while scene.get_node("Environment")._terrain_refreshing:
		await process_frame
		if Time.get_ticks_msec()-started>30000: expect(false,"Latest terrain navigation completes");return
	expect(scene.get_node("Environment/CourtyardAnimals").ready_for_motion,"Animals resume on latest terrain")

func close_shore(label: String) -> void:
	var view: Vector3=scene.camera.view;var point: Vector3=scene.camera.focus_point
	scene.camera.focus_point=Vector3(.3,.13,-7.5);scene.camera.view=Vector3(190,40,13)
	await frames(8);await shot(label+"-back")
	scene.camera.view=Vector3(250,45,13);await frames(8);await shot(label+"-side")
	scene.camera.view=view;scene.camera.focus_point=point;await frames()

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/island-shrink-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	var brush: Node=scene.island_builder
	await click(brush._panel.find_child("LandErase",true,false))
	var before: Dictionary=scene.farm_state.snapshot()
	var world:=Vector3(0,.13,-8.5)
	var core_before: Dictionary=scene.get_node("Environment/GroundCover/CoreGrass")._tile_shapes.duplicate(true)
	await mouse(scene.camera.unproject_position(world),true)
	await move_world(world+Vector3(.5,0,0))
	expect(brush.draft!=before.layout and not brush.draft.construction.land.is_empty(),"Held erase stroke trims original land immediately")
	if brush.draft==before.layout: await finish();return
	expect(scene.farm_state.snapshot()==before,"Held erase never publishes a partial state")
	expect(scene.get_node("Environment/CourtyardAnimals").preview_kind=="hen","Ground animals cannot walk onto pending removed ground")
	await shot("01-held-shrinking")
	await close_shore("01-held-shore")
	brush._focus_lost();await frames()
	expect(brush.draft==before.layout and scene.get_node("Environment/MainBank").visible,"Focus loss restores authored shore")
	expect(scene.get_node("Environment/GroundCover/CoreGrass").visible and scene.get_node("Environment/GroundCover/CoreGrass")._tile_shapes==core_before,"Cancelling restores exact original core grass")
	expect(scene.get_node("Environment/CourtyardAnimals").preview_kind.is_empty(),"Cancelling restores animal motion")
	await mouse(scene.camera.unproject_position(world),false)
	await drag(Vector3(6.5,.13,0),Vector3(6,.13,0))
	expect(brush.draft==before.layout and not brush._brush_message.is_empty(),"Dragging across occupied bridge approach cannot erase its support")
	await shot("02-bridge-protected")
	await click(brush._panel.find_child("Cancel",true,false))
	await drag(world,world+Vector3(.5,0,0))
	var trimmed: Dictionary=brush.candidate.snapshot()
	expect(brush.issue().is_empty(),"Safe trimmed shore can be confirmed")
	var house_id: int=scene.get_node("Environment/MainHouse").get_instance_id()
	var core_id: int=brush._shore._core.get_instance_id()
	var normal_path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocked"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocked/child")
	await click(brush._panel.find_child("Finish",true,false))
	expect(brush.active and not brush.busy and brush._status.text.contains("未能保存"),"Actual write failure leaves erase preview retryable")
	expect(scene.farm_state.snapshot()==before,"Failed erase keeps every original crop and layout authoritative")
	scene.store.directory=normal_path
	var started: int=Time.get_ticks_msec()
	await click(brush._panel.find_child("Finish",true,false))
	print("SHRINK_FINISH_INPUT_MS ",Time.get_ticks_msec()-started)
	expect(not brush.active and scene.farm_state.snapshot().layout==trimmed,"Finish saves trimmed island without a reload")
	expect(scene.get_node("Environment/MainHouse").get_instance_id()==house_id and scene.get_node("Environment/GroundCover/CoreGrass").get_instance_id()==core_id,"Actual core grass preview is adopted in place")
	await create_timer(1).timeout
	await close_shore("03-saved-shore")
	# A real state action after construction; undo must not restore its old stock.
	scene.clock=func() -> float: return 2000060.0
	expect(scene.farm_state.harvest("field_03","cell_06",2000060).ok,"Opening crop is still harvestable after shrinking")
	scene.refresh_farm();expect(scene._save_farm(),"Later harvest is durable")
	var harvest: Dictionary=scene.farm_state.snapshot()
	scene._begin_construction("land");await create_timer(1).timeout
	await click(brush._undo)
	expect(scene.farm_state.snapshot().layout==before.layout,"Undo restores the authored shoreline")
	expect(scene.farm_state.snapshot().inventory==harvest.inventory and scene.farm_state.snapshot().fields==harvest.fields,"Undo does not roll back later harvest or crop time")
	await drag(world,world+Vector3(.5,0,0))
	await click(brush._panel.find_child("Finish",true,false))
	expect(scene.farm_state.snapshot().layout==trimmed,"Shrink can be applied again after undo")
	await wait_for_terrain()
	var restored: Dictionary=Store.new(normal_path).load_state()
	expect(restored.ok and restored.farm.layout==trimmed and restored.farm.inventory==harvest.inventory,"Disk contains the final cut and later harvest")
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(normal_path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return 2000060.0
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.courtyard_plan.snapshot()==trimmed,"Reopening reconstructs the same authored-island cut")
	expect(scene.farm_state.snapshot().inventory==harvest.inventory,"Reopening keeps harvested food")
	await close_shore("04-reopened-shore")
	scene._begin_construction("land");await create_timer(1).timeout
	brush=scene.island_builder
	await click(brush._panel.find_child("LandAdd",true,false))
	await drag(Vector3(0,.13,6),Vector3(0,.13,8.5))
	await drag(Vector3(0,.13,8.5),Vector3(2.5,.13,8.5))
	await click(brush._confirm)
	expect(scene.courtyard_plan.land_bounds().end.y>9,"Add remains usable after erasing authored land and reopening")
	await choose_tool("bench")
	var bench_point: Vector2=scene.camera.unproject_position(Vector3(0,.13,7.5))
	await mouse(bench_point,true);await mouse(bench_point,false)
	await click(brush._panel.find_child("Finish",true,false));await create_timer(1).timeout
	expect(scene.decoration_layout._instances.has("bench"),"Actual player bench is placed on the expanded shore")
	if not scene.decoration_layout._instances.has("bench"): await finish();return
	var with_bench: Dictionary=scene.farm_state.snapshot().layout
	var bench_id: int=scene.decoration_layout._instances.bench.get_instance_id()
	scene._begin_construction("land");await create_timer(1).timeout
	await click(brush._panel.find_child("LandErase",true,false))
	expect(Support.capture(scene).has("decoration_bench"),"Support checks include the actual free-placed model footprint")
	await drag(Vector3(.5,.13,7.5),Vector3(.5,.13,7.5))
	expect(brush.draft==with_bench and brush._brush_message.contains("物件"),"Erasing under player furniture is refused before publication")
	expect(scene.decoration_layout._instances.bench.get_instance_id()==bench_id,"Refused shrink never moves or deletes player furniture")
	await shot("05-player-bench-protected")
	await click(brush._panel.find_child("Cancel",true,false))
	root.size=Vector2i(960,640);await frames()
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Add and erase controls fit the small window")
	scene.atmosphere.set_preview_hour(21);await frames(8);await shot("06-small-night")
	await finish()
