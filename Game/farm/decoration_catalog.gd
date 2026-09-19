extends RefCounted
## Stable decoration and slot identities; spatial transforms belong to the courtyard.
const Crops=preload("res://farm/crop_catalog.gd")

const IDS: Array[String] = ["pot", "flowerpot", "lantern", "bench", "drying_rack", "tea_table"]
const ITEMS: Dictionary = {
	"pot": {"name": "粗陶罐", "type": "ground", "total": 3, "varieties": 1},
	"flowerpot": {"name": "花盆", "type": "ground", "total": 8, "varieties": 2},
	"lantern": {"name": "灯笼", "type": "hanging", "total": 16, "varieties": 3},
	"bench": {"name": "竹长凳", "type": "ground", "total": 0, "varieties": 0},
	"drying_rack": {"name": "小晒架", "type": "ground", "total": 0, "varieties": 0, "shared_meals":1},
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
	if item.has("shared_meals"): return "菜篮 → 厨房：分享1份做好的菜"
	return "累计收获 %d 篮 · %d 种菜" % [item.total,item.varieties]

static func progress(item_id: String,harvested: Dictionary,kitchen: Dictionary) -> String:
	var rule: Dictionary=ITEMS[item_id]
	if rule.has("shared_meals"):
		var shared: int=0
		for record: Dictionary in kitchen.records.values(): shared+=int(record.shared)
		return "分享成品 %d/%d 份"%[mini(shared,rule.shared_meals),rule.shared_meals]
	return "累计收获 %d/%d 篮 · %d/%d 种菜"%[mini(Crops.total_harvested(harvested),rule.total),rule.total,mini(Crops.varieties(harvested),rule.varieties),rule.varieties]

static func earned(item_id: String,harvested: Dictionary,kitchen: Dictionary={}) -> bool:
	var rule: Dictionary=ITEMS[item_id]
	var shared: int=0
	for record: Dictionary in kitchen.get("records",{}).values(): shared+=int(record.shared)
	return Crops.total_harvested(harvested)>=rule.total and Crops.varieties(harvested)>=rule.varieties and shared>=rule.get("shared_meals",0)
