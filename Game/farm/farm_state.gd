extends RefCounted
## The sole mutable owner of planting state. No scene, clock reading or disk I/O.

const Trellis=preload("res://layout/trellis_slots.gd")
const Crops = preload("res://farm/crop_catalog.gd")
const Plan = preload("res://layout/courtyard_plan.gd")
const Neighbors = preload("res://farm/neighbor_catalog.gd")
const Kitchen = preload("res://farm/kitchen.gd")
const Companions = preload("res://farm/animal_companions.gd")
const Memories = preload("res://farm/garden_memories.gd")
const Seasons = preload("res://farm/season_catalog.gd")
const FIELD_IDS: Array[String] = Plan.FIELD_IDS
# Row-major: columns run along +X and rows along +Z in the presentation layer.
const CELL_IDS: Array[String] = ["cell_01", "cell_02", "cell_03", "cell_04", "cell_05", "cell_06", "cell_07", "cell_08", "cell_09", "cell_10", "cell_11", "cell_12", "cell_13", "cell_14", "cell_15", "cell_16"]
# JSON numbers remain exact only up to this bound.
const MAX_HARVEST_COUNT: int = 9007199254740991

var _data: Dictionary


func _init(now_utc_seconds: float = 0.0, layout: Dictionary = {}) -> void:
	assert(_valid_time(now_utc_seconds), "Farm initialization requires finite nonnegative UTC seconds")
	var plan: RefCounted = Plan.new() if layout.is_empty() else Plan.from_snapshot(layout)
	assert(plan != null, "Farm initialization requires a valid layout")
	_data = {"fields": {}, "harvested": {}, "inventory":{}, "neighbors":Neighbors.initial_state(), "layout":plan.snapshot(), "kitchen":Kitchen.initial_state(),"animals":Companions.initial_state(),"memories":Memories.initial_state(),"season":"daily"}
	Companions.include_flocks(_data.animals,plan.construction.flocks)
	for crop_id: String in Crops.crop_ids():
		_data.harvested[crop_id] = 0
		_data.inventory[crop_id] = 0
	for definition: Dictionary in _planting_areas(plan):
		var field_id: String = definition.id
		_data.fields[field_id] = {"cells": {}}
		for cell_id: String in definition.cells:
			_data.fields[field_id].cells[cell_id] = _empty_cell(now_utc_seconds)
	_set_initial_crop("field_03", "greens", 1.0)
	_set_initial_crop("field_04", "greens", 0.2)
	_set_initial_crop("field_05", "radish", 0.1)
	_set_initial_crop("field_06", "radish", 0.6)
	# A small optional corner, not a recurring chore or a gate on the whole garden.
	for id: String in ["cell_11","cell_12","cell_13","cell_14","cell_15","cell_16"]:
		if _data.fields.has("field_06") and _data.fields.field_06.cells.has(id):
			_data.fields.field_06.cells[id].ground = "rough" if id in ["cell_11","cell_12"] else "weedy"


func snapshot() -> Dictionary:
	return _data.duplicate(true)

func copy() -> RefCounted:
	# This owner's state has already passed admission or gameplay rules. Copy
	# it privately for a transaction; external snapshots still use restore.
	var result: RefCounted=new()
	result._data=_data.duplicate(true)
	return result

func set_season(id: String) -> bool:
	if not Seasons.valid(id): return false
	_data.season = id
	return true

func field_ids() -> Array[String]:
	# Ground-bed consumers use this list; the separate trellis view uses FIELD_ID.
	var result: Array[String] = []
	for field: Dictionary in _data.layout.fields: result.append(field.id)
	return result

func cell_ids(field_id: String) -> Array[String]:
	var result: Array[String] = []
	if field_id==Trellis.FIELD_ID:
		result.assign(_data.fields[field_id].cells.keys());return result
	for field: Dictionary in _data.layout.fields:
		if field.id == field_id: result.assign(field.cells)
	return result

func trellis_retains_crops(plan: RefCounted) -> bool:
	var slots: Dictionary=Trellis.slots(plan)
	for id: String in _data.fields[Trellis.FIELD_ID].cells:
		if not slots.has(id) and not _data.fields[Trellis.FIELD_ID].cells[id].crop_id.is_empty(): return false
	return true

func apply_layout(layout: Dictionary, now_utc_seconds: float) -> Dictionary:
	if not _valid_time(now_utc_seconds): return _result(false,"invalid_time")
	var plan: RefCounted = Plan.from_snapshot(layout)
	if plan == null: return _result(false,"invalid_layout")
	var candidate: Dictionary = _data.duplicate(true)
	var fields: Dictionary = {}
	for definition: Dictionary in _planting_areas(plan):
		var previous: Dictionary = _data.fields.get(definition.id,{}).get("cells",{})
		var cells: Dictionary = {}
		for id: String in definition.cells:
			cells[id] = previous[id].duplicate(true) if previous.has(id) else _empty_cell(now_utc_seconds)
		fields[definition.id] = {"cells":cells}
	# A resize/removal may not erase an occupied cell. No partial change or time
	# advancement on rejection; the editor can ask the player to harvest first.
	for field_id: String in _data.fields:
		for cell_id: String in _data.fields[field_id].cells:
			if not _data.fields[field_id].cells[cell_id].crop_id.is_empty() and not fields.get(field_id,{}).get("cells",{}).has(cell_id):
				return _result(false,"occupied_cell_removed")
	candidate.fields = fields
	candidate.layout = plan.snapshot()
	Companions.include_flocks(candidate.animals,plan.construction.flocks)
	if candidate.layout!=_data.layout: Memories.mark(candidate.memories,"arrange",now_utc_seconds)
	var changed: Array[String] = _settle_data(candidate,now_utc_seconds)
	_data = candidate
	return _result(true,"",changed)


func restore_snapshot(data: Dictionary) -> bool:
	# Disk format/version and recovery remain the storage boundary's responsibility.
	# Check the entire candidate before changing any authoritative field.
	if not _valid_snapshot(data):
		return false
	_data = data.duplicate(true)
	_data.layout = Plan.from_snapshot(data.layout).snapshot()
	for id: String in _data.animals:
		for field: String in ["preference","visits","shared","revision"]: _data.animals[id][field]=int(_data.animals[id][field])
	for crop_id: String in Crops.crop_ids():
		_data.harvested[crop_id] = int(_data.harvested[crop_id])
		_data.inventory[crop_id] = int(_data.inventory[crop_id])
	for id: String in Neighbors.IDS: _data.neighbors[id].round=int(_data.neighbors[id].round)
	_data.kitchen.revision = int(_data.kitchen.revision)
	for recipe: String in Kitchen.RECIPES:
		_data.kitchen.stock[recipe] = int(_data.kitchen.stock[recipe])
		_data.kitchen.records[recipe].made = int(_data.kitchen.records[recipe].made)
		_data.kitchen.records[recipe].shared = int(_data.kitchen.records[recipe].shared)
	for station: String in Kitchen.STATIONS:
		var job: Dictionary = _data.kitchen.jobs[station]
		if not job.is_empty():
			job.start_utc = float(job.start_utc)
			job.finish_utc = float(job.finish_utc)
	return true

func share_basket(neighbor: String, round_index: int, basket: Dictionary) -> Dictionary:
	if neighbor not in Neighbors.IDS: return _result(false,"invalid_neighbor")
	var visit: Dictionary = _data.neighbors[neighbor]
	if visit.round!=round_index or visit.pending: return _result(false,"stale_visit")
	if round_index>=2147483646: return _result(false,"inventory_limit")
	var needed: int = Neighbors.wish(neighbor,round_index).amount
	var amount: int = 0
	for crop: Variant in basket:
		if not crop is String or not Neighbors.accepts(neighbor,round_index,crop): return _result(false,"wrong_crop")
		var count: Variant = basket[crop]
		if not _is_number(count) or count<=0 or count>needed or floorf(count)!=count: return _result(false,"invalid_amount")
		if _data.inventory[crop]<count: return _result(false,"insufficient_food")
		amount+=int(count)
	if amount!=needed: return _result(false,"incomplete_basket")
	for crop: String in basket: _data.inventory[crop]-=int(basket[crop])
	visit.pending=true
	return _result(true,"")

func kitchen_action(action: String, request: Dictionary, revision: int, now: float,decorations: Dictionary={}) -> Dictionary:
	return Kitchen.act(_data.kitchen,_data.inventory,action,request,revision,now,decorations)

func animal_action(id: String,action: String,value: Variant,revision: int) -> Dictionary:
	return Companions.act(_data.animals,_data.inventory,id,action,value,revision)

func remember(id: String, now: float) -> bool:
	return Memories.mark(_data.memories,id,now)

func photo_action(action: String, photo: Dictionary) -> bool:
	return Memories.photo_action(_data.memories,action,photo)

func claim_gift(neighbor: String, round_index: int, crop: String) -> Dictionary:
	if neighbor not in Neighbors.IDS: return _result(false,"invalid_neighbor")
	var visit: Dictionary = _data.neighbors[neighbor]
	if visit.round!=round_index or not visit.pending: return _result(false,"stale_visit")
	if crop not in Neighbors.HOMES[neighbor].gifts: return _result(false,"invalid_gift")
	if _data.inventory[crop]>=MAX_HARVEST_COUNT or round_index>=2147483646: return _result(false,"inventory_limit")
	_data.inventory[crop]+=1
	visit.pending=false
	visit.round+=1
	visit.last_gift=crop
	return _result(true,"")


func get_field(field_id: String) -> Dictionary:
	if not _data.fields.has(field_id):
		return {}
	var field: Dictionary = {"id": field_id, "cells": {}}
	for cell_id: String in cell_ids(field_id):
		field.cells[cell_id] = get_cell(field_id, cell_id)
	return field


func get_cell(field_id: String, cell_id: String) -> Dictionary:
	if not _data.fields.has(field_id) or not _data.fields[field_id].cells.has(cell_id):
		return {}
	var cell: Dictionary = _data.fields[field_id].cells[cell_id].duplicate(true)
	cell["id"] = cell_id
	cell["field_id"] = field_id
	cell["progress"] = 0.0
	cell["remaining_seconds"] = 0.0
	cell["stage"] = "empty"
	if not cell.crop_id.is_empty():
		var duration: float = Crops.definition(cell.crop_id).duration_seconds
		cell.progress = cell.growth_seconds / duration
		cell.remaining_seconds = duration - cell.growth_seconds
		cell.stage = "mature" if cell.progress >= 1.0 else ("young" if cell.progress >= Crops.YOUNG_PROGRESS else "sprout")
	return cell


func settle(now_utc_seconds: float) -> Dictionary:
	if not _valid_time(now_utc_seconds):
		return _result(false, "invalid_time")
	var changed: Array[String] = _settle_data(_data, now_utc_seconds)
	return _result(true, "", changed)


func sow(field_id: String, cell_id: String, crop_id: String, now_utc_seconds: float) -> Dictionary:
	if Crops.definition(crop_id).is_empty():
		return _result(false, "invalid_crop")
	return _act("sow", field_id, cell_id, crop_id, now_utc_seconds)


func mature_all_crops(now_utc_seconds: float) -> Dictionary:
	if not _valid_time(now_utc_seconds): return _result(false, "invalid_time")
	var changed: Array[String] = _settle_data(_data, now_utc_seconds)
	for field_id: String in _data.fields:
		for cell: Dictionary in _data.fields[field_id].cells.values():
			if cell.crop_id.is_empty(): continue
			cell.growth_seconds = Crops.definition(cell.crop_id).duration_seconds
			if not changed.has(field_id): changed.append(field_id)
	return _result(true, "", changed)


func water(field_id: String, cell_id: String, now_utc_seconds: float) -> Dictionary:
	return _act("water", field_id, cell_id, "", now_utc_seconds)


func harvest(field_id: String, cell_id: String, now_utc_seconds: float) -> Dictionary:
	return _act("harvest", field_id, cell_id, "", now_utc_seconds)


func tidy(action: String, field_id: String, cell_id: String, now: float) -> Dictionary:
	if action not in ["weed","till"]: return _result(false,"invalid_tool")
	return _act(action,field_id,cell_id,"",now)


func _act(action: String, field_id: String, cell_id: String, crop_id: String, now_utc_seconds: float) -> Dictionary:
	if not _valid_time(now_utc_seconds):
		return _result(false, "invalid_time")
	if not _data.fields.has(field_id):
		return _result(false, "invalid_field")
	if not _data.fields[field_id].cells.has(cell_id):
		return _result(false, "invalid_cell")
	# Failed actions are atomic no-ops, including time. Periodic settle() is independent.
	var candidate: Dictionary = _data.duplicate(true)
	var changed: Array[String] = _settle_data(candidate, now_utc_seconds)
	var field: Dictionary = candidate.fields[field_id].cells[cell_id]
	var reward_crop: String = ""
	if action in ["weed","till"]:
		if not field.crop_id.is_empty(): return _result(false,"occupied")
		if field.ground != ("weedy" if action=="weed" else "rough"):
			return _result(false,"wrong_ground")
		field.ground = "rough" if action=="weed" else "ready"
	elif action == "sow":
		if not Crops.supports(crop_id,field_id==Trellis.FIELD_ID): return _result(false,"wrong_support")
		if field.ground != "ready": return _result(false,"unprepared")
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
			field.growth_seconds = minf(duration, field.growth_seconds + duration * Crops.definition(field.crop_id).water_progress)
			field.watered = true
		else:
			if field.growth_seconds < duration:
				return _result(false, "not_mature")
			reward_crop = field.crop_id
			if candidate.harvested[reward_crop] >= MAX_HARVEST_COUNT or candidate.inventory[reward_crop]>=MAX_HARVEST_COUNT:
				return _result(false, "harvest_limit")
			candidate.harvested[reward_crop] += 1
			candidate.inventory[reward_crop] += 1
			candidate.fields[field_id].cells[cell_id] = _empty_cell(field.last_settled_utc_seconds)
	if not changed.has(field_id):
		changed.append(field_id)
	_data = candidate
	return _result(true, "", changed, reward_crop)


func _settle_data(data: Dictionary, now_utc_seconds: float) -> Array[String]:
	var changed: Array[String] = []
	for field_id: String in data.fields:
		for cell_id: String in data.fields[field_id].cells:
			var cell: Dictionary = data.fields[field_id].cells[cell_id]
			if now_utc_seconds <= cell.last_settled_utc_seconds:
				continue
			var elapsed: float = now_utc_seconds - cell.last_settled_utc_seconds
			if not cell.crop_id.is_empty():
				var duration: float = Crops.definition(cell.crop_id).duration_seconds
				cell.growth_seconds = minf(duration, cell.growth_seconds + elapsed)
			# Empty and mature cells also keep their latest rollback-safe baseline.
			cell.last_settled_utc_seconds = now_utc_seconds
			if not changed.has(field_id):
				changed.append(field_id)
	return changed


func _set_initial_crop(field_id: String, crop_id: String, progress: float) -> void:
	if not _data.fields.has(field_id) or not _data.fields[field_id].cells.has("cell_06"): return
	_data.fields[field_id].cells.cell_06.crop_id = crop_id
	_data.fields[field_id].cells.cell_06.growth_seconds = Crops.definition(crop_id).duration_seconds * progress


static func _empty_cell(now_utc_seconds: float) -> Dictionary:
	return {"crop_id": "", "growth_seconds": 0.0, "last_settled_utc_seconds": now_utc_seconds, "watered": false, "ground":"ready"}


static func _result(ok: bool, reason: String, changed: Array[String] = [], reward_crop: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason, "changed_fields": changed, "reward_crop_id": reward_crop, "reward_amount": 0 if reward_crop.is_empty() else 1}


static func _valid_time(value: float) -> bool:
	return is_finite(value) and value >= 0.0


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _valid_snapshot(data: Dictionary) -> bool:
	if data.size() != 9 or not Seasons.valid(data.get("season")) or not data.get("fields") is Dictionary or not data.get("harvested") is Dictionary or not data.get("layout") is Dictionary:
		return false
	if not data.get("memories") is Dictionary or not Memories.valid(data.memories): return false
	if not data.get("animals") is Dictionary or not Companions.valid(data.animals): return false
	if not data.get("kitchen") is Dictionary or not Kitchen.valid(data.kitchen): return false
	if not data.get("inventory") is Dictionary or not data.get("neighbors") is Dictionary: return false
	if data.inventory.size()!=Crops.crop_ids().size() or not Neighbors.valid(data.neighbors): return false
	var plan: RefCounted = Plan.from_snapshot(data.layout)
	if plan == null: return false
	for kind: String in Companions.Flocks.KINDS:
		for i: int in int(plan.construction.flocks[kind].count):
			if not data.animals.has(Companions.Flocks.id(kind,i)): return false
	var fields: Dictionary = data.fields
	var harvested: Dictionary = data.harvested
	if fields.size() != plan.fields.size()+1 or harvested.size() != Crops.crop_ids().size():
		return false
	for crop_id: String in Crops.crop_ids():
		var stock: Variant = data.inventory.get(crop_id)
		if not _is_number(stock) or stock<0 or stock>MAX_HARVEST_COUNT or floorf(stock)!=stock: return false
		var count: Variant = harvested.get(crop_id)
		if not _is_number(count) or float(count) < 0.0 or float(count) > MAX_HARVEST_COUNT or float(count) != floorf(float(count)):
			return false
	for definition: Dictionary in _planting_areas(plan):
		var field_id: String = definition.id
		if not fields.get(field_id) is Dictionary:
			return false
		var field: Dictionary = fields[field_id]
		if field.size() != 1 or not field.get("cells") is Dictionary or field.cells.size() != definition.cells.size():
			return false
		for cell_id: String in definition.cells:
			if not field.cells.get(cell_id) is Dictionary or not valid_cell_snapshot(field.cells[cell_id]):
				return false
			var cell: Dictionary=field.cells[cell_id]
			if field_id==Trellis.FIELD_ID and cell.ground!="ready": return false
			if not cell.crop_id.is_empty() and not Crops.supports(cell.crop_id,field_id==Trellis.FIELD_ID): return false
	return true


static func valid_cell_snapshot(field: Dictionary) -> bool:
	if field.size() != 5 or not field.get("crop_id") is String or not field.get("watered") is bool:
		return false
	if field.get("ground") not in ["ready","rough","weedy"]: return false
	if field.ground!="ready" and not field.crop_id.is_empty(): return false
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
		if field.watered and float(growth) < crop.duration_seconds * crop.water_progress:
			return false
	return true

static func _planting_areas(plan: RefCounted) -> Array:
	var result: Array=plan.fields.duplicate()
	result.append(Trellis.definition(plan))
	return result
