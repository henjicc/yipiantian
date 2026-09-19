extends SceneTree
## Real menu, scene replacement and changing geometry under optional SDFGI.

const Crops = preload("res://farm/crop_catalog.gd")
const Settings = preload("res://settings/settings_store.gd")
var scene: Node3D
var folder: String
var output: String = ""
var checks: int = 0
var failures: Array[String] = []
var now: float = 1800000000.0
var samples: Array[Dictionary] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()


func _run() -> void:
	folder = ProjectSettings.globalize_path("res://../.local/verification/high-quality-%d" % Time.get_ticks_usec())
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1920,1080)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = load("res://farm/farm_store.gd").new(folder.path_join("farm"))
	scene.settings_store = Settings.new(folder.path_join("preferences"))
	scene.clock = func() -> float: return now
	root.add_child(scene)
	await create_timer(1.0).timeout
	var data: Dictionary = scene.farm_state.snapshot()
	var index: int = 0
	for field: Dictionary in data.fields.values():
		for cell: Dictionary in field.cells.values():
			cell.crop_id = Crops.crop_ids()[index % 12]
			cell.growth_seconds = Crops.definition(cell.crop_id).duration_seconds * [.1,.5,1.0][(index / 12) as int % 3]
			cell.ground = "ready"
			cell.watered = false
			index += 1
	data.fields.field_01.cells.cell_01.crop_id = ""
	data.fields.field_01.cells.cell_01.growth_seconds = 0.0
	_expect(scene.farm_state.restore_snapshot(data), "Mixed-stage fixture is valid")
	scene.refresh_farm()
	var before: Dictionary = scene.farm_state.snapshot()
	var water: ShaderMaterial = scene.get_node("Environment").get_water_surface().material_override
	var shore: Texture2D = water.get_shader_parameter("shore_distance")
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for hour: float in [14.0,22.0]:
		scene.atmosphere.set_preview_hour(hour)
		for quality: String in ["standard","high"]:
			await _choose_quality(quality)
			await _settle_light()
			_expect(scene.focus_detail.get_settings().quality == quality, "Real menu selects " + quality)
			_expect(scene.camera.get_world_3d().environment.sdfgi_enabled == (quality == "high"), "Menu changes actual GI")
			_expect(water.get_shader_parameter("shore_distance") == shore and water.get_shader_parameter("shore_contacts_enabled"), "Water shore data survives shader switch")
			_expect(water.get_shader_parameter("boat_mask_enabled"), "Moving boat keeps its water exclusion")
			_expect(scene.camera.attributes.dof_blur_far_enabled, "High and standard retain DOF preference")
			await _measure("%02d-%s" % [int(hour),quality])
			await _capture("%02d-%s-overview" % [int(hour),quality])
	_expect(scene.farm_state.snapshot() == before, "Quality and daylight changes leave farming unchanged")
	_check_geometry()
	_expect(scene.farm_state.sow("field_01","cell_01","celery",now).ok, "New crop can be planted under high quality")
	scene.refresh_farm()
	_check_geometry()
	now += Crops.definition("celery").duration_seconds * .55
	scene.settle_farm()
	_expect(scene.farm_state.get_cell("field_01","cell_01").stage == "young", "Real growth replaces the planted stage")
	_check_geometry()
	var replacement = load("res://farm/decoration_state.gd").new()
	replacement.unlock({"greens":10,"radish":6,"spinach":1})
	_expect(replacement.place("flowerpot","ground_02",0).ok, "Moving prop fixture has a valid placement")
	scene.decoration_layout.accept_state(replacement)
	_check_geometry()
	scene.atmosphere.ripple_at(Vector3(2,0,1))
	await _choose_quality("low")
	_expect(not scene.camera.get_world_3d().environment.sdfgi_enabled and root.msaa_3d == Viewport.MSAA_2X, "Low removes GI and restores 2x MSAA")
	_expect(not scene.camera.attributes.dof_blur_far_enabled, "Low temporarily disables DOF")
	_expect(water.shader == preload("res://atmosphere/quiet_water.gdshader"), "Low restores original water shader")
	_expect(water.get_shader_parameter("ripple_center") == Vector2(2,1), "Ripple origin survives quality return")
	await _choose_quality("high")
	await _settle_light()
	_expect(water.shader == preload("res://atmosphere/quiet_water_high.gdshader"), "High restores isolated water lighting")
	var boat_before: Transform3D = water.get_shader_parameter("world_to_boat")
	await create_timer(.25).timeout
	_expect(water.get_shader_parameter("world_to_boat") != boat_before, "Boat masking still follows movement in high quality")
	var night_fill: Vector3 = water.get_shader_parameter("sky_fill")
	scene.atmosphere.set_preview_hour(14.0)
	_expect(water.get_shader_parameter("sky_fill") != night_fill, "Water fill follows day/night changes")
	scene._focus_field(2)
	await create_timer(1.0).timeout
	for hour: float in [14.0,22.0]:
		scene.atmosphere.set_preview_hour(hour)
		await _settle_light()
		await _capture("%02d-high-focus" % int(hour))
	for season: String in ["after_rain","drying","daily"]:
		scene.atmosphere.set_season(season)
		scene.atmosphere.set_preview_hour(14.0)
		await _settle_light()
		await _capture(season + "-high")
	# The same saved-scene replacement path is used by courtyard layout changes.
	_expect(scene._save_farm(), "Current farm saved before rebuilding scene")
	var expected_farm: Dictionary = scene.farm_state.snapshot()
	var old_environment: Environment = scene.camera.get_world_3d().environment
	var old_scene: Node3D = scene
	var scene_name: String = scene.name
	scene._reload_saved_scene()
	for frame: int in 180:
		await process_frame
		var candidate: Node = root.get_node_or_null(scene_name)
		if candidate != null and candidate != old_scene:
			scene = candidate
			break
	_expect(scene != old_scene, "Layout reload creates a new scene")
	_expect(scene.camera.get_world_3d().environment != old_environment, "Layout reload discards stale GI volume")
	_expect(scene.focus_detail.get_settings().quality == "high" and scene.camera.get_world_3d().environment.sdfgi_enabled, "Saved high quality survives scene replacement")
	_expect(scene.farm_state.snapshot() == expected_farm, "Scene replacement preserves actual farm state")
	_check_geometry()
	await _choose_quality("standard")
	_expect(not scene.camera.get_world_3d().environment.sdfgi_enabled and root.msaa_3d == Viewport.MSAA_4X, "Standard restores original rendering after reload")
	_expect(Settings.new(folder.path_join("preferences")).load_settings().settings.quality == "standard", "Menu close persists final quality choice")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"device":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"cells":index,"plants_during_samples":index-1,"note":"60-frame samples; foreground counts retained, no sustained FPS claim."},"\t"))
		file.close()
	scene.farm_audio.shutdown()
	scene.queue_free()
	scene = null
	await process_frame
	await process_frame
	for failure: String in failures: push_error(failure)
	print("HIGH_QUALITY_SCENE_TEST checks=%d failures=%d output=%s" % [checks,failures.size(),output])
	quit(0 if failures.is_empty() else 1)


func _choose_quality(value: String) -> void:
	await _click(scene.get_node("HUD/Layout/ViewControls/Settings").get_global_rect().get_center())
	_expect(scene.game_menu.visible, "Settings button opens real menu")
	if not scene.game_menu.visible:
		push_error("MENU_FAILED " + str(root.gui_get_focus_owner()))
		quit(1)
		return
	var control: OptionButton = scene.game_menu._quality
	await _click(control.get_global_rect().get_center())
	var popup: PopupMenu = control.get_popup()
	_expect(popup.visible, "Quality popup opens from pointer input")
	var target: int = scene.game_menu.QUALITY_VALUES.find(value)
	for step: int in control.item_count:
		if popup.get_focused_item() == target: break
		await _key(popup, KEY_DOWN)
	await _key(popup, KEY_ENTER)
	_expect(scene.settings_values.quality == value, "Popup keyboard activation applies " + value)
	if scene.settings_values.quality != value:
		print("POPUP_DIAGNOSTIC id=%s focused=%s selected=%s expected=%s" % [popup.get_window_id(),popup.get_focused_item(),control.selected,value])
		quit(1)
		return
	await _click(scene.game_menu._close.get_global_rect().get_center())
	await create_timer(.2).timeout


func _check_geometry() -> void:
	var baked: int = 0
	var invalid: Array[String] = []
	for mesh: GeometryInstance3D in scene.find_children("*","GeometryInstance3D",true,false):
		if mesh.gi_mode == GeometryInstance3D.GI_MODE_DISABLED: continue
		baked += 1
		var part: Node = mesh
		while part != null and part.get_parent() != scene.get_node("Environment"): part = part.get_parent()
		if part == null or not (part.name in ["MainBank","EastBank","MainHouse","PorchDeck","Kitchen","EntranceTrellis"] or part.scene_file_path.ends_with("/stone_bridge.glb")):
			invalid.append(str(mesh.get_path()))
	_expect(baked > 0 and invalid.is_empty(), "Only fixed architecture contributes to GI: " + str(invalid))


func _settle_light() -> void:
	for frame: int in 100: await process_frame


func _measure(label: String) -> void:
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var foreground: int = 0
	for frame: int in 60:
		await RenderingServer.frame_post_draw
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu())
		foreground += int(scene.window_activity.is_foreground())
	gpu.sort(); cpu.sort()
	samples.append({"label":label,"gpu_median_ms":gpu[30],"gpu_p95_ms":gpu[57],"cpu_median_ms":cpu[30],"foreground_frames":foreground,"frames":60,"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})


func _capture(label: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK, "Captured " + label)


func _key(viewport: Viewport, code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.window_id = (viewport as Window).get_window_id()
		event.keycode = code
		event.pressed = down
		# PopupMenu handles keys in Window's input path, before Viewport.push_input.
		Input.parse_input_event(event)
		await process_frame


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await process_frame
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await physics_frame
		await process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
