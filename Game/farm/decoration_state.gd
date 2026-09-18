extends RefCounted
## Owns unlocks and confirmed placements. Previews never enter persistent state.

const Catalog = preload("res://farm/decoration_catalog.gd")
const Crops = preload("res://farm/crop_catalog.gd")
var _items: Dictionary = {}


func _init() -> void:
	for item_id: String in Catalog.IDS:
		_items[item_id] = {"unlocked": false, "slot_id": "", "quarter_turn": 0}


func snapshot() -> Dictionary:
	return _items.duplicate(true)


func restore_snapshot(data: Dictionary) -> bool:
	if data.size() != Catalog.IDS.size():
		return false
	var occupied: Array[String] = []
	for item_id: String in Catalog.IDS:
		if not data.get(item_id) is Dictionary:
			return false
		var item: Dictionary = data[item_id]
		if item.size() != 3 or not item.get("unlocked") is bool or not item.get("slot_id") is String:
			return false
		var turn: Variant = item.get("quarter_turn")
		if not (turn is int or turn is float) or not is_finite(float(turn)) or float(turn) != floorf(float(turn)):
			return false
		if item.slot_id.is_empty():
			if turn != 0:
				return false
		elif not item.unlocked or Catalog.SLOT_TYPES.get(item.slot_id) != Catalog.ITEMS[item_id].type or not Catalog.allowed_turns(item.slot_id).has(int(turn)) or occupied.has(item.slot_id):
			return false
		else:
			occupied.append(item.slot_id)
	_items = data.duplicate(true)
	for item_id: String in Catalog.IDS:
		_items[item_id].quarter_turn = int(_items[item_id].quarter_turn)
	return true


func unlock(harvested: Dictionary) -> Array[String]:
	var unlocked: Array[String] = []
	for item_id: String in Catalog.IDS:
		var rule: Dictionary = Catalog.ITEMS[item_id]
		if not _items[item_id].unlocked and Crops.total_harvested(harvested)>=rule.total and Crops.varieties(harvested)>=rule.varieties:
			_items[item_id].unlocked = true
			unlocked.append(item_id)
	return unlocked


func can_place(item_id: String, slot_id: String, quarter_turn: int) -> Dictionary:
	if not _items.has(item_id) or not Catalog.SLOT_TYPES.has(slot_id):
		return {"ok": false, "reason": "invalid_target"}
	if not _items[item_id].unlocked:
		return {"ok": false, "reason": "locked"}
	if Catalog.ITEMS[item_id].type != Catalog.SLOT_TYPES[slot_id]:
		return {"ok": false, "reason": "wrong_type"}
	if not Catalog.allowed_turns(slot_id).has(quarter_turn):
		return {"ok": false, "reason": "invalid_rotation"}
	for other_id: String in Catalog.IDS:
		if other_id != item_id and _items[other_id].slot_id == slot_id:
			return {"ok": false, "reason": "occupied"}
	return {"ok": true, "reason": ""}


func place(item_id: String, slot_id: String, quarter_turn: int) -> Dictionary:
	var result: Dictionary = can_place(item_id, slot_id, quarter_turn)
	if result.ok:
		_items[item_id].slot_id = slot_id
		_items[item_id].quarter_turn = quarter_turn
	return result
