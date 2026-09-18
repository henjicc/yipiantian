extends SceneTree
const Store=preload("res://farm/farm_store.gd")
const Settings=preload("res://settings/settings_store.gd")
var scene: Node3D
var now: float=1000
var folder: String
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func click(control: Control) -> void:
	await process_frame
	var ancestor: Node=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await process_frame
			await process_frame
			break
		ancestor=ancestor.get_parent()
	var point: Vector2=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point
	Input.parse_input_event(motion)
	await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		Input.parse_input_event(event)
		await process_frame
	await process_frame
func shot(label: String) -> void:
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../.local/verification/kitchen-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate()
	scene.store=Store.new(folder.path_join("farm"))
	scene.settings_store=Settings.new(folder.path_join("preferences"))
	scene.clock=func() -> float: return now
	root.add_child(scene)
	await process_frame
	var fixture: Dictionary=scene.farm_state.snapshot()
	for id: String in fixture.inventory: fixture.inventory[id]=10
	scene.farm_state.restore_snapshot(fixture)
	scene._save_farm()
	scene.atmosphere.set_preview_hour(14)
	scene._open_basket()
	var book: Node=scene.harvest_book
	await click(book._tabs.kitchen)
	await shot("recipes")
	# First write fails, so neither ingredients nor world food may change.
	var stable: Dictionary=scene.farm_state.snapshot()
	var pending: String=scene.store.directory.path_join(Store.PENDING)
	DirAccess.make_dir_absolute(pending)
	await click(book._root.find_child("StartCooking",true,false))
	expect(scene._save_failed and scene.farm_state.snapshot()==stable,"Failed kitchen write preserves ingredients and jobs")
	expect(scene.kitchen_display._contents.is_empty(),"Failed write cannot show food")
	DirAccess.remove_absolute(pending)
	scene._retry_storage()
	scene._open_basket()
	await click(book._root.find_child("StartCooking",true,false))
	expect(not scene.farm_state.snapshot().kitchen.jobs.stove.is_empty(),"Real UI starts cooking")
	for entry: Array in [["leaf_pickle","mustard"],["root_dry","radish"]]:
		await click(book._root.find_child("Recipe_"+entry[0],true,false))
		book.kitchen_page.crop=entry[1]
		book._render()
		await process_frame
		await click(book._root.find_child("StartCooking",true,false))
	expect(scene.kitchen_display._contents.size()==3,"All three stations show work")
	await shot("three-stations")
	now+=3600
	scene.settle_farm()
	for station: String in ["stove","rack","jar"]:
		await click(book._root.find_child("ViewKitchen_"+station,true,false))
		expect(book.viewing,"Station view opens via visible button "+station)
		await create_timer(.8).timeout
		await shot("working-"+station)
		book.end_view()
		await create_timer(.8).timeout
		await click(book._root.find_child("Collect_"+station,true,false))
		expect(scene.farm_state.snapshot().kitchen.jobs[station].is_empty(),"Collect via UI "+station)
	await shot("stock")
	var kitchen: Dictionary=scene.farm_state.snapshot().kitchen
	expect(kitchen.records.leaf_stir.made==1 and kitchen.records.leaf_pickle.made==1 and kitchen.records.root_dry.made==1,"Journal receives all methods")
	# Scroll reaches the stored food actions; paired wheel events match real input.
	var scroll: ScrollContainer=book._root.find_child("Pages",true,false)
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
	await process_frame
	await process_frame
	await click(book._root.find_child("ShareMeal_leaf_stir",true,false))
	expect(book.tab=="journal" and scene.farm_state.snapshot().kitchen.stock.leaf_stir==0,"Sharing consumes one cooked serving and opens its record")
	await shot("journal")
	var persisted: Dictionary=scene.store.load_state()
	expect(persisted.ok and persisted.farm.kitchen==scene.farm_state.snapshot().kitchen,"Kitchen reads back all progress")
	book.tab="kitchen";book._render()
	await process_frame
	await click(book._root.find_child("ViewKitchen_table",true,false))
	expect(book.viewing,"Table view opens via visible button")
	await create_timer(.8).timeout
	await shot("served-table")
	book.end_view()
	await create_timer(.8).timeout
	await click(book._root.find_child("Recipe_root_soup",true,false))
	await click(book._root.find_child("StartCooking",true,false))
	now+=40
	scene.settle_farm()
	await click(book._root.find_child("Collect_stove",true,false))
	await click(book._root.find_child("ViewKitchen_table",true,false))
	expect(book.viewing and scene.kitchen_display._ids.table=="root_soup","Cooked soup reaches the real table")
	await create_timer(.8).timeout
	await shot("served-soup")
	scene.atmosphere.set_preview_hour(21)
	await create_timer(.8).timeout
	await shot("served-soup-night")
	book.end_view()
	await create_timer(.8).timeout
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,600)
	await process_frame
	await shot("minimum-window")
	expect(root.get_visible_rect().encloses(book._paper.get_global_rect()),"Kitchen fits minimum window")
	book.dismiss()
	await create_timer(1).timeout
	scene.farm_audio.shutdown();scene.queue_free()
	await process_frame
	await process_frame
	print("KITCHEN_SCENE failures=",failures.size()," evidence=",folder)
	quit(0 if failures.is_empty() else 1)
