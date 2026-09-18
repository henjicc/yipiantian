extends SceneTree
## Scene entrances share the real tool/drag/modal path; fresh play needs only one crop.
const Store=preload("res://farm/farm_store.gd")
var scene: Node
var folder: String
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func pointer(point: Vector2,down: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	root.push_input(event,true);await physics_frame;await process_frame
func move(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point
	root.push_input(event,true);await physics_frame;await process_frame
func click_point(point: Vector2) -> void:
	await move(point);await pointer(point,true);await pointer(point,false)
func click(control: Control) -> void:
	var ancestor: Node=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control);await process_frame;await process_frame;break
		ancestor=ancestor.get_parent()
	await click_point(control.get_global_rect().get_center())
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func entrance_point(target: Node,id: String) -> Vector2:
	for mesh: MeshInstance3D in target.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null: continue
		var center: Vector2=scene.camera.unproject_position(mesh.to_global(mesh.mesh.get_aabb().get_center()))
		for offset: Vector2 in [Vector2.ZERO,Vector2(8,0),Vector2(-8,0),Vector2(0,8),Vector2(0,-8)]:
			var point: Vector2=center+offset
			if root.get_visible_rect().has_point(point) and scene._scene_entry_at(point)==id: return point
	return Vector2.INF
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../.local/verification/life-entries-%d"%Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate()
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=load("res://settings/settings_store.gd").new(folder.path_join("settings"));scene.clock=func() -> float: return 1000
	root.add_child(scene);await process_frame
	while not scene.get_node("Environment/CourtyardAnimals").ready_for_motion: await process_frame
	scene.atmosphere.set_preview_hour(14);await create_timer(.4).timeout
	# The first harvest is a real cell click with the ordinary tool.
	scene._focus_field(2);await create_timer(1).timeout
	scene._open_palette("tools");await create_timer(.3).timeout
	await click(scene.get_node("HUD/Layout/ToolChoices/Harvest"))
	await click_point(scene.camera.unproject_position(scene.farm.fields[2].to_global(scene.farm.cell_center("cell_06"))))
	check(scene.farm_state.snapshot().inventory.greens==1,"Fresh scene yields one basket without planting a full field")
	scene._cancel_tool();scene.camera.return_overview();await create_timer(1).timeout
	var entries: Dictionary={"stove":"Kitchen","rack":"LivingDetails/SidePorchDryingRack","jar":"LivingDetails/YardJarCluster","table":"LivingDetails/PorchHarvestTable","willow":"NeighborIslets/WillowNeighbor","bamboo":"NeighborIslets/BambooNeighbor","ferry":"NeighborIslets/EasternCottage"}
	for id: String in entries:
		var target: Node3D=scene.get_node("Environment/"+entries[id])
		if id in ["willow","bamboo","ferry"]:
			var view: Dictionary=scene.get_node("Environment/NeighborIslets").story_view(id)
			scene.camera.view_neighbor(view.point,view.view)
		else:
			scene.camera.view_neighbor(target.global_position+Vector3(0,.7,0),Vector3(35,40,11))
		await create_timer(1).timeout
		var point: Vector2=entrance_point(target,id)
		check(point!=Vector2.INF,"Actual visible entrance can be picked: "+id)
		if point==Vector2.INF: continue
		if id=="stove":
			var blocker:=MeshInstance3D.new();blocker.mesh=BoxMesh.new()
			scene.get_node("Environment").add_child(blocker)
			blocker.global_position=scene.camera.project_ray_origin(point)+scene.camera.project_ray_normal(point)*3
			check(scene._scene_entry_at(point).is_empty(),"A newly placed foreground surface blocks the entrance")
			blocker.hide();blocker.queue_free();await process_frame
		# Dragging over the same subject must not open a modal.
		await move(point);await pointer(point,true);await move(point+Vector2(18,0));await move(point);await pointer(point,false)
		check(not scene.harvest_book.active,"Drag does not open "+id)
		await click_point(point)
		check(scene.harvest_book.active,"Click opens "+id)
		if id in ["willow","bamboo","ferry"]:
			check(scene.harvest_book.neighbor==id and scene.harvest_book.tab=="neighbors","Correct household "+id)
		else: check(scene.harvest_book.tab=="kitchen","Correct kitchen entrance "+id)
		scene.harvest_book.dismiss();await process_frame
	# Initial basket -> first story -> optional illustrated return gift.
	scene.camera.return_overview();await create_timer(1).timeout
	scene._open_scene_entry("willow");await create_timer(.3).timeout
	var book: Node=scene.harvest_book
	var number: SpinBox=book._content.find_child("Amount_greens",true,false)
	number.value=1;await process_frame
	await click(book._send);await process_frame
	check(scene.farm_state.snapshot().inventory.greens==0,"Initial basket shared once")
	var gift: Control=book._content.find_child("Gift_radish",true,false)
	check(gift!=null and gift.get_node_or_null("Icon")!=null,"Return gift uses shared illustrated card")
	if gift!=null: await click(gift)
	check(scene.farm_state.snapshot().inventory.radish==1,"First return gift ready for another activity")
	check(scene.get_node("Environment/NeighborIslets")._story_groups.has("willow"),"First gift creates visible household change")
	book.dismiss();scene._open_scene_entry("stove");await create_timer(.3).timeout
	await click(book._content.find_child("Recipe_root_soup",true,false))
	var ingredient: Control=book._content.find_child("Ingredient_radish",true,false)
	await click(ingredient)
	check(book.kitchen_page.crop=="radish","Picture card selects actual ingredient")
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,600);await create_timer(.4).timeout
	await click(ingredient);await shot("ingredient-minimum")
	check(ingredient.get_global_rect().end.x<=root.get_visible_rect().end.x,"Ingredient cards fit smallest view")
	await click(book._content.find_child("StartCooking",true,false))
	check(not scene.farm_state.snapshot().kitchen.jobs.stove.is_empty(),"First return gift can start cooking")
	book.dismiss();scene._select_tool("water")
	var entry_point: Vector2=entrance_point(scene.get_node("Environment/Kitchen"),"stove")
	if entry_point!=Vector2.INF:
		await click_point(entry_point);check(not book.active,"Active farming tool does not open kitchen")
	scene._cancel_tool()
	scene.farm_audio.shutdown();await create_timer(.15).timeout
	print("LIFE_ENTRIES failures=",failures," evidence=",folder)
	scene.queue_free();await process_frame;quit(0 if failures==0 else 1)
