extends "res://../tests/island_construction_test.gd"

func ready_draft() -> bool:
	var started: int=Time.get_ticks_msec()
	while scene.island_builder.field_preview.pending:
		await process_frame
		if Time.get_ticks_msec()-started>20000:
			expect(false,"Field validation finishes");return false
	var message: String=scene.island_builder.issue()
	expect(message.is_empty(),"Field draft accepted: "+message)
	return message.is_empty()

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/island-fields-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var plan:=Plan.new()
	plan.apply_construction({"east_land":[],"land":[[-3,5,5,5]],"trellis":[],"bridge":[],"buildings":{"house":[],"kitchen":[]},"flocks":preload("res://layout/flock_layout.gd").initial()})
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=plan
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	var house_id: int=scene.get_node("Environment/MainHouse").get_instance_id()
	var water_id: int=scene.get_node("Environment/CourtyardAnimals").water.get_instance_id()
	var original: Dictionary=scene.farm_state.snapshot()
	var original_paths: Node3D=scene.get_node("Environment/GardenPaths")
	var original_fences: Array[Node3D]=[]
	for node: Node in scene.get_node("Environment").get_children():
		if node is Node3D and node.has_meta("fence_spans") and node.visible: original_fences.append(node)
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	await choose_tool("fields")
	expect(original_paths.is_visible_in_tree(),"Opening field tools retains the existing visible paths")
	for node: Node3D in original_fences: expect(node.is_visible_in_tree(),"Opening field tools retains existing fence and contact shadows")
	expect(not scene.island_builder.field_preview.pending,"Unchanged field layout needs no repeated navigation build")
	await click(scene.island_builder._field_actions.get_node("AddField"))
	await drag(Vector3(-1.5,.13,7),Vector3(1,.13,9))
	var builder: Node=scene.island_builder
	expect(builder.draft.fields.size()==7,"Real drag creates a seventh field on painted land")
	expect(scene.farm_state.snapshot()==original,"Field preview cannot alter authoritative planting state")
	expect(builder.field_preview.farm.fields.size()==7 and not scene.farm.visible,"New soil appears before save")
	if not await ready_draft(): await shot("failure-new-field");await finish();return
	var definition: Dictionary=builder.candidate.fields[6]
	var pose: Transform3D=builder.candidate.field_transform(6)
	var resize_started: int=Time.get_ticks_msec()
	await drag(pose*Vector3(definition.size.x*.5,.12,definition.size.y*.5),pose*Vector3(definition.size.x*.5,0,.8))
	print("FIELD_RESIZE_INPUT_MS ",Time.get_ticks_msec()-resize_started)
	expect(builder.draft.fields[6].rows==3,"Corner handle resizes the field directly in the scene")
	builder._values.columns.value=5
	if not await ready_draft(): await shot("failure-resize");await finish();return
	expect(builder.field_preview.farm.fields[6].get_meta("field_size")==builder.candidate.fields[6].size,"Rendered soil matches changed row and column counts")
	await shot("01-new-field-preview")
	var wanted: Dictionary=builder.draft.duplicate(true)
	var start: int=Time.get_ticks_msec()
	await click(builder._panel.find_child("Finish",true,false))
	print("FIELD_FINISH_INPUT_MS ",Time.get_ticks_msec()-start)
	expect(not builder.active and scene.farm_state.snapshot().layout==wanted,"Finish commits the visible field and exits")
	expect(scene.get_node("Environment/MainHouse").get_instance_id()==house_id,"Field completion retains the island scene")
	expect(scene.farm.fields.size()==7,"New field joins normal farming")
	for node: Node3D in original_fences: expect(is_instance_valid(node) and node.is_visible_in_tree(),"Field-only save preserves unchanged fence instances and shadows")
	var id: String=scene.farm.field_id(6)
	start=Time.get_ticks_msec()
	while scene.get_node("Environment")._terrain_refreshing:
		await process_frame
		if Time.get_ticks_msec()-start>15000: expect(false,"Field navigation refresh finishes");break
	var animals: Node3D=scene.get_node("Environment/CourtyardAnimals")
	expect(animals.water.get_instance_id()==water_id,"Field-only edits retain the existing water navigation")
	var endpoints: Dictionary=scene.get_node("Environment").circulation.endpoints
	expect(not animals.yard.path(endpoints.house,endpoints[id]).is_empty(),"The new field has a usable animal route from the yard")
	scene._focus_field(6);await create_timer(1).timeout
	scene._select_crop("greens")
	var cell: String=scene.farm.cell_ids(6)[-1]
	var at: Vector3=scene.farm.fields[6].to_global(scene.farm.cell_position(6,cell))
	await mouse(scene.camera.unproject_position(at),true);await mouse(scene.camera.unproject_position(at),false)
	expect(scene.farm_state.get_cell(id,cell).crop_id=="greens","New field accepts planting through real mouse input")
	await shot("02-planted")
	scene._begin_construction("fields");await create_timer(1).timeout
	var cancel_before: Dictionary=scene.farm_state.snapshot()
	var cancel_center: Vector3=scene.courtyard_plan.fields[0].position
	await mouse(scene.camera.unproject_position(cancel_center),true)
	var motion:=InputEventMouseMotion.new();motion.position=scene.camera.unproject_position(cancel_center+Vector3(.5,0,0));motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true);await frames()
	start=Time.get_ticks_msec();builder._focus_lost()
	expect(Time.get_ticks_msec()-start<250,"Focus loss restores the unfinished field gesture promptly")
	expect(builder.draft==cancel_before.layout,"Focus loss discards only the unfinished field gesture")
	await mouse(motion.position,false)
	await mouse(scene.camera.unproject_position(at),true);await mouse(scene.camera.unproject_position(at),false)
	builder._values.rows.value=2;await frames()
	expect(builder._confirm.disabled and builder.issue().contains("作物"),"Shrinking away an occupied row is rejected")
	builder.cancel_draft();await frames()
	expect(scene.farm_state.get_cell(id,cell).crop_id=="greens","Cancel preserves the planted crop")
	for preview_body: StaticBody3D in builder.field_preview.farm.fields:
		expect(preview_body.collision_layer==0,"Preview fields cannot intercept normal farm picking")
	var before: Dictionary=scene.farm_state.snapshot()
	var center: Vector3=scene.courtyard_plan.fields[6].position
	await drag(center,center+Vector3(-.5,0,0))
	if not await ready_draft(): await shot("failure-move");await finish();return
	await click(builder._field_actions.get_node("RotateField"))
	if not await ready_draft(): await shot("failure-rotate");await finish();return
	expect(builder.draft.fields[6].yaw==15,"Rotate button updates the selected field")
	await shot("03-moved-rotated")
	var normal_path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	await click(builder._panel.find_child("Finish",true,false))
	expect(builder.active and not builder.busy and builder._status.text.contains("未能保存"),"Failed save keeps the field draft retryable")
	expect(scene.farm_state.snapshot()==before,"Failed field save leaves authoritative crops and layout unchanged")
	scene.store.directory=normal_path
	await click(builder._panel.find_child("Finish",true,false))
	expect(not builder.active,"Retry completes in place")
	expect(scene.farm_state.snapshot().fields==before.fields,"Moving and rotating retain every crop record")
	expect(scene.farm_state.snapshot().inventory==before.inventory,"Construction does not change inventory")
	scene.clock=func() -> float: return 2003600.0
	scene.settle_farm();await frames()
	var grown: Dictionary=scene.farm_state.get_cell(id,cell).duplicate(true)
	expect(grown.stage=="mature","Adopted field renders later growth using its own observers")
	scene._begin_construction("fields");await create_timer(1).timeout
	await click(builder._undo)
	start=Time.get_ticks_msec()
	while builder.busy:
		await process_frame
		if Time.get_ticks_msec()-start>20000: expect(false,"Undo finishes");break
	expect(scene.farm_state.snapshot().layout==before.layout,"Undo restores the previous field transform")
	expect(scene.farm_state.get_cell(id,cell).crop_id=="greens","Undo preserves planting performed after the earlier construction")
	expect(scene.farm_state.get_cell(id,cell)==grown,"Undo does not rewind elapsed crop growth")
	builder.finish();await frames()
	var disk: Dictionary=Store.new(normal_path).load_state()
	expect(disk.ok and disk.farm.fields==scene.farm_state.snapshot().fields,"Disk retains the current crop records after undo")
	var final_layout: Dictionary=scene.farm_state.snapshot().layout
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(normal_path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene;await frames(6)
	expect(scene.courtyard_plan.snapshot()==final_layout and scene.farm.fields.size()==7,"Reopening restores the added field and layout")
	expect(scene.farm_state.get_cell(id,cell).crop_id=="greens","Reopening retains new-field planting")
	scene.atmosphere.set_preview_hour(11);await shot("04-reopened")
	scene._begin_construction("fields");await create_timer(1).timeout
	root.size=Vector2i(960,600);await frames(5)
	expect(scene.island_builder._panel.get_global_rect().end.y<=root.get_visible_rect().size.y,"Field actions and Finish fit the minimum window")
	await shot("05-small-window")
	scene.island_builder.finish()
	await finish()
