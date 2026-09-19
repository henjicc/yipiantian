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
	expect(brush._shore._surface.mesh!=null,"Continuous shore triangulates")
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
	if not await apply(): await finish();return
	expect(scene.courtyard_plan.snapshot()==persisted,"Brush shape survives actual saved scene rebuild")
	expect(scene.courtyard_plan.lily_coves==planned_plants,"Confirmed plants match the live candidate")
	expect(scene.farm_state.snapshot().fields==original.fields,"Painting retains every crop")
	await shot("06-saved")
	print("BRUSH_EVIDENCE "+folder)
	await finish()
