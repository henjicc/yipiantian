extends SceneTree
## Final shared-system boundary: a spatially admitted 12-field, 384-crop courtyard.
const Plan=preload("res://layout/courtyard_plan.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
const Farm=preload("res://farm/farm_state.gd")
const Store=preload("res://farm/farm_store.gd")
var scene: Node
var folder: String
var failures: int=0
var measurements: Array[Dictionary]=[]
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
	values.sort();return {"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))]}
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
	var plan:=Plan.new();plan.expand_shore(8,8)
	var probe:=preload("res://scenes/environment/courtyard.gd").new();probe.plan=plan;probe.layout_probe=true;probe.process_mode=Node.PROCESS_MODE_DISABLED
	root.add_child(probe)
	var obstacles: Dictionary=probe.layout_obstacles.duplicate(true)
	root.remove_child(probe);probe.free()
	var prototype: Dictionary=Plan.resized_field(plan.fields[0],8,4,Vector2(5,2.05))
	plan.fields.clear()
	# Probe candidate footprints against actual model feet, preserving ordinary paths.
	for row: int in 52:
		for column: int in 53:
			if plan.fields.size()==12: break
			var field: Dictionary=prototype.duplicate(true)
			field.position=Vector3(-12.8+column*.35,plan.ground_height+.07,-5.5+row*.35)
			field.id="field_%02d"%(plan.fields.size()+1);field.seed=91744+plan.fields.size()*7919
			plan.fields.append(field)
			var accepted: bool=Circulation.field_placement_issues(plan,obstacles).is_empty()
			var polygon: PackedVector2Array=plan.field_polygon(plan.fields.size()-1,.35)
			for prior: int in plan.fields.size()-1:
				if not Geometry2D.intersect_polygons(polygon,plan.field_polygon(prior,.35)).is_empty(): accepted=false;break
			if not accepted: plan.fields.pop_back()
		if plan.fields.size()==12: break
	check(plan.fields.size()==12,"Twelve complete fields fit real island and obstacles")
	var routes:=Circulation.new();routes.build(plan,obstacles)
	check(routes.issues.is_empty(),"Capacity layout keeps all entrances and fields connected: "+str(routes.issues))
	write_json("layout",plan.snapshot())
	if failures>0: print("CAPACITY_LAYOUT failures=",failures," count=",plan.fields.size()," evidence=",folder);quit(1);return
	var farm:=Farm.new(1000,plan.snapshot());var data: Dictionary=farm.snapshot();var species: Array[String]=Farm.Crops.crop_ids();var index: int=0
	for field: Dictionary in data.fields.values():
		for cell: Dictionary in field.cells.values():
			cell.ground="ready";cell.crop_id=species[index%species.size()];cell.growth_seconds=Farm.Crops.definition(cell.crop_id).duration_seconds;index+=1
	for home: String in Farm.Neighbors.IDS: data.neighbors[home]={"round":3,"pending":false,"last_gift":Farm.Neighbors.HOMES[home].gifts[0]}
	data.season="after_rain"
	check(index==384 and farm.restore_snapshot(data),"Maximum mixed-crop fixture is valid")
	var store:=Store.new(folder.path_join("farm"));store.load_state();check(store.save(farm.snapshot(),preload("res://farm/decoration_state.gd").new().snapshot()).ok,"Maximum scene persists")
	scene=load("res://scenes/main.tscn").instantiate();scene.store=store;scene.settings_store=load("res://settings/settings_store.gd").new(folder.path_join("settings"));scene.clock=func() -> float: return 1000
	root.add_child(scene);await process_frame
	while not scene.get_node("Environment/CourtyardAnimals").ready_for_motion: await process_frame
	root.mode=Window.MODE_EXCLUSIVE_FULLSCREEN
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	check(scene.farm.fields.size()==12,"All fields presented")
	for field: Node3D in scene.farm.fields: check(field.get_node("Crops").get_child_count()==32,"Each field renders 32 plants")
	check(scene.get_node("Environment/CourtyardAnimals").birds.size()==7,"All animals coexist with capacity planting")
	check(scene.get_node("Environment").circulation.issues.is_empty(),"Actual scene retains traversable circulation")
	var neighbors: Node3D=scene.get_node("Environment/NeighborIslets")
	var footprint: PackedVector2Array=preload("res://scenes/environment/animal_space.gd").footprint(neighbors.get_node("WillowNeighbor").get_child(0),-.55,.55,false)
	check(Geometry2D.intersect_polygons(footprint,plan.plateau()).is_empty(),"Maximum expansion cannot merge with Willow household")
	check(neighbors.get_node("WillowNeighbor").scale==Vector3.ONE,"Neighbor keeps its real authored size")
	scene.atmosphere.set_preview_hour(14);await measure("overview-day")
	scene._focus_field(10);await create_timer(1).timeout;await measure("field-day")
	scene.atmosphere.set_preview_hour(21);await measure("field-night")
	check(Store.new(store.directory).load_state().farm==scene.farm_state.snapshot(),"No unintended growth rewards or state loss during rendering")
	write_json("result",{"failures":failures,"fields":12,"crops":384,"species":12,"animals":7,"size":root.size,"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"measurements":measurements,"note":"Short per-view render samples; foreground counts retained, no focus stealing or low-end/long-term certification."})
	print("LIFE_CAPACITY failures=",failures," evidence=",folder)
	scene.farm_audio.shutdown();await create_timer(.15).timeout
	scene.queue_free();await process_frame;await process_frame;quit(0 if failures==0 else 1)
