extends "res://../tests/island_construction_test.gd"
const Flocks=preload("res://layout/flock_layout.gd")
var now: float=2000000.0

func ready_draft() -> bool:
	var builder: Node=scene.island_builder
	var start: int=Time.get_ticks_msec()
	while builder._layout_check_pending():
		await process_frame
		if Time.get_ticks_msec()-start>20000: expect(false,"Flock region check finishes");return false
	var issue: String=builder.issue()
	expect(issue.is_empty(),"Flock accepted: "+issue)
	return issue.is_empty()

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/flock-layout-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var plan:=Plan.new();var construction: Dictionary=Construction.initial()
	construction.land=[[-3,5,5,5]];plan.apply_construction(construction)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=plan
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8);scene.atmosphere.set_preview_hour(11)
	var animals: Node3D=scene.get_node("Environment/CourtyardAnimals")
	var scene_id: int=scene.get_instance_id();var originals: Dictionary={}
	for bird: Dictionary in animals.birds: originals[String(bird.node.name)]=bird.node
	var snapshot: Dictionary=scene.farm_state.snapshot()
	for identity: String in ["YardHen1","LakeGoose1"]:
		snapshot.animals[identity].name="留下的名字";snapshot.animals[identity].visits=4;snapshot.animals[identity].shared=2;snapshot.animals[identity].revision=6
	expect(scene.farm_state.restore_snapshot(snapshot),"Named hens and geese fixture")
	animals.interaction.profiles=snapshot.animals.duplicate(true)
	if OS.get_cmdline_user_args().has("--edges-only"):
		await edges(animals);await finish();return
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	var builder: Node=scene.island_builder
	await choose_tool("hen")
	expect(builder.tool=="hen" and builder._rows.count.visible,"Hen catalog opens a working region editor")
	builder._values.count.value=4
	await drag(Vector3(-2,.13,6),Vector3(1,.13,9))
	if not await ready_draft(): await shot("hen-invalid");await finish();return
	expect(builder.draft.construction.flocks.hen.area==[-2.0,6.0,3.0,3.0],"Hen region uses the visible ground-plane drag")
	var adopted: Node3D=builder.flock_preview.models.YardHen4
	await shot("01-hens-preview")
	if not await apply(): await finish();return
	expect(scene.get_instance_id()==scene_id and animals.interaction.find("YardHen4").node==adopted,"Hen commit adopts new model without reloading")
	expect(animals._hens.size()==4 and animals._swimmers.size()==5,"Hen count does not change waterfowl")
	for identity: String in originals: expect(animals.interaction.find(identity).node==originals[identity],"Existing animal retained: "+identity)
	expect(scene.farm_state.snapshot().animals.YardHen1==snapshot.animals.YardHen1,"Hen identity and interaction history retained")
	var before_area: Array=builder.draft.construction.flocks.hen.area.duplicate()
	await drag(Vector3(-.5,.13,7.5),Vector3(0,.13,7.5))
	expect(builder.draft.construction.flocks.hen.area==[-1.5,6.0,3.0,3.0],"Dragging inside moves the whole region")
	builder.cancel_draft();await frames()
	expect(builder.draft.construction.flocks.hen.area==before_area and animals.preview_kind.is_empty(),"Cancel restores hen region and motion")
	# Four visible corner handles resize around the opposite corner.
	await drag(Vector3(-2,.21,6),Vector3(-2.5,.13,5.5))
	expect(builder._flock_gesture=="resize","Hen corner hits resize instead of redraw")
	if not await ready_draft(): await finish();return
	expect(builder.draft.construction.flocks.hen.area==[-2.5,5.5,3.5,3.5],"Corner resize keeps the opposite corner fixed")
	if not await apply(): await finish();return
	var saved_hens: Dictionary=scene.farm_state.snapshot()
	await click(builder._panel.find_child("DrawFlock",true,false))
	await drag(Vector3(-12,.13,4),Vector3(-8,.13,8))
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Hen region rejects open water")
	builder.cancel_draft()
	await choose_tool("goose")
	expect(builder.tool=="goose" and builder._values.count.max_value==8,"Goose editor has its own population limit")
	builder._values.count.value=4
	await drag(Vector3(4,-.25,10),Vector3(8,-.25,14))
	if not await ready_draft(): await shot("goose-invalid");await finish();return
	await shot("02-geese-preview")
	var expected: Dictionary=builder.draft.duplicate(true)
	var prior: Dictionary=scene.farm_state.snapshot();var usual: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	await click(builder._confirm)
	while builder.busy: await process_frame
	expect(scene.farm_state.snapshot()==prior and animals.interaction.find("LakeGoose4").is_empty(),"Failed goose save preserves live count and authority")
	expect(builder._status.text.contains("未能保存") and is_instance_valid(builder.flock_preview),"Failed goose save remains retryable")
	scene.store.directory=usual
	if not await apply(): await finish();return
	expect(scene.get_instance_id()==scene_id and animals._swimmers.size()==7,"Goose region commits in place")
	expect(scene.farm_state.snapshot().layout==expected and scene.farm_state.snapshot().animals.LakeGoose1==snapshot.animals.LakeGoose1,"Goose region and identity saved")
	var positions: Dictionary={}
	for bird: Dictionary in animals.birds: positions[String(bird.node.name)]=bird.position
	await create_timer(9).timeout
	for kind: String in ["hen","goose"]:
		var moved: bool=false
		for bird: Dictionary in animals.birds:
			if bird.kind!=kind: continue
			moved=moved or bird.position.distance_to(positions[String(bird.node.name)])>.06
			expect(bird.space.contains(bird.position),"Animal remains in actual clear region: "+String(bird.node.name))
		expect(moved,"Autonomous activity resumes: "+kind)
	await shot("03-flocks-active")
	# One Finish waits for the real private region worker, then returns control.
	await drag(Vector3(6,-.25,12),Vector3(6.5,-.25,12))
	if not await ready_draft(): await finish();return
	var pending: Node3D=builder.flock_preview
	pending._space=null;pending._due=0;pending.pending=true;pending._process(0)
	expect(pending._worker!=null,"Real flock check is running before Finish")
	expected=builder.draft.duplicate(true)
	await click(builder._panel.find_child("Finish",true,false))
	while builder.busy: await process_frame
	expect(not builder.active and scene.farm_state.snapshot().layout==expected,"Single Finish completes the current region and exits")
	# Removing all geese preserves archived identities and unrelated flocks.
	scene._begin_construction("goose");await create_timer(1).timeout
	builder._values.count.value=0
	if not await apply(): await finish();return
	expect(animals._swimmers.size()==3 and animals._hens.size()==4,"Zero geese retains hens and ducks")
	now+=120
	var after: Dictionary=scene.farm_state.snapshot();after.inventory.greens+=2;scene.farm_state.restore_snapshot(after)
	await choose_tool("land");await click(builder._undo)
	while builder.busy: await process_frame
	expect(animals._swimmers.size()==7 and scene.farm_state.snapshot().animals.LakeGoose1==snapshot.animals.LakeGoose1,"Cross-tool undo restores goose identities")
	expect(scene.farm_state.snapshot().inventory==after.inventory,"Undo keeps subsequent inventory")
	await choose_tool("hen");await click(builder._panel.find_child("ResetFlock",true,false))
	if not await apply(): await finish();return
	expect(animals.flock_spaces.hen==animals.yard and scene.farm_state.snapshot().layout.construction.flocks.hen.area.is_empty(),"Free activity restores full valid land space")
	await click(builder._undo)
	while builder.busy: await process_frame
	expect(scene.farm_state.snapshot().layout.construction.flocks.hen==saved_hens.layout.construction.flocks.hen,"Undo restores hen boundary")
	builder.finish();await create_timer(1).timeout
	# Opposing close views reveal actual feet and waterline contacts.
	scene.focus_detail.set_depth_of_field(false,0)
	scene.camera.focus_point=Vector3(-.5,.13,7.2);scene.camera.view=Vector3(35,25,8);await frames(15);await shot("04-hens-front")
	scene.camera.view=Vector3(215,25,8);await frames(15);await shot("05-hens-back")
	scene.camera.focus_point=Vector3(6,-.25,12);scene.camera.view=Vector3(35,25,10);await frames(15);await shot("06-geese-front")
	scene.camera.view=Vector3(215,25,10);await frames(15);await shot("07-geese-back")
	var saved: Dictionary=scene.farm_state.snapshot()
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.store=Store.new(usual);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float:return now
	root.add_child(scene);current_scene=scene;await frames(8)
	animals=scene.get_node("Environment/CourtyardAnimals")
	expect(scene.farm_state.snapshot().layout==saved.layout and scene.farm_state.snapshot().animals==saved.animals,"Reopen restores all flock parameters and histories")
	expect(animals._hens.size()==4 and animals._swimmers.size()==7,"Reopen restores all populations")
	scene._begin_construction("hen");await create_timer(1).timeout;root.size=Vector2i(960,640);await frames()
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Animal editor fits small window")
	scene.atmosphere.set_preview_hour(22);await frames(12);await shot("08-small-night")
	await finish()

func edges(animals: Node3D) -> void:
	scene._begin_construction("hen");await create_timer(1).timeout
	var builder: Node=scene.island_builder
	for kind: String in ["hen","goose","duck"]:
		await choose_tool("ducks" if kind=="duck" else kind)
		builder._values.count.value=Flocks.SPECIES[kind].limit
		if not await ready_draft() or not await apply(): return
	expect(animals.birds.size()==28 and animals._hens.size()==8 and animals._swimmers.size()==20,"All species maximum populations coexist")
	for bird: Dictionary in animals.birds: expect(bird.space.contains(bird.position),"Maximum population stays on valid habitat: "+String(bird.node.name))
	await shot("09-max-population")
	await choose_tool("hen");builder._values.count.value=4
	var before: Dictionary=builder.draft.duplicate(true)
	await mouse(scene.camera.unproject_position(Vector3(-2,.13,6)),true)
	var motion:=InputEventMouseMotion.new();motion.window_id=root.get_window_id();motion.position=scene.camera.unproject_position(Vector3(1,.13,9));motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true);await frames();scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(builder.draft==before,"Focus loss cancels only held hen-region gesture")
	await drag(Vector3(-2,.13,6),Vector3(1,.13,9))
	if not await ready_draft(): return
	var pending: Node3D=builder.flock_preview
	pending._space=null;pending._due=0;pending.pending=true;pending._process(0)
	expect(pending._worker!=null,"Private hen region worker starts")
	builder.cancel_draft();builder.choose("goose");builder._values.count.value=4
	await drag(Vector3(4,-.25,10),Vector3(8,-.25,14))
	if not await ready_draft(): return
	expect(builder.flock_preview.kind=="goose" and animals.preview_kind=="goose","Retired hen worker cannot replace new goose preview")
	if not await apply(): return
	await choose_tool("hen");builder._values.count.value=4
	await drag(Vector3(-2,.13,6),Vector3(1,.13,9))
	if not await ready_draft() or not await apply(): return
	var environment: Node3D=scene.get_node("Environment")
	var old_yard: RefCounted=animals.yard
	environment.refresh_terrain(false)
	builder._values.count.value=5
	expect(builder.flock_preview.pending and not animals.yard_ready,"Hens wait for the actual running terrain navigation refresh")
	var expected: Dictionary=builder.draft.duplicate(true)
	var start: int=Time.get_ticks_msec()
	await click(builder._panel.find_child("Finish",true,false))
	while builder.busy:
		await process_frame
		if Time.get_ticks_msec()-start>25000: expect(false,"Hen Finish completes after terrain update");return
	print("HEN_TERRAIN_FINISH_MS ",Time.get_ticks_msec()-start)
	expect(not builder.active and scene.farm_state.snapshot().layout==expected,"One Finish saves hens after the current terrain refresh")
	expect(animals.yard!=old_yard and animals.interaction.find("YardHen5").space==animals.flock_spaces.hen,"Hens use the latest real ground navigation")
	while environment._terrain_refreshing: await process_frame
	for bird: Dictionary in animals.birds:
		if bird.kind=="hen": expect(bird.space.contains(bird.position),"Hens remain valid after background replacement")
	# Waterfowl must yield even when one uses the whole lake and one a region.
	var duck: Dictionary=animals.interaction.find("LakeDuck1");var goose: Dictionary=animals.interaction.find("LakeGoose1")
	var at: Vector2=goose.space.nearest(Vector2(6,12));var target: Vector2=at+Vector2(.8,0)
	expect(duck.space!=goose.space and duck.space.contains(at) and goose.space.contains(target),"Cross-species avoidance fixture uses distinct valid navigation spaces")
	duck.position=at;goose.position=target;duck.node.position.x=at.x;duck.node.position.z=at.y;goose.node.position.x=target.x;goose.node.position.z=target.y
	duck.route=PackedVector2Array([target]);duck.waypoint=0;duck.state="swim";duck.timer=100;duck.heading=PI/2;duck.buddy=null
	goose.route=PackedVector2Array();goose.state="rest";goose.timer=100;goose.velocity=Vector2.ZERO
	var safe: bool=true
	for i: int in 120:
		animals._advance(duck,1.0/30);animals._advance(goose,1.0/30)
		if duck.position.distance_to(goose.position)<duck.radius+goose.radius-.001: safe=false
	expect(safe,"Duck and goose avoid overlap across different region grids")
	# New plants may not fill an existing goose region even away from current birds.
	var plant_plan: RefCounted=Plan.from_snapshot(scene.farm_state.snapshot().layout)
	for y: int in 7:
		for x: int in 7:
			plant_plan.plants.append({"id":y*7+x+1,"kind":"lotus","pose":[4.3+x*.55,10.3+y*.55,0.0,1.0]})
	var preview=preload("res://presentation/plant_layout_preview.gd").new();scene.add_child(preview);preview.configure(scene);preview.update(plant_plan)
	expect(not preview.message.is_empty(),"Plant preview rejects covering active goose habitat")
	preview.free()
	scene._begin_construction("hen");await create_timer(1).timeout
	await click(builder._panel.find_child("DrawFlock",true,false))
	await drag(Vector3(-2,.13,6),Vector3(0,.13,8))
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Insufficient hen density is visibly rejected")
	builder.cancel_draft()
	# One crowded region with adequate raw area but insufficient usable space.
	builder._values.count.value=1
	await click(builder._panel.find_child("DrawFlock",true,false))
	await drag(Vector3(-1,.13,-4),Vector3(1,.13,-2))
	while builder._layout_check_pending(): await process_frame
	expect(not builder.issue().is_empty() and builder._confirm.disabled,"Building-obstructed hen region is visibly rejected")
	builder.cancel_draft();await shot("10-regions-retained")
	await choose_tool("fields")
	await click(builder._field_actions.get_node("AddField"))
	await drag(Vector3(-1.5,.13,7),Vector3(1,.13,9))
	while builder.field_preview.pending: await process_frame
	if not builder.issue().contains("鸡群"):
		print("FIELD_GUARD_DETAILS ",preload("res://layout/courtyard_circulation.gd").field_placement_issues(builder.candidate,environment.layout_obstacles))
	expect(builder._confirm.disabled and builder.issue().contains("鸡群"),"Actual field preview refuses consuming the saved hen region: "+builder.issue())
	builder.cancel_draft()
	if not failures.is_empty(): await shot("field-failure")
	builder.finish();await create_timer(1).timeout
	scene.focus_detail.set_depth_of_field(false,0)
	scene.camera.focus_point=Vector3(6,-.25,12);scene.camera.view=Vector3(35,25,10);await frames(15);await shot("11-geese-contact-front")
	scene.camera.view=Vector3(215,25,10);await frames(15);await shot("12-geese-contact-back")
