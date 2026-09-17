extends RefCounted
## UI preferences have their own file and never read or write farm progress.

const VERSION: int = 1
const MAX_BYTES: int = 4096
const MAIN: String = "settings.json"
const PENDING: String = "settings.pending.json"
const DEFAULTS: Dictionary = {
	"master": 0.8, "music": 0.7, "effects": 0.8,
	"fullscreen": false, "quality": "standard", "dof_enabled": true,
}
var directory: String
var _loaded: bool = false
var _kind: String = "not_loaded"
var _expected_hash: String = ""


func _init(settings_directory: String = "user://preferences") -> void:
	directory = ProjectSettings.globalize_path(settings_directory).simplify_path()


func load_settings() -> Dictionary:
	_loaded = true
	if not _safe_paths():
		_kind = "unsafe_path"
		return _load_failure(_kind)
	var data: Dictionary = _read(MAIN)
	_kind = data.kind
	_expected_hash = data.get("hash", "")
	if _kind == "valid":
		return {"ok": true, "kind": "loaded", "settings": data.settings.duplicate(true)}
	if _kind == "missing":
		return {"ok": true, "kind": "first", "settings": DEFAULTS.duplicate(true)}
	return _load_failure(_kind)


func save(settings: Dictionary) -> Dictionary:
	if not valid_settings(settings):
		return _failure("invalid_settings")
	if not _loaded:
		return _failure("not_loaded")
	if not _safe_paths():
		return _failure("unsafe_path")
	# An unreadable directory can become available on an explicit retry. Unknown
	# versions stay read-only; only replacing that file externally admits a retry.
	if _kind in ["io", "unsafe_path", "unsupported"]:
		var reloaded: Dictionary = load_settings()
		if not reloaded.ok:
			return _failure(_kind)
	var current: Dictionary = _read(MAIN)
	if current.kind == "unsupported":
		return _failure("unsupported")
	if current.kind == "io" or current.get("hash", "") != _expected_hash or (current.kind == "missing") != (_kind == "missing"):
		return _failure("changed_on_disk")
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if mkdir_error != OK:
		return _failure("create_directory", mkdir_error)
	if current.kind == "corrupt":
		var archive: String = "settings.unreadable.%s.json" % _expected_hash
		var dir := DirAccess.open(directory)
		if dir.is_link(archive) or DirAccess.dir_exists_absolute(_path(archive)):
			return _failure("preserve_original")
		if not FileAccess.file_exists(_path(archive)):
			var copy_error: Error = DirAccess.copy_absolute(_path(MAIN), _path(archive))
			if copy_error != OK:
				return _failure("preserve_original", copy_error)
		if FileAccess.get_sha256(_path(archive)) != _expected_hash:
			return _failure("preserve_original")
	if _read(PENDING).kind == "unsupported":
		return _failure("unsupported_pending")
	var text: String = JSON.stringify({"version": VERSION, "settings": settings}, "\t")
	var file := FileAccess.open(_path(PENDING), FileAccess.WRITE)
	if file == null:
		return _failure("write", FileAccess.get_open_error())
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _failure("flush", write_error)
	var verified: Dictionary = _read(PENDING)
	if verified.kind != "valid" or verified.settings != settings:
		return _failure("verify")
	var replace_error: Error = DirAccess.rename_absolute(_path(PENDING), _path(MAIN))
	if replace_error != OK:
		return _failure("replace", replace_error)
	_kind = "valid"
	_expected_hash = verified.hash
	print("SETTINGS_STORE stage=saved version=%d" % VERSION)
	return {"ok": true, "kind": "saved"}


static func valid_settings(value: Dictionary) -> bool:
	if value.size() != DEFAULTS.size():
		return false
	for key: String in ["master", "music", "effects"]:
		var volume: Variant = value.get(key)
		if not (volume is float or volume is int) or not is_finite(float(volume)) or float(volume) < 0.0 or float(volume) > 1.0:
			return false
	return value.get("fullscreen") is bool and value.get("dof_enabled") is bool and value.get("quality") in ["standard", "low"]


func _read(filename: String) -> Dictionary:
	var path: String = _path(filename)
	if DirAccess.dir_exists_absolute(path):
		return {"kind": "io"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"kind": "missing" if FileAccess.get_open_error() == ERR_FILE_NOT_FOUND else "io"}
	var hash_value: String = FileAccess.get_sha256(path)
	if file.get_length() == 0 or file.get_length() > MAX_BYTES:
		file.close()
		return {"kind": "corrupt", "hash": hash_value}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		return {"kind": "io"}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"kind": "corrupt", "hash": hash_value}
	var data: Dictionary = json.data
	var version: Variant = data.get("version")
	if not (version is float or version is int) or not is_finite(float(version)) or float(version) != floorf(float(version)):
		return {"kind": "corrupt", "hash": hash_value}
	if version != VERSION:
		return {"kind": "unsupported", "hash": hash_value}
	if data.size() != 2 or not data.get("settings") is Dictionary or not valid_settings(data.settings):
		return {"kind": "corrupt", "hash": hash_value}
	return {"kind": "valid", "settings": data.settings, "hash": hash_value}


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
	return not dir.is_link(MAIN) and not dir.is_link(PENDING)


func _path(filename: String) -> String:
	return directory.path_join(filename)


static func _load_failure(kind: String) -> Dictionary:
	push_warning("SETTINGS_STORE stage=load reason=%s" % kind)
	return {"ok": false, "kind": kind, "settings": DEFAULTS.duplicate(true)}


static func _failure(kind: String, error: Error = FAILED) -> Dictionary:
	push_warning("SETTINGS_STORE stage=%s error=%d" % [kind, error])
	return {"ok": false, "kind": kind, "error": int(error)}
