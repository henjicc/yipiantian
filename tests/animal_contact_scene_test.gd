extends SceneTree
const Farm=preload("res://farm/farm_state.gd")
const Store=preload("res://farm/farm_store.gd")
var scene: Node3D
var folder: String
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func click(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new();move.position=point;Input.parse_input_event(move);await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event)
		await physics_frame;await process_frame
func button(control: Control) -> void: await click(control.get_global_rect().get_center())
func shot(label: String) -> void:
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func center(bird: Dictionary) -> Vector3:
	return bird.node.global_position+Vector3.UP*(.24 if bird.kind=="hen" else (.48 if bird.kind=="duck" else .67))*bird.node.scale.x
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../.local/verification/animal-contact-%d"%Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.store=Store.new(folder.path_join("farm"));scene.settings_store=load("res://settings/settings_store.gd").new(folder.path_join("settings"))
	root.add_child(scene);await process_frame
	var animals: Node=scene.get_node("Environment/CourtyardAnimals")
	while not animals.ready_for_motion: await process_frame
	animals.set_process(false)
	animals._rng.seed=791
	var fixture: Dictionary=scene.farm_state.snapshot();fixture.inventory.greens=6;scene.farm_state.restore_snapshot(fixture);scene._save_farm()
	scene.atmosphere.set_preview_hour(14)
	for kind: String in ["goose","duck","hen"]:
		var bird: Dictionary={}
		for candidate: Dictionary in animals.birds:
			if candidate.kind==kind and scene._animal_at(scene.camera.unproject_position(center(candidate)))==String(candidate.node.name): bird=candidate;break
		if bird.is_empty():
			for candidate: Dictionary in animals.birds:
				if candidate.kind==kind: bird=candidate;break
			scene.camera.view_neighbor(center(bird),Vector3(30,40,5.8));await create_timer(1.2).timeout
		await click(scene.camera.unproject_position(center(bird)));await create_timer(1.2).timeout
		check(scene._animal_active() and scene.animal_panel.animal_id==String(bird.node.name),"Actual animal click opens "+kind)
		if not scene._animal_active(): await shot(kind+"-not-selected");continue
		var id: String=bird.node.name
		if kind=="goose":
			var before: Dictionary=scene.farm_state.snapshot()
			scene.animal_panel._name.text="小雪"
			var pending: String=scene.store.directory.path_join(Store.PENDING);DirAccess.make_dir_absolute(pending)
			await button(scene.animal_panel._save)
			check(scene._save_failed and scene.farm_state.snapshot()==before,"Write failure publishes no name or state")
			DirAccess.remove_absolute(pending);scene._retry_storage();await create_timer(1.2).timeout
			scene._open_animal(id);await create_timer(1.2).timeout
			scene.animal_panel._name.text="小雪";await button(scene.animal_panel._save)
			check(scene.farm_state.snapshot().animals[id].name=="小雪","Rename actually saved")
			scene.animal_panel._rest.select(3);scene.animal_panel._rest.item_selected.emit(3)
			check(scene.farm_state.snapshot().animals[id].preference==2,"Rest choice saved")
		var before_food: int=scene.farm_state.snapshot().inventory.greens
		await button(scene.animal_panel._feed)
		check(animals.interaction.active.has(id),"Feeding starts safe approach "+kind)
		print("APPROACH ",id," at=",bird.position," plan=",animals.interaction.active.get(id,{}))
		check(scene.farm_state.snapshot().inventory.greens==before_food-1,"Food charged once "+kind)
		var approached: bool=false
		for step: int in 1500:
			animals._process(1.0/30)
			if animals.interaction.active.has(id) and animals.interaction.active[id].phase=="response": approached=true;break
		check(approached,"Animal reaches food without teleport "+kind)
		if not approached: print("FAILED_APPROACH ",id," at=",bird.position," state=",bird.state," recoveries=",bird.recoveries)
		if approached:
			var closest: float=INF
			var food_at: Vector3=animals.interaction.active[id].food.global_position
			for step: int in 180:
				animals._process(1.0/30)
				closest=minf(closest,bird.pose.beak_world_position().distance_to(food_at))
				if closest<.08: break
			print("BEAK_FOOD ",id," minimum_distance=",closest)
			check(closest<.12,"Animated beak reaches the shared leaves "+kind)
			await shot(kind+"-feeding")
		for step: int in 240: animals._process(1.0/30)
		check(not animals.interaction.active.has(id),"Interaction returns to normal AI "+kind)
		await button(scene.animal_panel._call)
		check(animals.interaction.active.has(id),"Free greeting starts "+kind)
		check(scene.farm_state.snapshot().inventory.greens==before_food-1,"Greeting is free "+kind)
		for step: int in 1500:
			animals._process(1.0/30)
			if not animals.interaction.active.has(id): break
		for entry: Dictionary in animals.birds: check(entry.space.contains(entry.position),"Valid animal area during interaction")
		scene.animal_panel.dismiss();await create_timer(1.2).timeout
	var saved: Dictionary=scene.store.load_state();scene._load_game(saved)
	check(saved.farm.animals==scene.farm_state.snapshot().animals,"Reload keeps identity, food history and rest choice")
	var hen: Dictionary=animals.interaction.find("YardHen1")
	scene._open_animal("YardHen1");await create_timer(1.2).timeout
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,600)
	await shot("minimum-panel")
	check(root.get_visible_rect().encloses(scene.animal_panel._root.get_child(0).get_global_rect()),"Panel fits minimum viewport")
	var before_click: Dictionary=scene.farm_state.snapshot()
	await click(Vector2(200,200))
	check(before_click==scene.farm_state.snapshot(),"Open panel prevents world farming")
	scene.animal_panel.dismiss();await create_timer(1.2).timeout
	check(scene._tools_available(),"Closing restores farming controls")
	scene.farm_audio.shutdown();scene.queue_free();await process_frame;await process_frame
	print("ANIMAL_CONTACT_SCENE failures=",failures," evidence=",folder);quit(0 if failures==0 else 1)
