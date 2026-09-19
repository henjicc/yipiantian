extends "res://../tests/island_fields_test.gd"
const Support=preload("res://layout/land_support.gd")
var now: float=2000000.0

func shore_grass_checks(preview: bool=true) -> void:
	var environment: Node3D=scene.get_node("Environment")
	var brush: Node=scene.island_builder
	var plan: RefCounted=brush.candidate if preview else scene.courtyard_plan
	for expansion: bool in [false,true]:
		var shown: Node3D
		if preview: shown=brush._shore._grass if expansion else brush._shore._core
		else: shown=environment.get_node("ExpansionGrass" if expansion else "GroundCover/CoreGrass")
		var reference:=preload("res://scenes/environment/ground_cover.gd").new()
		reference._exclusions=shown._exclusions.duplicate();reference.object_footprints=shown.object_footprints.duplicate()
		reference.update_tiles(plan,expansion)
		expect(grass_appearance(shown)==grass_appearance(reference),"Local shore grass matches fresh full geometry on "+("added land" if expansion else "original land"))
		reference.free()

func east_view() -> void:
	scene.camera._move_to(Vector3(16,.4,-2),Vector3(24,65,22));await create_timer(1).timeout

func grow() -> void:
	await drag(Vector3(16,.11,-3.5),Vector3(19,.11,-3.5))
	await drag(Vector3(16,.11,-2.5),Vector3(19,.11,-2.5))
	await drag(Vector3(16,.11,-1.5),Vector3(19,.11,-1.5))

func wait_terrain() -> void:
	await frames()
	var started: int=Time.get_ticks_msec()
	while scene.get_node("Environment")._terrain_refreshing:
		await process_frame
		if Time.get_ticks_msec()-started>30000: expect(false,"Latest terrain refresh finishes");return
	expect(scene.get_node("Environment/CourtyardAnimals").ready_for_motion,"Animals resume on the edited islands")

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/multi-island-land-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8);scene.atmosphere.set_preview_hour(11)
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout;await east_view()
	if OS.get_cmdline_user_args().has("--edges"):
		await edge_checks();await finish();return
	var brush: Node=scene.island_builder
	var original: Dictionary=scene.farm_state.snapshot()
	var original_mesh: Mesh=scene.get_node("Environment/MainBank").get_child(0).mesh
	var main_rock: Node3D
	for child: Node in scene.get_node("Environment").get_children():
		if child.has_meta("shore_stone") and child.get_meta("shore_island",0)==0: main_rock=child;break
	var main_rock_id: int=main_rock.get_instance_id()
	var original_fence: Node3D
	for child: Node in scene.get_node("Environment").get_children():
		if child.has_meta("fence_spans"): original_fence=child;break
	var fence_id: int=original_fence.get_instance_id()
	await mouse(scene.camera.unproject_position(Vector3(16,.11,-3.5)),true)
	var motion:=InputEventMouseMotion.new();motion.position=scene.camera.unproject_position(Vector3(19,.11,-3.5));motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	motion.window_id=root.get_window_id();root.push_input(motion,true);await frames()
	expect(brush.draft.construction.east_land.size()>1 and brush.draft.construction.land.is_empty(),"Held drag grows only the island where it began")
	if brush.draft.construction.east_land.is_empty(): await shot("failed-held");await finish();return
	expect(not scene.get_node("Environment/EastBank").visible and scene.get_node("Environment/MainBank").visible,"East shore appears live without hiding the main island")
	expect(scene.farm_state.snapshot()==original,"Held east terrain remains a preview")
	await shot("01-held-east-growing")
	brush._focus_lost();await frames()
	expect(brush.draft==original.layout and scene.get_node("Environment/EastBank").visible,"Focus loss restores both islands")
	await mouse(motion.position,false)
	await grow()
	shore_grass_checks()
	expect(is_instance_valid(original_fence) and original_fence.visible and original_fence.get_instance_id()==fence_id,"Unchanged garden fence stays visible during east shore editing")
	expect(brush.issue().is_empty(),"East extension respects existing support and bridge water passage: "+brush.issue())
	if not brush.issue().is_empty(): await shot("failed-extension");await finish();return
	expect(brush._shore._grass.get_child_count()>0,"Grass exists on the added east land before save")
	var expanded: Dictionary=brush.candidate.snapshot()
	var grass_id: int=brush._shore._grass.get_instance_id()
	var scene_id: int=scene.get_instance_id()
	var save_path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocked"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocked/child")
	await click(brush._panel.find_child("Finish",true,false))
	expect(brush.active and not brush.busy and brush._status.text.contains("未能保存") and scene.farm_state.snapshot()==original,"Actual failed save keeps original islands and a retryable preview")
	scene.store.directory=save_path
	await click(brush._panel.find_child("Finish",true,false))
	expect(not brush.active and scene.get_instance_id()==scene_id and scene.courtyard_plan.snapshot()==expanded,"Retry completes in the current scene")
	expect(scene.get_node("Environment/ExpansionGrass").get_instance_id()==grass_id,"Completion adopts the visible grass")
	expect(is_instance_valid(original_fence) and original_fence.visible and original_fence.get_instance_id()==fence_id and scene.get_node("Environment")._contact_sources.has(original_fence),"Saving east terrain retains unchanged fence geometry and contacts")
	expect(scene.get_node("Environment/MainBank").get_child(0).mesh==original_mesh and is_instance_valid(main_rock) and main_rock.get_instance_id()==main_rock_id,"Editing east leaves main bank mesh and rocks untouched")
	await wait_terrain()
	expect(not scene.get_node("Environment/CourtyardAnimals").water.contains(Vector2(18,-2.5)),"Water animals cannot enter the new east land")
	scene._begin_construction("fields");await create_timer(1).timeout;await east_view()
	await click(brush._field_actions.get_node("AddField"))
	await drag(Vector3(17,.11,-3),Vector3(18.5,.11,-1.5))
	expect(brush.draft.fields.size()==7,"Real field drag uses the east extension")
	if brush.draft.fields.size()!=7 or not await ready_draft(): await shot("failed-field");await finish();return
	await click(brush._panel.find_child("Finish",true,false))
	expect(scene.farm.fields.size()==7 and absf(scene.courtyard_plan.fields[6].position.y-.18)<.001,"New field saves on the actual east ground height")
	scene._focus_field(6);await create_timer(1).timeout;scene._select_crop("greens")
	var id: String=scene.farm.field_id(6);var cell: String=scene.farm.cell_ids(6)[0]
	var at: Vector3=scene.farm.fields[6].to_global(scene.farm.cell_position(6,cell))
	await mouse(scene.camera.unproject_position(at),true);await mouse(scene.camera.unproject_position(at),false)
	expect(scene.farm_state.get_cell(id,cell).crop_id=="greens","The extension supports actual mouse planting")
	scene._begin_construction("land");await create_timer(1).timeout;await east_view()
	await click(brush._panel.find_child("LandErase",true,false))
	var planted: Dictionary=scene.farm_state.snapshot().layout
	await drag(Vector3(19,.11,-2.5),Vector3(19,.11,-2.5))
	expect(brush.draft==planted and brush._brush_message.contains("田块"),"Shrink refuses to remove east crop support")
	await shot("02-field-protected")
	await click(brush._panel.find_child("Cancel",true,false))
	await drag(Vector3(19.5,.11,-1),Vector3(19.5,.11,-1))
	expect(brush.draft!=planted and brush.issue().is_empty(),"A free east edge can be trimmed")
	if brush.draft==planted or not brush.issue().is_empty(): await shot("failed-shrink");await finish();return
	shore_grass_checks()
	var trimmed: Dictionary=brush.candidate.snapshot()
	await click(brush._confirm);await wait_terrain()
	expect(scene.courtyard_plan.snapshot()==trimmed,"East shrink adopts the live terrain")
	now+=60;expect(scene.farm_state.harvest("field_03","cell_06",now).ok,"Later main-island harvest still works")
	scene.refresh_farm();scene._save_farm()
	var later: Dictionary=scene.farm_state.snapshot()
	await click(brush._undo);await wait_terrain()
	expect(scene.courtyard_plan.snapshot()==planted and scene.farm_state.snapshot().inventory==later.inventory and scene.farm_state.snapshot().fields==later.fields,"Undo restores only east terrain and retains later harvest and crop state")
	shore_grass_checks(false)
	await drag(Vector3(19.5,.11,-1),Vector3(19.5,.11,-1));await click(brush._panel.find_child("Finish",true,false));await wait_terrain()
	var final_state: Dictionary=scene.farm_state.snapshot()
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(save_path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8);scene.atmosphere.set_preview_hour(11)
	expect(scene.courtyard_plan.snapshot()==trimmed and scene.farm_state.snapshot().fields==final_state.fields,"Actual reopen preserves both edited land and crops on the extension")
	expect(scene.courtyard_plan.unpainted()!=null,"Original bank geometry remains available after crops occupy an extension")
	scene.camera.focus_point=Vector3(17,.3,-2.5);scene.camera.view=Vector3(130,40,13);await frames(8);await shot("03-east-reopened-back")
	scene.camera.view=Vector3(230,35,13);await frames(8);await shot("04-east-reopened-side")
	root.size=Vector2i(960,640);scene.atmosphere.set_preview_hour(21);scene._begin_construction("land");await create_timer(1).timeout;await east_view();await shot("05-east-small-night")
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Island brush controls remain usable in a small window")
	await finish()

func edge_checks() -> void:
	var brush: Node=scene.island_builder
	var initial: Dictionary=scene.farm_state.snapshot().layout
	expect(Support.neighbor_issue(scene.get_node("Environment"),scene.courtyard_plan).is_empty(),"Original island spacing is valid")
	var coves: Array=scene.courtyard_plan.lily_coves.duplicate()
	await drag(Vector3(14,.11,1),Vector3(14,.11,3))
	expect(brush.candidate.lily_coves!=coves and brush.candidate.lily_coves[0]==coves[0],"East lotus follows a southward shore extension while distant main lotus stays put")
	await shot("00-east-lotus-following")
	brush.cancel_draft();await frames()
	expect(scene.courtyard_plan.lily_coves==coves,"Cancelling restores original water-plant anchors")
	await grow()
	var east: Array=brush.draft.construction.east_land.duplicate(true)
	var east_mesh: Mesh=brush._shore._surfaces[1].mesh
	scene.camera._move_to(Vector3(0,.4,5),Vector3(24,65,22));await create_timer(1).timeout
	await drag(Vector3(0,.13,6),Vector3(0,.13,8))
	expect(not brush.draft.construction.land.is_empty() and brush.draft.construction.east_land==east,"Separate strokes can edit both islands in one draft without changing the other log")
	expect(brush._shore._surfaces[1].mesh==east_mesh,"Further main-island painting retains the unchanged east preview mesh")
	shore_grass_checks()
	expect(brush.issue().is_empty(),"Combined two-island draft passes support and spacing checks: "+brush.issue())
	await click(brush._confirm);await wait_terrain()
	var combined: Dictionary=scene.farm_state.snapshot().layout
	expect(not combined.construction.land.is_empty() and combined.construction.east_land==east,"One confirmation persists both island edits")
	await click(brush._undo);await wait_terrain()
	expect(scene.courtyard_plan.snapshot()==initial,"Undo restores both banks together: "+brush._status.text)
	shore_grass_checks(false)
	if scene.courtyard_plan.snapshot()!=initial: await shot("failed-both-undo");return
	await east_view();await click(brush._panel.find_child("LandErase",true,false))
	await drag(Vector3(10,.11,0),Vector3(10,.11,0))
	expect(brush.draft==initial,"East bridge landing support cannot be erased")
	await click(brush._panel.find_child("Cancel",true,false))
	await drag(Vector3(13,.11,-6),Vector3(13,.11,-6))
	expect(brush.draft==initial and not brush._brush_message.is_empty(),"East authored tree root support cannot be erased")
	await click(brush._panel.find_child("Cancel",true,false));await click(brush._panel.find_child("LandAdd",true,false))
	scene.camera._move_to(Vector3(12,.4,-9),Vector3(24,65,27));await create_timer(1).timeout
	await drag(Vector3(12,.11,-6),Vector3(12,.11,-15))
	expect(brush.draft!=initial and brush.issue().contains("邻岛") and brush._confirm.disabled,"Real northward brush reports the neighboring island and cannot commit an overlap")
	await shot("06-neighbor-protected")
	brush.cancel_draft();await frames()
	expect(scene.courtyard_plan.snapshot()==initial and scene.get_node("Environment/EastBank").visible,"Cancelling the neighbor conflict restores the original east shore")
	scene.camera._move_to(Vector3(0,.4,-7),Vector3(24,65,22));await create_timer(1).timeout
	await click(brush._panel.find_child("LandErase",true,false))
	await drag(Vector3(0,.13,-8.5),Vector3(.5,.13,-8.5))
	expect(brush.draft!=initial and brush.issue().is_empty(),"Main-island original ground can still be trimmed")
	if brush.draft!=initial:
		shore_grass_checks()
		brush.cancel_draft();await frames();shore_grass_checks(false)
		expect(scene.get_node("Environment/GroundCover/CoreGrass").visible,"Cancelling main shrink restores visible original grass")
