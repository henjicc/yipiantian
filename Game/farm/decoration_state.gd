extends RefCounted
## Owns unlocks and confirmed placements. Previews never enter persistent state.

const Catalog = preload("res://farm/decoration_catalog.gd")
const Crops = preload("res://farm/crop_catalog.gd")
var _items: Dictionary = {}


func _init() -> void:
	for item_id: String in Catalog.IDS:
		_items[item_id] = {"unlocked": Catalog.ITEMS[item_id].total==0, "slot_id": "", "quarter_turn": 0, "position": []}


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
		if item.size() != 4 or not item.get("unlocked") is bool or not item.get("slot_id") is String or not item.get("position") is Array:
			return false
		var turn: Variant = item.get("quarter_turn")
		if not (turn is int or turn is float) or not is_finite(float(turn)) or float(turn) != floorf(float(turn)):
			return false
		if not item.position.is_empty():
			if not item.unlocked or not item.slot_id.is_empty() or Catalog.ITEMS[item_id].type != "ground" or item.position.size()!=2 or int(turn) not in [0,1,2,3]: return false
			for coordinate: Variant in item.position:
				if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(float(coordinate))>30: return false
		elif item.slot_id.is_empty():
			if turn != 0:
				return false
		elif not item.unlocked or Catalog.SLOT_TYPES.get(item.slot_id) != Catalog.ITEMS[item_id].type or not Catalog.allowed_turns(item.slot_id).has(int(turn)) or occupied.has(item.slot_id):
			return false
		else:
			occupied.append(item.slot_id)
	_items = data.duplicate(true)
	for item_id: String in Catalog.IDS:
		_items[item_id].quarter_turn = int(_items[item_id].quarter_turn)
		if not _items[item_id].position.is_empty():
			_items[item_id].position=[float("%.4f" % _items[item_id].position[0]),float("%.4f" % _items[item_id].position[1])]
	return true


func unlock(harvested: Dictionary) -> Array[String]:
	var unlocked: Array[String] = []
	for item_id: String in Catalog.IDS:
		var rule: Dictionary = Catalog.ITEMS[item_id]
		if not _items[item_id].unlocked and Crops.total_harvested(harvested)>=rule.total and Crops.varieties(harvested)>=rule.varieties:
			_items[item_id].unlocked = true
			unlocked.append(item_id)
	return unlocked


func can_place(item_id: String, slot_id: String, quarter_turn: int, replace_occupied: bool=false) -> Dictionary:
	if not _items.has(item_id) or not Catalog.SLOT_TYPES.has(slot_id):
		return {"ok": false, "reason": "invalid_target"}
	if not _items[item_id].unlocked:
		return {"ok": false, "reason": "locked"}
	if Catalog.ITEMS[item_id].type != Catalog.SLOT_TYPES[slot_id]:
		return {"ok": false, "reason": "wrong_type"}
	if not Catalog.allowed_turns(slot_id).has(quarter_turn):
		return {"ok": false, "reason": "invalid_rotation"}
	for other_id: String in Catalog.IDS:
		if not replace_occupied and other_id != item_id and _items[other_id].slot_id == slot_id:
			return {"ok": false, "reason": "occupied"}
	return {"ok": true, "reason": ""}


func place(item_id: String, slot_id: String, quarter_turn: int, replace_occupied: bool=false) -> Dictionary:
	var result: Dictionary = can_place(item_id, slot_id, quarter_turn,replace_occupied)
	if result.ok:
		for other_id: String in Catalog.IDS:
			if other_id!=item_id and _items[other_id].slot_id==slot_id: remove(other_id)
		_items[item_id].slot_id = slot_id
		_items[item_id].quarter_turn = quarter_turn
		_items[item_id].position = []
	return result

static func is_placed(item: Dictionary) -> bool:
	return not item.get("slot_id", "").is_empty() or not item.get("position", []).is_empty()

func place_at(item_id: String, point: Vector2, quarter_turn: int) -> Dictionary:
	if not _items.has(item_id) or Catalog.ITEMS[item_id].type!="ground" or not point.is_finite() or absf(point.x)>30 or absf(point.y)>30 or quarter_turn not in [0,1,2,3]:
		return {"ok":false,"reason":"invalid_target"}
	if not _items[item_id].unlocked: return {"ok":false,"reason":"locked"}
	_items[item_id].slot_id=""
	# A tenth of a millimetre is below visible placement precision and has a
	# stable JSON representation, unlike float32 ray coordinates converted to double.
	_items[item_id].position=[float("%.4f" % point.x),float("%.4f" % point.y)]
	_items[item_id].quarter_turn=quarter_turn
	return {"ok":true,"reason":""}

func remove(item_id: String) -> Dictionary:
	if not _items.has(item_id) or not is_placed(_items[item_id]): return {"ok":false,"reason":"not_placed"}
	_items[item_id].slot_id=""
	_items[item_id].quarter_turn=0
	_items[item_id].position=[]
	return {"ok":true,"reason":""}
