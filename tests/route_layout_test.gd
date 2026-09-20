extends "res://../tests/island_construction_test.gd"
const Routes=preload("res://layout/player_routes.gd")
var now: float=2000000.0

func ready_draft() -> bool:
	var builder: Node=scene.island_builder;var start: int=Time.get_ticks_msec()
	while builder._layout_check_pending():
		await process_frame
		if Time.get_ticks_msec()-start>20000: expect(false,"Route validation finishes");return false
	expect(builder.issue().is_empty(),"Route accepted: "+builder.issue())
	return builder.issue().is_empty()

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/route-layout-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var plan:=Plan.new();var construction: Dictionary=Construction.initial()
	construction.land=[[-3,5,5,5]];plan.apply_construction(construction)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=plan
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8);scene.atmosphere.set_preview_hour(11)
	if OS.get_cmdline_user_args().has("--edges-only"):
		await edges();await finish();return
	var original: Node3D=scene;var house: Node3D=scene.get_node("Environment/MainHouse")
	var animals: Node3D=scene.get_node("Environment/CourtyardAnimals")
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	await choose_tool("road");var builder: Node=scene.island_builder
	expect(builder.tool=="road" and builder._route_actions.visible,"Road catalog opens drawing controls")
	# Hold through a corner; geometry must exist before releasing the mouse.
	var start: Vector2=scene.camera.unproject_position(Vector3(-1.5,.13,6.5))
	await mouse(start,true)
	for target: Vector3 in [Vector3(-1.5,.13,8),Vector3(1,.13,8)]:
		var event:=InputEventMouseMotion.new();event.position=scene.camera.unproject_position(target);event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.window_id=root.get_window_id()
		var event_start: int=Time.get_ticks_usec();root.push_input(event,true);print("ROUTE_DRAG_EVENT_US ",Time.get_ticks_usec()-event_start);await frames()
	expect(builder.draft.routes.size()==1 and builder.draft.routes[0].points.size()==3,"Held stroke preserves the corner")
	expect(builder.route_preview.display.roads.get_child_count()>5,"Stone road appears while mouse is held")
	expect(scene.farm_state.snapshot().layout.routes.is_empty(),"Held preview has no authoritative side effect")
	await shot("01-held-road")
	await mouse(scene.camera.unproject_position(Vector3(1,.13,8)),false)
	if not await ready_draft(): await finish();return
	# Switch within the route category without discarding the road draft.
	await click(builder._tools.fence)
	expect(builder.draft.routes.size()==1,"Switch to fence keeps the road draft")
	await drag(Vector3(0,.13,6.5),Vector3(0,.13,9))
	if not await ready_draft(): await shot("invalid-fence");await finish();return
	var preview: Node3D=builder.route_preview.display
	expect(preview.fence.get_node("Contacts").get_child_count()>0,"Fence posts have local contact shading")
	await shot("02-fence-crossing")
	if not await apply(): await finish();return
	expect(scene==original and scene.get_node("Environment/MainHouse")==house and scene.get_node("Environment/CourtyardAnimals")==animals,"Saving keeps farm, house and animals")
	expect(scene.get_node("Environment/PlayerRoutes")==preview,"Saving adopts the preview geometry")
	var since: int=Time.get_ticks_msec()
	while not animals.yard_ready:
		await frames()
		if Time.get_ticks_msec()-since>20000: expect(false,"Navigation refresh finishes");await finish();return
	expect(animals.yard.contains(Vector2(0,8)),"Road crossing remains open in actual animal space")
	expect(not animals.yard.contains(Vector2(0,7)),"Actual fence blocks animal movement")
	expect(not animals.yard.path(Vector2(-.7,8),Vector2(.7,8)).is_empty(),"Actual animal route crosses the gate")
	var old_contacts: Node3D=scene.get_node("Environment/PlayerRoutes/Fences/Contacts")
	await click(builder._route_buttons.gate)
	var gate: Vector2=scene.camera.unproject_position(Vector3(0,.13,7));await mouse(gate,true);await mouse(gate,false)
	expect(builder.draft.routes[1].openings.size()==1,"Click adds a manual entrance")
	if not await ready_draft(): await finish();return
	var saved: Dictionary=scene.farm_state.snapshot();var path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	await click(builder._confirm);while builder.busy: await frames()
	expect(scene.farm_state.snapshot()==saved and builder._status.text.contains("未能保存"),"Failed save keeps authoritative layout and retryable draft")
	scene.store.directory=path
	if not await apply(): await finish();return
	expect(not is_instance_valid(old_contacts),"Opening replacement releases old post contact pools")
	var before: Array=scene.courtyard_plan.routes.duplicate(true)
	await click(builder._route_buttons.erase)
	var at: Vector2=scene.camera.unproject_position(Vector3(0,.13,8.8));await mouse(at,true);await mouse(at,false)
	expect(builder.draft.routes.size()==1,"Remove deletes only selected fence stroke")
	expect(builder.route_preview.display.fence.get_node("Contacts").get_child_count()==0,"Erasing the last fence leaves no contact decal")
	builder.cancel_draft();await frames()
	expect(scene.courtyard_plan.routes==before and builder.draft.routes==before,"Cancel restores the full drawn fence")
	await click(builder._route_buttons.draw)
	await drag(Vector3(-2,.13,7),Vector3(-2,.13,9))
	if not await apply(): await finish();return
	var updated: Dictionary=scene.farm_state.snapshot();updated.inventory.greens+=2
	expect(scene.farm_state.restore_snapshot(updated),"Later harvest fixture")
	await click(builder._undo);while builder.busy: await frames()
	expect(scene.courtyard_plan.routes==before and scene.farm_state.snapshot().inventory==updated.inventory,"Construction undo preserves later inventory")
	await choose_tool("road")
	await drag(Vector3(-3.5,.13,0),Vector3(-1,.13,0))
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Road through planted field rejected")
	builder.cancel_draft();builder.finish();await create_timer(1).timeout
	await shot("03-finished")
	var layout: Dictionary=scene.courtyard_plan.snapshot()
	var stones: Array=[]
	for stone: Node3D in scene.get_node("Environment/PlayerRoutes/Roads").get_children(): stones.append(stone.transform)
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.courtyard_plan.snapshot()==layout,"Reopening actual scene restores roads, fence and entrance")
	expect(scene.get_node("Environment/PlayerRoutes/Roads").get_child_count()>5,"Reopened road has real stone geometry")
	var restored_stones: Array=[]
	for stone: Node3D in scene.get_node("Environment/PlayerRoutes/Roads").get_children(): restored_stones.append(stone.transform)
	expect(restored_stones==stones,"Saved road stones restore identical poses and sizes")
	scene.atmosphere.set_preview_hour(11);scene.camera.focus_point=Vector3(-.5,.3,7.5);scene.camera.view=Vector3(22,40,10)
	await frames(10);await shot("04-close-front")
	scene.camera.view=Vector3(200,35,10);await frames(10);await shot("05-close-back")
	scene.atmosphere.set_preview_hour(22);await frames(10);await shot("06-night")
	root.size=Vector2i(960,640);scene._begin_construction("fence");await frames(10)
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Route controls fit minimum window")
	await shot("07-small-window");await finish()

func edges() -> void:
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	await choose_tool("road");var builder: Node=scene.island_builder
	var original: Dictionary=scene.farm_state.snapshot()
	var start: Vector2=scene.camera.unproject_position(Vector3(-1.5,.13,7))
	await mouse(start,true)
	var move:=InputEventMouseMotion.new();move.position=scene.camera.unproject_position(Vector3(1,.13,7));move.button_mask=MOUSE_BUTTON_MASK_LEFT;move.window_id=root.get_window_id()
	root.push_input(move,true);await frames()
	expect(not builder.draft.routes.is_empty(),"Held stroke exists before focus loss")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT);await frames()
	expect(builder.draft==original.layout and scene.farm_state.snapshot()==original,"Focus loss cancels only the unfinished stroke")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await mouse(move.position,false)
	await drag(Vector3(-1.5,.13,7),Vector3(1,.13,7))
	var abandoned: Node3D=builder.route_preview
	# Restart the real private check then cancel in the same frame.
	while abandoned._worker!=null: await frames()
	abandoned.pending=true;abandoned._due=0;abandoned._process(0)
	expect(abandoned._worker!=null and abandoned._worker.is_started(),"A real route worker is running before cancel")
	var since: int=Time.get_ticks_msec();builder.cancel_draft()
	print("ROUTE_CANCEL_MS ",Time.get_ticks_msec()-since)
	await choose_tool("lotus");await create_timer(.5).timeout
	expect(builder.tool=="lotus" and scene.farm_state.snapshot()==original,"Late route result cannot overwrite a different tool")
	expect(scene.get_node("Environment/PlayerRoutes").visible,"Cancel restores authored geometry visibility")
	await choose_tool("road")
	await drag(Vector3(-1.5,.13,8),Vector3(1,.13,8))
	await click(builder._tools.fence)
	await drag(Vector3(0,.13,6.5),Vector3(0,.13,9))
	if not await ready_draft(): return
	var expected: Dictionary=builder.candidate.snapshot()
	var preview: Node3D=builder.route_preview
	while preview._worker!=null: await frames()
	preview.pending=true;preview._due=0;preview._process(0)
	var button: Control=builder._panel.find_child("Finish",true,false)
	var position: Vector2=button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.window_id=root.get_window_id();root.push_input(event,true)
	since=Time.get_ticks_msec()
	while builder.busy:
		await frames()
		if Time.get_ticks_msec()-since>20000: expect(false,"Pending finish timeout");return
	print("ROUTE_FINISH_PENDING_MS ",Time.get_ticks_msec()-since)
	expect(not builder.active and scene.farm_state.snapshot().layout==expected,"One real Finish click waits for the latest check then exits")
	var animals: Node3D=scene.get_node("Environment/CourtyardAnimals")
	while not animals.yard_ready: await frames()
	# Use the real moving actor, pose and space; only its starting destination is fixed.
	var hen: Dictionary=animals.interaction.find("YardHen1")
	hen.position=animals.yard.nearest(Vector2(-.9,8));hen.node.position=Vector3(hen.position.x,animals.yard.ground_height(hen.position),hen.position.y)
	hen.velocity=Vector2.ZERO;hen.heading=PI/2;hen.buddy=null;hen.interest=Vector2.INF;hen.stuck=0.0
	hen.route=animals.yard.path(hen.position,animals.yard.nearest(Vector2(.9,8)));hen.waypoint=0;hen.state="walk"
	var crossed: bool=false;since=Time.get_ticks_msec();var supported: bool=true
	while Time.get_ticks_msec()-since<10000:
		await frames()
		supported=supported and hen.space.contains(hen.position)
		if hen.position.x>.6: crossed=true;break
	expect(crossed and supported,"Live hen walks through the entrance without crossing solid fence")
	await create_timer(1).timeout
	scene.camera.focus_point=Vector3(0,.4,8);scene.camera.view=Vector3(20,35,10);await frames(10);await shot("edge-hen-through-gate")
	var authored: Array=scene.courtyard_plan.routes.duplicate(true)
	scene._begin_construction("fields");await create_timer(1).timeout
	await click(builder._panel.find_child("AddField",true,false))
	await drag(Vector3(-1.5,.13,7),Vector3(1,.13,9))
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Later field cannot displace the player's road or fence")
	builder.cancel_draft()
	await choose_tool("land")
	await drag(Vector3(-1,.13,9),Vector3(-1,.13,11))
	if not await apply(): return
	expect(scene.courtyard_plan.routes==authored and scene.get_node("Environment/PlayerRoutes").visible,"Later land painting preserves authored lines")
	var decorations: Dictionary=scene.decoration_state.snapshot();decorations.bench.unlocked=true
	expect(scene.decoration_state.restore_snapshot(decorations),"Bench unlocked for placement check")
	scene.decoration_layout.refresh_confirmed();await choose_tool("bench")
	scene.decoration_layout.preview_on_ground(Vector2(-.5,8));await frames()
	var before_props: Dictionary=scene.decoration_state.snapshot()
	scene.decoration_layout.confirm_preview();await frames()
	expect(scene.decoration_state.snapshot()==before_props and scene.decoration_layout._message.contains("碰到"),"Furniture cannot occupy player's road")
	builder.cancel_draft();await choose_tool("fence")
	await click(builder._route_buttons.gate)
	var at: Vector2=scene.camera.unproject_position(Vector3(0,.13,7));await mouse(at,true);await mouse(at,false)
	expect(builder.draft.routes[1].openings.size()==1,"Entrance click opens the fence")
	await mouse(at,true);await mouse(at,false)
	expect(builder.draft.routes[1].openings.is_empty(),"Second entrance click closes the same gap")
	builder.cancel_draft();await choose_tool("road")
	await drag(Vector3(3.5,.13,8),Vector3(4.5,.13,8))
	expect(not builder.issue().is_empty(),"Open-water line has visible rejection")
	builder.cancel_draft();await choose_tool("fence")
	root.size=Vector2i(960,640);await frames(10);await shot("edge-small-controls")
