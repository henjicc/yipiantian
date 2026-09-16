extends RefCounted
## The sole mutable owner of planting state. No scene, clock reading or disk I/O.

const Crops = preload("res://farm/crop_catalog.gd")
const FIELD_IDS: Array[String] = ["field_01", "field_02", "field_03", "field_04", "field_05", "field_06"]
# JSON numbers remain exact only up to this bound.
const MAX_HARVEST_COUNT: int = 9007199254740991

var _data: Dictionary


func _init(now_utc_seconds: float = 0.0) -> void:
	assert(_valid_time(now_utc_seconds), "Farm initialization requires finite nonnegative UTC seconds")
	_data = {"fields": {}, "harvested": {"greens": 0, "radish": 0}}
	for field_id: String in FIELD_IDS:
		_data.fields[field_id] = _empty_field(now_utc_seconds)
	_set_initial_crop("field_03", "greens", 1.0)
	_set_initial_crop("field_04", "greens", 0.2)
	_set_initial_crop("field_05", "radish", 0.1)
	_set_initial_crop("field_06", "radish", 0.6)


func snapshot() -> Dictionary:
	return _data.duplicate(true)


func restore_snapshot(data: Dictionary) -> bool:
	# Disk format/version and recovery remain the storage boundary's responsibility.
	# Check the entire candidate before changing any authoritative field.
	if not _valid_snapshot(data):
		return false
	_data = data.duplicate(true)
	for crop_id: String in Crops.crop_ids():
		_data.harvested[crop_id] = int(_data.harvested[crop_id])
	return true


func get_field(field_id: String) -> Dictionary:
	if not _data.fields.has(field_id):
		return {}
	var field: Dictionary = _data.fields[field_id].duplicate(true)
	field["id"] = field_id
	field["progress"] = 0.0
	field["remaining_seconds"] = 0.0
	field["stage"] = "empty"
	if not field.crop_id.is_empty():
		var duration: float = Crops.definition(field.crop_id).duration_seconds
		field.progress = field.growth_seconds / duration
		field.remaining_seconds = duration - field.growth_seconds
		field.stage = "mature" if field.progress >= 1.0 else ("young" if field.progress >= Crops.YOUNG_PROGRESS else "sprout")
	return field


func settle(now_utc_seconds: float) -> Dictionary:
	if not _valid_time(now_utc_seconds):
		return _result(false, "invalid_time")
	var changed: Array[String] = _settle_data(_data, now_utc_seconds)
	return _result(true, "", changed)


func sow(field_id: String, crop_id: String, now_utc_seconds: float) -> Dictionary:
	if Crops.definition(crop_id).is_empty():
		return _result(false, "invalid_crop")
	return _act("sow", field_id, crop_id, now_utc_seconds)


func water(field_id: String, now_utc_seconds: float) -> Dictionary:
	return _act("water", field_id, "", now_utc_seconds)


func harvest(field_id: String, now_utc_seconds: float) -> Dictionary:
	return _act("harvest", field_id, "", now_utc_seconds)


func _act(action: String, field_id: String, crop_id: String, now_utc_seconds: float) -> Dictionary:
	if not _valid_time(now_utc_seconds):
		return _result(false, "invalid_time")
	if not _data.fields.has(field_id):
		return _result(false, "invalid_field")
	# Failed actions are atomic no-ops, including time. Periodic settle() is independent.
	var candidate: Dictionary = _data.duplicate(true)
	var changed: Array[String] = _settle_data(candidate, now_utc_seconds)
	var field: Dictionary = candidate.fields[field_id]
	var reward_crop: String = ""
	if action == "sow":
		if not field.crop_id.is_empty():
			return _result(false, "occupied")
		field.crop_id = crop_id
	elif field.crop_id.is_empty():
		return _result(false, "empty")
	else:
		var duration: float = Crops.definition(field.crop_id).duration_seconds
		if action == "water":
			if field.growth_seconds >= duration:
				return _result(false, "mature")
			if field.watered:
				return _result(false, "already_watered")
			field.growth_seconds = minf(duration, field.growth_seconds + duration * Crops.WATER_PROGRESS)
			field.watered = true
		else:
			if field.growth_seconds < duration:
				return _result(false, "not_mature")
			reward_crop = field.crop_id
			if candidate.harvested[reward_crop] >= MAX_HARVEST_COUNT:
				return _result(false, "harvest_limit")
			candidate.harvested[reward_crop] += 1
			candidate.fields[field_id] = _empty_field(field.last_settled_utc_seconds)
	if not changed.has(field_id):
		changed.append(field_id)
	_data = candidate
	return _result(true, "", changed, reward_crop)


func _settle_data(data: Dictionary, now_utc_seconds: float) -> Array[String]:
	var changed: Array[String] = []
	for field_id: String in FIELD_IDS:
		var field: Dictionary = data.fields[field_id]
		if now_utc_seconds <= field.last_settled_utc_seconds:
			continue
		var elapsed: float = now_utc_seconds - field.last_settled_utc_seconds
		if not field.crop_id.is_empty():
			var duration: float = Crops.definition(field.crop_id).duration_seconds
			field.growth_seconds = minf(duration, field.growth_seconds + elapsed)
		# Advance empty and mature fields too; rollback sowing cannot reuse elapsed time.
		field.last_settled_utc_seconds = now_utc_seconds
		changed.append(field_id)
	return changed


func _set_initial_crop(field_id: String, crop_id: String, progress: float) -> void:
	_data.fields[field_id].crop_id = crop_id
	_data.fields[field_id].growth_seconds = Crops.definition(crop_id).duration_seconds * progress


static func _empty_field(now_utc_seconds: float) -> Dictionary:
	return {"crop_id": "", "growth_seconds": 0.0, "last_settled_utc_seconds": now_utc_seconds, "watered": false}


static func _result(ok: bool, reason: String, changed: Array[String] = [], reward_crop: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason, "changed_fields": changed, "reward_crop_id": reward_crop, "reward_amount": 0 if reward_crop.is_empty() else 1}


static func _valid_time(value: float) -> bool:
	return is_finite(value) and value >= 0.0


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _valid_snapshot(data: Dictionary) -> bool:
	if data.size() != 2 or not data.get("fields") is Dictionary or not data.get("harvested") is Dictionary:
		return false
	var fields: Dictionary = data.fields
	var harvested: Dictionary = data.harvested
	if fields.size() != FIELD_IDS.size() or harvested.size() != Crops.crop_ids().size():
		return false
	for crop_id: String in Crops.crop_ids():
		var count: Variant = harvested.get(crop_id)
		if not _is_number(count) or float(count) < 0.0 or float(count) > MAX_HARVEST_COUNT or float(count) != floorf(float(count)):
			return false
	for field_id: String in FIELD_IDS:
		if not fields.get(field_id) is Dictionary:
			return false
		var field: Dictionary = fields[field_id]
		if field.size() != 4 or not field.get("crop_id") is String or not field.get("watered") is bool:
			return false
		var growth: Variant = field.get("growth_seconds")
		var baseline: Variant = field.get("last_settled_utc_seconds")
		if not _is_number(growth) or float(growth) < 0.0 or not _is_number(baseline) or not _valid_time(float(baseline)):
			return false
		if field.crop_id.is_empty():
			if float(growth) != 0.0 or field.watered:
				return false
		else:
			var crop: Dictionary = Crops.definition(field.crop_id)
			if crop.is_empty() or float(growth) > crop.duration_seconds:
				return false
			if field.watered and float(growth) < crop.duration_seconds * Crops.WATER_PROGRESS:
				return false
	return true
