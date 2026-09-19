extends "res://../tests/island_construction_test.gd"
const Catalog = preload("res://layout/construction_catalog.gd")
var now: float=2000000.0

func place_at_visible_slot(item: String, slots: Array[String]) -> bool:
	await choose_tool(item)
	var decor: Node=scene.decoration_layout
	for slot: String in slots:
		if not decor._rings[slot].visible: continue
		var point: Vector2=scene.camera.unproject_position(decor._rings[slot].global_position)
		await mouse(point,true);await mouse(point,false)
		if decor.preview_slot!=slot: continue
		if decor.placement_issue(decor._preview,item,slot).is_empty(): return true
	expect(false,"A visible supported slot can be selected for "+item)
	return false

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/construction-catalog-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	var builder: Node=scene.island_builder
	expect(builder.active,"HUD enters construction catalog")
	if OS.get_cmdline_user_args().has("--switches-only"):
		for repeat: int in 5:
			for id: String in ["fields","trellis","bridge","ducks"]:
				await choose_tool(id)
				expect(builder.tool==id,"Repeated category selection reaches "+id)
		await choose_tool("fields")
		var start: Vector2=scene.camera.unproject_position(scene.farm.fields[0].global_position)
		await mouse(start,true)
		var event:=InputEventMouseMotion.new();event.position=start+Vector2(25,0);event.relative=Vector2(25,0);event.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(event,true);await frames()
		await mouse(builder.choices.categories.routes.get_global_rect().get_center(),false)
		expect(builder.draft==scene.farm_state.snapshot().layout,"Releasing an unfinished field drag over UI restores its draft")
		await finish();return
	var original: Dictionary=scene.farm_state.snapshot()
	await drag(Vector3(0,.13,6),Vector3(2,.13,8))
	expect(builder.draft!=original.layout,"Land tool still produces a real draft")
	await click(builder.choices.categories.plants)
	expect(builder.draft==original.layout and scene.farm_state.snapshot()==original,"Changing category cancels unsaved land without publishing it")
	expect(builder.tool.is_empty() and builder._confirm.disabled,"Browsing a category does not keep the old brush active")
	await shot("01-plants")
	await click(builder.choices.items.lotus)
	expect(builder.tool.is_empty() and builder.choices.items.lotus.disabled,"Unavailable plant tool cannot perform a different operation")
	root.size=Vector2i(960,640);await frames()
	for category: String in Catalog.CATEGORIES:
		await click(builder.choices.categories[category])
		var visible: Array[String]=[]
		for id: String in builder.choices.items:
			var card: Control=builder.choices.items[id]
			if card.is_visible_in_tree(): visible.append(id)
		expect(visible==Catalog.in_category(category),"Category displays its actual contents: "+category)
		expect(root.get_visible_rect().encloses(builder._panel.get_global_rect()),"Catalog fits minimum window: "+category)
	await click(builder.choices.categories.objects);await shot("02-small-window")
	root.size=Vector2i(1600,900);await frames()
	await choose_tool("lantern")
	expect(scene.decoration_layout.selected_item.is_empty() and builder._status.text.contains("累计收获"),"Locked lantern retains its harvest requirement")
	expect(Catalog.has_capability("lantern","light") and Catalog.has_capability("lantern","decoration"),"Category does not erase a lamp's combined capabilities")
	var fixture: Dictionary=scene.farm_state.snapshot()
	fixture.harvested.greens=20;fixture.harvested.radish=20;fixture.harvested.spinach=20
	scene.farm_state.restore_snapshot(fixture);scene.decoration_state.unlock(fixture.harvested)
	scene._save_farm()
	if not await place_at_visible_slot("bench",["ground_01","ground_02","ground_03","ground_04"]): await finish();return
	expect(not scene.decoration_layout.hud.visible and builder.visible,"Existing prop controller uses the construction panel")
	var before: Dictionary=scene.decoration_state.snapshot()
	var pending_slot: String=scene.decoration_layout.preview_slot
	await shot("03-bench-preview")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(scene.decoration_layout.preview_slot.is_empty() and scene.decoration_layout.active and scene.decoration_state.snapshot()==before,"Focus loss restores prop preview and keeps the catalog usable")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	if not await place_at_visible_slot("bench",[pending_slot]): await finish();return
	var path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocked"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocked/child")
	await click(builder._confirm)
	expect(scene.decoration_state.snapshot()==before and scene.decoration_layout.preview_slot==pending_slot and builder._status.text.contains("未能保存"),"Failed save preserves both confirmed state and retryable prop preview")
	scene.store.directory=path
	var scene_id: int=scene.get_instance_id()
	await click(builder._confirm)
	expect(scene.decoration_state.snapshot().bench.slot_id==pending_slot and scene.get_instance_id()==scene_id,"Retry confirms prop in place without scene reload")
	expect(not builder._undo.disabled,"Confirmed prop has one-step construction undo")
	now+=3600;scene.settle_farm()
	var current_farm: Dictionary=scene.farm_state.snapshot()
	await click(builder.choices.categories.land)
	await click(builder._undo)
	expect(scene.decoration_state.snapshot()==before,"Undo remains available across catalog categories")
	expect(scene.farm_state.snapshot().fields==current_farm.fields and scene.farm_state.snapshot().inventory==current_farm.inventory,"Prop undo does not rewind crop progress or inventory")
	if not await place_at_visible_slot("lantern",["hanging_01","hanging_02","hanging_03","hanging_04"]): await finish();return
	var target: String=scene.decoration_layout.preview_slot
	await click(builder._panel.find_child("Finish",true,false))
	expect(not builder.active and not scene.decoration_layout.active and scene.decoration_state.snapshot().lantern.slot_id==target,"Finish confirms pending lantern and exits both controllers")
	var anchors: Array=scene.decoration_layout.lantern_anchors()
	expect(anchors.size()==1 and anchors[0].global_position.is_equal_approx(scene.get_node("Environment").get_slot_marker(target).global_position),"Light capability supplies the actual placed lantern anchor")
	var saved: Dictionary=scene.decoration_state.snapshot()
	expect(Store.new(path).load_state().decorations==saved,"Unified catalog uses the durable decoration store")
	await create_timer(1).timeout;await shot("04-finished")
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(6)
	expect(scene.decoration_state.snapshot()==saved,"Actual scene reopen restores catalog placement")
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	await choose_tool("fields")
	expect(scene.island_builder.tool=="fields" and is_instance_valid(scene.island_builder.field_preview),"Planting category opens the live field controller")
	await choose_tool("trellis")
	print("TRELLIS_SELECTION tool=",scene.island_builder.tool," controls=",scene.island_builder._rows.length.visible," card=",scene.island_builder._tools.trellis.get_global_rect()," hovered=",root.gui_get_hovered_control())
	await shot("05-trellis")
	expect(scene.island_builder.tool=="trellis" and scene.island_builder._rows.length.visible,"Trellis still exposes its actual size controls")
	await choose_tool("bridge")
	expect(scene.island_builder.tool=="bridge" and scene.island_builder._rows.bridge_width.visible,"Bridge category opens endpoint and width editing")
	await choose_tool("ducks")
	expect(scene.island_builder.tool=="ducks" and scene.island_builder._rows.count.visible,"Animal category opens the existing duck region editor")
	await shot("05-animals")
	await finish()
