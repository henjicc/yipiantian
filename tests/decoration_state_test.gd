extends SceneTree

const Farm = preload("res://farm/farm_state.gd")
const Decorations = preload("res://farm/decoration_state.gd")
const Store = preload("res://farm/farm_store.gd")
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var farm := Farm.new(1000.0)
	var decorations := Decorations.new()
	_expect(decorations.unlock(farm.snapshot().harvested).is_empty(), "No unlock before earned harvest")
	_expect(not decorations.place("pot", "ground_01", 0).ok, "Locked item cannot be placed")
	for boundary: Array in [[4, 3, false, false], [5, 2, false, false], [5, 3, true, false], [9, 6, true, false], [10, 5, true, false], [10, 6, true, true]]:
		var candidate := Decorations.new()
		candidate.unlock({"greens": boundary[0], "radish": boundary[1]})
		_expect(candidate.snapshot().flowerpot.unlocked == boundary[2] and candidate.snapshot().lantern.unlocked == boundary[3], "Each crop-specific unlock threshold is exact")
	var now: float = 1000.0
	for crop: String in ["greens", "radish"]:
		for cycle in (10 if crop == "greens" else 6):
			farm.sow("field_01", "cell_06", crop, now)
			farm.water("field_01", "cell_06", now)
			now += 6000.0
			farm.harvest("field_01", "cell_06", now)
			var unlocked: Array[String] = decorations.unlock(farm.snapshot().harvested)
			if crop == "greens" and cycle == 2:
				_expect(unlocked == ["pot"], "Exactly three total baskets unlock pot")
			elif crop == "radish" and cycle == 2:
				_expect(unlocked == ["flowerpot"], "Five greens plus three radish unlock flowerpot")
			elif crop == "radish" and cycle == 5:
				_expect(unlocked == ["lantern"], "Ten greens plus six radish unlock lantern")
			else:
				_expect(unlocked.is_empty(), "No early or repeated unlock")
	_expect(farm.snapshot().harvested == {"greens": 10, "radish": 6}, "Unlocks never spend harvest")
	_expect(decorations.unlock({"greens": 0, "radish": 0}).is_empty() and decorations.snapshot().lantern.unlocked, "Earned unlocks are never revoked")
	_expect(decorations.place("pot", "ground_01", 3).ok, "Ground placement accepts quarter rotation")
	var before: Dictionary = decorations.snapshot()
	_expect(not decorations.place("flowerpot", "ground_01", 0).ok and decorations.snapshot() == before, "Occupied target rejects without mutation")
	_expect(not decorations.place("lantern", "ground_02", 0).ok, "Hanging item rejects ground slots")
	_expect(not decorations.place("lantern", "hanging_01", 1).ok, "Hanging item rejects unsupported rotation")
	_expect(decorations.place("pot", "ground_02", 1).ok and decorations.place("flowerpot", "ground_01", 0).ok, "Moving frees previous slot")
	_expect(decorations.place("lantern", "hanging_04", 0).ok, "Alternative hanging slot works")
	var restored := Decorations.new()
	_expect(restored.restore_snapshot(decorations.snapshot()) and restored.snapshot() == decorations.snapshot(), "Confirmed placements round trip")
	var invalid: Dictionary = decorations.snapshot()
	invalid.flowerpot.slot_id = "ground_02"
	_expect(not restored.restore_snapshot(invalid), "Duplicate occupancy rejected at load")
	invalid = decorations.snapshot()
	invalid.pot.quarter_turn = 1.5
	_expect(not restored.restore_snapshot(invalid), "Fractional rotation rejected at load")
	var folder: String = ProjectSettings.globalize_path("res://../").simplify_path().path_join(".local/verification/decorations-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var legacy: Dictionary = {"fields": {}, "harvested": farm.snapshot().harvested}
	for field_id: String in Farm.FIELD_IDS:
		legacy.fields[field_id] = farm.snapshot().fields[field_id].cells.cell_06.duplicate(true)
	var original: String = JSON.stringify({"version": 1, "farm": legacy})
	_write(folder.path_join(Store.MAIN), original)
	var store := Store.new(folder)
	var loaded: Dictionary = store.load_state()
	_expect(loaded.ok and loaded.migrated and loaded.farm == farm.snapshot(), "Version one migration preserves all farm state")
	_expect(loaded.decorations.lantern.unlocked and loaded.decorations.pot.slot_id.is_empty(), "Version one derives earned unlocks without placing")
	_expect(FileAccess.get_file_as_string(folder.path_join(Store.MAIN)) == original, "Reading migration does not alter original bytes")
	FileAccess.set_read_only_attribute(folder.path_join(Store.MAIN), true)
	_expect(not store.save(farm.snapshot(), decorations.snapshot()).ok and not store.save(farm.snapshot(), decorations.snapshot()).ok, "Failed migration can retry without altering original main")
	var copies: int = 0
	for name: String in DirAccess.get_files_at(folder):
		if name.begins_with("farm.v1."):
			copies += 1
	_expect(copies == 1 and FileAccess.get_file_as_string(folder.path_join(Store.MAIN)) == original, "Migration retries reuse one original copy and preserve v1")
	FileAccess.set_read_only_attribute(folder.path_join(Store.MAIN), false)
	_expect(store.save(farm.snapshot(), decorations.snapshot()).ok, "Version three saves full state explicitly")
	_expect(FileAccess.get_file_as_string(folder.path_join(Store.BACKUP)) == original, "First migration save retains exact version one backup")
	var migration_copy: String = ""
	for name: String in DirAccess.get_files_at(folder):
		if name.begins_with("farm.v1."):
			migration_copy = FileAccess.get_file_as_string(folder.path_join(name))
	_expect(migration_copy == original, "Original version one remains archived beyond rotating backups")
	loaded = Store.new(folder).load_state()
	_expect(loaded.ok and not loaded.migrated and loaded.decorations == decorations.snapshot() and loaded.farm == farm.snapshot(), "Version three reopens farm and decoration placements")
	FileAccess.set_read_only_attribute(folder.path_join(Store.MAIN), true)
	decorations.place("pot", "ground_03", 2)
	_expect(not store.save(farm.snapshot(), decorations.snapshot()).ok and Store.new(folder).load_state().decorations == loaded.decorations, "Failed placement save preserves last committed position")
	FileAccess.set_read_only_attribute(folder.path_join(Store.MAIN), false)
	_expect(store.save(farm.snapshot(), decorations.snapshot()).ok and Store.new(folder).load_state().decorations == decorations.snapshot(), "Retry saves moved item without new unlock or harvest")
	_write(folder.path_join(Store.MAIN), JSON.stringify({"version": Store.VERSION + 1, "farm": farm.snapshot(), "decorations": decorations.snapshot()}))
	_expect(Store.new(folder).load_state().kind == "unsupported", "Newer schema refuses downgrade")
	for failure: String in failures:
		push_error(failure)
	print("DECORATION_STATE_TEST checks=%d failures=%d directory=%s" % [checks, failures.size(), folder])
	quit(0 if failures.is_empty() else 1)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
