extends SceneTree
## Native-window test. Pass an isolated --record-session directory with config.json.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session_dir: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--record-session="):
			session_dir = argument.trim_prefix("--record-session=")
	if session_dir.is_empty():
		push_error("An isolated recording session directory is required.")
		quit(1)
		return
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	var isolated: String = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification/scene-save-%d" % Time.get_ticks_usec())
	scene.store = load("res://farm/farm_store.gd").new(isolated)
	root.add_child(scene)
	for attempt in 100:
		if FileAccess.file_exists(session_dir.path_join("ready.json")):
			break
		await create_timer(0.1).timeout
	if not FileAccess.file_exists(session_dir.path_join("ready.json")):
		push_error("Recording window did not become ready.")
		quit(1)
		return
	var event := InputEventKey.new()
	event.keycode = KEY_F9
	event.pressed = true
	root.push_input(event)
	# Movie Maker queues a graceful quit on F9; check the published request now.
	var file := FileAccess.open(session_dir.path_join("stop.json"), FileAccess.READ)
	if file == null or JSON.parse_string(file.get_as_text()).get("reason") != "user_f9":
		push_error("F9 did not request a graceful recording stop.")
		quit(1)
		return
	if not is_equal_approx(scene.camera.transition_seconds, 0.75):
		push_error("Manual recording changed the normal camera speed.")
		quit(1)
		return
	print("RECORDING_CONTROLS_SMOKE failures=0")
	if not OS.has_feature("movie"):
		quit()
	# In MovieMaker the recording owner must finish its two cleanup frames and
	# quit itself. An immediate test quit would hide a broken cleanup sequence.
