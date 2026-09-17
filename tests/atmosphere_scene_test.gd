extends SceneTree
## Complete main scene, isolated v2 save, real clicks and mixer capture.

const Store = preload("res://farm/farm_store.gd")
const Farm = preload("res://farm/farm_state.gd")
const Decorations = preload("res://farm/decoration_state.gd")
var scene: Node3D
var now: float = 1800000000.0
var output_dir: String = ""
var failures: Array[String] = []
var checks: int = 0
var capture: AudioEffectCapture


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_dir = arg.trim_prefix("--output=")
	_run.call_deferred()


func _run() -> void:
	var folder: String = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification/atmosphere-scene-%d" % Time.get_ticks_usec())
	var store = Store.new(folder)
	_expect(store.load_state().kind == "missing", "Isolated fixture has no player data")
	var farm: Dictionary = Farm.new(now).snapshot()
	farm.harvested = {"greens": 10, "radish": 6}
	var decorations = Decorations.new()
	decorations.unlock(farm.harvested)
	_expect(decorations.place("lantern", "hanging_01", 0).ok, "Fixture has one earned placed lantern")
	_expect(store.save(farm, decorations.snapshot()).ok, "Fixture saves through versioned owner")
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(folder)
	scene.settings_store = load("res://settings/settings_store.gd").new(scene.store.directory.path_join("preferences"))
	scene.clock = func() -> float: return now
	root.add_child(scene)
	root.grab_focus()
	await create_timer(0.6).timeout
	var courtyard: Node3D = scene.get_node("Environment")
	var material: Material = courtyard.get_water_surface().get_active_material(0)
	_expect(material is ShaderMaterial and material.shader.resource_path == "res://atmosphere/quiet_water.gdshader", "Formal water actually uses the animated shader")
	var lights: Array[Node] = scene.find_children("FarmLanternLight", "OmniLight3D", true, false)
	_expect(lights.size() == 1, "Only the one placed lantern emits light")
	var before_visuals: Dictionary = scene.farm_state.snapshot()
	for pair in [[6.5, "dawn"], [12.0, "day"], [18.0, "dusk"], [22.0, "night"]]:
		scene.atmosphere.set_preview_hour(pair[0])
		await create_timer(0.3).timeout
		if pair[1] == "day":
			_expect(is_zero_approx(lights[0].light_energy), "Lantern is off in daylight")
			_expect(courtyard.get_backdrop_material().get_shader_parameter("atmosphere_tint") == Color.WHITE, "Daylight preserves original backdrop colours")
		if pair[1] == "night":
			_expect(lights[0].light_energy > 0.0, "Placed lantern warms the night")
			_expect(courtyard.get_backdrop_material().get_shader_parameter("atmosphere_tint") != Color.WHITE, "Night also darkens unshaded distant panorama")
		await _screenshot("formal_%s_overview.png" % pair[1])
	_expect(scene.farm_state.snapshot() == before_visuals, "Four visual times leave the authoritative farm untouched")
	# Verify the actual main-scene action-to-sound binding, excluding ambient/music.
	scene.farm_audio.set_volumes(0.8, 0.0, 1.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("FarmAmbient"), true)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.6
	AudioServer.add_bus_effect(0, capture)
	await _click(scene.camera.unproject_position(scene.farm.fields[2].global_position + Vector3(0, 0.4, 0)))
	await create_timer(0.85).timeout
	var harvest: Button = scene.get_node("HUD/Layout/FarmControls/Harvest")
	await _click(harvest.get_global_rect().get_center())
	capture.clear_buffer()
	await _click(scene.camera.unproject_position(scene.farm.fields[2].global_position + Vector3(0, 0.4, 0)))
	await create_timer(0.25).timeout
	_expect(scene.farm_state.snapshot().harvested.greens == 11, "Real harvest click succeeds exactly once")
	_expect(_peak() > 0.001, "Main action emits real audible-range PCM")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("FarmAmbient"), false)
	scene.farm_audio.set_volumes(0.8, 0.7, 0.8)
	await _click(scene.camera.unproject_position(scene.farm.fields[5].global_position + Vector3(0, 0.4, 0)))
	await create_timer(0.85).timeout
	await _screenshot("formal_night_focus.png")
	scene.atmosphere.set_preview_hour(12.0)
	await create_timer(0.3).timeout
	await _screenshot("formal_day_focus.png")
	var growth_before: float = scene.farm_state.get_field("field_04").growth_seconds
	var settings: Dictionary = scene.farm_audio.get_volumes()
	root.mode = Window.MODE_MINIMIZED
	now += 120.0
	await create_timer(1.25).timeout
	_expect(not scene.farm_audio.is_foreground() and Engine.max_fps > 0 and Engine.max_fps <= 15, "Actual main window applies background policy")
	_expect(scene.farm_state.get_field("field_04").growth_seconds == growth_before + 120.0, "UTC settlement continues under background frame cap")
	capture.clear_buffer()
	await create_timer(0.2).timeout
	_expect(_peak() < 0.000001, "Actual main background mix is silent")
	root.mode = Window.MODE_WINDOWED
	root.grab_focus()
	await create_timer(0.5).timeout
	_expect(scene.farm_audio.is_foreground() and scene.farm_audio.get_volumes() == settings, "Main restores foreground and retained user mix")
	_expect(_peak() > 0.00001, "Main music and ambience resume")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	scene.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("ATMOSPHERE_SCENE_TEST checks=%d failures=%d fixture=%s" % [checks, failures.size(), folder])
	quit(0 if failures.is_empty() else 1)


func _peak() -> float:
	var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var peak: float = 0.0
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event)
		await physics_frame
		await process_frame


func _screenshot(filename: String) -> void:
	if output_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(output_dir.path_join(filename)) == OK, "Saved " + filename)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
