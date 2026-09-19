extends RefCounted
## Versioned local storage. This owner serializes writes; the farm owns all gameplay rules.

const FarmState = preload("res://farm/farm_state.gd")
const Decorations = preload("res://farm/decoration_state.gd")
const VERSION: int = 19
const MAX_BYTES: int = 524288
const MAIN: String = "farm.json"
const BACKUP: String = "farm.backup.json"
const PENDING: String = "farm.pending.json"
const BACKUP_PENDING: String = "farm.backup.pending.json"
var directory: String
var _writable: bool = false
var _expected_main: String = ""
var _expected_missing: bool = true


func _init(save_directory: String = "user://farm-v19") -> void:
	directory = ProjectSettings.globalize_path(save_directory).simplify_path()


func load_state() -> Dictionary:
	_writable = false
	if not _safe_paths():
		return _failure("unsafe_path")
	var primary: Dictionary = _read(MAIN)
	if primary.kind == "valid":
		_admit(primary.text, false)
		return {"ok": true, "kind": "loaded", "farm": primary.farm, "decorations": primary.decorations, "migrated": primary.version < VERSION}
	if primary.kind == "unsupported" or primary.kind == "io":
		return _failure(primary.kind)
	var backup: Dictionary = _read(BACKUP)
	if backup.kind == "unsupported":
		return _failure("unsupported")
	if backup.kind == "valid":
		return {"ok": false, "kind": "recovery_available", "source": BACKUP}
	var staged_backup: Dictionary = _read(BACKUP_PENDING)
	if staged_backup.kind == "unsupported":
		return _failure("unsupported")
	if staged_backup.kind == "valid":
		return {"ok": false, "kind": "recovery_available", "source": BACKUP_PENDING}
	var pending: Dictionary = _read(PENDING)
	if pending.kind == "unsupported":
		return _failure("unsupported")
	# Only an interrupted first creation may recover a pending candidate. Once a
	# committed main exists, never replay an uncommitted action from a temp file.
	if primary.kind == "missing" and backup.kind == "missing" and staged_backup.kind == "missing" and pending.kind == "valid":
		return {"ok": false, "kind": "recovery_available", "source": PENDING}
	if primary.kind == "missing" and backup.kind == "missing" and staged_backup.kind == "missing" and pending.kind == "missing":
		_admit("", true)
		return {"ok": true, "kind": "missing"}
	return _failure("io" if backup.kind == "io" or pending.kind == "io" else "corrupt")


func save(farm: Dictionary, decorations: Dictionary) -> Dictionary:
	if not _writable:
		return _failure("not_loaded")
	var validator := FarmState.new()
	if not validator.restore_snapshot(farm):
		return _failure("invalid_state")
	var decoration_validator := Decorations.new()
	if not decoration_validator.restore_snapshot(decorations):
		return _failure("invalid_decorations")
	if not _safe_paths():
		return _failure("unsafe_path")
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK:
		return _failure("create_directory", mkdir_error)
	var current: Dictionary = _read(MAIN)
	if not _matches_expected(current):
		return _failure("changed_on_disk")
	for filename: String in [BACKUP, BACKUP_PENDING, PENDING]:
		if _read(filename).kind == "unsupported":
			return _failure("unsupported")
	var text: String = JSON.stringify({"version": VERSION, "farm": validator.snapshot(), "decorations": decoration_validator.snapshot()}, "\t")
	var result: Dictionary = _write_verified(PENDING, text)
	if not result.ok:
		return result
	if current.kind == "valid":
		result = _write_verified(BACKUP_PENDING, current.text)
		if not result.ok:
			return result
		var backup_error: Error = DirAccess.rename_absolute(_path(BACKUP_PENDING), _path(BACKUP))
		if backup_error != OK:
			return _failure("replace_backup", backup_error)
	# Windows rename replaces the destination without deleting the main first.
	# If the last replacement fails, the old main and its validated backup remain.
	var replace_error: Error = DirAccess.rename_absolute(_path(PENDING), _path(MAIN))
	if replace_error != OK:
		return _failure("replace_main", replace_error)
	_admit(text, false)
	print("FARM_SAVE stage=complete version=%d" % VERSION)
	return {"ok": true, "kind": "saved"}


func recover() -> Dictionary:
	var state: Dictionary = load_state()
	if state.kind != "recovery_available":
		return state if not state.ok else _failure("no_recovery")
	var source: Dictionary = _read(state.source)
	if source.kind != "valid":
		return _failure("recovery_changed")
	# Explicit recovery retains the original bytes for diagnosis, including malformed
	# or oversized input. It never silently replaces a file with a fresh farm.
	if FileAccess.file_exists(_path(MAIN)):
		var archive: String = "farm.unreadable.%d.%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
		if FileAccess.file_exists(_path(archive)):
			return _failure("preserve_original")
		var copy_error: Error = DirAccess.copy_absolute(_path(MAIN), _path(archive))
		if copy_error != OK or FileAccess.get_sha256(_path(MAIN)) != FileAccess.get_sha256(_path(archive)):
			return _failure("preserve_original", copy_error)
	var result: Dictionary = _write_verified(PENDING, source.text)
	if not result.ok:
		return result
	var replace_error: Error = DirAccess.rename_absolute(_path(PENDING), _path(MAIN))
	if replace_error != OK:
		return _failure("recover_replace", replace_error)
	_admit(source.text, false)
	print("FARM_LOAD stage=recovered source=%s version=%d" % [state.source, source.version])
	return {"ok": true, "kind": "recovered", "farm": source.farm, "decorations": source.decorations, "migrated": source.version < VERSION}


func _read(filename: String) -> Dictionary:
	var path: String = _path(filename)
	if DirAccess.dir_exists_absolute(path):
		return {"kind": "io"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var error: Error = FileAccess.get_open_error()
		return {"kind": "missing" if error == ERR_FILE_NOT_FOUND else "io"}
	if file.get_length() == 0 or file.get_length() > MAX_BYTES:
		file.close()
		return {"kind": "corrupt"}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return {"kind": "io"}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"kind": "corrupt"}
	var data: Dictionary = json.data
	var version: Variant = data.get("version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != floorf(float(version)):
		return {"kind": "corrupt"}
	if version != VERSION:
		return {"kind": "unsupported"}
	if data.size() != 3 or not data.get("farm") is Dictionary:
		return {"kind": "corrupt"}
	var validator := FarmState.new()
	var farm_data: Dictionary = data.farm
	if not validator.restore_snapshot(farm_data):
		return {"kind": "corrupt"}
	var decoration_validator := Decorations.new()
	if not data.get("decorations") is Dictionary or not decoration_validator.restore_snapshot(data.decorations):
		return {"kind": "corrupt"}
	return {"kind": "valid", "version": int(version), "text": text, "farm": validator.snapshot(), "decorations": decoration_validator.snapshot()}


func _write_verified(filename: String, text: String) -> Dictionary:
	var file := FileAccess.open(_path(filename), FileAccess.WRITE)
	if file == null:
		return _failure("write_" + filename, FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _failure("flush_" + filename, write_error)
	var verified: Dictionary = _read(filename)
	if verified.kind != "valid" or verified.text != text:
		return _failure("verify_" + filename)
	return {"ok": true}


func _matches_expected(current: Dictionary) -> bool:
	if _expected_missing:
		return current.kind == "missing"
	return current.kind == "valid" and current.text == _expected_main


func _admit(text: String, missing: bool) -> void:
	_writable = true
	_expected_main = text
	_expected_missing = missing


func _path(filename: String) -> String:
	return directory.path_join(filename)


func _safe_paths() -> bool:
	if not directory.is_absolute_path():
		return false
	var cursor: String = directory
	while cursor != cursor.get_base_dir():
		var parent := DirAccess.open(cursor.get_base_dir())
		if parent != null and parent.is_link(cursor):
			return false
		cursor = cursor.get_base_dir()
	var dir := DirAccess.open(directory)
	if dir == null:
		return not FileAccess.file_exists(directory)
	for filename: String in [MAIN, BACKUP, PENDING, BACKUP_PENDING]:
		if dir.is_link(filename):
			return false
	return true


static func _failure(kind: String, error: Error = FAILED) -> Dictionary:
	push_warning("FARM_STORE stage=%s error=%d" % [kind, error])
	return {"ok": false, "kind": kind, "error": int(error)}
