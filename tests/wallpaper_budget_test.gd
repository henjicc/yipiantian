extends Node
## Release-compatible, isolated wall-clock probe. Native occlusion uses an owned,
## non-focusing cover on the same test screen; no player profile or system lock.
const Store = preload("res://farm/farm_store.gd")
const Settings = preload("res://settings/settings_store.gd")
const Farm = preload("res://farm/farm_state.gd")
const Decorations = preload("res://farm/decoration_state.gd")
@onready var root: Window = get_tree().root
var scene: Node3D
var output: String
var phase: String = "startup"
var samples: Array[Dictionary] = []
var phase_started: int
var physics_count: int = 0
var physics_delta: float = 0.0
var seconds: float = 180.0
var repeats: int = 3
var soak_hours: float = 0.0
var native: bool = false
var capacity: bool = false
var resolution: String = "1080"
var quality: String = "standard"
var cover: Window
var failures: Array[String] = []
var visible_only: bool = false
var visual_only: bool = false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		elif arg.begins_with("--seconds="): seconds=clampf(float(arg.trim_prefix("--seconds=")),3,180)
		elif arg.begins_with("--repeats="): repeats=clampi(int(arg.trim_prefix("--repeats=")),1,3)
		elif arg.begins_with("--soak-hours="): soak_hours=clampf(float(arg.trim_prefix("--soak-hours=")),0,8)
		elif arg.begins_with("--resolution="): resolution=arg.trim_prefix("--resolution=")
		elif arg.begins_with("--quality="): quality=arg.trim_prefix("--quality=")
		elif arg=="--native": native=true
		elif arg=="--capacity": capacity=true
		elif arg=="--visible-only": visible_only=true
		elif arg=="--visual-only": visual_only=true
	_run.call_deferred()

func _physics_process(delta: float) -> void:
	physics_count+=1;physics_delta+=delta

func _write(name: String, value: Variant) -> void:
	var file:=FileAccess.open(output.path_join(name),FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t"));file.close()

func _status() -> void:
	var host: int=0
	if scene!=null and scene.desktop_wallpaper!=null: host=int(scene.desktop_wallpaper._host.get("pid",0))
	_write("status.json",{"phase":phase,"pid":OS.get_process_id(),"host":host,"ticks":Time.get_ticks_msec(),"cap":Engine.max_fps})

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label);push_error(label)

func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or FileAccess.file_exists(output.path_join("results.json")) or resolution not in ["1080","1440","2160","native"] or quality not in ["low","standard","high"]:
		push_error("Use a fresh absolute evidence directory and a supported resolution.");get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	seed(924)
	var production_keep_on: bool=DisplayServer.screen_is_kept_on()
	# Keep only the isolated measurement process awake. The normal game respects
	# OS energy saving; a timed rendering sample must not silently become screen-off.
	DisplayServer.screen_set_keep_on(true)
	root.current_screen=0;root.size=Vector2i(3840,2160)
	root.position=DisplayServer.screen_get_position(0)
	_status()
	_write("measurement-policy.json",{"production_keep_screen_on":production_keep_on,"probe_keep_screen_on":true,"system_power_plan_changed":false})
	var store:=Store.new(output.path_join("farm"))
	check(store.load_state().kind=="missing","Fixture directory must be fresh")
	var plan:=Farm.Plan.new()
	if capacity:
		plan.expand_shore(8,8)
		var construction: Dictionary = plan.construction.duplicate(true)
		construction.east_land=[[15,-5,4,4],[18,-5,4,4],[15,-2,4,3],[18,-2,4,3]]
		check(plan.apply_construction(construction),"Capacity terrain is admitted before placing fields")
		var prototype: Dictionary=Farm.Plan.resized_field(plan.fields[0],8,4,Vector2(5,2.05))
		plan.fields.clear()
		for point: Vector2 in [Vector2(-8.6,-5.5),Vector2(-10.7,-2.7),Vector2(-11.75,.1),Vector2(-2.3,.1),Vector2(-12.1,2.9),Vector2(-11.75,5.7),Vector2(-5.8,6.4),Vector2(.15,7.8),Vector2(-9.3,9.2),Vector2(-3.35,10.6),Vector2(2.6,10.6),Vector2(18.5,-2.5)]:
			var field: Dictionary=prototype.duplicate(true)
			field.position=Vector3(point.x,plan.ground_height_at(point)+.07,point.y)
			field.id="field_%02d"%(plan.fields.size()+1);field.seed=91744+plan.fields.size()*7919
			plan.fields.append(field)
		for kind: String in Farm.Companions.Flocks.KINDS: plan.construction.flocks[kind].count=Farm.Companions.Flocks.SPECIES[kind].limit
		plan.construction.flocks.duck.area=[-20.0,7.0,4.0,10.0]
		plan.construction.flocks.goose.area=[-6.0,-13.0,12.0,3.0]
	check(Farm.Plan.from_snapshot(plan.snapshot()) != null,"Measurement layout passes normal admission")
	if not failures.is_empty(): get_tree().quit(1);return
	var farm:=Farm.new(Time.get_unix_time_from_system(),plan.snapshot())
	var data: Dictionary=farm.snapshot()
	var species: Array[String]=Farm.Crops.seeds(false)
	var index: int=0
	for id: String in farm.field_ids():
		for cell: Dictionary in data.fields[id].cells.values():
			cell.ground="ready";cell.crop_id=species[index%species.size()]
			cell.growth_seconds=Farm.Crops.definition(cell.crop_id).duration_seconds;index+=1
	check(farm.restore_snapshot(data) and store.save_state(farm,Decorations.new()).ok,"Mixed mature fixture admitted and saved")
	var settings:=Settings.new(output.path_join("preferences"))
	var values: Dictionary=settings.load_settings().settings
	values.resolution=resolution;values.quality=quality;values.master=0.0
	check(settings.save(values).ok,"Isolated display preferences saved")
	if not failures.is_empty(): get_tree().quit(1);return
	var started: int=Time.get_ticks_msec()
	scene=load("res://scenes/main.tscn").instantiate()
	scene.store=store;scene.settings_store=settings
	root.add_child(scene)
	if visual_only:
		scene.get_node("Environment/CourtyardAnimals")._rng.seed=924
	scene.atmosphere.set_preview_hour(12)
	if native:
		check(scene.desktop_wallpaper.available(),"Native host exists beside executable")
		scene._enter_wallpaper()
		for tick: int in 100:
			await get_tree().create_timer(.1).timeout
			if scene.desktop_wallpaper.active and not scene.desktop_wallpaper.busy: break
		check(scene.desktop_wallpaper.active,"Real native host attached")
	else: scene._wallpaper_changed(true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await RenderingServer.frame_post_draw
	_write("startup-pipelines.json",_pipeline_counts())
	_write("ready.json",{"startup_ms":Time.get_ticks_msec()-started,"engine":Engine.get_version_info(),"exported":not OS.has_feature("editor"),"native_host":native,"adapter":RenderingServer.get_video_adapter_name(),"resolution":resolution,"output_size":root.size,"crop_count":index,"animals":scene.get_node("Environment/CourtyardAnimals").birds.size()})
	if visual_only:
		await _visual_comparison()
		return
	for repeat: int in repeats: await _case("visible_%d"%repeat,seconds)
	root.get_texture().get_image().save_png(output.path_join("day.png"))
	if visible_only:
		_write("results.json",{"cases":samples,"failures":failures})
		phase="complete";_status();scene._request_exit();return
	if soak_hours>0:
		var end: int=Time.get_ticks_msec()+int(soak_hours*3600000)
		while Time.get_ticks_msec()<end: await _case("soak_%d"%samples.size(),minf(180,(end-Time.get_ticks_msec())/1000.0))
	await _actions()
	await _cover(true)
	await get_tree().create_timer(1).timeout
	var short_resume: int = Time.get_ticks_usec()
	await _cover(false)
	await RenderingServer.frame_post_draw
	_write("resume_short.json",{"first_frame_ms":(Time.get_ticks_usec()-short_resume)/1000.0})
	for cycle: int in 2:
		await _cover(true)
		var farm_text: String=FileAccess.get_file_as_string(store.directory.path_join(Store.MAIN))
		await _case("covered_%d"%cycle,seconds,false)
		check(samples[-1].drawn_frames==0,"Covered scene submits zero frames in steady state")
		check(FileAccess.get_file_as_string(store.directory.path_join(Store.MAIN))==farm_text,"Unchanged covered farm is not periodically saved")
		if seconds<180:
			scene.window_activity._hidden_since-=scene.window_activity.DEEP_IDLE_MSEC # accelerated unit path, never a five-minute claim
		else:
			while not scene.window_activity._deep_idle: await get_tree().create_timer(.1).timeout
		await _case("deep_idle_%d"%cycle,minf(seconds,30),false)
		check(samples[-1].drawn_frames==0,"Deep idle stays at zero frames after resource disposal settles")
		var resume: int=Time.get_ticks_usec()
		await _cover(false)
		await RenderingServer.frame_post_draw
		_write("resume_%d.json"%cycle,{"first_frame_ms":(Time.get_ticks_usec()-resume)/1000.0,"accelerated_idle":seconds<180})
		await _case("restored_%d"%cycle,minf(seconds,15))
	scene.atmosphere.set_preview_hour(21)
	await _case("night",minf(seconds,15))
	root.get_texture().get_image().save_png(output.path_join("night.png"))
	_write("results.json",{"cases":samples,"failures":failures})
	phase="complete";_status()
	scene._request_exit()
	if not failures.is_empty(): get_tree().quit(1)

func _cover(enabled: bool) -> void:
	if native:
		if enabled:
			cover=Window.new();cover.visible=false;cover.process_mode=Node.PROCESS_MODE_ALWAYS
			cover.force_native=true;cover.borderless=true;cover.unfocusable=true
			cover.position=root.position;cover.size=root.size;cover.always_on_top=true
			root.add_child(cover);cover.show()
		else: cover.hide();cover.queue_free()
		for tick: int in 50:
			await get_tree().create_timer(.05).timeout
			if scene.window_activity.is_suspended()==enabled: break
	else: scene.window_activity.set_wallpaper_visible(not enabled)
	check(scene.window_activity.is_suspended()==enabled,"Visibility transition reached expected state")

func _actions() -> void:
	if native:
		scene.desktop_wallpaper.set_interacting(true)
		while scene.desktop_wallpaper.busy: await get_tree().process_frame
	else: scene.window_activity.set_wallpaper_interacting(true)
	scene._focus_field(2)
	await get_tree().create_timer(1).timeout
	var timings: Array[Dictionary]=[]
	for action: String in ["harvest","sow","water"]:
		for cell: String in scene.farm.cell_ids(2):
			scene.selected_field=2;scene.selected_cell=cell;scene.selected_tool=action;scene.selected_crop="greens"
			var started: int=Time.get_ticks_usec()
			scene._apply_tool()
			timings.append({"action":action,"ms":(Time.get_ticks_usec()-started)/1000.0})
			check(not scene._save_failed,"Action is durably saved")
			var after: Dictionary = scene.farm_state.get_cell(scene.farm.field_id(2),cell)
			check(after.crop_id.is_empty() if action=="harvest" else (after.crop_id=="greens" and (action!="water" or after.watered)),"Action changed exactly the requested cell: "+action+"/"+cell)
			await get_tree().process_frame
	_write("actions.json",timings)
	scene._cancel_tool();scene._return_overview()
	if native:
		scene.desktop_wallpaper.set_interacting(false)
		while scene.desktop_wallpaper.busy: await get_tree().process_frame
	else: scene.window_activity.set_wallpaper_interacting(false)
	await get_tree().create_timer(1).timeout

func _case(label: String, seconds: float, drawing: bool=true) -> void:
	phase="warmup_"+label
	_status()
	# Godot 4.7.2 performs a non-presenting draw to drain deferred GPU frees even
	# with its render loop disabled. Exclude disposal from the steady-state sample.
	var warm_seconds: float = 30.0 if seconds>=180 and drawing else 6.0 if label.begins_with("deep_idle") else 3.0
	var warm_end: int = Time.get_ticks_msec() + int(warm_seconds * 1000)
	var warm_frames: int = Engine.get_frames_drawn()
	while Time.get_ticks_msec() < warm_end:
		await get_tree().process_frame
		# Warm the same render-server queries used by the sample. Deferred server
		# commands must not first execute after the steady-state counter starts.
		RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	phase=label
	_status()
	var start := Time.get_ticks_usec()
	var previous := start
	var p_start := physics_count
	var pd_start := physics_delta
	var frames_start := Engine.get_frames_drawn()
	var arrays := {"interval_ms":[],"gpu_ms":[],"render_cpu_ms":[],"process_ms":[],"physics_ms":[],"draw_calls":[],"primitives":[],"shadow_primitives":[]}
	var last_status := start
	var last_drawn: int = frames_start
	var covered_seconds: float = 0.0
	var hidden_draws: Array[Dictionary] = []
	var previous_pump: int = start
	var focused: int = 0
	while float(Time.get_ticks_usec()-start)/1e6 < seconds:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		if now-last_status>2_000_000:
			_status()
			last_status=now
		if scene.window_activity.is_suspended(): covered_seconds+=(now-previous_pump)/1e6
		previous_pump=now
		if drawing and Engine.get_frames_drawn()==last_drawn: continue
		if not drawing and Engine.get_frames_drawn()!=last_drawn:
			hidden_draws.append({"seconds":(now-start)/1e6,"loop":RenderingServer.is_render_loop_enabled(),"suspended":scene.window_activity.is_suspended(),"deep_idle":scene.window_activity._deep_idle,"target":root.get_texture().get_size()})
		last_drawn=Engine.get_frames_drawn()
		arrays.interval_ms.append(float(now-previous)/1000.0)
		previous=now
		arrays.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()) if drawing else 0.0)
		arrays.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu() if drawing else 0.0)
		arrays.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		arrays.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		arrays.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		arrays.primitives.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		arrays.shadow_primitives.append(RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
		if root.has_focus(): focused+=1
	var row := {"case":label,"seconds":float(Time.get_ticks_usec()-start)/1e6,"frames":arrays.interval_ms.size(),"drawn_frames":Engine.get_frames_drawn()-frames_start,"cap":Engine.max_fps,"focus_frames":focused,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"static_memory":Performance.get_monitor(Performance.MEMORY_STATIC),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"texture_memory":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"buffer_memory":Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),"physics_steps":physics_count-p_start,"physics_delta":physics_delta-pd_start,"save_failed":scene._save_failed,"quality":scene.focus_detail.get_settings(),"scale":root.scaling_3d_scale}
	for key: String in arrays: row[key]=_stats(arrays[key])
	row.covered_seconds=covered_seconds
	row.warmup_drawn_frames=frames_start-warm_frames
	row.hidden_draws=hidden_draws
	row.pipeline_compilations=_pipeline_counts()
	samples.append(row)
	_write("partial-results.json",samples)
	print("AUDIT_CASE ",label," gpu=",row.gpu_ms.median," nodes=",row.nodes," static_mb=",row.static_memory/1048576.0)

func _stats(data: Array) -> Dictionary:
	if data.is_empty(): return {"median":null,"p95":null,"p99":null,"max":null}
	data.sort()
	return {"median":data[data.size()/2],"p95":data[mini(data.size()-1,int(data.size()*.95))],"p99":data[mini(data.size()-1,int(data.size()*.99))],"max":data[-1]}


func _pipeline_counts() -> Dictionary:
	return {"canvas":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),"mesh":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),"surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),"draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),"specialization":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)}


func _visual_comparison() -> void:
	# This path is for isolated copies whose shader TIME is fixed by the visual
	# comparison setup. Never use these frozen scenes as performance evidence.
	scene.get_node("Environment/CourtyardAnimals").set_process(false)
	scene.camera.configure_sway(false,30)
	for hour: float in [12,21]:
		scene.atmosphere.set_preview_hour(hour)
		await _visual_shot("overview_%d"%hour)
	scene.atmosphere.set_preview_hour(12)
	scene._focus_field(2)
	await _visual_shot("crop_near")
	scene._return_overview()
	await get_tree().create_timer(1).timeout
	for id: String in ["willow","bamboo","ferry"]:
		var view: Dictionary=scene.get_node("Environment/NeighborIslets").story_view(id)
		scene.camera.view_neighbor(view.point,view.view)
		scene.focus_detail.protect_neighbor(view.island)
		await _visual_shot("neighbor_"+id)
		scene.camera.leave_neighbor()
		scene.focus_detail.protect_neighbor(null)
		await get_tree().create_timer(1).timeout
	for yaw: float in [-12,27.5,68]:
		scene.camera.restore_overview_angles(Vector2(yaw,10))
		await _visual_shot("orbit_%s"%yaw)
	_write("visual.json",{"failures":failures,"note":"Fixed shader time; same mature crop layout, camera/hour and stationary seeded animals. Screenshots do not establish motion stability or performance."})
	scene._request_exit()


func _visual_shot(label: String) -> void:
	await get_tree().create_timer(1.5).timeout
	var frame: Node3D=scene.camera.get_node("CameraForeground")
	frame.set_process(false)
	frame._motion_time=17.0
	frame._process(0.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
	frame.set_process(true)
