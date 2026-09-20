extends "res://../tests/island_construction_test.gd"
var now: float=2000000.0

func click(control: Control) -> void:
	if not is_instance_valid(control): expect(false,"Requested UI control exists");return
	var ancestor: Node=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control);await frames(2);break
		ancestor=ancestor.get_parent()
	await super.click(control)

func tap(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.window_id=root.get_window_id()
	root.push_input(event,true);await frames()
	await mouse(point,true);await mouse(point,false)

func cell_point(index: int,id: String) -> Vector2:
	return scene.camera.unproject_position(scene.farm.fields[index].to_global(scene.farm.cell_position(index,id)))

func open_kitchen() -> void:
	await click(scene.hud.find_child("OpenBasket",true,false));await frames()
	await click(scene.harvest_book._tabs.kitchen)

func page_button(id: String) -> Control:
	return scene.harvest_book._root.find_child(id,true,false)

func prop_point() -> Vector2:
	var prop: Node3D=scene.decoration_layout._instances.drying_rack
	for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
		var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i: int in range(0,vertices.size(),maxi(1,vertices.size()/60)):
			var screen: Vector2=scene.camera.unproject_position(mesh.to_global(vertices[i]))
			if scene._scene_entry_at(screen)=="garden_rack": return screen
	return Vector2.INF

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/construction-life-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var plan:=Plan.new()
	plan.apply_construction({"east_land":[],"land":[[-3,5,5,5]],"trellis":[],"bridge":[],"buildings":{"house":[],"kitchen":[]},"flocks":preload("res://layout/flock_layout.gd").initial()})
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=plan
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	# Start with a real harvest and the existing field action menu.
	await tap(cell_point(2,"cell_06"));await create_timer(1).timeout
	await tap(cell_point(2,"cell_06"))
	expect(scene.field_menu.active,"Mature crop opens real harvest menu")
	if not scene.field_menu.active: await finish();return
	var petal: Control=scene.field_menu.cards.get_node("harvest")
	await tap(petal.global_position+petal.center)
	expect(scene.farm_state.snapshot().inventory.greens==1,"Harvest provides one basket for cooking")
	await open_kitchen();await shot("01-first-recipe")
	await click(page_button("StartCooking"))
	expect(not scene.farm_state.snapshot().kitchen.jobs.stove.is_empty(),"Visible recipe button cooks actual harvest")
	now+=20;scene.settle_farm();await frames()
	await click(page_button("Collect_stove"))
	expect(scene.farm_state.snapshot().kitchen.stock.leaf_stir==1,"Collect cooked harvest")
	var before: Dictionary=scene.farm_state.snapshot()
	var pending: String=scene.store.directory.path_join(Store.PENDING)
	DirAccess.make_dir_absolute(pending)
	await click(page_button("ShareMeal_leaf_stir"))
	expect(scene._save_failed and scene.farm_state.snapshot()==before and not scene.decoration_state.snapshot().drying_rack.unlocked,"Failed sharing save neither consumes food nor grants construction")
	DirAccess.remove_absolute(pending);scene._retry_storage();await frames()
	await open_kitchen();await click(page_button("ShareMeal_leaf_stir"))
	expect(scene.harvest_book.tab=="journal" and scene.decoration_state.snapshot().drying_rack.unlocked,"Retry shares once and unlocks portable rack")
	expect(scene.farm_state.snapshot().kitchen.records.leaf_stir.shared==1 and scene.farm_state.snapshot().kitchen.stock.leaf_stir==0,"Reward uses one serving exactly once")
	await shot("02-earned-rack")
	await click(page_button("BuildDryingRack"));await create_timer(1).timeout
	var builder: Node=scene.island_builder
	expect(builder.active and builder.tool=="drying_rack" and not scene.harvest_book.active,"Earned reward leads straight into its placement tool")
	await tap(scene.camera.unproject_position(Vector3(-1,.13,8)))
	var decor: Node=scene.decoration_layout
	expect(decor.has_preview(),"Place earned rack on expanded land with real pointer")
	if not decor.has_preview(): await finish();return
	var preview_id: int=decor._preview.get_instance_id()
	await click(builder._panel.find_child("Finish",true,false));await create_timer(1).timeout
	expect(not builder.active and decor._instances.has("drying_rack"),"Finish saves the new useful structure")
	if not decor._instances.has("drying_rack"): await shot("failure-placement");await finish();return
	expect(decor._instances.drying_rack.get_instance_id()==preview_id,"Finished structure reuses preview instance")
	# Capacity comparison uses supplied root vegetables, independent of the earned reward.
	var fixture: Dictionary=scene.farm_state.snapshot();fixture.inventory.radish=3
	scene.farm_state.restore_snapshot(fixture);scene._save_farm()
	await open_kitchen();await click(page_button("Recipe_root_dry"))
	expect(page_button("CookingStation")!=null,"Placed rack exposes two drying locations")
	await click(page_button("Ingredient_radish"));await click(page_button("StartCooking"))
	expect(not scene.farm_state.snapshot().kitchen.jobs.rack.is_empty() and not decor._instances.drying_rack.get_node("Harvest").visible,"Original drying job stays on original rack")
	scene.harvest_book.dismiss();await create_timer(1).timeout
	# Focus the actual prop for reliable visible mesh selection, then click its mesh.
	scene.camera.view_neighbor(decor._instances.drying_rack.global_position+Vector3.UP*.4,Vector3(22,34,5.5))
	await create_timer(1).timeout
	var hit: Vector2=prop_point()
	expect(hit!=Vector2.INF,"Portable rack has a visible scene interaction")
	if hit==Vector2.INF: await finish();return
	await tap(hit);await frames()
	expect(scene.harvest_book.active and scene.harvest_book.kitchen_page.selected_station=="garden_rack","World click selects this rack's own production slot")
	await click(page_button("StartCooking"))
	var kitchen: Dictionary=scene.farm_state.snapshot().kitchen
	expect(not kitchen.jobs.rack.is_empty() and not kitchen.jobs.garden_rack.is_empty() and scene.farm_state.snapshot().inventory.radish==1,"Two racks run simultaneously for exactly two baskets")
	expect(decor._instances.drying_rack.get_node("Harvest").visible,"New job appears on the movable rack")
	await shot("03-parallel-drying")
	await click(page_button("ViewKitchen_garden_rack"));await create_timer(1).timeout
	scene.focus_detail.set_depth_of_field(false);await frames();await shot("04-rack-front")
	scene.camera.view_neighbor(decor._instances.drying_rack.global_position+Vector3.UP*.4,Vector3(202,24,4.5))
	await create_timer(1).timeout;await shot("05-rack-back")
	scene.atmosphere.set_preview_hour(22);await frames(8);await shot("06-rack-night")
	scene.harvest_book.end_view();await create_timer(1).timeout
	root.size=Vector2i(960,640);await frames();await shot("07-small-kitchen")
	expect(root.get_visible_rect().encloses(scene.harvest_book._paper.get_global_rect()),"Four station kitchen fits small window")
	root.size=Vector2i(1600,900);await frames();scene.harvest_book.dismiss();await create_timer(1).timeout
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	await choose_tool("drying_rack")
	var placed: Dictionary=scene.decoration_state.snapshot()
	await click(builder._undo)
	expect(scene.decoration_state.snapshot()==placed and builder._status.text.contains("先收起成品"),"Undo cannot orphan a working rack")
	await click(builder._decoration_remove)
	expect(scene.decoration_state.snapshot()==placed and builder._status.text.contains("先收起成品"),"Remove gives actionable busy-rack feedback")
	var start: Vector3=decor._instances.drying_rack.global_position+Vector3.UP*.6
	await drag(start,start+Vector3(1,0,0));await click(builder._decoration_rotate)
	expect(decor.has_preview() and decor._preview.get_node("Harvest").visible,"Moving and rotating previews the actual processing food")
	var moved: Vector2=decor.preview_position
	builder.cancel_draft();await frames()
	expect(scene.decoration_state.snapshot()==placed and decor._instances.drying_rack.visible,"Cancel restores working rack with same job")
	await choose_tool("drying_rack")
	await drag(start,start+Vector3(1,0,0));await click(builder._decoration_rotate)
	DirAccess.make_dir_absolute(pending)
	await click(builder._confirm)
	expect(scene.decoration_state.snapshot()==placed and decor.has_preview() and builder._status.text.contains("未能保存"),"Move write failure preserves working support and retryable preview")
	DirAccess.remove_absolute(pending)
	await click(builder._confirm)
	expect(scene.decoration_state.snapshot().drying_rack.position==[moved.x,moved.y] and scene.farm_state.snapshot().kitchen==kitchen,"Retry moves rack without restarting either job")
	await click(builder._undo)
	expect(scene.decoration_state.snapshot()==placed and scene.farm_state.snapshot().kitchen==kitchen,"Undo movement preserves processing and inventory")
	await click(builder._panel.find_child("Finish",true,false));await create_timer(1).timeout
	var path: String=scene.store.directory
	var saved: Dictionary=scene.farm_state.snapshot()
	scene.farm_audio.shutdown();root.remove_child(scene);scene.free();await frames()
	now+=90
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.farm_state.snapshot().kitchen==saved.kitchen and scene.decoration_state.snapshot()==placed,"Real scene reopen preserves reward and both jobs across offline time")
	expect(scene.decoration_layout._instances.drying_rack.get_node("Harvest").visible,"Reopen reconstructs actual drying contents")
	await open_kitchen()
	await click(page_button("Collect_rack"));await click(page_button("Collect_garden_rack"))
	expect(scene.farm_state.snapshot().kitchen.stock.root_dry==2 and scene.farm_state.snapshot().inventory.radish==1,"Both offline batches collect exactly once")
	expect(not scene.decoration_layout._instances.drying_rack.get_node("Harvest").visible,"Collection clears only finished food")
	scene.harvest_book.dismiss();await create_timer(1).timeout
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout;await choose_tool("drying_rack")
	await click(scene.island_builder._decoration_remove)
	expect(not scene.decoration_layout._instances.has("drying_rack") and scene.decoration_state.snapshot().drying_rack.unlocked,"Collected rack can be stored without losing unlock")
	await click(scene.island_builder._undo)
	expect(scene.decoration_layout._instances.has("drying_rack") and scene.farm_state.snapshot().kitchen.stock.root_dry==2,"Undo removal restores capacity without rewinding collected food")
	await shot("08-reopened-collected")
	await finish()
