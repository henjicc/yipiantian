extends SceneTree
## Isolated real-scene exit regression; each mode ends through the product path.

const Main = preload("res://scenes/main.tscn")
const Store = preload("res://farm/farm_store.gd")
const Settings = preload("res://settings/settings_store.gd")
var checks: int = 0
var scene: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var mode: String = "normal"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
	var folder: String = get_script().resource_path.get_base_dir().get_base_dir().path_join(".local/verification/exit-cleanup/test-%s-%d" % [mode, Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(folder.path_join("farm"))
	var save: String = folder.path_join("farm/farm.json")
	if mode == "unloaded":
		FileAccess.open(save, FileAccess.WRITE).store_string('{"version":999}')
	scene = Main.instantiate()
	scene.store = Store.new(folder.path_join("farm"))
	scene.settings_store = Settings.new(folder.path_join("preferences"))
	root.add_child(scene)
	await create_timer(0.15).timeout
	var audio: Node = scene.farm_audio
	audio.set_foreground(true)
	var volumes: Dictionary = audio.get_volumes()
	if mode != "unloaded":
		# A newer on-disk revision is a real failed-save boundary, without touching
		# the player's profile or mocking the persistence implementation.
		var saved: String = FileAccess.get_file_as_string(save)
		FileAccess.open(save, FileAccess.WRITE).store_string(saved + "\n")
		scene._request_exit()
		_expect(not scene._exiting, "Failed farm save keeps the game open")
		_expect(audio.get_node("Music").stream != null, "Rejected exit retains music for retry")
		_expect(not root.gui_disable_input, "Rejected exit retains UI input")
		if mode == "normal":
			FileAccess.open(save, FileAccess.WRITE).store_string(saved)
			scene._retry_storage()
			# A file where the settings directory belongs makes a genuine settings
			# write fail, and must block final shutdown too.
			var blocked: String = folder.path_join("blocked-preferences")
			FileAccess.open(blocked, FileAccess.WRITE).store_string("block")
			scene.settings_store = Settings.new(blocked)
			scene.settings_store.load_settings()
			scene._settings_dirty = true
			scene._request_exit()
			_expect(not scene._exiting, "Failed settings save also keeps the game open")
			_expect(audio.get_node("Music").stream != null, "Failed settings save retains audio")
			scene.settings_store = Settings.new(folder.path_join("preferences"))
			scene.settings_store.load_settings()
			_expect(scene._save_settings(), "Settings retry can recover before final exit")
	if mode == "abandon":
		scene.hud.exit_requested.emit()
	else:
		scene._request_exit()
	_expect(scene._exiting, "Permitted exit enters terminal state")
	_expect(root.gui_disable_input and not scene.can_process(), "Drain blocks GUI and farm processing")
	scene._request_exit()
	scene.hud.exit_requested.emit()
	audio.shutdown()
	audio.set_foreground(true)
	_expect(not audio.play_ui() and not audio.play_action("water", {"ok": true}), "Shutdown cannot restart sound")
	_expect(audio.get_volumes() == volumes, "Shutdown does not rewrite volume preferences")
	for child: Node in audio.get_children():
		if child is AudioStreamPlayer:
			_expect(child.stream == null and not child.playing, "Stopped player releases its stream")
	var before: String = FileAccess.get_file_as_string(save)
	var input := InputEventKey.new()
	input.keycode = KEY_ESCAPE
	input.pressed = true
	root.push_input(input)
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await process_frame
	_expect(scene._exiting and root.gui_disable_input, "Input cannot cancel or reopen an admitted exit")
	_expect(FileAccess.get_file_as_string(save) == before, "Focus during drain cannot write the save")
	print("EXIT_CLEANUP_PASS mode=%s checks=%d; awaiting real product quit" % [mode, checks])


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		push_error("EXIT_CLEANUP_FAIL: " + label)
		quit(1)
