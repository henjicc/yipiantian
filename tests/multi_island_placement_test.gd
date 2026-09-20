extends "res://../tests/island_fields_test.gd"
const Space=preload("res://layout/island_space.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
const Geometry=preload("res://presentation/decoration_geometry.gd")
var now: float=2000000.0

func _field_site() -> Vector2:
	var plan: RefCounted=Plan.from_snapshot(scene.courtyard_plan.snapshot())
	var field: Dictionary=Plan.resized_field(plan.fields[0],2,2,Vector2(1.4,1.17))
	field.id="field_07";plan.fields.append(field)
	for z: float in [-2.5,-3.5,-1.5,-5.5,.0]:
		for x: float in [15,14.5,15.5,12,11.5,14,16]:
			field.position=Vector3(x,plan.ground_height_at(Vector2(x,z))+.07,z)
			if not Circulation.field_placement_issues(plan,scene.get_node("Environment").layout_obstacles).is_empty(): continue
			var paths:=Circulation.new();paths.build(plan,scene.get_node("Environment").layout_obstacles)
			if paths.issues.is_empty(): return Vector2(x,z)
	return Vector2.INF

func _bench_site() -> Vector2:
	var environment: Node3D=scene.get_node("Environment")
	var prop: Node3D=Geometry.build(environment,"bench");scene.add_child(prop)
	for z: float in [-2,-3,-4,-1,0,-5]:
		for x: float in [11.5,12,14.5,15,15.5,16]:
			Geometry.pose(prop,{"slot_id":"","position":[x,z],"quarter_turn":0},environment.plan)
			if scene.decoration_layout.placement_issue(prop,"bench","").is_empty(): prop.free();return Vector2(x,z)
	prop.free();return Vector2.INF

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/multi-island-placement-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	if OS.get_cmdline_user_args().has("--routes"):
		await _routes();await finish();return
	if OS.get_cmdline_user_args().has("--structures"):
		await _structures();await finish();return
	var site: Vector2=_field_site();print("EAST_FIELD_SITE ",site)
	expect(site.is_finite(),"An empty east-bank site can connect to the house across the existing bridge")
	if not site.is_finite(): await finish();return
	var original: Dictionary=scene.farm_state.snapshot()
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	await choose_tool("fields")
	scene.camera._move_to(Vector3(12,.4,-2.5),Vector3(24,65,24));await create_timer(1).timeout
	var builder: Node=scene.island_builder
	await click(builder._field_actions.get_node("AddField"))
	var a: Vector2=site-Vector2(.7,.6);var b: Vector2=site+Vector2(.7,.6)
	await drag(Vector3(a.x,.11,a.y),Vector3(b.x,.11,b.y))
	expect(builder.draft.fields.size()==7,"Real pointer drag creates a field on the opposite island")
	if builder.draft.fields.size()!=7: await shot("failed-create");await finish();return
	if not await ready_draft(): await shot("failed-east-field");await finish();return
	expect(absf(builder.candidate.fields[6].position.y-.18)<.001,"Field soil follows the east island's own height")
	expect(scene.farm_state.snapshot()==original,"East field preview leaves the authoritative farm unchanged")
	await shot("01-east-field-preview")
	var before: Dictionary=builder.draft.duplicate(true)
	var normal_path: String=scene.store.directory
	var file:=FileAccess.open(folder.path_join("blocked"),FileAccess.WRITE);file.store_string("file");file.close()
	scene.store.directory=folder.path_join("blocked/child")
	await click(builder._panel.find_child("Finish",true,false))
	expect(builder.active and builder.draft==before and scene.farm_state.snapshot()==original,"Failed east-island save preserves both original state and retryable draft")
	scene.store.directory=normal_path
	var scene_id: int=scene.get_instance_id()
	await click(builder._panel.find_child("Finish",true,false))
	expect(not builder.active and scene.farm.fields.size()==7 and scene.get_instance_id()==scene_id,"Finish adopts the east field without replacing the scene")
	scene._focus_field(6);await create_timer(1).timeout
	scene._select_crop("greens")
	var id: String=scene.farm.field_id(6);var cell: String=scene.farm.cell_ids(6)[0]
	var at: Vector3=scene.farm.fields[6].to_global(scene.farm.cell_position(6,cell))
	await mouse(scene.camera.unproject_position(at),true);await mouse(scene.camera.unproject_position(at),false)
	expect(scene.farm_state.get_cell(id,cell).crop_id=="greens","The saved east field accepts actual mouse planting")
	await shot("02-east-field-planted")
	scene._begin_construction("bench");await create_timer(1).timeout
	scene.camera._move_to(Vector3(12,.4,-2.5),Vector3(24,65,24));await create_timer(1).timeout
	var bench_site: Vector2=_bench_site();print("EAST_BENCH_SITE ",bench_site)
	expect(bench_site.is_finite(),"An east-bank bench has a supported footprint away from the planted field and paths")
	if not bench_site.is_finite(): await finish();return
	await drag(Vector3(bench_site.x,.11,bench_site.y),Vector3(bench_site.x,.11,bench_site.y))
	var decor: Node=scene.decoration_layout
	expect(decor.has_preview() and absf(decor._preview.global_position.y-.115)<.001,"Actual free placement previews the bench at east ground height")
	if not decor.has_preview(): await finish();return
	var preview_id: int=decor._preview.get_instance_id()
	await click(builder._confirm)
	expect(decor._instances.has("bench") and decor._instances.bench.get_instance_id()==preview_id,"East bench save keeps the same visible model")
	var saved: Dictionary=scene.decoration_state.snapshot()
	await choose_tool("bench")
	await drag(Vector3(bench_site.x,.11,bench_site.y),Vector3(8,.13,3))
	expect(not decor.placement_issue(decor._preview,"bench","").is_empty(),"Dragging from the east bank into water rejects unsupported placement")
	builder.cancel_draft();await frames()
	expect(scene.decoration_state.snapshot()==saved and absf(decor._instances.bench.position.y-.115)<.001,"Cancel restores the original east bench")
	now+=30;scene.settle_farm();scene._save_farm()
	var planted: Dictionary=scene.farm_state.get_cell(id,cell).duplicate(true)
	await click(builder._undo)
	expect(scene.decoration_state.snapshot().bench.position.is_empty(),"Undo removes the latest east-island bench placement")
	expect(scene.farm_state.get_cell(id,cell)==planted,"Construction undo preserves the later crop and its settled growth time")
	await choose_tool("bench");decor.preview_on_ground(bench_site);await click(builder._panel.find_child("Finish",true,false))
	await shot("03-east-built")
	var layout: Dictionary=scene.courtyard_plan.snapshot()
	var state: Dictionary=scene.farm_state.snapshot()
	saved=scene.decoration_state.snapshot()
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(normal_path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.courtyard_plan.snapshot()==layout and scene.decoration_state.snapshot()==saved,"Actual scene restart restores opposite-bank layout and furniture")
	expect(scene.farm_state.snapshot().fields==state.fields,"Actual scene restart preserves east crops")
	var environment: Node3D=scene.get_node("Environment")
	var endpoints: Dictionary=environment.circulation.endpoints
	expect(environment.circulation.issues.is_empty() and not environment.circulation.road.path(endpoints.house,endpoints[id]).is_empty(),"Reloaded east field remains reachable across the bridge")
	var east_paths_valid: bool=true
	for path: PackedVector3Array in scene.courtyard_plan.paths:
		for p: Vector3 in path:
			if p.x>10 and absf(p.y-.095)>.001: east_paths_valid=false
	expect(east_paths_valid,"East paving follows east ground height")
	scene._begin_construction("fields");await create_timer(1).timeout
	scene.camera._move_to(Vector3(13,.4,-2.5),Vector3(100,55,18));await create_timer(1).timeout;await shot("04-east-reopened-side")
	scene.camera._move_to(Vector3(13,.4,-2.5),Vector3(-80,45,18));await create_timer(1).timeout;await shot("05-east-reopened-back")
	scene.atmosphere.set_preview_hour(22);root.size=Vector2i(960,640);await frames(8);await shot("06-east-small-night")
	await finish()

func _checked(preview: Node) -> String:
	var started: int=Time.get_ticks_msec()
	while preview.pending:
		await process_frame
		if Time.get_ticks_msec()-started>25000: return "check timeout"
	return scene.island_builder.issue()

func _routes() -> void:
	var rules=preload("res://layout/player_routes.gd")
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	var builder: Node=scene.island_builder
	scene.camera._move_to(Vector3(13,.4,-2.5),Vector3(24,65,24));await create_timer(1).timeout
	for kind: String in ["road","fence"]:
		await choose_tool(kind)
		var start:=Vector2.INF
		for z: float in [-3,-2.5,-4,-1.5,-5.5]:
			for x: float in [14.5,15,11.5,12]:
				var plan: RefCounted=Plan.from_snapshot(scene.courtyard_plan.snapshot())
				plan.routes.append({"id":plan.routes.size()+1,"kind":kind,"points":[[x,z],[x+1,z]],"openings":[]})
				if kind=="fence" and rules.fence_spans(plan.routes,0).is_empty(): continue
				if rules.placement_issue(plan,scene.get_node("Environment").layout_obstacles).is_empty(): start=Vector2(x,z);break
			if start.is_finite(): break
		expect(start.is_finite(),"Supported east island site exists for "+kind)
		if not start.is_finite(): return
		await drag(Vector3(start.x,.11,start.y),Vector3(start.x+1,.11,start.y))
		expect(is_instance_valid(builder.route_preview),"Real drag previews east "+kind)
		if not is_instance_valid(builder.route_preview): return
		var issue: String=await _checked(builder.route_preview)
		expect(issue.is_empty(),"East line retains passage: "+issue)
		if not issue.is_empty(): return
		await click(builder._confirm)
		expect(scene.courtyard_plan.routes[-1].kind==kind,"East line saved: "+kind)
	var routes: Node3D=scene.get_node("Environment/PlayerRoutes")
	var grounded: bool=true
	for stone: Node3D in routes.roads.get_children():
		if absf(stone.position.y-.095)>.001: grounded=false
	for span: Dictionary in routes._spans:
		if absf(span.a.y-.11)>.001 or absf(span.b.y-.11)>.001: grounded=false
	expect(grounded and not routes._spans.is_empty(),"Actual road stones and fence posts use the east bank height")
	scene.camera._move_to(Vector3(14,.4,-3),Vector3(100,45,16));await create_timer(1).timeout;await shot("11-east-routes-side")
	scene.camera._move_to(Vector3(14,.4,-3),Vector3(-80,45,16));await create_timer(1).timeout;await shot("12-east-routes-back")
	var saved: Dictionary=scene.courtyard_plan.snapshot();var path: String=scene.store.directory
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.courtyard_plan.snapshot()==saved and scene.get_node("Environment").circulation.issues.is_empty(),"East roads and fence restore with connected circulation")

func _structures() -> void:
	var builder: Node=scene.island_builder
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	if OS.get_cmdline_user_args().has("--kitchen"):
		await _kitchen();return
	await choose_tool("trellis")
	var original: Dictionary=scene.farm_state.snapshot()
	var site:=Vector2.INF
	for z: float in [-2.5,-3,-2,-1.5,-5.5]:
		for x: float in [15,14.5,15.5,11.5,12]:
			builder.draft.construction.trellis=[2.4,.8,2.2,x,z,0];builder._refresh()
			if not builder.trellis_preview.message.is_empty(): continue
			if (await _checked(builder.trellis_preview)).is_empty(): site=Vector2(x,z);break
		if site.is_finite(): break
	expect(site.is_finite(),"Trellis and its roots can fit and connect on the existing east island");print("EAST_TRELLIS_SITE ",site)
	if not site.is_finite(): await shot("failed-trellis");return
	var expected: Dictionary=builder.draft.duplicate(true)
	var preview_id: int=builder.trellis_preview.structure.get_instance_id()
	expect(absf(builder.trellis_preview.bed.position.y-.11)<.001,"Live trellis bed uses east ground")
	builder.cancel_draft();await frames()
	expect(scene.farm_state.snapshot()==original and scene.get_node("Environment/EntranceTrellis").visible,"Cancel restores the authored trellis on the main island")
	builder.draft=expected;builder._refresh()
	expect((await _checked(builder.trellis_preview)).is_empty(),"East trellis remains admissible after cancel")
	preview_id=builder.trellis_preview.structure.get_instance_id()
	await click(builder._confirm)
	expect(scene.get_node("Environment/EntranceTrellis").get_instance_id()==preview_id and absf(scene.courtyard_plan.anchors.trellis.y-.11)<.001,"Save adopts the east trellis without reloading its mesh")
	scene.camera._move_to(Vector3(13,.4,-2.5),Vector3(100,45,18));await create_timer(1).timeout;await shot("07-east-trellis-side")
	scene.camera._move_to(Vector3(13,.4,-2.5),Vector3(-80,45,18));await create_timer(1).timeout;await shot("08-east-trellis-back")
	# Undo frees the small island for the larger kitchen assembly.
	await click(builder._undo);await frames()
	var started: int=Time.get_ticks_msec()
	while builder.busy:
		await process_frame
		if Time.get_ticks_msec()-started>25000: expect(false,"Trellis undo completes");return
	expect(scene.courtyard_plan.snapshot()==original.layout,"Undo restores the main-island trellis before switching tools")
	await _kitchen()

func _kitchen() -> void:
	var builder: Node=scene.island_builder
	await choose_tool("kitchen")
	expect(builder.tool=="kitchen","Kitchen tool is available after the asynchronous undo")
	if builder.tool!="kitchen": return
	var site:=Vector2.INF
	for yaw: float in [0,90,-90,-180]:
		for z: float in [-2.5,-3.5,-1.5,-4.5]:
			for x: float in [14.5,15,12,11.5,13.5]:
				builder.draft.construction.buildings.kitchen=[x,z,yaw];builder._refresh()
				if not is_instance_valid(builder.building_preview): expect(false,"Kitchen preview exists for valid parameters");return
				if not builder.building_preview.message.is_empty(): continue
				var message: String=await _checked(builder.building_preview)
				if message.is_empty(): site=Vector2(x,z);break
				var routes:=Circulation.new();routes.build(builder.candidate,builder.building_preview._obstacles)
				print("KITCHEN_ROUTE_REJECT ",Vector3(x,yaw,z)," ",routes.issues)
			if site.is_finite(): break
		if site.is_finite(): break
	print("EAST_KITCHEN_SITE ",site)
	expect(site.is_finite(),"Kitchen assembly can fit on the east bank with an accessible door")
	if not site.is_finite(): await shot("failed-kitchen");return
	var chosen_yaw: float=builder.candidate.angles.kitchen
	builder.cancel_draft();await frames()
	scene.camera._move_to(Vector3(4,.4,-2),Vector3(24,65,44));await create_timer(1).timeout
	var kitchen: Node3D=scene.get_node("Environment/Kitchen")
	var origin: Vector3=kitchen.global_position
	var grab: Vector3=origin+Vector3.UP*2.4
	var pointer: Vector2=builder.world_point(scene.camera.unproject_position(grab))
	var target: Vector2=pointer+site-Vector2(origin.x,origin.z)
	await drag(grab,Vector3(target.x,scene.courtyard_plan.ground_height_at(target),target.y))
	expect(builder.candidate.anchors.kitchen.distance_to(Vector3(site.x,.095,site.y))<.01,"Actual roof drag moves kitchen across the bridge to the east island")
	if chosen_yaw!=0: builder.draft.construction.buildings.kitchen[2]=chosen_yaw;builder._refresh()
	expect((await _checked(builder.building_preview)).is_empty(),"Mouse-dragged kitchen retains its door and bridge passage")
	expect(absf(scene.get_node("Environment/Kitchen").position.y-.095)<.001,"Kitchen preview lowers the whole assembly to east ground")
	await click(builder._confirm)
	expect(absf(scene.courtyard_plan.anchors.kitchen.y-.095)<.001,"Kitchen placement saves on the east island")
	scene.camera._move_to(Vector3(13,.4,-2.5),Vector3(100,45,18));await create_timer(1).timeout;await shot("09-east-kitchen-side")
	var depth: Vector2=scene.focus_detail.depth_range(scene.camera,Transform3D(Basis.IDENTITY,scene.courtyard_plan.anchors.kitchen),AABB(Vector3(-2,0,-2),Vector3(4,4,4)))
	expect(scene.camera.attributes.dof_blur_near_distance<=depth.x and scene.camera.attributes.dof_blur_far_distance>=depth.y,"Construction clear band protects the moved east kitchen from either view direction")
	scene.camera._move_to(Vector3(13,.4,-2.5),Vector3(-80,45,18));await create_timer(1).timeout;await shot("10-east-kitchen-back")
	var layout: Dictionary=scene.courtyard_plan.snapshot();var path: String=scene.store.directory
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.courtyard_plan.snapshot()==layout and scene.get_node("Environment").circulation.issues.is_empty(),"Moved kitchen and reachable entrance survive actual reopening")
	expect(absf(scene.get_node("Environment/Kitchen").position.y-.095)<.001,"Reloaded kitchen retains the same ground contact")
