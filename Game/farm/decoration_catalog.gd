extends RefCounted
## Stable decoration and slot identities; spatial transforms belong to the courtyard.

const IDS: Array[String] = ["pot", "flowerpot", "lantern"]
const ITEMS: Dictionary = {
	"pot": {"name": "粗陶罐", "type": "ground", "total": 3, "greens": 0, "radish": 0},
	"flowerpot": {"name": "花盆", "type": "ground", "total": 0, "greens": 5, "radish": 3},
	"lantern": {"name": "灯笼", "type": "hanging", "total": 0, "greens": 10, "radish": 6},
}
const SLOT_TYPES: Dictionary = {
	"ground_01": "ground", "ground_02": "ground", "ground_03": "ground", "ground_04": "ground",
	"hanging_01": "hanging", "hanging_02": "hanging", "hanging_03": "hanging", "hanging_04": "hanging",
}


static func allowed_turns(slot_id: String) -> Array[int]:
	if SLOT_TYPES.get(slot_id) == "ground":
		return [0, 1, 2, 3]
	if SLOT_TYPES.get(slot_id) == "hanging":
		return [0]
	return []


static func requirement(item_id: String) -> String:
	var item: Dictionary = ITEMS[item_id]
	return "累计收获 %d 篮" % item.total if item.total > 0 else "青菜 %d 篮 · 白萝卜 %d 篮" % [item.greens, item.radish]
