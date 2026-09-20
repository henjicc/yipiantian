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

func path_appearance(paths: Node3D) -> Array:
	var result: Array=[]
	for stone: Node3D in paths.get_children():
		var meshes: Array=[]
		var geometry: Array[Node]=stone.find_children("*","MeshInstance3D",true,false)
		if stone is MeshInstance3D: geometry.push_front(stone)
		assert(not geometry.is_empty(),"Path appearance includes actual stone meshes")
		for mesh: MeshInstance3D in geometry:
			var surfaces: Array=[]
			for i: int in mesh.mesh.get_surface_count():
				var material: ShaderMaterial=mesh.get_active_material(i)
				surfaces.append([material.shader,material.get_shader_parameter("base_color"),material.get_shader_parameter("rock_color"),material.get_shader_parameter("ground_level")])
			meshes.append([mesh.mesh,mesh.transform,surfaces])
		result.append([stone.transform,meshes])
	return result

func path_reuse_checks() -> void:
	var environment: Node3D=scene.get_node("Environment")
	var plan:=Plan.new()
	plan.paths=[PackedVector3Array([Vector3(0,.11,0),Vector3(2,.11,0)])]
	var original: Node3D=environment.make_paths(plan)
	var before: Array=path_appearance(original)
	plan.paths=[PackedVector3Array([Vector3(1,.11,1),Vector3(5,.11,2)]),PackedVector3Array([Vector3(3,.11,1),Vector3(3,.11,4)])]
	var reused: Node3D=environment.make_paths(plan,original)
	var fresh: Node3D=environment.make_paths(plan)
	expect(reused.get_child_count()>original.get_child_count() and path_appearance(reused)==path_appearance(fresh),"Reused and newly added stones match fresh path shape, pose, paint and ground height")
	expect(path_appearance(original)==before,"Preview road creation does not move or recolor the original stones")
	plan.paths=[PackedVector3Array([Vector3(-1,.11,0),Vector3(0,.11,0)])]
	var shorter: Node3D=environment.make_paths(plan,reused)
	var short_fresh: Node3D=environment.make_paths(plan)
	expect(shorter.get_child_count()<reused.get_child_count() and path_appearance(shorter)==path_appearance(short_fresh),"Repeated preview can shrink and relocate paths without stale stones")
	for node: Node3D in [shorter,short_fresh,reused,fresh]: node.free()
	expect(path_appearance(original)==before,"Cancelling reused roads leaves original materials and transforms intact")
	original.free()

func grass_appearance(cover: Node3D) -> Dictionary:
	var result: Dictionary={}
	for cell: Vector2i in cover._tiles:
		var mesh: MeshInstance3D=cover._tiles[cell]
		var arrays: Array=mesh.mesh.surface_get_arrays(0)
		result[cell]=[mesh.transform,arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_COLOR]]
	return result

func grass_reuse_checks() -> void:
	var preview: Node3D=scene.island_builder.field_preview
	for expansion: bool in [false,true]:
		var shown: Node3D=preview.expansion if expansion else preview.core
		var reference:=preload("res://scenes/environment/ground_cover.gd").new()
		reference._exclusions=shown._exclusions.duplicate();reference.object_footprints=shown.object_footprints.duplicate()
		reference.update_tiles(preview.validated,expansion)
		expect(grass_appearance(shown)==grass_appearance(reference),"Local field/path grass update matches full generated geometry on "+("added land" if expansion else "original land"))
		var source: Node3D=scene.get_node("Environment/ExpansionGrass" if expansion else "Environment/GroundCover/CoreGrass")
		var visible: Array[Node3D]=[]
		for parent: Node3D in [source,shown]:
			for tile: Node3D in parent.get_children():
				if tile.is_visible_in_tree(): visible.append(tile)
		var complete: bool=visible.size()==shown._tiles.size()
		for tile: Node3D in shown._tiles.values(): complete=complete and tile in visible
		expect(complete,"Field grass preview shows each final tile once with no stale original grass")
		reference.free()

func borrowed_field_checks() -> bool:
	var originals: Array=scene.farm.fields.duplicate()
	var layout: Dictionary=scene.farm_state.snapshot().layout
	scene._begin_construction("fields");await create_timer(1).timeout
	var builder: Node=scene.island_builder
	builder.selected_field=0;builder._field_action("remove");await frames()
	expect(is_instance_valid(originals[0]) and not originals[0].visible,"Removing a borrowed empty field retains its original for cancellation")
	var indices: bool=true
	for i: int in builder.field_preview.farm.fields.size():
		indices=indices and builder.field_preview.farm.fields[i].get_meta("field_index")==i
	expect(indices,"Removing a field gives remaining preview fields their actual picking indices")
	builder.cancel_draft();await frames();builder.finish();await frames()
	var restored: bool=scene.farm.fields==originals and scene.farm_state.snapshot().layout==layout
	for i: int in originals.size():
		restored=restored and originals[i].is_visible_in_tree() and originals[i].collision_layer==1 and originals[i].get_meta("field_index")==i
	expect(restored,"Cancel restores the exact original fields, visibility and picking after a removal")
	scene._begin_construction("fields");await create_timer(1).timeout
	expect(scene.farm_state.sow("field_01","cell_01","greens",2000000.0).ok,"Live borrowed-field fixture plants through the farming rules")
	scene.refresh_farm()
	expect(originals[0].get_node("Crops/cell_01").get_meta("stage_key")=="greens/sprout","An unchanged borrowed field displays later planting")
	scene.clock=func() -> float: return 2003600.0
	scene.settle_farm();await frames()
	expect(originals[0].get_node("Crops/cell_01").get_meta("stage_key")=="greens/mature" and originals[0].is_visible_in_tree(),"An unchanged borrowed crop keeps growing visibly during construction")
	await click(builder._field_actions.get_node("AddField"));await drag(Vector3(-1.5,.13,7),Vector3(1,.13,9))
	if not await ready_draft(): return false
	await click(builder._panel.find_child("Finish",true,false))
	expect(not builder.active and scene.farm.fields[0]==originals[0] and originals[0].get_node("Crops/cell_01").get_meta("stage_key")=="greens/mature","Saving another field adopts the current grown crop without replacing it")
	expect(scene.farm_state.harvest("field_01","cell_01",2003600.0).ok,"Adopted living field can still be harvested")
	scene.refresh_farm();await frames()
	expect(not originals[0].has_node("Crops/cell_01"),"The adopted field removes a harvested crop using its current visual records")
	return true

func _run() -> void:
	if OS.get_cmdline_user_args().has("--paths-only"):
		scene=Node3D.new()
		var environment: Node3D=load("res://scenes/environment/courtyard.gd").new();environment.name="Environment"
		scene.add_child(environment)
		path_reuse_checks();scene.free()
		print("PATH_APPEARANCE checks=",checks," failures=",failures.size());quit(0 if failures.is_empty() else 1);return
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/island-fields-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var plan:=Plan.new()
	plan.apply_construction({"east_land":[],"land":[[-3,5,5,5]],"trellis":[],"bridge":[],"buildings":{"house":[],"kitchen":[]},"flocks":preload("res://layout/flock_layout.gd").initial()})
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=plan
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene;await frames(8)
	if OS.get_cmdline_user_args().has("--borrowed-only"):
		var completed: Variant=await borrowed_field_checks()
		expect(completed==true,"Borrowed-field lifecycle reaches its final harvest check")
		await finish();return
	path_reuse_checks()
	scene.atmosphere.set_preview_hour(11)
	var house_id: int=scene.get_node("Environment/MainHouse").get_instance_id()
	var water_id: int=scene.get_node("Environment/CourtyardAnimals").water.get_instance_id()
	var original: Dictionary=scene.farm_state.snapshot()
	var original_fields: Array=scene.farm.fields.duplicate()
	var original_paths: Node3D=scene.get_node("Environment/GardenPaths")
	var original_core: Node3D=scene.get_node("Environment/GroundCover/CoreGrass")
	var original_expansion: Node3D=scene.get_node("Environment/ExpansionGrass")
	var opening_tiles: Dictionary=original_core._tiles.duplicate()
	var original_fences: Array[Node3D]=[]
	for node: Node in scene.get_node("Environment").get_children():
		if node is Node3D and node.has_meta("fence_spans") and node.visible: original_fences.append(node)
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	await choose_tool("fields")
	expect(original_paths.is_visible_in_tree(),"Opening field tools retains the existing visible paths")
	for node: Node3D in original_fences: expect(node.is_visible_in_tree(),"Opening field tools retains existing fence and contact shadows")
	expect(not scene.island_builder.field_preview.pending,"Unchanged field layout needs no repeated navigation build")
	expect(scene.island_builder.field_preview.farm.fields==original_fields,"Opening fields reuses the actual existing field and crop instances")
	expect(scene.island_builder.field_preview.core._tiles==opening_tiles and original_core.is_visible_in_tree(),"Opening fields retains the actual unchanged grass tiles")
	await click(scene.island_builder._field_actions.get_node("AddField"))
	await drag(Vector3(-1.5,.13,7),Vector3(1,.13,9))
	var builder: Node=scene.island_builder
	expect(builder.draft.fields.size()==7,"Real drag creates a seventh field on painted land")
	expect(scene.farm_state.snapshot()==original,"Field preview cannot alter authoritative planting state")
	expect(builder.field_preview.farm.fields.size()==7 and builder.field_preview.farm.fields[6].is_visible_in_tree(),"New soil appears before save")
	expect(builder.field_preview.farm.fields.slice(0,6)==original_fields and original_fields[0].is_visible_in_tree(),"Adding a field leaves existing living fields visible in place")
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
	grass_reuse_checks()
	await shot("01-new-field-preview")
	var wanted: Dictionary=builder.draft.duplicate(true)
	var start: int=Time.get_ticks_msec()
	await click(builder._panel.find_child("Finish",true,false))
	print("FIELD_FINISH_INPUT_MS ",Time.get_ticks_msec()-start)
	expect(not builder.active and scene.farm_state.snapshot().layout==wanted,"Finish commits the visible field and exits")
	expect(scene.get_node("Environment/MainHouse").get_instance_id()==house_id,"Field completion retains the island scene")
	expect(scene.farm.fields.size()==7,"New field joins normal farming")
	expect(scene.farm.fields.slice(0,6)==original_fields,"Accepting the new field retains all six original field instances")
	expect(scene.get_node("Environment/GroundCover/CoreGrass")==original_core and scene.get_node("Environment/ExpansionGrass")==original_expansion,"Saving field edits keeps the original grass owners")
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
	grass_reuse_checks()
	for preview_body: StaticBody3D in builder.field_preview.farm.fields:
		expect(preview_body.collision_layer==0,"Preview fields cannot intercept normal farm picking")
	var before: Dictionary=scene.farm_state.snapshot()
	var center: Vector3=scene.courtyard_plan.fields[6].position
	var moved_original: Node3D=scene.farm.fields[6]
	var unmoved_original: Node3D=scene.farm.fields[0]
	await drag(center,center+Vector3(-.5,0,0))
	if not await ready_draft(): await shot("failure-move");await finish();return
	await click(builder._field_actions.get_node("RotateField"))
	if not await ready_draft(): await shot("failure-rotate");await finish();return
	expect(builder.draft.fields[6].yaw==15,"Rotate button updates the selected field")
	expect(not moved_original.is_visible_in_tree() and builder.field_preview.farm.fields[6]!=moved_original and builder.field_preview.farm.fields[6].is_visible_in_tree(),"Only the moved field uses a private visible replacement")
	expect(builder.field_preview.farm.fields[0]==unmoved_original and unmoved_original.is_visible_in_tree(),"Moving and rotating one field does not duplicate the untouched field")
	grass_reuse_checks()
	await shot("03-moved-rotated")
	var normal_path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocker"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocker/child")
	await click(builder._panel.find_child("Finish",true,false))
	expect(builder.active and not builder.busy and builder._status.text.contains("未能保存"),"Failed save keeps the field draft retryable")
	expect(scene.farm_state.snapshot()==before,"Failed field save leaves authoritative crops and layout unchanged")
	expect(is_instance_valid(moved_original) and not moved_original.visible,"Failed save retains the original field for cancellation")
	scene.store.directory=normal_path
	await click(builder._panel.find_child("Finish",true,false))
	expect(not builder.active,"Retry completes in place")
	expect(scene.farm.fields[0]==unmoved_original and unmoved_original.collision_layer==1,"Successful save retains the untouched field and restores ordinary picking")
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
