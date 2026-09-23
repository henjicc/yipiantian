extends SceneTree

const Sample = preload("res://scenes/atmosphere_sample/atmosphere_sample.gd")
const Atmosphere = preload("res://atmosphere/day_night.gd")
const Farm = preload("res://farm/farm_state.gd")
var failures: Array[String] = []
var checks: int = 0
var output_dir: String = ""
var sample: Node3D
var capture: AudioEffectCapture
var movie: bool = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_dir = arg.trim_prefix("--output=")
		if arg == "--movie-test":
			movie = true
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	sample = Sample.new()
	root.add_child(sample)
	if movie:
		# Only this isolated test bypasses focus to exercise offline MovieMaker mix.
		sample.activity.queue_free()
		sample.audio.set_foreground(true)
		sample.atmosphere.set_preview_hour(10.0)
		await create_timer(0.6).timeout
		sample.audio.play_action("sow", {"ok": true})
		await create_timer(1.0).timeout
		sample.audio.play_action("water", {"ok": true})
		await create_timer(1.3).timeout
		sample.audio.play_action("harvest", {"ok": true})
		await create_timer(1.1).timeout
		sample.free()
		await process_frame
		await process_frame
		quit()
		return
	root.grab_focus()
	await create_timer(0.4).timeout
	_expect(sample.activity.is_foreground(), "Native inspection window has focus")
	_expect(sample.audio.is_foreground(), "Window lifecycle restores audio foreground")
	_expect(sample.water.get_active_material(0) is ShaderMaterial, "Water uses the atmosphere shader despite base override")
	var bus_count: int = AudioServer.bus_count
	sample.audio.free()
	sample.audio = preload("res://audio/farm_audio.gd").new()
	sample.add_child(sample.audio)
	sample.activity.foreground_changed.connect(sample.audio.set_foreground)
	sample.atmosphere.night_weight_changed.connect(sample.audio.set_night_weight)
	sample.audio.set_night_weight(sample.atmosphere.get_night_weight())
	_expect(AudioServer.bus_count == bus_count, "Recreating controller does not duplicate buses")
	_expect(sample.audio.set_volumes(0.8, 0.7, 0.8), "Valid independent volumes accepted")
	_expect(not sample.audio.set_volumes(NAN, 1.0, 1.0), "Nonfinite volume rejected")
	var remembered: Dictionary = sample.audio.get_volumes()
	var copy: Dictionary = sample.audio.get_volumes()
	copy.master = 0.0
	_expect(sample.audio.get_volumes() == remembered, "Settings snapshot does not mutate controller")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.5
	AudioServer.add_bus_effect(0, capture)
	await create_timer(0.5).timeout
	_expect(_peak() > 0.00001, "Actual Master audio contains music and ambience")
	var music_player := sample.audio.get_node("Music") as AudioStreamPlayer
	music_player.seek(music_player.stream.get_length() - 0.15)
	await create_timer(0.4).timeout
	_expect(music_player.playing and music_player.get_playback_position() < 0.5, "Imported music actually loops through its end")
	sample.audio.set_volumes(0.0, 0.7, 0.8)
	await create_timer(0.12).timeout
	capture.clear_buffer()
	await create_timer(0.15).timeout
	_expect(_peak() < 0.000001, "Master volume zero produces actual silence")
	_expect(not sample.audio.play_action("sow", {"ok": true}), "Muted actions do not accumulate")
	sample.audio.set_volumes(0.8, 0.0, 0.0)
	await create_timer(0.12).timeout
	capture.clear_buffer()
	await create_timer(0.15).timeout
	_expect(_peak() < 0.000001, "Music and effects zero also mute both ambient streams")
	sample.audio.set_volumes(0.8, 0.7, 0.8)
	_expect(not sample.audio.play_action("harvest", {"ok": false}), "Failed action is silent")
	_expect(not sample.audio.play_action("unknown", {"ok": true}), "Unknown action is silent")
	_expect(sample.audio.play_ui(), "Interface feedback plays")
	_expect(not sample.audio.play_ui(), "Repeated interface feedback is suppressed")
	_expect(sample.audio.play_action("water", {"ok": true}), "Successful action plays")
	var accepted: int = 0
	for index in 30:
		if sample.audio.play_action("water", {"ok": true}):
			accepted += 1
	_expect(accepted == 0, "Rapid repeated clicks do not layer thirty voices")
	await create_timer(0.35).timeout
	_expect(_peak() < 1.0, "Live mixer stays below clipping")
	var old_cap: int = Engine.max_fps
	root.mode = Window.MODE_MINIMIZED
	await create_timer(0.5).timeout
	_expect(not sample.audio.is_foreground(), "Native minimize mutes audio")
	_expect(not RenderingServer.is_render_loop_enabled(), "Native minimize stops rendering")
	_expect(paused, "Invisible scene pauses until UTC settlement on restore")
	_expect(sample.audio.get_volumes() == remembered, "Minimize does not rewrite user volumes")
	capture.clear_buffer()
	await create_timer(0.2).timeout
	_expect(_peak() < 0.000001, "Background mix is actually silent")
	root.mode = Window.MODE_WINDOWED
	root.grab_focus()
	await create_timer(0.5).timeout
	_expect(sample.audio.is_foreground(), "Native window restore resumes audio")
	_expect(Engine.max_fps == old_cap, "Foreground restores prior frame cap")
	_expect(sample.audio.get_volumes() == remembered, "Foreground restores user mix")
	_expect(_peak() > 0.00001, "Actual audio resumes after restore")
	# The visual sampler remains cyclic and continuous at midnight and each key.
	_expect(Atmosphere.sample_hour(0) == Atmosphere.sample_hour(24), "Midnight visual wraps without a jump")
	for hour in [5.0, 6.5, 9.0, 12.0, 16.5, 18.5, 20.0]:
		var before: Dictionary = Atmosphere.sample_hour(hour - 0.001)
		var after: Dictionary = Atmosphere.sample_hour(hour + 0.001)
		_expect(absf(before.sun_energy - after.sun_energy) < 0.001, "Continuous light transition at %.1f" % hour)
		_expect(absf(before.backdrop_tint.r - after.backdrop_tint.r) < 0.001 and absf(before.sky_horizon.b - after.sky_horizon.b) < 0.001, "Layered landscape and mist remain continuous at %.1f" % hour)
	var evening: Dictionary = Atmosphere.sample_hour(18.0)
	var night: Dictionary = Atmosphere.sample_hour(22.0)
	_expect(evening.backdrop_tint.r < 0.7 and evening.backdrop_tint.b > evening.backdrop_tint.r, "Evening background darkens and cools before full night")
	_expect(night.backdrop_tint.r < evening.backdrop_tint.r and night.backdrop_tint.b < evening.backdrop_tint.b, "Distant scenery continues darkening into night")
	var farm = Farm.new(1000.0)
	var before_visuals: Dictionary = farm.snapshot()
	for pair in [[6.5, "dawn"], [12.0, "day"], [18.0, "dusk"], [22.0, "night"]]:
		sample.atmosphere.set_preview_hour(pair[0])
		await create_timer(0.25).timeout
		if not output_dir.is_empty():
			await _screenshot("independent_%s.png" % pair[1])
	_expect(farm.snapshot() == before_visuals, "Presentation time changes do not alter farm state")
	sample.atmosphere.ripple_at(Vector3.ZERO)
	await create_timer(0.5).timeout
	if not output_dir.is_empty():
		await _screenshot("independent_ripple.png")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	for failure in failures:
		push_error(failure)
	print("ATMOSPHERE_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _peak() -> float:
	var frames: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var peak: float = 0.0
	for frame in frames:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak


func _screenshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.save_png(output_dir.path_join(filename)) == OK, "Saved " + filename)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
