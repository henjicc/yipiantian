extends SceneTree

const Store = preload("res://settings/settings_store.gd")
var checks: int = 0
var failures: Array[String] = []
var root_path: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root_path = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(".local/verification/settings-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(root_path)
	var path: String = root_path.path_join("roundtrip")
	var store := Store.new(path)
	var loaded: Dictionary = store.load_settings()
	_expect(loaded.ok and loaded.kind == "first" and loaded.settings == Store.DEFAULTS, "Missing preferences use honest first-run defaults")
	loaded.settings.master = 0.0
	_expect(Store.DEFAULTS.master == 0.8, "Returned settings cannot mutate defaults")
	var values: Dictionary = loaded.settings
	values.fullscreen = true
	values.quality = "low"
	values.dof_enabled = false
	_expect(store.save(values).ok, "All preference categories save")
	_expect(Store.new(path).load_settings().settings == values, "Reopening preserves exact settings")
	values.quality = "high"
	_expect(store.save(values).ok, "High quality is a supported saved preference")
	_expect(Store.new(path).load_settings().settings.quality == "high", "Reopening preserves high quality")
	var farm_marker: String = root_path.path_join("farm.json")
	_write(farm_marker, "unchanged farm sentinel")
	var before: String = FileAccess.get_file_as_string(path.path_join(Store.MAIN))
	DirAccess.make_dir_absolute(path.path_join(Store.PENDING))
	values.music = 0.0
	_expect(not store.save(values).ok, "Real filesystem write failure is not success")
	_expect(FileAccess.get_file_as_string(path.path_join(Store.MAIN)) == before, "Failed write retains committed preferences")
	DirAccess.remove_absolute(path.path_join(Store.PENDING))
	_expect(store.save(values).ok, "Explicit retry saves current in-memory settings")
	_expect(FileAccess.get_file_as_string(farm_marker) == "unchanged farm sentinel", "Preference I/O does not modify farm state")
	var old: String = FileAccess.get_file_as_string(path.path_join(Store.MAIN))
	FileAccess.set_read_only_attribute(path.path_join(Store.MAIN), true)
	values.effects = 0.0
	_expect(not store.save(values).ok, "Read-only final file rejects atomic replacement")
	_expect(FileAccess.get_file_as_string(path.path_join(Store.MAIN)) == old, "Failed replacement preserves bytes")
	FileAccess.set_read_only_attribute(path.path_join(Store.MAIN), false)
	_expect(store.save(values).ok, "Replacement retry recovers after permission repair")
	for bad: Variant in [-0.1, 1.1, NAN, INF, "0.5", true, null]:
		var invalid: Dictionary = values.duplicate(true)
		invalid.master = bad
		_expect(not store.save(invalid).ok, "Invalid volume is rejected: %s" % str(bad))
	for key: String in ["quality", "fullscreen", "dof_enabled"]:
		var invalid: Dictionary = values.duplicate(true)
		invalid[key] = "invalid"
		_expect(not store.save(invalid).ok, "Invalid enum/boolean is rejected: " + key)
	var stale := Store.new(path)
	stale.load_settings()
	values.master = 0.42
	_expect(store.save(values).ok, "Active owner saves newer preferences")
	_expect(not stale.save(Store.DEFAULTS).ok, "Stale preference owner cannot overwrite another session")
	var corrupt_path: String = root_path.path_join("corrupt")
	DirAccess.make_dir_absolute(corrupt_path)
	_write(corrupt_path.path_join(Store.MAIN), "{ broken settings")
	var corrupt := Store.new(corrupt_path)
	loaded = corrupt.load_settings()
	_expect(not loaded.ok and loaded.kind == "corrupt" and loaded.settings == Store.DEFAULTS, "Malformed settings return defaults with explicit failure")
	var original_hash: String = FileAccess.get_sha256(corrupt_path.path_join(Store.MAIN))
	_expect(corrupt.save(values).ok, "Explicit save may repair malformed settings")
	_expect(FileAccess.get_sha256(corrupt_path.path_join("settings.unreadable.%s.json" % original_hash)) == original_hash, "Corrupt original is archived byte-for-byte before replacement")
	var future_path: String = root_path.path_join("future")
	DirAccess.make_dir_absolute(future_path)
	var future: String = JSON.stringify({"version": 99, "settings": values, "future": true})
	_write(future_path.path_join(Store.MAIN), future)
	var newer := Store.new(future_path)
	loaded = newer.load_settings()
	_expect(not loaded.ok and loaded.kind == "unsupported", "Future version is an explicit load failure")
	_expect(not newer.save(values).ok, "Future settings cannot be silently downgraded")
	_expect(FileAccess.get_file_as_string(future_path.path_join(Store.MAIN)) == future, "Unknown-version original stays untouched")
	_write(future_path.path_join(Store.MAIN), JSON.stringify({"version": 1, "settings": Store.DEFAULTS}))
	_expect(newer.save(values).ok, "Explicit retry recovers after external future-file repair")
	var blocked_path: String = root_path.path_join("blocked")
	_write(blocked_path, "not a directory")
	var blocked := Store.new(blocked_path)
	_expect(not blocked.load_settings().ok and not blocked.save(values).ok, "Non-directory settings location fails without false success")
	_expect(FileAccess.get_file_as_string(blocked_path) == "not a directory", "Blocked location is never overwritten")
	DirAccess.remove_absolute(blocked_path)
	_expect(blocked.save(values).ok, "Retry can create preferences after blocker removal")
	var unloaded := Store.new(root_path.path_join("never_loaded"))
	_expect(not unloaded.save(values).ok, "Saving requires an explicit load boundary")
	print("SETTINGS_TEST checks=%d failures=%d directory=%s" % [checks, failures.size(), root_path])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
