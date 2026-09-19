extends "res://../tests/island_construction_test.gd"
const Plants=preload("res://layout/plantings.gd")
var now: float=2000000.0

func place(point: Vector2) -> void:
	var at: Vector2=scene.camera.unproject_position(Vector3(point.x,-.25,point.y))
	await mouse(at,true);await mouse(at,false)

func free_point(kind: String, target: Vector2) -> Vector2:
	var builder: Node=scene.island_builder
	var best:=Vector2.INF;var distance: float=INF
	for y: int in range(-18,27):
		for x: int in range(-28,34):
			var point:=Vector2(x,y)*.5
			if point.distance_squared_to(target)>=distance: continue
			var screen: Vector2=scene.camera.unproject_position(Vector3(point.x,-.25,point.y))
			if not Rect2(30,30,1240,810).has_point(screen): continue
			var near: bool=false
			for entry: Dictionary in builder.draft.plants:
				if Plants.position(entry).distance_to(point)<1: near=true;break
			if near: continue
			if builder.plant_preview.entry_issue(Plants.make_entry(999,kind,point),builder.candidate).is_empty():
				best=point;distance=point.distance_squared_to(target)
	return best

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/plant-layout-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	if OS.get_cmdline_user_args().has("--edges-only"):
		await edges();await finish();return
	var environment: Node3D=scene.get_node("Environment")
	var animals: Node3D=environment.get_node("CourtyardAnimals")
	var identity: int=scene.get_instance_id()
	var house: Node3D=environment.get_node("MainHouse")
	var bird: Node3D=animals.birds[0].node
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	await choose_tool("lotus")
	var builder: Node=scene.island_builder
	expect(builder.tool=="lotus" and is_instance_valid(builder.plant_preview),"Plant catalog opens usable in-world tool")
	var original: Dictionary=scene.farm_state.snapshot()
	for kind: String in Plants.KINDS:
		await click(builder.choices.items[kind])
		var point: Vector2=free_point(kind,Vector2(-4,8))
		print("PLANT_POINT ",kind," ",point)
		expect(point.is_finite(),"A visible suitable habitat exists for "+kind)
		if not point.is_finite(): await finish();return
		var before: int=builder.draft.plants.size()
		await place(point)
		expect(builder.draft.plants.size()==before+1,"Point places exactly one "+kind)
		expect(builder.plant_preview.display.get_node(kind+"_high").multimesh.instance_count==1,"Actual mesh appears immediately for "+kind)
	expect(builder.draft.plants.size()==4,"Changing species retains the mixed unsaved planting")
	expect(scene.farm_state.snapshot()==original,"Point previews do not publish state")
	await shot("01-four-species")
	await click(builder.choices.items.lotus)
	var before_invalid: Array=builder.draft.plants.duplicate(true)
	await place(Vector2.ZERO)
	expect(builder.draft.plants==before_invalid and builder._status.text.contains("水面"),"Land is skipped with a clear reason")
	await click(builder._plant_buttons.brush)
	builder._values.radius.value=1.5;builder._values.density.value=2
	var point: Vector2=free_point("lotus",Vector2(-5,10))
	var start: Vector2=scene.camera.unproject_position(Vector3(point.x,-.25,point.y))
	await mouse(start,true)
	var before_drag: int=builder.draft.plants.size()
	var event:=InputEventMouseMotion.new();event.position=start+Vector2(100,0);event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.window_id=root.get_window_id()
	var started: int=Time.get_ticks_usec();root.push_input(event,true);print("PLANT_POINTER_US ",Time.get_ticks_usec()-started);await frames()
	expect(builder.draft.plants.size()>before_drag and before_drag>4,"Held brush grows actual plants along its path")
	await shot("02-held-brush")
	await mouse(event.position,false)
	var painted: Array=builder.draft.plants.duplicate(true)
	await mouse(start,true);await mouse(start,false)
	expect(builder.draft.plants==painted,"Repeated stroke does not stack plants or reroll poses")
	# Focus loss rolls back only the held gesture.
	point=free_point("lotus",Vector2(4,11))
	await mouse(scene.camera.unproject_position(Vector3(point.x,-.25,point.y)),true)
	expect(builder.draft.plants.size()>painted.size(),"Second stroke is visible before release")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(builder.draft.plants==painted,"Focus loss restores only current stroke")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	var usual: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	await click(builder._confirm)
	expect(scene.farm_state.snapshot()==original and builder._status.text.contains("未能保存"),"Failed save leaves authority intact and draft retryable")
	scene.store.directory=usual
	var shown: Node3D=builder.plant_preview.display
	if not await apply(): await finish();return
	expect(scene.get_instance_id()==identity and environment.get_node("MainHouse")==house and animals.birds[0].node==bird,"Save retains scene, house and animal identities")
	expect(environment.get_node("PlayerPlants")==shown,"Save adopts the displayed plant mesh batches")
	expect(scene.farm_state.snapshot().layout.plants==painted,"Saved planting retains every pose")
	await shot("03-saved")
	# Move one clump without replacing its identity, then rotate it in place.
	await click(builder._plant_buttons.move);builder._values.radius.value=.3
	var single: Dictionary=painted[0].duplicate(true)
	var origin: Vector2=Plants.position(single)
	await drag(Vector3(origin.x,-.25,origin.y),Vector3(origin.x+.2,-.25,origin.y))
	expect(builder._plant_selected==[single.id] and builder.draft.plants[0].pose[0]!=single.pose[0],"Small radius moves exactly one selected clump")
	await click(builder._plant_rotate)
	expect(is_equal_approx(builder.draft.plants[0].pose[2],fposmod(single.pose[2]+15,360)),"Rotation edits selected plant orientation")
	if not await apply(): await finish();return
	painted=scene.farm_state.snapshot().layout.plants.duplicate(true)
	# A larger radius moves a patch together, and cancel restores all saved poses.
	builder._values.radius.value=2
	origin=Plants.position(painted[0])
	await drag(Vector3(origin.x,-.25,origin.y),Vector3(origin.x+.3,-.25,origin.y+.2))
	expect(builder._plant_selected.size()>1,"Larger radius selects a group of the same species")
	var shifted: int=0
	for i: int in painted.size():
		if builder.draft.plants[i].id in builder._plant_selected and builder.draft.plants[i].pose!=painted[i].pose: shifted+=1
	expect(shifted==builder._plant_selected.size(),"Every selected clump follows the group drag")
	builder.cancel_draft()
	expect(builder.draft.plants==painted,"Cancel restores exact saved patch arrangement")
	# Eraser touches only selected species and player placements.
	await click(builder.choices.items.lotus);await click(builder._plant_buttons.erase)
	builder._values.radius.value=3
	await place(Plants.position(painted[0]))
	expect(builder.draft.plants.size()<painted.size(),"Eraser removes player lotus clumps")
	for entry: Dictionary in painted:
		if entry.kind!="lotus": expect(entry in builder.draft.plants,"Eraser preserves other species")
	if not await apply(): await finish();return
	now+=120;var state: Dictionary=scene.farm_state.snapshot();state.inventory.greens+=2
	scene.farm_state.restore_snapshot(state)
	await choose_tool("land");await click(builder._undo)
	expect(scene.farm_state.snapshot().layout.plants==painted and scene.farm_state.snapshot().inventory==state.inventory,"Cross-tool undo restores plants without undoing inventory")
	# Wait for background navigation, then verify individually blocked clumps.
	var waiting: int=Time.get_ticks_msec()
	while environment._terrain_refreshing:
		await process_frame
		if Time.get_ticks_msec()-waiting>45000: expect(false,"Plant navigation refresh finishes");break
	for entry: Dictionary in painted:
		expect(environment.layout_obstacles.has("player_plant_%d"%entry.id),"Player plant footprint protects later construction")
		if animals.water.bounds.has_point(Plants.position(entry)): expect(not animals.water.contains(Plants.position(entry)),"Animals avoid planted clumps")
	builder.finish();while scene.camera.is_transitioning(): await process_frame
	var saved: Dictionary=scene.farm_state.snapshot()
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(usual);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.farm_state.snapshot().layout==saved.layout,"Reopening actual scene restores exact planting layout")
	scene.atmosphere.set_preview_hour(11)
	for pose: Vector3 in [Vector3(25,35,12),Vector3(205,55,10)]:
		scene.camera.focus_point=Vector3(-4,0,9);scene.camera.view=pose
		await frames(8);await shot("04-close-%d"%pose.x)
	scene.camera.view=Vector3(25,35,12)
	scene.atmosphere.set_preview_hour(22);await frames(8);await shot("05-night")
	scene._begin_construction("lotus");await create_timer(1).timeout
	root.size=Vector2i(960,640);await frames()
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Plant tools fit minimum window")
	await shot("06-small-window")
	await finish()

func edges() -> void:
	scene._begin_construction("trapa");await create_timer(1).timeout
	var builder: Node=scene.island_builder
	var env: Node3D=scene.get_node("Environment")
	var before: Dictionary=scene.farm_state.snapshot()
	for point: Vector2 in [Vector2(8.1,-.15),Vector2(9,4.3)]:
		await place(point)
		expect(builder.draft.plants.is_empty(),"Bridge or boat rejects plant placement")
	await click(builder._plant_buttons.brush);builder._values.radius.value=3;builder._values.density.value=3
	scene.camera.focus_point=Vector3(-4,0,8);scene.camera.view=Vector3(15,65,32);await frames(8)
	for at: Vector2 in [Vector2(-10,9),Vector2(-6,11),Vector2(-2,11),Vector2(2,11),Vector2(6,10)]:
		var since: int=Time.get_ticks_msec();await place(at);print("PLANT_DENSE_GESTURE_MS ",Time.get_ticks_msec()-since," count=",builder.draft.plants.size())
		if builder.draft.plants.size()==Plants.MAX_CLUMPS: break
	expect(builder.draft.plants.size()==Plants.MAX_CLUMPS,"Dense painting reaches bounded capacity")
	var full: Array=builder.draft.plants.duplicate(true)
	await place(Vector2(2,11));builder._values.density.value=1
	expect(builder.draft.plants==full,"Capacity and density changes preserve existing planting")
	expect(builder.plant_preview.display.get_node("trapa_high").multimesh.instance_count==Plants.MAX_CLUMPS,"Every clump is displayed in the real mesh batch")
	await shot("edge-01-capacity")
	if not await apply(): return
	# Switching detail affects the actual committed batches.
	builder.finish();await create_timer(1).timeout
	scene.focus_detail.set_quality("low");await frames()
	expect(env.get_node("PlayerPlants/trapa_low").visible and not env.get_node("PlayerPlants/trapa_high").visible,"Low quality keeps plants using their authored low meshes")
	await shot("edge-02-low")
	scene.focus_detail.set_quality("standard")
	expect(env.get_node("PlayerPlants/trapa_high").visible,"Returning to standard restores high meshes")
	scene._begin_construction("trapa");await create_timer(1).timeout
	# One finish saves an eraser stroke and exits, without replacing the scene.
	await click(builder._plant_buttons.erase);builder._values.radius.value=1
	await place(Plants.position(full[0]))
	var expected: Dictionary=builder.draft.duplicate(true)
	await click(builder._panel.find_child("Finish",true,false))
	expect(not builder.active and scene.farm_state.snapshot().layout==expected,"One Finish saves edited plants and exits")
	# Cancel restores automatic scenery visibility, not only plant data.
	scene._begin_construction("lotus");await create_timer(1).timeout
	var visibility: Dictionary={}
	for lotus: Node3D in env._floaters: visibility[lotus]=lotus.visible
	await click(builder._plant_buttons.brush);builder._values.radius.value=3
	await place(Vector2(-4,8));builder.cancel_draft()
	var restored: bool=true
	for lotus: Node3D in visibility: restored=restored and lotus.visible==visibility[lotus]
	expect(restored,"Cancel restores automatic lotus visibility")
	# Planting can never authorize terrain to cover the protected clumps.
	await choose_tool("land")
	await drag(Vector3(-4,.13,5.5),Vector3(-4,.13,10))
	expect(not builder.issue().is_empty(),"Land brush detects protected water planting")
	var saved: Dictionary=scene.farm_state.snapshot()
	await click(builder._panel.find_child("Finish",true,false))
	expect(builder.active and scene.farm_state.snapshot()==saved,"Invalid terrain cannot be confirmed over player plants")
	builder.cancel_draft()
	expect(scene.farm_state.snapshot().fields==before.fields,"All planting operations preserve crop identities")
	var sources_valid: bool=true
	for source: Variant in env._shore_sources: sources_valid=sources_valid and is_instance_valid(source)
	expect(sources_valid,"Cancelled shore preview never registers freed temporary rocks")
	# Move UI remains usable at the minimum viewport.
	await choose_tool("trapa");await click(builder._plant_buttons.move)
	expect(is_instance_valid(builder.plant_preview.display),"Plant tool reopens after cancelling terrain preview")
	root.size=Vector2i(960,640);await frames()
	expect(root.get_visible_rect().encloses(builder._panel.get_global_rect()),"Group movement tools fit the minimum window")
	await shot("edge-03-small-move")
