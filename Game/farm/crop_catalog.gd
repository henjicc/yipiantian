extends RefCounted
## September Jiangnan choices; durations and water benefits are game tuning.

const YOUNG_PROGRESS: float = 0.35
const GROUPS := {"leaf":"叶菜", "root":"根菜", "aromatic":"香辛菜", "stem":"茎菜"}
const CROP_GROUPS := {
	"greens":"leaf", "radish":"root", "spinach":"leaf", "lettuce":"leaf",
	"chrysanthemum":"leaf", "coriander":"aromatic", "celery":"stem", "mustard":"leaf",
	"tatsoi":"leaf", "carrot":"root", "scallion":"aromatic", "garlic":"aromatic",
}
const CROPS := {
	"greens": {"name": "青菜", "minutes": 30, "water": .20},
	"radish": {"name": "白萝卜", "minutes": 90, "water": .20},
	"spinach": {"name": "菠菜", "minutes": 45, "water": .24},
	"lettuce": {"name": "生菜", "minutes": 40, "water": .25},
	"chrysanthemum": {"name": "茼蒿", "minutes": 35, "water": .22},
	"coriander": {"name": "香菜", "minutes": 50, "water": .16},
	"celery": {"name": "芹菜", "minutes": 100, "water": .30},
	"mustard": {"name": "雪里蕻", "minutes": 65, "water": .22},
	"tatsoi": {"name": "乌塌菜", "minutes": 60, "water": .24},
	"carrot": {"name": "胡萝卜", "minutes": 120, "water": .15},
	"scallion": {"name": "小葱", "minutes": 55, "water": .12},
	"garlic": {"name": "青蒜", "minutes": 70, "water": .12},
}


static func crop_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(CROPS.keys())
	return result


static func definition(crop_id: String) -> Dictionary:
	if not CROPS.has(crop_id):
		return {}
	var crop: Dictionary = CROPS[crop_id]
	return {"id": crop_id, "name": crop.name, "duration_seconds": crop.minutes * 60.0, "water_progress": crop.water,
		"group":CROP_GROUPS[crop_id]}

static func varieties(harvested: Dictionary) -> int:
	var count: int = 0
	for id: String in crop_ids():
		if harvested.get(id,0)>0: count+=1
	return count


static func icon_path(crop_id: String) -> String:
	return "res://art/ui/crops/%s.png" % crop_id if CROPS.has(crop_id) else ""


static func total_harvested(harvested: Dictionary) -> int:
	var total: int = 0
	for count: int in harvested.values():
		total += count
	return total
