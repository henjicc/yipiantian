extends SceneTree
## Final shared-system boundary: a spatially admitted 12-field, 384-crop courtyard.
const Plan=preload("res://layout/courtyard_plan.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
const Farm=preload("res://farm/farm_state.gd")
const Store=preload("res://farm/farm_store.gd")
const Plants=preload("res://layout/plantings.gd")
const Flocks=preload("res://layout/flock_layout.gd")
var scene: Node
var folder: String
var failures: int=0
var measurements: Array[Dictionary]=[]
var construction_mode: bool=OS.get_cmdline_user_args().has("--construction")
var construction_completed: bool=false
var preplanted: bool=OS.get_cmdline_user_args().has("--preplanted")
var actions: Array[Dictionary]=[]
var _sample: Dictionary={}
var _sample_tick: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func write_json(name: String,value: Variant) -> void:
	var file:=FileAccess.open(folder.path_join(name+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t"));file.close()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	values.sort();return {"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"max":values[-1]}
func measure(label: String) -> void:
	await create_timer(1).timeout
	var gpu: Array[float]=[];var cpu: Array[float]=[];var intervals: Array[float]=[]
	var focus: int=0;var previous: int=Time.get_ticks_usec()
	for i: int in 120:
		await RenderingServer.frame_post_draw
		var tick: int=Time.get_ticks_usec();intervals.append((tick-previous)/1000.0);previous=tick
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu())
		if scene.window_activity.is_foreground(): focus+=1
	measurements.append({"view":label,"gpu_ms":stats(gpu),"cpu_render_ms":stats(cpu),"frame_interval_ms":stats(intervals),"foreground_frames":focus,"frames":120,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	await shot(label)
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../.local/verification/life-capacity-%d"%Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	print("EVIDENCE "+folder)
	if construction_mode: root.size=Vector2i(1600,900)
	var plan:=Plan.new();plan.expand_shore(8,8)
	var construction: Dictionary=plan.construction.duplicate(true)
	construction.east_land=[[15,-5,4,4],[18,-5,4,4],[15,-2,4,3],[18,-2,4,3]]
	check(preload("res://layout/island_construction.gd").valid(construction),"Capacity terrain uses legal brush stamp sizes")
	check(plan.apply_construction(construction),"Capacity fixture extends the east island with a connected shoreline")
	var probe:=preload("res://scenes/environment/courtyard.gd").new();probe.plan=plan;probe.layout_probe=true;probe.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(probe)
	var obstacles: Dictionary=probe.layout_obstacles.duplicate(true)
	root.remove_child(probe);probe.free()
	var prototype: Dictionary=Plan.resized_field(plan.fields[0],8,4,Vector2(5,2.05))
	plan.fields.clear()
	# Keep the admitted 12-field fixture fixed for comparable measurements.
	# Still verify it against actual model feet and complete island support.
	for point: Vector2 in [Vector2(-8.6,-5.5),Vector2(-10.7,-2.7),Vector2(-11.75,.1),Vector2(-2.3,.1),Vector2(-12.1,2.9),Vector2(-11.75,5.7),Vector2(-5.8,6.4),Vector2(.15,7.8),Vector2(-9.3,9.2),Vector2(-3.35,10.6),Vector2(2.6,10.6),Vector2(18.5,-2.5)]:
		var field: Dictionary=prototype.duplicate(true)
		field.position=Vector3(point.x,plan.ground_height_at(point)+.07,point.y)
		field.id="field_%02d"%(plan.fields.size()+1);field.seed=91744+plan.fields.size()*7919
		plan.fields.append(field)
		check(plan.supporting_island(plan.field_polygon(plan.fields.size()-1,.14))>=0,"Capacity field has full island support")
		for prior: int in plan.fields.size()-1:
			check(Geometry2D.intersect_polygons(plan.field_polygon(plan.fields.size()-1,.35),plan.field_polygon(prior,.35)).is_empty(),"Capacity fields preserve their working clearance")
	check(Circulation.field_placement_issues(plan,obstacles).is_empty(),"Capacity fields respect actual objects")
	check(plan.fields.size()==12,"Twelve complete fields fit real island and obstacles")
	var routes:=Circulation.new();routes.build(plan,obstacles)
	check(routes.issues.is_empty(),"Capacity layout keeps all entrances and fields connected: "+str(routes.issues))
	if construction_mode:
		for kind: String in ["duck","goose","hen"]:
			plan.construction.flocks[kind].count=Flocks.SPECIES[kind].limit
		# Keep all 28 animals moving in legal player-selectable areas. Random
		# swimmers entering an uncommitted brush made this performance fixture
		# wait for chance instead of measuring completion. Dynamic placement
		# clearance remains covered separately by plant_layout_test --clearance.
		plan.construction.flocks.duck.area=[-20.0,7.0,4.0,10.0]
		plan.construction.flocks.goose.area=[-6.0,-13.0,12.0,3.0]
		check(Flocks.valid(plan.construction.flocks) and Flocks.terrain_issue(plan).is_empty(),"Capacity animal areas are valid and clear of both banks")
	if preplanted:
		# Animals spawn with these real plant obstacles, so field measurements
		# do not depend on an animal walking out of an uncommitted plant brush.
		for i: int in Plants.MAX_CLUMPS:
			var entry: Dictionary=Plants.make_entry(i+1,"trapa",Vector2(17+(i%16)*.5,7+floori(i/16.0)*.5))
			check(Plants.habitat_issue(entry,plan,plan.water_banks()).is_empty(),"Established capacity plant has water support")
			plan.plants.append(entry)
	write_json("layout",plan.snapshot())
	if failures>0: print("CAPACITY_LAYOUT failures=",failures," count=",plan.fields.size()," evidence=",folder);quit(1);return
	var farm:=Farm.new(1000,plan.snapshot());var data: Dictionary=farm.snapshot();var species: Array[String]=Farm.Crops.seeds(false);var index: int=0
	for id: String in farm.field_ids():
		for cell: Dictionary in data.fields[id].cells.values():
			cell.ground="ready";cell.crop_id=species[index%species.size()];cell.growth_seconds=Farm.Crops.definition(cell.crop_id).duration_seconds;index+=1
	for cell: Dictionary in data.fields[Farm.Trellis.FIELD_ID].cells.values():
		cell.crop_id="luffa";cell.growth_seconds=Farm.Crops.definition("luffa").duration_seconds
	for home: String in Farm.Neighbors.IDS: data.neighbors[home]={"round":3,"pending":false,"last_gift":Farm.Neighbors.HOMES[home].gifts[0]}
	data.season="after_rain"
	check(index==384 and farm.restore_snapshot(data),"Maximum mixed-crop fixture is valid")
	if failures>0: print("CAPACITY_STATE failures=",failures," crops=",index);quit(1);return
	print("CAPACITY_STATE valid=true ground_crops=",index," trellis_crops=",data.fields[Farm.Trellis.FIELD_ID].cells.size())
	var store:=Store.new(folder.path_join("farm"));store.load_state();check(store.save(farm.snapshot(),preload("res://farm/decoration_state.gd").new().snapshot()).ok,"Maximum scene persists")
	scene=load("res://scenes/main.tscn").instantiate();scene.store=store;scene.settings_store=load("res://settings/settings_store.gd").new(folder.path_join("settings"));scene.clock=func() -> float: return 1000
	root.add_child(scene)
	# Fullscreen/DPI changes queue UI layout after the scene's ready callback.
	# A real player sees rendered controls before clicking their final positions.
	for i: int in 8: await RenderingServer.frame_post_draw
	while not scene.get_node("Environment/CourtyardAnimals").ready_for_motion: await process_frame
	if not construction_mode: root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	check(scene.farm.fields.size()==12,"All fields presented")
	for field: Node3D in scene.farm.fields: check(field.get_node("Crops").get_child_count()==32,"Each field renders 32 plants")
	check(scene.get_node("Environment/CourtyardAnimals").birds.size()==(28 if construction_mode else 7),"All animals coexist with capacity planting")
	if construction_mode:
		for kind: String in Flocks.KINDS:
			check(Flocks.space_issue(kind,Flocks.SPECIES[kind].limit,scene.get_node("Environment/CourtyardAnimals").flock_spaces[kind]).is_empty(),"Capacity animal regions retain enough connected usable space: "+kind)
	check(scene.get_node("Environment").circulation.issues.is_empty(),"Actual scene retains traversable circulation")
	var neighbors: Node3D=scene.get_node("Environment/NeighborIslets")
	var footprint: PackedVector2Array=preload("res://scenes/environment/animal_space.gd").footprint(neighbors.get_node("WillowNeighbor").get_child(0),-.55,.55,false)
	check(Geometry2D.intersect_polygons(footprint,plan.plateau()).is_empty(),"Maximum expansion cannot merge with Willow household")
	check(neighbors.get_node("WillowNeighbor").scale==Vector3.ONE,"Neighbor keeps its real authored size")
	if construction_mode:
		RenderingServer.frame_post_draw.connect(_collect_frame)
		await construction_checks()
		check(construction_completed,"All capacity construction stages reached their final checks")
		RenderingServer.frame_post_draw.disconnect(_collect_frame);_sample={}
	else:
		scene.atmosphere.set_preview_hour(14);await measure("overview-day")
		scene._focus_field(10);await create_timer(1).timeout;await measure("field-day")
		scene.atmosphere.set_preview_hour(21);await measure("field-night")
	check(Store.new(store.directory).load_state().farm==scene.farm_state.snapshot(),"No unintended growth rewards or state loss during rendering")
	write_json("result",{"failures":failures,"fields":12,"crops":384,"species":12,"trellis_crops":data.fields[Farm.Trellis.FIELD_ID].cells.size(),"animals":scene.get_node("Environment/CourtyardAnimals").birds.size(),"plants":scene.courtyard_plan.plants.size(),"size":root.size,"quality":scene.focus_detail._quality,"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"measurements":measurements,"actions":actions,"note":"Actual render and input samples; focus recorded without stealing it. --dev-preview uses the normal second-screen preview frame policy; no low-end certification."})
	print("LIFE_CAPACITY failures=",failures," evidence=",folder)
	scene.farm_audio.shutdown();await create_timer(.15).timeout
	scene.queue_free();await process_frame;await process_frame;quit(0 if failures==0 else 1)

func _collect_frame() -> void:
	if _sample.is_empty(): return
	var tick: int=Time.get_ticks_usec()
	_sample.intervals.append((tick-_sample_tick)/1000.0);_sample_tick=tick
	_sample.gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	_sample.cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu())
	if scene.window_activity.is_foreground(): _sample.foreground+=1

func begin_sample(label: String) -> void:
	_sample_tick=Time.get_ticks_usec()
	_sample={"label":label,"started":_sample_tick,"intervals":[],"gpu":[],"cpu":[],"foreground":0}

func end_sample() -> void:
	var intervals: Array[float]=[];intervals.assign(_sample.intervals)
	var gpu: Array[float]=[];gpu.assign(_sample.gpu)
	var cpu: Array[float]=[];cpu.assign(_sample.cpu)
	var result: Dictionary={"action":_sample.label,"elapsed_ms":(Time.get_ticks_usec()-_sample.started)/1000.0,"frames":intervals.size(),"foreground_frames":_sample.foreground,"frame_interval_ms":stats(intervals),"gpu_ms":stats(gpu),"cpu_render_ms":stats(cpu),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	actions.append(result);_sample={};print("CONSTRUCTION_SAMPLE "+JSON.stringify(result));write_json("actions",actions)

func pointer(point: Vector2, pressed: bool) -> void:
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.window_id=root.get_window_id()
	root.push_input(event,true);await process_frame;await process_frame

func click(control: Control) -> void:
	var point: Vector2=control.get_global_rect().get_center()
	var event:=InputEventMouseMotion.new();event.position=point;event.window_id=root.get_window_id();root.push_input(event,true)
	await process_frame;await pointer(point,true);await pointer(point,false)

func choose(id: String) -> void:
	var builder: Node=scene.island_builder
	await click(builder.choices.categories[preload("res://layout/construction_catalog.gd").item(id).category])
	await click(builder.choices.items[id])

func stroke(a: Vector3,b: Vector3,steps: int=48) -> void:
	var point: Vector2=scene.camera.unproject_position(a)
	await pointer(point,true)
	for i: int in range(1,steps+1):
		var next: Vector2=scene.camera.unproject_position(a.lerp(b,float(i)/steps))
		var event:=InputEventMouseMotion.new();event.position=next;event.relative=next-point;event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.window_id=root.get_window_id()
		root.push_input(event,true);point=next;await process_frame
	await pointer(point,false)

func settle() -> void:
	var started: int=Time.get_ticks_msec()
	while scene.island_builder.busy or scene.get_node("Environment")._terrain_refreshing:
		await process_frame
		if Time.get_ticks_msec()-started>60000: check(false,"Background construction settles within 60 seconds");return

func paint_capacity_plants() -> bool:
	await choose("trapa")
	var builder: Node=scene.island_builder
	check(builder.active and builder.tool=="trapa" and builder.draft.has("plants"),"Real UI opens the plant brush")
	if not builder.active or builder.tool!="trapa" or not builder.draft.has("plants"): await shot("failed-tool-entry");return false
	await click(builder._plant_buttons.brush);builder._values.radius.value=3;builder._values.density.value=3
	begin_sample("dense-plant-brush")
	for point: Vector2 in [Vector2(17,7),Vector2(21,7),Vector2(24,4),Vector2(-4,18),Vector2(0,18),Vector2(4,17)]:
		await stroke(Vector3(point.x,-.25,point.y),Vector3(point.x+1,-.25,point.y),12)
		if builder.draft.plants.size()==Plants.MAX_CLUMPS: break
	end_sample()
	check(builder.draft.plants.size()==Plants.MAX_CLUMPS,"Real dense brush fills 160 stable clumps with 384 crops and 28 animals")
	if OS.get_cmdline_user_args().has("--profile"):
		var timings: Dictionary={}
		var started: int=Time.get_ticks_usec()
		var plan: RefCounted=Plan.from_snapshot(builder.draft);timings.decode_ms=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec();builder.plant_preview.update(plan);timings.preview_ms=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec();builder.issue();timings.issue_ms=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec()
		var dressing: Node3D=preload("res://presentation/shore_dressing.gd").plants(plan)
		timings.dressing_ms=(Time.get_ticks_usec()-started)/1000.0;dressing.free()
		started=Time.get_ticks_usec();scene.get_node("Environment").fit_player_dressing(plan);timings.fitting_ms=(Time.get_ticks_usec()-started)/1000.0
		started=Time.get_ticks_usec()
		for entry: Dictionary in plan.plants: builder.plant_preview.entry_issue(entry,plan,false)
		timings.static_entries_ms=(Time.get_ticks_usec()-started)/1000.0
		write_json("plant-profile",timings);print("PLANT_PROFILE "+JSON.stringify(timings))
	var waiting_since: int=Time.get_ticks_msec()
	while builder.issue().contains("动物") and Time.get_ticks_msec()-waiting_since<20000:
		await create_timer(.25).timeout;builder._refresh()
	print("CAPACITY_PLANTS ",builder.draft.plants.size()," issue=",builder.issue())
	check(builder.issue().is_empty(),"Capacity planting can complete after animals clear the live preview: "+builder.issue())
	if builder.draft.plants.size()!=Plants.MAX_CLUMPS or not builder.issue().is_empty(): await shot("failed-plants");return false
	begin_sample("plant-confirm-and-background")
	await click(builder._confirm);await settle();end_sample()
	check(scene.courtyard_plan.plants.size()==160,"Capacity planting commits in the same scene")
	return scene.courtyard_plan.plants.size()==160

func construction_checks() -> void:
	scene.atmosphere.set_preview_hour(11)
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	check(scene.island_builder.active,"Real UI opens island construction")
	if not scene.island_builder.active: await shot("failed-construction-entry");return
	if not preplanted and not await paint_capacity_plants(): return
	var builder: Node=scene.island_builder
	check(scene.courtyard_plan.plants.size()==160,"Terrain and field samples include 160 established plants")
	var saved_fields: Dictionary=scene.farm_state.snapshot().fields
	var saved_inventory: Dictionary=scene.farm_state.snapshot().inventory
	var identity: int=scene.get_instance_id()
	var original_east: Array=scene.courtyard_plan.construction.east_land.duplicate(true)
	var original_road_heights: Dictionary={}
	for path: PackedVector3Array in scene.courtyard_plan.paths:
		for i: int in range(1,path.size()):
			for part: int in 8:
				var at: Vector3=path[i-1].lerp(path[i],part/8.0)
				var point:=Vector2(at.x,at.z)
				original_road_heights[point]=scene.get_node("Environment/CourtyardAnimals").yard.ground_height(point)
	await choose("land")
	scene.camera._move_to(Vector3(20,.4,-2),Vector3(24,65,25));await create_timer(1).timeout
	begin_sample("east-held-land-stroke")
	await stroke(Vector3(21.5,.11,-3.5),Vector3(24,.11,-3.5));end_sample()
	check(builder.draft.construction.east_land!=original_east and builder.issue().is_empty(),"Full scene accepts real east terrain stroke: "+builder.issue())
	await shot("capacity-east-preview")
	if builder.draft.construction.east_land==original_east or not builder.issue().is_empty(): return
	var expected: Dictionary=builder.candidate.snapshot()
	begin_sample("land-finish")
	await click(builder._panel.find_child("Finish",true,false));end_sample()
	check(not builder.active and scene.courtyard_plan.snapshot()==expected and scene.get_instance_id()==identity,"Finish adopts large-scene terrain without reloading")
	begin_sample("land-background-navigation")
	await settle();end_sample()
	check(scene.get_node("Environment/CourtyardAnimals").ready_for_motion,"All capacity animals resume after terrain edit")
	var refreshed_yard: RefCounted=scene.get_node("Environment/CourtyardAnimals").yard
	check(absf(refreshed_yard.ground_height(Vector2(23,-3.5))-.11)<.001,"Background indexing supports the real height of newly painted east ground")
	var road_heights_match: bool=true
	for point: Vector2 in original_road_heights:
		if not is_equal_approx(original_road_heights[point],refreshed_yard.ground_height(point)): road_heights_match=false
	check(road_heights_match,"Background rebuild preserves exact foot heights along existing stone roads")
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	begin_sample("land-undo-and-background")
	await click(builder._undo);await settle();end_sample()
	check(scene.courtyard_plan.construction.east_land==original_east,"Large-scene terrain undo succeeds")
	for id: String in ["fields","trellis","house","bridge","ducks","trapa"]:
		begin_sample("select-"+id);await choose(id);end_sample()
		if id=="fields":
			scene.camera._move_to(Vector3(18,.4,-2),Vector3(24,65,25));await create_timer(1).timeout
			var before_move: Dictionary=builder.draft.duplicate(true)
			var center: Vector3=scene.courtyard_plan.fields[-1].position
			begin_sample("capacity-field-drag-and-check")
			await stroke(center,center+Vector3(0,0,.5),12)
			var waiting: int=Time.get_ticks_msec()
			while builder.field_preview.pending:
				await process_frame
				if Time.get_ticks_msec()-waiting>60000: check(false,"Capacity field validation finishes");break
			end_sample()
			check(builder.draft!=before_move and builder.issue().is_empty(),"A fully planted field can move in the capacity scene: "+builder.issue())
			await shot("capacity-field-preview")
			begin_sample("capacity-field-cancel");await click(builder._panel.find_child("Cancel",true,false));end_sample()
			check(builder.draft==before_move,"Capacity field cancel restores the layout")
		if id=="fields" and OS.get_cmdline_user_args().has("--profile"):
			var timings: Dictionary={}
			var started: int=Time.get_ticks_usec()
			var copy:=FarmLayout.new();copy.plan.fields.clear();root.add_child(copy);copy.hide();copy.copy_from(scene.farm)
			timings.copy_farm_ms=(Time.get_ticks_usec()-started)/1000.0;copy.free()
			started=Time.get_ticks_usec();builder.field_preview.core.update_tiles(builder.candidate,false);timings.core_grass_ms=(Time.get_ticks_usec()-started)/1000.0
			started=Time.get_ticks_usec();builder.field_preview.expansion.update_expansion(builder.candidate);timings.expansion_grass_ms=(Time.get_ticks_usec()-started)/1000.0
			started=Time.get_ticks_usec();builder.field_preview.show_ground(builder.candidate);timings.ground_ms=(Time.get_ticks_usec()-started)/1000.0
			var environment: Node3D=scene.get_node("Environment")
			started=Time.get_ticks_usec();var fresh: Node3D=environment.make_paths(scene.courtyard_plan)
			timings.fresh_paths_ms=(Time.get_ticks_usec()-started)/1000.0;timings.path_stones=fresh.get_child_count()
			started=Time.get_ticks_usec();var reused: Node3D=environment.make_paths(scene.courtyard_plan,environment.get_node("GardenPaths"))
			timings.reused_paths_ms=(Time.get_ticks_usec()-started)/1000.0
			fresh.free();reused.free()
			write_json("field-profile",timings);print("FIELD_PROFILE "+JSON.stringify(timings))
	await choose("land");await click(builder._panel.find_child("Finish",true,false));await settle()
	check(scene.farm_state.snapshot().fields==saved_fields and scene.farm_state.snapshot().inventory==saved_inventory,"Capacity construction preserves every crop and inventory")
	scene.atmosphere.set_preview_hour(11);await measure("capacity-overview-day")
	scene.atmosphere.set_preview_hour(21);await measure("capacity-overview-night")
	construction_completed=true
