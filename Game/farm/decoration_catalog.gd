extends RefCounted
## Stable decoration and slot identities; spatial transforms belong to the courtyard.

const IDS: Array[String] = ["pot", "flowerpot", "lantern", "bench", "drying_rack", "tea_table"]
const ITEMS: Dictionary = {
	"pot": {"name": "粗陶罐", "type": "ground", "total": 3, "varieties": 1},
	"flowerpot": {"name": "花盆", "type": "ground", "total": 8, "varieties": 2},
	"lantern": {"name": "灯笼", "type": "hanging", "total": 16, "varieties": 3},
	"bench": {"name": "竹长凳", "type": "ground", "total": 0, "varieties": 0},
	"drying_rack": {"name": "小晒架", "type": "ground", "total": 0, "varieties": 0},
	"tea_table": {"name": "茶桌", "type": "ground", "total": 0, "varieties": 0},
}
const SLOT_TYPES: Dictionary = {
	"ground_01": "ground", "ground_02": "ground", "ground_03": "ground", "ground_04": "ground",
	"hanging_01": "hanging", "hanging_02": "hanging", "hanging_03": "hanging", "hanging_04": "hanging",
}


static func allowed_turns(slot_id: String) -> Array[int]:
	if SLOT_TYPES.get(slot_id) == "ground":
		return [0, 1, 2, 3]
	if SLOT_TYPES.get(slot_id) == "hanging":
		return [0, 1, 2, 3]
	return []


static func requirement(item_id: String) -> String:
	var item: Dictionary = ITEMS[item_id]
	return "累计收获 %d 篮 · %d 种菜" % [item.total,item.varieties]
