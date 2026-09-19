extends SceneTree
const Plan=preload("res://layout/courtyard_plan.gd")
const Construction=preload("res://layout/island_construction.gd")
const Store=preload("res://farm/farm_store.gd")
const Settings=preload("res://settings/settings_store.gd")
var scene: Node3D
var folder: String
var failures: Array[String]=[]
var checks: int=0

func _initialize() -> void: _run.call_deferred()
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message);push_error(message)

func frames(count: int=3) -> void:
	for i: int in count: await physics_frame;await process_frame

func mouse(point: Vector2, pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=pressed
	event.window_id=root.get_window_id()
	root.push_input(event,true);await frames()

func click(control: Control) -> void:
	var p: Vector2=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=p;motion.window_id=root.get_window_id()
	root.push_input(motion,true);await frames()
	await mouse(p,true);await mouse(p,false)

func drag(a: Vector3,b: Vector3) -> void:
	var start: Vector2=scene.camera.unproject_position(a);var end: Vector2=scene.camera.unproject_position(b)
	var hover:=InputEventMouseMotion.new();hover.position=start;hover.window_id=root.get_window_id();root.push_input(hover,true);await frames()
	await mouse(start,true)
	var event:=InputEventMouseMotion.new();event.position=end;event.relative=end-start;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	event.window_id=root.get_window_id()
	root.push_input(event,true);await frames();await mouse(end,false)

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))

func apply() -> bool:
	var old: Node=scene
	var expected: Dictionary=scene.island_builder.candidate.snapshot()
	await click(scene.island_builder._confirm)
	var start: int=Time.get_ticks_msec()
	while is_instance_valid(old) and root.get_node_or_null("FarmExperience")==old:
		await create_timer(.1).timeout
		if not old.island_builder.busy:
			if old.farm_state.snapshot().layout==expected: return true
			expect(false,"Construction accepted: "+old.island_builder._status.text)
			return false
		if Time.get_ticks_msec()-start>45000:
			expect(false,"Construction rebuild timeout");return false
	scene=root.get_node("FarmExperience")
	await frames(5)
	expect(scene.island_builder.active,"Construction resumes after scene replacement")
	return true

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/island-construction-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder)
	print("EVIDENCE "+folder)
	var base: Dictionary=Plan.new().snapshot()
	var bad: Dictionary=base.duplicate(true);bad.construction.land=[[30,30,1,1]]
	expect(Plan.from_snapshot(bad)==null,"Out of range land rejected")
	bad=base.duplicate(true);bad.construction.land=[[12,12,2,2]]
	expect(Plan.from_snapshot(bad)==null,"Detached island patch rejected")
	bad=base.duplicate(true);bad.construction.ducks.count=13
	expect(Plan.from_snapshot(bad)==null,"Population bound enforced")
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene
	await frames(8)
	scene.atmosphere.set_preview_hour(11)
	var crops: Dictionary=scene.farm_state.snapshot().fields
	await shot("00-entry")
	print("ENTRY ",root.get_visible_rect()," ",scene.hud.get_node("Layout/BuildIsland").get_global_rect()," ",scene._loaded," ",scene._save_failed)
	await click(scene.hud.get_node("Layout/BuildIsland"))
	print("ENTRY_AFTER ",scene.island_builder.active," hovered=",root.gui_get_hovered_control())
	expect(scene.island_builder.active,"Real HUD click enters in-world construction")
	if not scene.island_builder.active: await finish();return
	await create_timer(1).timeout
	await frames();await shot("01-original")
	await drag(Vector3(0,.13,6),Vector3(2,.13,8))
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
	root.push_input(escape,true);await frames()
	expect(scene.island_builder.active and scene.island_builder.draft==scene.farm_state.snapshot().layout,"Escape cancels only the pending draft")
	await drag(Vector3(0,.13,6),Vector3(3,.13,8.5))
	expect(scene.island_builder.draft.construction.land.size()>1,"World drag creates connected brush samples")
	expect(scene.farm_state.snapshot().layout.construction.land.is_empty(),"Preview does not mutate farm")
	await shot("02-land-preview")
	if not await apply(): await finish();return
	expect(scene.courtyard_plan.land_bounds().end.y>=8.5,"Committed land reaches dragged shore")
	expect(scene.farm_state.snapshot().fields==crops,"Construction preserves crop state")
	await shot("03-land-built")
	await click(scene.island_builder._tools.trellis)
	scene.island_builder._values.width.value=.8
	scene.island_builder._values.height.value=2.4
	await drag(Vector3(-5.8,.13,3.375),Vector3(-5.8,.13,3.5))
	expect(scene.island_builder.draft.construction.trellis[0]>4.65,"Direct trellis drag changes length")
	await shot("04-trellis-preview")
	if not await apply(): await finish();return
	var trellis: Node3D=scene.get_node("Environment/EntranceTrellis")
	expect(trellis.has_meta("post_count") and trellis.get_meta("post_count")==12,"Longer trellis adds real posts")
	await shot("05-trellis-built")
	await click(scene.island_builder._tools.bridge)
	var ends: Array[Vector3]=Construction.bridge_points(scene.courtyard_plan)
	await drag(ends[1],Vector3(8,.13,3))
	expect(scene.island_builder._confirm.disabled,"Unsupported bridge endpoint cannot be committed")
	scene.island_builder.cancel_draft()
	await drag(ends[1],Vector3(11.0,.13,.1))
	expect(not scene.island_builder.draft.construction.bridge.is_empty(),"Direct bridge endpoint drag creates adaptive bridge")
	print("BRIDGE_ISSUE "+scene.island_builder.issue())
	await shot("06-bridge-preview")
	if not await apply(): await finish();return
	expect(scene.has_node("Environment/AdaptiveBridge"),"Adaptive bridge appears after save")
	await shot("07-bridge-built")
	await click(scene.island_builder._tools.ducks)
	scene.island_builder._values.count.value=6
	await drag(Vector3(-12,.13,4),Vector3(-8,.13,10))
	print("DUCK_ISSUE "+scene.island_builder.issue())
	await shot("08-ducks-preview")
	if not await apply(): await finish();return
	var animals: Node3D=scene.get_node("Environment/CourtyardAnimals")
	var positions: Dictionary={};var duck_count: int=0
	for bird: Dictionary in animals.birds:
		if bird.kind=="duck": duck_count+=1;positions[bird.node.name]=bird.position
	expect(duck_count==6,"Requested six live ducks spawned")
	expect(scene.island_builder.issue().is_empty(),"Restored construction opens after animal space is ready")
	await create_timer(8).timeout
	var moved: bool=false
	for bird: Dictionary in animals.birds:
		if bird.kind=="duck":
			moved=moved or bird.position.distance_to(positions[bird.node.name])>.05
			expect(bird.space.contains(bird.position),"Duck stays inside valid chosen water")
	expect(moved,"Placed ducks move autonomously")
	await shot("09-ducks-active")
	await flock_preview_checks()
	var saved: Dictionary=scene.farm_state.snapshot()
	var store:=Store.new(folder.path_join("farm"));var restored: Dictionary=store.load_state()
	expect(restored.ok and restored.farm==saved,"Full layout and animal identities survive disk reload")
	# An actual I/O failure must leave the durable and visible farm unchanged.
	var normal_path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	scene.island_builder._values.count.value=7
	await click(scene.island_builder._confirm)
	while scene.island_builder.busy: await frames()
	expect(scene.farm_state.snapshot()==saved,"Failed construction save leaves authoritative farm intact")
	expect(scene.island_builder._status.text.contains("未能保存"),"Failed save is visible and retryable")
	scene.store.directory=normal_path
	if not await apply(): await finish();return
	expect(scene.farm_state.snapshot().layout.construction.ducks.count==7,"Retry succeeds without duplicate construction")
	var old: Node=scene
	await click(scene.island_builder._undo)
	var start: int=Time.get_ticks_msec()
	while is_instance_valid(old) and root.get_node_or_null("FarmExperience")==old:
		await frames()
		if Time.get_ticks_msec()-start>45000: expect(false,"Undo timeout");await finish();return
	scene=root.get_node("FarmExperience");await frames(5)
	expect(scene.farm_state.snapshot().layout.construction.ducks.count==6,"Undo restores previous duck count")
	expect(scene.farm_state.snapshot().fields==crops,"Undo does not rewind or erase crops")
	scene.island_builder.finish()
	await shot("10-finished")
	# Reinstantiate the actual main scene, not only decode the store.
	var old_view: Dictionary=scene.farm_state.snapshot().layout
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(normal_path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene;await frames(6)
	expect(scene.courtyard_plan.snapshot()==old_view,"Reopening actual scene restores the complete construction")
	await shot("11-reopened")
	scene.atmosphere.set_preview_hour(11)
	for target: Dictionary in [{"name":"12-trellis-close","point":Vector3(-5.8,1,1),"view":Vector3(55,32,12)}, {"name":"13-bridge-close","point":Vector3(8,.3,0),"view":Vector3(24,35,14)}]:
		scene.camera.focus_point=target.point;scene.camera.view=target.view
		await frames(8);await shot(target.name)
	scene.atmosphere.set_preview_hour(22);await frames(15);await shot("14-bridge-night")
	root.size=Vector2i(960,640);await frames()
	scene._begin_construction("trellis");await frames()
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Construction panel fits minimum window")
	await shot("15-small-window")
	await finish()

func flock_preview_checks() -> void:
	var builder: Node=scene.island_builder
	expect(builder._preview.get_child_count()==1,"Unchanged flock shows only live ducks and area outline")
	builder._values.count.value=7;await frames()
	expect(builder._preview.get_child_count()==8,"Seven-duck draft has seven preview models and outline")
	for bird: Dictionary in scene.get_node("Environment/CourtyardAnimals").birds:
		if bird.kind=="duck": expect(not bird.node.visible,"Draft hides live duck to avoid doubled count")
	builder.cancel_draft();await frames()
	for bird: Dictionary in scene.get_node("Environment/CourtyardAnimals").birds:
		if bird.kind=="duck": expect(bird.node.visible,"Cancelling restores live duck visibility")
	expect(builder._preview.get_child_count()==1,"Cancel removes all temporary ducks")

func finish() -> void:
	if is_instance_valid(scene): root.remove_child(scene);scene.free()
	await frames()
	print("ISLAND_CONSTRUCTION checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
