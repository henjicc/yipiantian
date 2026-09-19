extends "res://../tests/island_construction_test.gd"
var now: float=2000000.0

func ready_draft() -> bool:
	var started: int=Time.get_ticks_msec()
	var builder: Node=scene.island_builder
	while is_instance_valid(builder.bridge_preview) and builder.bridge_preview.pending:
		await process_frame
		if Time.get_ticks_msec()-started>20000: expect(false,"Bridge route check finishes");return false
	var message: String=builder.issue()
	if not message.is_empty() and is_instance_valid(builder.bridge_preview):
		for key: String in builder.bridge_preview._obstacles:
			if preload("res://layout/island_space.gd").overlaps(builder.bridge_preview.footprint,builder.bridge_preview._obstacles[key]): print("BRIDGE_OVERLAP ",key)
	expect(message.is_empty(),"Bridge draft accepted: "+message)
	return message.is_empty()

func terrain_ready() -> void:
	var started: int=Time.get_ticks_msec()
	while scene.get_node("Environment")._terrain_refreshing:
		await process_frame
		if Time.get_ticks_msec()-started>30000: expect(false,"Bridge background navigation completes");return

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/bridge-layout-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	if OS.get_cmdline_user_args().has("--views-only"):
		var layout: Dictionary=Plan.new().snapshot();layout.construction.bridge=[5.4,-.1,11.0,.1,1.2,1]
		scene.courtyard_plan=Plan.from_snapshot(layout)
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	if OS.get_cmdline_user_args().has("--views-only"):
		await inspect_bridge();await finish();return
	var environment: Node3D=scene.get_node("Environment")
	var animals: Node3D=environment.get_node("CourtyardAnimals")
	var original: Dictionary=scene.farm_state.snapshot()
	var scene_id: int=scene.get_instance_id()
	var house: Node3D=environment.get_node("MainHouse")
	var original_bridge: Node3D=environment.get_bridge()
	var birds: Array[Node3D]=[]
	for bird: Dictionary in animals.birds: birds.append(bird.node)
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	await choose_tool("bridge")
	scene.camera.focus_point=Vector3(4,.13,0);await frames(10)
	var builder: Node=scene.island_builder
	if OS.get_cmdline_user_args().has("--edges-only"):
		await edge_checks(builder);await finish();return
	if OS.get_cmdline_user_args().has("--move-only"):
		await move_checks(builder);await finish();return
	var ends: Array[Vector3]=Construction.bridge_points(scene.courtyard_plan)
	await drag(ends[1],Vector3(8,.13,3))
	expect(builder._confirm.disabled and not builder.issue().is_empty(),"Unsupported bridge end is rejected")
	builder.cancel_draft();await frames()
	expect(environment.get_bridge()==original_bridge and original_bridge.visible,"Cancel retains original bridge instance")
	# Hold the pointer: geometry and supports must already be at the new end.
	var start: Vector2=scene.camera.unproject_position(ends[1]+Vector3.UP*.12)
	await mouse(start,true)
	var event:=InputEventMouseMotion.new();event.position=scene.camera.unproject_position(Vector3(11,.13,.1));event.button_mask=MOUSE_BUTTON_MASK_LEFT
	event.window_id=root.get_window_id()
	var before: int=Time.get_ticks_usec();root.push_input(event,true)
	print("BRIDGE_POINTER_US ",Time.get_ticks_usec()-before);await frames()
	expect(is_instance_valid(builder.bridge_preview) and builder.bridge_preview.structure.has_meta("bridge_supports"),"Held pointer displays generated bridge and supports")
	expect(scene.farm_state.snapshot()==original and not original_bridge.visible,"Held preview preserves authority and hides original")
	await mouse(event.position,false)
	expect(builder.issue().contains("景物"),"Bridge rejects new intrusion into authored jars")
	await drag(Construction.bridge_points(builder.candidate)[0]+Vector3.UP*.12,Vector3(5.4,.13,-.1))
	if not await ready_draft(): await shot("failure-placement");await finish();return
	var automatic_clear: bool=true
	for entry: Dictionary in builder.bridge_preview._dressing:
		if entry.node.visible and preload("res://layout/island_space.gd").overlaps(builder.bridge_preview.footprint,entry.footprint): automatic_clear=false
	expect(automatic_clear,"Automatic bank stones clear the bridge during preview")
	await shot("01-preview")
	var preview: Node3D=builder.bridge_preview.structure
	var support: Vector2=preview.get_meta("bridge_supports")[2]
	var contact: Node3D=builder.bridge_preview.contacts
	var old_source: int=original_bridge.get_instance_id()
	if not await apply(): await finish();return
	expect(scene.get_instance_id()==scene_id and environment.get_node("MainHouse")==house,"Save keeps main scene and house")
	expect(environment.get_bridge()==preview and environment.get_node("BridgeContacts")==contact,"Save adopts preview bridge and contact shading")
	expect(environment._shore_sources.has(preview) and environment._contact_sources.has(preview),"Waterline and contact source registries follow new bridge")
	var no_old: bool=true
	for source: Node3D in environment._shore_sources: no_old=no_old and is_instance_valid(source) and source.get_instance_id()!=old_source
	expect(no_old,"Old stone bridge is removed from shoreline registry")
	for i: int in birds.size(): expect(animals.birds[i].node==birds[i],"Existing animal survives bridge save")
	expect(environment.circulation.issues.is_empty() and environment.circulation.endpoints.has("bridge"),"Bridge has a checked approach from the house")
	for mesh: GeometryInstance3D in preview.find_children("*","GeometryInstance3D",true,false): expect(mesh.gi_mode==GeometryInstance3D.GI_MODE_STATIC,"Adopted bridge participates in indirect lighting")
	await terrain_ready()
	for child: Node in environment.get_children():
		if child.get_meta("bridge_dressing_hidden",false): expect(not environment.layout_obstacles.has(String(child.name)) and not environment._shore_sources.has(child),"Hidden bank stone stays out of navigation and waterline sources")
	expect(not animals.water.contains(support),"Waterfowl navigation avoids actual new bridge support")
	expect(animals.ready_for_motion,"Animals resume after local terrain update")
	await shot("02-committed")
	var saved: Dictionary=scene.farm_state.snapshot()
	var normal: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	builder._values.bridge_width.value=1.0
	if not await ready_draft(): await finish();return
	await click(builder._confirm)
	while builder.busy: await process_frame
	expect(scene.farm_state.snapshot()==saved and environment.get_bridge()==preview,"Failed save keeps authority and committed bridge")
	expect(builder._status.text.contains("未能保存") and is_instance_valid(builder.bridge_preview),"Failed bridge save retains retryable draft")
	scene.store.directory=normal
	if not await apply(): await finish();return
	expect(scene.farm_state.snapshot().layout.construction.bridge[4]==1.0,"Bridge width retry succeeds")
	# Undo while the just-committed water refresh is still running.
	now+=120
	var state: Dictionary=scene.farm_state.snapshot();state.inventory.greens+=2;scene.farm_state.restore_snapshot(state)
	await choose_tool("land");await click(builder._undo)
	while builder.busy: await process_frame
	expect(scene.get_instance_id()==scene_id and scene.farm_state.snapshot().layout==saved.layout,"Cross-tool undo restores bridge parameters in place")
	expect(scene.farm_state.snapshot().inventory==state.inventory,"Bridge undo retains later inventory")
	await terrain_ready()
	# Return to the authored stone bridge through the same public commit path.
	scene.previous_layout=original.layout;builder.previous=original.layout;builder._refresh()
	await click(builder._undo)
	while builder.busy: await process_frame
	expect(scene.farm_state.snapshot().layout.construction.bridge.is_empty(),"Undo can restore authored stone bridge")
	expect(environment.get_bridge().scene_file_path.ends_with("/stone_bridge.glb"),"Restoration uses actual stone geometry")
	await terrain_ready();await shot("03-stone-restored")
	await choose_tool("bridge")
	await drag(ends[1],Vector3(11,.13,.1))
	await drag(Construction.bridge_points(builder.candidate)[0]+Vector3.UP*.12,Vector3(5.4,.13,-.1))
	if not await ready_draft(): await finish();return
	builder._values.bridge_width.value=1.1
	expect(builder.bridge_preview.pending,"Final width starts a real pending bridge check")
	var final_layout: Dictionary=builder.draft
	before=Time.get_ticks_msec()
	await click(builder._panel.find_child("Finish",true,false))
	while builder.busy: await process_frame
	print("BRIDGE_FINISH_MS ",Time.get_ticks_msec()-before)
	expect(not builder.active and scene.farm_state.snapshot().layout==final_layout,"One Finish saves bridge and exits")
	await terrain_ready()
	scene.atmosphere.set_preview_hour(22);await frames(10);await shot("04-night")
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(normal);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	environment=scene.get_node("Environment")
	if scene.courtyard_plan.snapshot()!=final_layout:
		for key: String in final_layout:
			if final_layout[key]!=scene.courtyard_plan.snapshot()[key]: print("BRIDGE_REOPEN_DIFF ",key," expected=",final_layout[key]," actual=",scene.courtyard_plan.snapshot()[key])
	expect(scene.courtyard_plan.snapshot()==final_layout,"Reopening restores exact bridge layout")
	expect(environment.get_bridge().has_meta("bridge_supports") and environment._shore_sources.has(environment.get_bridge()),"Reopened bridge is registered for waterline and navigation")
	scene.camera.focus_point=Vector3(8,.13,0);scene.camera.view=Vector3(35,35,14)
	await frames(10);await shot("05-reopened")
	scene.camera.view=Vector3(215,35,14);await frames(10);await shot("06-reverse")
	await finish()

func edge_checks(builder: Node) -> void:
	var environment: Node=scene.get_node("Environment")
	var original: Dictionary=scene.farm_state.snapshot()
	var original_bridge: Node3D=environment.get_bridge()
	var stones: Dictionary={}
	for child: Node in environment.get_children():
		if child.has_meta("bridge_dressing_stone"): stones[child]=child.visible
	var ends: Array[Vector3]=Construction.bridge_points(scene.courtyard_plan)
	# A held endpoint gesture is rolled back on focus loss.
	await mouse(scene.camera.unproject_position(ends[1]+Vector3.UP*.12),true)
	var event:=InputEventMouseMotion.new();event.position=scene.camera.unproject_position(Vector3(11,.13,.1));event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.window_id=root.get_window_id()
	root.push_input(event,true);await frames()
	expect(is_instance_valid(builder.bridge_preview),"Held bridge creates a preview")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(builder.draft==original.layout and original_bridge.visible,"Focus loss restores bridge draft and original mesh")
	for stone: Node3D in stones: expect(stone.visible==stones[stone],"Focus loss restores bank stone visibility")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN);await frames()
	await drag(ends[1]+Vector3.UP*.12,Vector3(11,.13,.1))
	await drag(Construction.bridge_points(builder.candidate)[0]+Vector3.UP*.12,Vector3(5.4,.13,-.1))
	var wanted: Dictionary=builder.draft.duplicate(true)
	# Start a fresh real check in this frame. The input helper's frame waits can
	# already finish an earlier worker on a headless/fast renderer.
	builder._values.bridge_width.value=1.1
	var pending: Node=builder.bridge_preview
	pending._due=0;pending._process(0)
	var started: int=Time.get_ticks_msec()
	expect(pending._worker!=null and pending._worker.is_alive(),"Cancellation exercises a running bridge worker")
	started=Time.get_ticks_msec();builder.cancel_draft()
	print("BRIDGE_CANCEL_MS ",Time.get_ticks_msec()-started)
	expect(original_bridge.visible and scene.farm_state.snapshot()==original,"Cancel restores scene without publishing bridge state")
	for stone: Node3D in stones: expect(stone.visible==stones[stone],"Cancel restores each automatic stone")
	builder.draft=wanted;builder._refresh();builder._values.bridge_width.value=1.0
	if not await ready_draft(): return
	expect(not is_instance_valid(pending) and not original_bridge.visible,"Retired worker cannot restore a newer bridge preview")
	expect(builder.bridge_preview.validated.construction.bridge[4]==1.0,"Only latest width receives the route result")
	builder.cancel_draft();await frames()
	# An existing hand-placed bench must be protected, not treated as bank dressing.
	var decor: Dictionary=scene.decoration_state.snapshot()
	decor.bench={"unlocked":true,"slot_id":"","position":[5.3,.9],"quarter_turn":0}
	expect(scene.decoration_state.restore_snapshot(decor),"Fixture restores a player bench")
	scene.decoration_layout.refresh_confirmed()
	var bench: Node3D=scene.decoration_layout._instances.bench
	var bench_pose: Transform3D=bench.global_transform
	builder.draft.construction.bridge=[5.4,.8,11.0,.1,1.0,1];builder._refresh()
	expect(builder._confirm.disabled and builder.issue().contains("摆件"),"Bridge placement protects the player's bench")
	expect(bench.visible and bench.global_transform==bench_pose,"Rejected bridge never hides or moves player content")
	builder.cancel_draft()
	decor.bench={"unlocked":true,"slot_id":"","position":[],"quarter_turn":0}
	scene.decoration_state.restore_snapshot(decor);scene.decoration_layout.refresh_confirmed()
	builder.draft=wanted;builder._refresh()
	if not await ready_draft() or not await apply(): return
	await terrain_ready()
	var bridge: Node3D=environment.get_bridge()
	# Shore vegetation follows the same full-width exit after a later terrain edit.
	var reed: Node3D=environment.get_node("BankReeds9")
	expect(not reed.visible and reed.get_meta("bridge_dressing_hidden",false),"Committed bridge clears the automatic reed at its exit")
	var shore_candidate: RefCounted=Plan.from_snapshot(scene.courtyard_plan.snapshot())
	shore_candidate.reeds[9]+=Vector3(2,0,0)
	environment.preview_shore_plants(shore_candidate)
	expect(reed.visible and reed.get_meta("bridge_dressing_hidden",false),"Moving shore preview restores a clear reed without publishing navigation")
	environment.preview_shore_plants(environment.plan)
	expect(not reed.visible,"Cancelling shore preview restores reed exclusion")
	# Later terrain edits must not bring hidden rocks back through the bridge.
	await choose_tool("land")
	await drag(Vector3(0,.13,6),Vector3(3,.13,7.5))
	if not await apply(): return
	await terrain_ready()
	expect(environment.get_bridge()==bridge,"Later shore edits preserve the committed bridge instance")
	var rocks: int=0
	for child: Node in environment.get_children():
		if not child.has_meta("shore_stone"): continue
		rocks+=1
		if child.get_meta("bridge_dressing_hidden",false): expect(not child.visible and not environment._shore_sources.has(child) and not environment.layout_obstacles.has(String(child.name)),"Shore edits preserve bridge stone exclusions")
	expect(rocks==preload("res://presentation/shore_dressing.gd").stones(scene.courtyard_plan).size(),"Shore edits replace hidden stones without accumulating duplicates")
	await choose_tool("bridge")
	root.size=Vector2i(960,640);await frames()
	expect(root.get_visible_rect().encloses(builder._panel.get_global_rect()),"Bridge controls fit the minimum window")
	await shot("edges-small-window")
	root.size=Vector2i(1600,900);await frames();await click(builder._panel.find_child("Finish",true,false))
	await inspect_bridge()

func inspect_bridge() -> void:
	while scene.camera.is_transitioning(): await process_frame
	scene.camera.focus_point=Vector3(8,.13,0);scene.camera.view=Vector3(35,35,14)
	await frames(10);await shot("edges-contact-front")
	expect(scene.camera.view==Vector3(35,35,14),"Contact inspection uses the requested close view")
	scene.camera.view=Vector3(215,35,14);await frames(10);await shot("edges-contact-reverse")
	expect(scene.camera.view==Vector3(215,35,14),"Reverse inspection keeps the opposite viewing direction")
	scene.focus_detail.set_quality("high");scene.atmosphere.set_preview_hour(22);await frames(20);await shot("edges-night")

func move_pointer(from: Vector3, to: Vector3) -> void:
	var event:=InputEventMouseMotion.new();event.position=scene.camera.unproject_position(to)
	event.relative=event.position-scene.camera.unproject_position(from)
	event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.window_id=root.get_window_id()
	var started: int=Time.get_ticks_usec();root.push_input(event,true)
	print("BRIDGE_MOVE_POINTER_US ",Time.get_ticks_usec()-started)
	await frames()

func move_checks(builder: Node) -> void:
	var environment: Node=scene.get_node("Environment")
	var original: Dictionary=scene.farm_state.snapshot()
	var original_bridge: Node3D=environment.get_bridge()
	var original_center:=Vector3(8.1,.45,-.15)
	# The visible deck, not a large endpoint hot zone, selects the entire bridge.
	var screen: Vector2=scene.camera.unproject_position(original_center)
	await mouse(screen,true);await mouse(screen,false)
	expect(builder.draft==original.layout and not is_instance_valid(builder.bridge_preview),"Stationary deck click does not replace the authored bridge")
	await drag(Vector3(8,.13,3),Vector3(8,.13,4))
	expect(builder.draft==original.layout,"Dragging open water does not move a bridge")
	await mouse(screen,true)
	await move_pointer(original_center,original_center+Vector3(0,0,-.5))
	expect(is_instance_valid(builder.bridge_preview) and builder._bridge_end==-1,"Held deck drag selects the complete authored bridge")
	if not is_instance_valid(builder.bridge_preview): return
	var original_ends: Array[Vector3]=Construction.bridge_points(scene.courtyard_plan)
	var held: Array[Vector3]=Construction.bridge_points(builder.candidate)
	expect((held[0]-original_ends[0]).distance_to(Vector3(0,0,-.5))<.0001 and (held[1]-original_ends[1]).distance_to(Vector3(0,0,-.5))<.0001,"Whole-bridge grid drag translates both ends equally")
	expect(scene.farm_state.snapshot()==original and not original_bridge.visible,"Held whole-bridge drag only changes preview")
	await move_pointer(original_center+Vector3(0,0,-.5),original_center)
	expect(builder.draft==original.layout and not is_instance_valid(builder.bridge_preview) and original_bridge.visible,"Dragging back to the press point restores the original mesh and draft")
	await mouse(screen,false);builder.cancel_draft();await frames()
	# Prepare the previously verified clear crossing, through real end handles.
	await drag(original_ends[1]+Vector3.UP*.12,Vector3(11,.13,.1))
	await drag(Construction.bridge_points(builder.candidate)[0]+Vector3.UP*.12,Vector3(5.4,.13,-.1))
	builder._values.bridge_width.value=.8
	if not await ready_draft() or not await apply(): return
	await terrain_ready()
	var saved: Dictionary=scene.farm_state.snapshot()
	var bridge: Node3D=environment.get_bridge()
	var center: Vector3=Construction.bridge_points(scene.courtyard_plan)[0].lerp(Construction.bridge_points(scene.courtyard_plan)[1],.5)+Vector3.UP*.30
	# Free drag uses one shared translation; width and structure counts stay stable.
	await click(builder._bridge_snap)
	var sections: int=bridge.get_meta("deck_sections")
	var support_count: int=bridge.get_meta("bridge_supports").size()
	await mouse(scene.camera.unproject_position(center),true)
	await move_pointer(center,center+Vector3(0,0,-.15))
	expect(is_instance_valid(builder.bridge_preview) and builder._bridge_end==-1,"Generated bridge deck remains draggable")
	if not is_instance_valid(builder.bridge_preview): return
	var moved: Array=builder.draft.construction.bridge
	var previous_parameters: Array=saved.layout.construction.bridge
	expect(is_equal_approx(moved[0],previous_parameters[0]) and is_equal_approx(moved[2],previous_parameters[2]) and is_equal_approx(moved[1],previous_parameters[1]-.15) and is_equal_approx(moved[3],previous_parameters[3]-.15),"Free placement preserves the exact endpoint separation")
	expect(moved[4]==previous_parameters[4] and builder.bridge_preview.structure.get_meta("deck_sections")==sections and builder.bridge_preview.structure.get_meta("bridge_supports").size()==support_count,"Whole move retains width, plank count and paired supports")
	await shot("move-held")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(builder.draft==saved.layout and bridge.visible,"Focus loss restores an unfinished whole-bridge drag")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN);await frames()
	await drag(center,center+Vector3(0,0,-.15))
	if not await ready_draft(): return
	var preview: Node3D=builder.bridge_preview.structure
	if not await apply(): return
	expect(environment.get_bridge()==preview and scene.get_node("Environment")==environment,"Whole move adopts the preview without reloading the island")
	await terrain_ready()
	var moved_layout: Dictionary=scene.courtyard_plan.snapshot()
	await shot("move-saved")
	# A second drag operates on the adopted bridge, not the deleted old mesh.
	center.z-=.15
	await drag(center,center+Vector3(0,0,4))
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Whole move rejects unsupported banks")
	expect(scene.farm_state.snapshot().layout==moved_layout,"Invalid whole move retains the saved crossing")
	builder.cancel_draft();await frames()
	expect(environment.get_bridge()==preview and preview.visible,"Cancel restores the adopted bridge")
	# Undo must restore endpoints without reverting later inventory.
	var state: Dictionary=scene.farm_state.snapshot();state.inventory.greens+=2;scene.farm_state.restore_snapshot(state);now+=120
	await click(builder._undo)
	while builder.busy: await process_frame
	expect(scene.courtyard_plan.snapshot()==saved.layout,"Undo restores both bridge ends")
	expect(scene.farm_state.snapshot().inventory==state.inventory,"Whole-bridge undo preserves subsequent inventory")
	await terrain_ready()
	center.z+=.15
	await drag(center,center+Vector3(0,0,-.15))
	if not await ready_draft(): return
	# Restore normal state after real save failure, then finish the same draft once.
	var directory: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("move-blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("move-blocker/child")
	await click(builder._confirm)
	while builder.busy: await process_frame
	expect(scene.courtyard_plan.snapshot()==saved.layout and builder._status.text.contains("未能保存"),"Whole-bridge save failure leaves prior crossing intact and draft retryable")
	scene.store.directory=directory
	var wanted: Dictionary=builder.draft.duplicate(true)
	await click(builder._panel.find_child("Finish",true,false))
	while builder.busy: await process_frame
	expect(not builder.active and scene.courtyard_plan.snapshot()==wanted,"One Finish retries, saves and exits whole-bridge editing")
	await terrain_ready();await inspect_bridge()
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout;await choose_tool("bridge")
	scene.camera.focus_point=Vector3(4,.13,0);await frames(10)
	builder._bridge_style.select(0);builder._bridge_style.item_selected.emit(0)
	if not await ready_draft(): return
	expect(builder.bridge_preview.structure.get_meta("bridge_style")==0 and scene.courtyard_plan.construction.bridge[5]==1,"Bridge style changes the live preview before saving")
	await shot("move-flat-preview")
	if not await apply(): return
	await terrain_ready()
	wanted=scene.courtyard_plan.snapshot()
	expect(wanted.construction.bridge[5]==0,"Flat style commits through the same local save")
	await click(builder._panel.find_child("Finish",true,false));await inspect_bridge()
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(directory);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.courtyard_plan.snapshot()==wanted,"Reopening restores the whole bridge at the moved endpoints and selected style")
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout;await choose_tool("bridge")
	root.size=Vector2i(960,640);await frames()
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Bridge snap control fits the minimum window")
	await shot("move-small-window")
