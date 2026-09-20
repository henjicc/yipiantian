extends "res://../tests/island_construction_test.gd"
var now: float=2000000.0

func ready_draft() -> bool:
	var start: int=Time.get_ticks_msec()
	while is_instance_valid(scene.island_builder.flock_preview) and scene.island_builder.flock_preview.pending:
		await process_frame
		if Time.get_ticks_msec()-start>20000: expect(false,"Water check finishes");return false
	var issue: String=scene.island_builder.issue()
	expect(issue.is_empty(),"Usable flock region: "+issue)
	return issue.is_empty()

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/duck-layout-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	var animals: Node3D=scene.get_node("Environment/CourtyardAnimals")
	var original_nodes: Dictionary={}
	for bird: Dictionary in animals.birds: original_nodes[String(bird.node.name)]=bird.node
	var water: RefCounted=animals.water
	var yard: RefCounted=animals.yard
	var scene_id: int=scene.get_instance_id()
	var snapshot: Dictionary=scene.farm_state.snapshot()
	snapshot.animals.LakeDuck1.name="留住小满";snapshot.animals.LakeDuck1.visits=3;snapshot.animals.LakeDuck1.revision=3;snapshot.animals.LakeDuck1.preference=3
	expect(scene.farm_state.restore_snapshot(snapshot),"Fixture retains individual name, visits and rest preference")
	animals.interaction.profiles=snapshot.animals.duplicate(true)
	if OS.get_cmdline_user_args().has("--edges-only"):
		await edges(animals);await finish();return
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	await choose_tool("ducks")
	var builder: Node=scene.island_builder
	builder._values.count.value=6
	var models: Dictionary=builder.flock_preview.models.duplicate()
	var start: Vector2=scene.camera.unproject_position(Vector3(-12,-.25,4))
	await mouse(start,true)
	for point: Vector3 in [Vector3(-8,-.25,9),Vector3(-8,-.25,9.5),Vector3(-8,-.25,10)]:
		var event:=InputEventMouseMotion.new();event.position=scene.camera.unproject_position(point);event.button_mask=MOUSE_BUTTON_MASK_LEFT
		event.window_id=root.get_window_id()
		var before: int=Time.get_ticks_usec();root.push_input(event,true)
		print("DUCK_POINTER_US ",Time.get_ticks_usec()-before);await frames()
	expect(is_instance_valid(builder.flock_preview) and builder.flock_preview.models.LakeDuck1==models.LakeDuck1,"Continuous area dragging reuses displayed duck models")
	expect(scene.farm_state.snapshot()==snapshot,"Held water-region draft does not publish state")
	await mouse(scene.camera.unproject_position(Vector3(-8,-.25,10)),false)
	if not await ready_draft(): await finish();return
	await shot("01-six-preview")
	var preview_node: Node3D=builder.flock_preview.models.LakeDuck6
	if not await apply(): await finish();return
	expect(scene.get_instance_id()==scene_id,"Flock save retains the actual main scene")
	expect(animals.water==water and animals.yard==yard,"Region change reuses full water and land navigation")
	expect(animals.birds.size()==10 and animals.interaction.find("LakeDuck6").node==preview_node,"Only new ducks are adopted from preview")
	for id: String in original_nodes: expect(animals.interaction.find(id).node==original_nodes[id],"Existing animal retained: "+id)
	expect(scene.farm_state.snapshot().animals.LakeDuck1==snapshot.animals.LakeDuck1,"Name, visits and preferences survive area change")
	var positions: Dictionary={}
	for bird: Dictionary in animals.birds:
		if bird.kind=="duck": positions[String(bird.node.name)]=bird.position
	await create_timer(8).timeout
	var moved: bool=false
	for bird: Dictionary in animals.birds:
		if bird.kind!="duck": continue
		moved=moved or bird.position.distance_to(positions[String(bird.node.name)])>.05
		expect(bird.space.contains(bird.position),"Saved duck stays on usable water")
	expect(moved,"Saved flock moves autonomously")
	await shot("02-six-active")
	await flock_preview_checks()
	var six: Dictionary=scene.farm_state.snapshot()
	var region: RefCounted=animals.flock_spaces.duck
	var usual: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	builder._values.count.value=7
	await click(builder._confirm)
	while builder.busy: await process_frame
	expect(scene.farm_state.snapshot()==six and animals.birds.size()==10,"Failed save changes neither authority nor live population")
	expect(builder._status.text.contains("未能保存") and is_instance_valid(builder.flock_preview),"Failed save keeps retryable preview")
	scene.store.directory=usual
	if not await apply(): await finish();return
	expect(animals.flock_spaces.duck==region,"Count-only save reuses the baked region")
	# Removing a followed individual must clear live cross-bird node references.
	animals.interaction.find("LakeGoose1").buddy=animals.interaction.find("LakeDuck7").node
	now+=120
	var state: Dictionary=scene.farm_state.snapshot();state.inventory.greens+=2
	expect(scene.farm_state.restore_snapshot(state),"Inventory changes after construction")
	await choose_tool("land")
	await click(builder._undo)
	while builder.busy: await process_frame
	expect(scene.get_instance_id()==scene_id and animals.birds.size()==10,"Cross-tool undo changes count in place")
	expect(animals.interaction.find("LakeGoose1").buddy==null,"Removing a duck clears companions following it")
	expect(scene.farm_state.snapshot().inventory==state.inventory,"Construction undo retains later inventory")
	await choose_tool("ducks")
	# Cancel an active worker, then edit another region; late results cannot apply.
	builder._flock_redraw=true
	await drag(Vector3(-12,-.25,4),Vector3(-8,-.25,9.5))
	builder.cancel_draft()
	builder._flock_redraw=true
	await drag(Vector3(-12,-.25,4),Vector3(-8,-.25,9))
	if not await ready_draft(): await finish();return
	expect(builder.flock_preview.validated.construction.flocks.duck.area==builder.draft.construction.flocks.duck.area,"Late cancelled water check cannot overwrite new draft")
	builder.cancel_draft();await frames()
	expect(not (animals.preview_kind=="duck") and original_nodes.LakeDuck1.visible,"Cancel restores original animals and motion")
	# A single Finish also waits for the current private check and exits.
	builder._flock_redraw=true
	await drag(Vector3(-12,-.25,4),Vector3(-8,-.25,9.5))
	var finished: Dictionary=builder.draft
	var before: int=Time.get_ticks_msec()
	await click(builder._panel.find_child("Finish",true,false))
	while builder.busy: await process_frame
	print("DUCK_FINISH_MS ",Time.get_ticks_msec()-before)
	expect(not builder.active and scene.farm_state.snapshot().layout==finished,"One Finish saves the latest region and exits")
	await shot("03-finished")
	scene._begin_construction("ducks");await create_timer(1).timeout
	builder._values.count.value=0
	if not await apply(): await finish();return
	expect(animals.birds.size()==4 and animals._swimmers.size()==2,"Zero ducks keeps geese and hens only")
	await click(builder._undo)
	while builder.busy: await process_frame
	expect(animals.birds.size()==10 and animals.interaction.profiles.LakeDuck1.visits==3,"Undo zero restores stable duck identities")
	builder.finish();await frames()
	var saved: Dictionary=scene.farm_state.snapshot()
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(usual);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.farm_state.snapshot().layout==saved.layout,"Reopening restores exact flock parameters")
	animals=scene.get_node("Environment/CourtyardAnimals")
	expect(animals.birds.size()==10 and animals.interaction.profiles.LakeDuck1==saved.animals.LakeDuck1,"Reopening restores count and individual history")
	expect(animals.flock_spaces.duck.resting.size()==4,"Every offered rest preference has a valid point")
	scene.atmosphere.set_preview_hour(22);await frames(10);await shot("04-reopened-night")
	await finish()

func edges(animals: Node3D) -> void:
	scene._begin_construction("ducks");await create_timer(1).timeout
	var builder: Node=scene.island_builder
	var original: Dictionary=scene.farm_state.snapshot()
	builder._values.count.value=12
	if not await apply(): return
	expect(animals.birds.size()==16,"Maximum flock appears without replacing geese or hens")
	for bird: Dictionary in animals.birds:
		if bird.kind=="duck": expect(bird.space.contains(bird.position),"Maximum flock has valid water positions")
	# Cached bind data must produce the same local beak on separate scaled rigs.
	var first: Dictionary=animals.interaction.find("LakeDuck1")
	var third: Dictionary=animals.interaction.find("LakeDuck3")
	var pose=preload("res://scenes/environment/bird_pose.gd").new()
	pose.root=third.node;pose.skeleton=third.pose.skeleton;pose.species="duck";pose.rests=third.pose.rests;pose.head=third.pose.head
	pose._find_beak(third.node)
	expect(pose.beak_rest.is_equal_approx(third.pose.beak_rest) and pose.beak_bindings==third.pose.beak_bindings,"Cached geometry matches direct extraction on smaller duck")
	expect(first.pose.skeleton!=third.pose.skeleton,"Cached geometry keeps independent animated skeletons")
	builder._values.count.value=6
	var before_drag: Dictionary=builder.draft.duplicate(true)
	await mouse(scene.camera.unproject_position(Vector3(-12,-.25,4)),true)
	var event:=InputEventMouseMotion.new();event.position=scene.camera.unproject_position(Vector3(-8,-.25,10));event.button_mask=MOUSE_BUTTON_MASK_LEFT
	event.window_id=root.get_window_id();root.push_input(event,true);await frames()
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(builder.draft==before_drag,"Focus loss restores only the unfinished area gesture")
	builder.cancel_draft();await frames()
	expect(not (animals.preview_kind=="duck") and first.node.visible,"Cancelled preview restores visibility and motion")
	builder._values.count.value=6
	builder._flock_redraw=true
	await drag(Vector3(-2,-.25,0),Vector3(2,-.25,5))
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Land cannot become a waterfowl region")
	expect(scene.farm_state.snapshot().layout.construction.flocks.duck.count==12,"Invalid region does not change the live flock")
	builder.cancel_draft();builder._values.count.value=6
	builder._flock_redraw=true
	await drag(Vector3(-12,-.25,4),Vector3(-8,-.25,10))
	if not await apply(): return
	var environment: Node3D=scene.get_node("Environment")
	var old_water: RefCounted=animals.water
	var yard: RefCounted=animals.yard
	# Exercise the actual concurrent terrain worker, not a mocked pending flag.
	environment.refresh_terrain(true)
	builder._values.count.value=7
	expect(builder.flock_preview.pending and not animals.water_ready,"Flock waits for actual terrain water revision")
	var latest: Dictionary=builder.draft
	var before: int=Time.get_ticks_msec()
	await click(builder._panel.find_child("Finish",true,false))
	while builder.busy:
		await process_frame
		if Time.get_ticks_msec()-before>20000: expect(false,"Finish during terrain update completes");return
	print("DUCK_TERRAIN_FINISH_MS ",Time.get_ticks_msec()-before)
	expect(not builder.active and scene.farm_state.snapshot().layout==latest,"One Finish survives an outstanding terrain water update")
	expect(animals.water!=old_water and animals.yard!=yard and animals.interaction.find("LakeDuck7").space==animals.flock_spaces.duck,"Flock uses refreshed water, not stale worker output")
	for bird: Dictionary in animals.birds:
		if bird.kind=="duck": expect(bird.space==animals.flock_spaces.duck and bird.space.contains(bird.position),"All ducks use committed current region")
	await shot("05-water-update")
	while environment._terrain_refreshing: await process_frame
	expect(animals.ready_for_motion and animals.birds.size()==11,"Background terrain finish retains the committed population")
	expect(scene.farm_state.snapshot().fields==original.fields,"Flock and concurrent navigation preserve crops")
	# The adopted newcomer participates in the ordinary animal interaction UI.
	scene.camera.focus_point=animals.interaction.find("LakeDuck7").node.position;scene.camera.view=Vector3(45,35,10)
	await create_timer(1).timeout
	var bird: Dictionary=animals.interaction.find("LakeDuck7")
	var centre: Vector3=bird.node.global_position+Vector3.UP*.48*bird.node.scale.x
	await mouse(scene.camera.unproject_position(centre),true);await mouse(scene.camera.unproject_position(centre),false)
	expect(scene.animal_panel.active and scene.animal_panel.animal_id=="LakeDuck7","New duck opens its real interaction panel")
	await shot("06-new-duck-panel")
