extends SceneTree
## Focused native evidence for continuous soil, ground selection and planting response.
var scene: Node3D
var output: String
var failures: Array[String] = []
const NOW: float = 1800000000.0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	if output.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native rendering and --output are required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,1000)
	root.content_scale_size = root.size
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = load("res://farm/farm_store.gd").new(output.path_join("save-%d" % Time.get_ticks_usec()))
	scene.settings_store = load("res://settings/settings_store.gd").new(scene.store.directory.path_join("settings"))
	scene.clock = func() -> float: return NOW
	root.add_child(scene)
	scene.atmosphere.set_preview_hour(13.0)
	scene.focus_detail.set_depth_of_field(false)
	await create_timer(.8).timeout
	scene._focus_field(0)
	await create_timer(.85).timeout
	scene.camera.set_process(false)
	scene.camera.position = Vector3(-1.2,2.65,3.2)
	scene.camera.look_at(Vector3(-3.3,.27,0))
	scene.camera.fov = 40
	scene.farm.select_field(-1)
	await shot("01-empty-unselected")
	scene.farm.select_field(0)
	await shot("02-field-selected")
	scene._select_cell("cell_06")
	var pad: MeshInstance3D = scene.farm._soil_meshes.field_01.cell_06
	_expect(scene.farm_state.sow("field_01","cell_06","greens",NOW).ok,"Sow accepted by farm state")
	scene.refresh_farm()
	# Step the real tween deterministically; background frame throttling and a first
	# shader compilation must not make a wall-clock sample miss this short cue.
	var soil_tween: Tween = scene.farm._planting_tweens["field_01/cell_06"]
	soil_tween.pause()
	soil_tween.custom_step(.12)
	var growing: float = float(pad.get_instance_shader_parameter("planted"))
	_expect(growing > 0.0 and growing < 1.0,"Mound grows over time instead of appearing instantly")
	await shot("03-planting-response", 0)
	soil_tween.play()
	await create_timer(.8).timeout
	_expect(is_equal_approx(float(pad.get_instance_shader_parameter("planted")),1.0),"Planted soil settles")
	_expect(scene.farm.fields[0].find_children("PlantingSoilBurst*","GPUParticles3D",false,false).is_empty(),"One-shot crumbs release their emitter")
	_expect(float(scene.farm._soil_meshes.field_01.cell_07.get_instance_shader_parameter("planted")) == 0.0,"Adjacent empty soil stays flat")
	# Actual state -> presentation for all six crop/stage combinations.
	var ids: Array[String] = ["cell_01","cell_02","cell_03","cell_09","cell_10","cell_11"]
	for i: int in ids.size():
		scene.farm_state.sow("field_01",ids[i],"greens" if i<3 else "radish",NOW)
	var data: Dictionary = scene.farm_state.snapshot()
	for i: int in ids.size():
		var duration: float = 1800.0 if i<3 else 5400.0
		data.fields.field_01.cells[ids[i]].growth_seconds = duration * [0.0,.5,1.0][i%3]
	data.fields.field_01.cells.cell_06.growth_seconds = 1800.0
	_expect(scene.farm_state.restore_snapshot(data),"Six-stage fixture is valid")
	scene.refresh_farm()
	scene.farm_state.water("field_01","cell_09",NOW)
	scene.refresh_farm()
	await create_timer(.7).timeout
	await shot("04-roots-front")
	for id: String in ids:
		var point: Vector3 = scene.farm.fields[0].to_global(scene.farm.cell_center(id))
		var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1)
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
		_expect(hit.get("collider") == scene.farm.fields[0] and scene.farm.cell_at(0,hit.position) == id,"Soil detail retains exact input identity "+id)
	scene.camera.position = Vector3(-5.1,2.2,-2.4)
	scene.camera.look_at(Vector3(-3.3,.3,0))
	await shot("05-roots-reverse")
	scene.camera.position = Vector3(-3.0,.95,1.35)
	scene.camera.look_at(Vector3(-3.6,.35,-.22))
	scene.camera.fov = 32
	await shot("05b-root-close")
	scene.camera.position = Vector3(-1.2,2.65,3.2)
	scene.camera.look_at(Vector3(-3.3,.27,0))
	scene.camera.fov = 40
	scene.atmosphere.set_preview_hour(22.0)
	await shot("06-night-selection")
	scene.atmosphere.set_preview_hour(13.0)
	var prior_radius: Vector2 = pad.get_instance_shader_parameter("root_radius")
	_expect(scene.farm_state.harvest("field_01","cell_06",NOW).ok,"Mature plant harvest accepted")
	scene.refresh_farm()
	_expect(pad.get_instance_shader_parameter("root_radius") == prior_radius,"Harvest retracts the existing contact footprint without an instant size jump")
	await create_timer(.6).timeout
	_expect(is_zero_approx(float(pad.get_instance_shader_parameter("planted"))),"Harvest restores the soil without leaving a mound")
	await shot("07-harvested")
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"render_size":root.size,"mound_intermediate":growing},"\t"))
	scene.farm_audio.shutdown()
	scene.free()
	await process_frame
	print("SOIL_PRESENTATION failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func shot(label: String, delay: float = .3) -> void:
	if delay > 0: await create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"Capture "+label)

func _expect(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error(label)
