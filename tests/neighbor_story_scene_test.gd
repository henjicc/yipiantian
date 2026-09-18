extends SceneTree
const Store=preload("res://farm/farm_store.gd")
const Settings=preload("res://settings/settings_store.gd")
const Neighbors=preload("res://farm/neighbor_catalog.gd")
var scene: Node3D
var folder: String
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func shot(label: String) -> void:
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func click(control: Control) -> void:
	if control==null:
		expect(false,"Required story control missing")
		quit(1)
		return
	await process_frame
	var point: Vector2=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func run() -> void:
	folder=ProjectSettings.globalize_path("res://../.local/verification/neighbor-story-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate()
	scene.store=Store.new(folder.path_join("farm"))
	scene.settings_store=Settings.new(folder.path_join("preferences"))
	scene.clock=func() -> float: return 1000
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.atmosphere.set_preview_hour(14)
	var fixture: Dictionary=scene.farm_state.snapshot()
	for crop: String in fixture.inventory: fixture.inventory[crop]=20
	scene.farm_state.restore_snapshot(fixture)
	scene._save_farm()
	scene._open_basket()
	await process_frame
	await process_frame
	var book: Node=scene.harvest_book
	await click(book._tabs.neighbors)
	var islets: Node3D=scene.get_node("Environment/NeighborIslets")
	var return_point: Vector3=scene.camera.focus_point
	var return_view: Vector3=scene.camera.view
	for id: String in Neighbors.IDS:
		await click(book._root.find_child(id,true,false))
		expect(book.neighbor==id,"Household selection "+id)
		await click(book._root.find_child("ViewHome",true,false))
		await create_timer(1).timeout
		await shot(id+"-before")
		book.end_view()
		await create_timer(1).timeout
		for index: int in 3:
			var wish: Dictionary=Neighbors.wish(id,index)
			var basket: Dictionary={}
			for crop: String in fixture.inventory:
				if Neighbors.accepts(id,index,crop): basket[crop]=wish.amount; break
			if id=="bamboo" and index==0:
				var quantity: SpinBox=book._root.find_child("Amount_greens",true,false)
				quantity.value=1
				await process_frame
				# All twelve choices exceed one page: scroll and submit with mouse input.
				var wheel:=InputEventMouseButton.new()
				wheel.position=book._paper.get_global_rect().position+Vector2(20,200)
				wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN
				wheel.factor=12
				wheel.pressed=true
				Input.parse_input_event(wheel)
				await process_frame
				wheel.pressed=false
				Input.parse_input_event(wheel)
				await process_frame
				await shot("bamboo-basket-scroll")
				await click(book._send)
			else:
				scene._exchange(id,index,basket,"")
			await process_frame
			var group: Node3D=islets._story_groups.get(id)
			if group==null:
				expect(false,"Delivery did not create household changes: "+id)
				quit(1)
				return
			var visible_count: int=0
			for prop: Node3D in group.get_children():
				if prop.visible: visible_count+=1
			expect(visible_count==index+1,"Each delivery adds exactly its authored scene change "+id)
			var stored: Dictionary=Store.new(scene.store.directory).load_state()
			expect(stored.ok and Neighbors.Stories.delivered(id,stored.farm.neighbors[id])==index+1,"Delivered story persists before gift claim")
			if index==2: await shot(id+"-reply")
			scene._exchange(id,index,{},Neighbors.HOMES[id].gifts[index%2])
			await process_frame
		expect(scene.farm_state.snapshot().neighbors[id].round==3,"All three chapters finish "+id)
		await click(book._root.find_child("History",true,false))
		await shot(id+"-letters")
		var before: Dictionary=scene.farm_state.snapshot()
		await click(book._root.find_child("ViewHome",true,false))
		expect(book.viewing and scene.camera.neighbor_view,"View button enters live neighbour scene")
		await create_timer(1).timeout
		await shot(id+"-after")
		expect(scene.focus_detail._attributes.dof_blur_amount>.1,"Neighbour viewing retains chosen DOF intensity")
		expect(is_equal_approx(scene.focus_detail.get_settings().fog_strength,.28),"World haze stays unchanged")
		expect(is_equal_approx(scene.focus_detail._neighbor_clear,1.0),"Visited island is readable through a local clear area")
		# Opposite-side contact inspection, using the same gameplay camera path.
		var viewpoint: Dictionary=islets.story_view(id)
		viewpoint.view.x+=105
		scene.camera.view_neighbor(viewpoint.point,viewpoint.view)
		await create_timer(1).timeout
		await shot(id+"-contact-side")
		var escape:=InputEventKey.new()
		escape.keycode=KEY_ESCAPE
		escape.pressed=true
		Input.parse_input_event(escape)
		await process_frame
		expect(book.active and not book.viewing,"Escape returns to letters before closing book")
		await create_timer(1).timeout
		expect(scene.camera.focus_point.is_equal_approx(return_point) and scene.camera.view.is_equal_approx(return_view),"Original framing restores after preview")
		expect(is_zero_approx(scene.focus_detail._neighbor_clear),"Returning restores ordinary world haze")
		expect(scene.farm_state.snapshot()==before,"Replaying letters and viewing scenery cannot spend or reward")
		await click(book._root.find_child("History",true,false))
		expect(not book._history_open,"Return to continuing daily correspondence")
	var saved: Dictionary=Store.new(scene.store.directory).load_state()
	scene._refresh_neighbor_stories()
	scene._refresh_neighbor_stories()
	for id: String in Neighbors.IDS:
		expect(islets._story_groups[id].get_child_count()==3,"Refresh does not duplicate props")
		expect(Neighbors.Stories.history(id,saved.farm.neighbors[id]).size()==3,"All completed letters survive disk reload")
	# Reconstruct changes from the persisted state, without keeping old instances.
	for group: Node3D in islets._story_groups.values(): group.queue_free()
	islets._story_groups.clear()
	await process_frame
	scene._load_game()
	await process_frame
	for id: String in Neighbors.IDS:
		expect(islets._story_groups[id].get_child_count()==3,"Saved household reconstructs every chapter")
		for prop: Node3D in islets._story_groups[id].get_children():
			expect(prop.visible and prop.position.y<1.4,"Story props reconstruct on ground, not roof/canopy")
	book.dismiss()
	scene.farm_audio.shutdown()
	scene.queue_free()
	await process_frame
	await process_frame
	print("NEIGHBOR_STORY_SCENE failures=",failures.size()," evidence=",folder)
	quit(0 if failures.is_empty() else 1)
