extends SceneTree
const Store=preload("res://farm/farm_store.gd")
const Settings=preload("res://settings/settings_store.gd")
var scene: Node3D
var failures: Array[String]=[]
var folder: String
func _initialize() -> void: run.call_deferred()
func expect(ok: bool,label: String) -> void:
	if not ok: failures.append(label);push_error(label)
func shot(label: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func let_hens_leave(decor: Node, animals: Node, removing: bool=false) -> void:
	while not animals.ready_for_motion: await process_frame
	var candidate:=preload("res://farm/decoration_state.gd").new()
	candidate.restore_snapshot(decor.state.snapshot())
	if removing: candidate.remove(decor.selected_item)
	else: candidate.place(decor.selected_item,decor.preview_slot,decor.preview_turn,true)
	for step: int in 3600:
		var issue: String=decor._restoration_issue(candidate.snapshot())
		if issue.is_empty() and not removing: issue=decor.placement_issue(decor._preview,decor.selected_item,decor.preview_slot)
		if issue.is_empty(): return
		if not issue.begins_with("小鸡"): expect(false,"Unexpected placement refusal: "+issue);return
		animals._process(1.0/30)
	expect(false,"Chicken leaves restored scenery footprint naturally")
func click(control: Control) -> void:
	await process_frame
	var point: Vector2=control.get_global_rect().get_center()
	await click_at(point)
func click_at(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.window_id=root.get_window_id();root.push_input(motion,true)
	await process_frame
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.window_id=root.get_window_id();root.push_input(event,true)
		await process_frame
func run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/living-decor-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate()
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("preferences"))
	root.add_child(scene)
	await process_frame
	var animals: Node=scene.get_node("Environment/CourtyardAnimals")
	while not animals.ready_for_motion: await process_frame
	for frame: int in 8: await physics_frame;await process_frame
	animals.set_process(false)
	var original_water: RefCounted=animals.water
	# A lathe without indices must survive merging with an indexed cylinder.
	var living: Node=scene.get_node("Environment/LivingDetails")
	var group:=Node3D.new()
	var profile: Array[Vector2]=[Vector2(.1,0),Vector2(.2,.3)]
	living._lathe(group,Vector3.ZERO,profile,living._clay)
	living._beam(group,Vector3.ZERO,Vector3.UP,.04,living._clay)
	var vertices: int=0
	for mesh: MeshInstance3D in group.get_children(): vertices+=mesh.mesh.get_faces().size()
	living._merge_static_group(group)
	expect(group.get_child(0).mesh.get_faces().size()==vertices,"Merging preserves indexed and non-indexed triangles")
	group.free()
	var fixture: Dictionary=scene.farm_state.snapshot()
	fixture.harvested.greens=20;fixture.harvested.radish=20;fixture.harvested.spinach=20;fixture.inventory.radish=4
	scene.farm_state.restore_snapshot(fixture)
	scene.farm_state.kitchen_action("start",{"recipe":"root_dry","crop":"radish"},0,1000)
	scene.farm_state.kitchen_action("collect",{"station":"rack"},1,1090)
	scene.farm_state.kitchen_action("share",{"recipe":"root_dry","neighbor":"willow"},2,1090)
	scene.decoration_state.unlock(fixture.harvested,scene.farm_state.snapshot().kitchen)
	scene._save_farm()
	var decor: Node=scene.decoration_layout
	decor.bind_state(scene.decoration_state)
	scene.atmosphere.set_preview_hour(14)
	scene._begin_decoration()
	await create_timer(1).timeout
	expect(decor.active,"Legacy arrangement entry opens its controller")
	print("LIVING_ENTRY active=",decor.active," loaded=",scene._loaded," saving=",scene._save_failed," focused=",root.has_focus())
	await shot("menu")
	for item: String in ["bench","drying_rack","tea_table"]:
		await click(decor.hud._items[item])
		var chosen: String=""
		for slot: String in ["ground_01","ground_02","ground_03","ground_04"]:
			if not decor.state.can_place(item,slot,0).ok: continue
			await click_at(scene.camera.unproject_position(decor._rings[slot].global_position))
			if decor._preview==null or decor.preview_slot!=slot: continue
			var issue: String=decor.placement_issue(decor._preview,item,slot)
			print("SITE item=",item," slot=",slot," at=",decor._preview.global_position," issue=",issue)
			if issue.is_empty(): chosen=slot;break
		expect(not chosen.is_empty(),"Available reachable site for "+item)
		if chosen.is_empty(): continue
		if item=="bench":
			var before: Dictionary=scene.decoration_state.snapshot()
			var pending: String=scene.store.directory.path_join(Store.PENDING)
			DirAccess.make_dir_absolute(pending)
			await click(decor.hud._confirm)
			expect(scene._save_failed and scene.decoration_state.snapshot()==before and decor._instances.is_empty(),"Failed placement leaves state and world unchanged")
			DirAccess.remove_absolute(pending)
			scene._retry_storage();scene._begin_decoration()
			await create_timer(1).timeout
			await click(decor.hud._items[item]);decor.preview_at(chosen)
		await click(decor.hud._confirm)
		while not animals.ready_for_motion: await process_frame
		expect(decor._instances.has(item),"Confirmed real placement "+item)
		expect(animals.water==original_water,"Ground furniture does not resample moving water obstacles")
	expect(animals.decoration_rest.size()>0,"Furniture supplies real resting approaches")
	if decor._instances.size()!=3:
		print("LIVING_DECOR failed admission evidence=",folder)
		scene.farm_audio.shutdown();scene.queue_free();await process_frame;quit(1);return
	await shot("placed")
	decor.finish_mode()
	await create_timer(1).timeout
	# Start drying through the actual authoritative kitchen transaction.
	scene._open_basket()
	scene._kitchen_action("start",{"recipe":"root_dry","crop":"radish","station":"garden_rack"},int(scene.farm_state.snapshot().kitchen.revision))
	scene.harvest_book.dismiss()
	expect(decor._instances.drying_rack.get_node("Harvest").visible,"Drying job appears on placed rack")
	expect(not decor._instances.tea_table.get_node("Tea").visible,"Day table stays clear")
	for item: String in ["bench","drying_rack","tea_table"]:
		var prop: Node3D=decor._instances[item]
		scene.camera.view_neighbor(prop.global_position+Vector3.UP*.3,Vector3(25,38,5))
		await create_timer(1).timeout
		await shot(item+"-front")
		scene.camera.view_neighbor(prop.global_position+Vector3.UP*.3,Vector3(180,24,2.8))
		await create_timer(1).timeout
		await shot(item+"-back")
	scene.atmosphere.set_preview_hour(21)
	await create_timer(1).timeout
	expect(decor._instances.tea_table.get_node("Tea").visible,"Night brings out tea")
	await shot("tea-night")
	scene.camera.leave_neighbor();await create_timer(1).timeout
	# Test actual paths to furniture, then run all movement against changed obstacles.
	var reached: bool=false
	for bird: Dictionary in animals.birds:
		if bird.kind!="hen": continue
		for point: Vector2 in animals.decoration_rest:
			var route: PackedVector2Array=animals.yard.path(bird.position,point)
			if route.is_empty(): continue
			bird.route=route;bird.waypoint=0;bird.state="walk";bird.interest=point
			for step: int in 3600:
				animals._process(1.0/30)
				if bird.position.distance_to(point)<.28 and bird.state=="rest": reached=true;break
			if reached: break
		if reached: break
	expect(reached,"Chicken walks to furniture and rests without teleporting")
	for bird: Dictionary in animals.birds: expect(bird.space.contains(bird.position),"Animal remains in valid space after furniture changes")
	scene._begin_decoration();await create_timer(1).timeout
	var before_move: Dictionary=decor.state.snapshot()
	await click(decor.hud._items.bench);decor.preview_at("ground_02")
	await click(decor.hud._rotate)
	await click(decor.hud._cancel)
	expect(decor.state.snapshot()==before_move and decor._instances.bench.visible,"Cancel move preserves original furniture")
	await click(decor.hud._items.bench);decor.preview_at("ground_02")
	await click(decor.hud._rotate)
	await let_hens_leave(decor,animals)
	await click(decor.hud._confirm)
	expect(decor.state.snapshot().bench.slot_id=="ground_02" and decor.state.snapshot().bench.quarter_turn==1,"Move and rotate to another real site")
	expect(scene.get_node("Environment/LivingDetails/YardWaterVats").visible,"Moving restores original site scenery")
	var old_slot: String=decor.state.snapshot().bench.slot_id
	await click(decor.hud._items.flowerpot);decor.preview_at(old_slot)
	expect(not decor.has_preview() and decor.state.snapshot().bench.slot_id==old_slot,"Occupied site preserves the placed bench")
	await click(decor.hud._items.bench)
	await let_hens_leave(decor,animals,true)
	await click(decor.hud._remove)
	while not animals.ready_for_motion: await process_frame
	await click(decor.hud._items.flowerpot);decor.preview_at(old_slot)
	await let_hens_leave(decor,animals)
	await click(decor.hud._confirm)
	expect(decor.state.snapshot().bench.slot_id=="" and decor._instances.has("flowerpot"),"Explicitly removing bench makes its site available")
	await click(decor.hud._items.flowerpot)
	await let_hens_leave(decor,animals,true)
	await click(decor.hud._remove)
	expect(not decor._instances.has("flowerpot"),"Remove updates world")
	var saved: Dictionary=scene.store.load_state()
	expect(saved.ok and saved.decorations==scene.decoration_state.snapshot(),"Furniture and kitchen persist together")
	scene._load_game(saved)
	expect(decor._instances.has("drying_rack") and decor._instances.has("tea_table") and decor._instances.drying_rack.get_node("Harvest").visible,"Reload reconstructs furniture and kitchen display")
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,600)
	await shot("minimum-window")
	decor.finish_mode();await create_timer(1).timeout
	scene.farm_audio.shutdown();scene.queue_free();await process_frame;await process_frame
	print("LIVING_DECOR failures=",failures.size()," evidence=",folder)
	quit(0 if failures.is_empty() else 1)
