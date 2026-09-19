extends RefCounted
## Player-facing construction choices; unlocks remain in DecorationState.
const Decorations = preload("res://farm/decoration_catalog.gd")
const CATEGORIES: Dictionary = {
	"land": "土地", "buildings": "建筑", "routes": "道路桥梁", "growing": "种植设施",
	"plants": "植物", "lights": "灯具", "objects": "摆件", "animals": "动物",
}
const ITEMS: Dictionary = {
	"land": {"name":"添地", "category":"land", "editor":"layout", "placement":"brush", "capabilities":["terrain"], "icon":"res://art/ui/actions/arrange.svg"},
	"house": {"name":"民居", "category":"buildings", "editor":"layout", "placement":"free", "capabilities":["entrance","attachments"], "icon":"res://art/ui/construction/house.png"},
	"kitchen": {"name":"厨房", "category":"buildings", "editor":"layout", "placement":"free", "capabilities":["entrance","attachments","production"], "icon":"res://art/ui/construction/kitchen.png"},
	"road": {"name":"石板路", "category":"routes", "editor":"", "placement":"line", "capabilities":["passage"], "icon":"res://art/ui/construction/road.png"},
	"fence": {"name":"竹篱", "category":"routes", "editor":"", "placement":"line", "capabilities":["obstacle"], "icon":"res://art/ui/construction/fence.png"},
	"bridge": {"name":"桥梁", "category":"routes", "editor":"layout", "placement":"endpoints", "capabilities":["passage","parametric"], "icon":"res://art/ui/construction/bridge.png"},
	"fields": {"name":"田块", "category":"growing", "editor":"layout", "placement":"grid", "capabilities":["planting","parametric"], "icon":"res://art/ui/crops/till.png"},
	"trellis": {"name":"菜架", "category":"growing", "editor":"layout", "placement":"free", "capabilities":["parametric","attachments"], "icon":"res://art/ui/construction/trellis.png"},
	"lotus": {"name":"荷花", "category":"plants", "editor":"layout", "placement":"water", "capabilities":["decoration"], "icon":"res://art/ui/construction/lotus.png"},
	"reed": {"name":"芦苇", "category":"plants", "editor":"layout", "placement":"shore", "capabilities":["decoration"], "icon":"res://art/ui/construction/reed.png"},
	"cattail": {"name":"香蒲", "category":"plants", "editor":"layout", "placement":"shore", "capabilities":["decoration"], "icon":"res://art/ui/construction/cattail.png"},
	"trapa": {"name":"菱叶", "category":"plants", "editor":"layout", "placement":"water", "capabilities":["decoration"], "icon":"res://art/ui/construction/trapa.png"},
	"hen": {"name":"鸡群", "category":"animals", "editor":"", "placement":"region", "capabilities":["animal"], "icon":"res://art/ui/animals/hen.png"},
	"ducks": {"name":"鸭群", "category":"animals", "editor":"layout", "placement":"region", "capabilities":["animal"], "icon":"res://art/ui/animals/duck.png"},
	"goose": {"name":"鹅群", "category":"animals", "editor":"", "placement":"region", "capabilities":["animal"], "icon":"res://art/ui/animals/goose.png"},
}
const DECORATION_CAPABILITIES: Dictionary = {
	"pot":["decoration","production"], "flowerpot":["decoration"], "lantern":["decoration","light"],
	"bench":["decoration"], "drying_rack":["decoration","production"], "tea_table":["decoration"],
}

static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(ITEMS.keys())
	result.append_array(Decorations.IDS)
	return result

static func item(id: String) -> Dictionary:
	if ITEMS.has(id): return ITEMS[id].duplicate(true)
	if not Decorations.ITEMS.has(id): return {}
	var source: Dictionary = Decorations.ITEMS[id]
	var abilities: Array = DECORATION_CAPABILITIES[id]
	return {"name":source.name, "category":"lights" if abilities.has("light") else "objects",
		"editor":"decoration", "placement":"attachment" if source.type=="hanging" else "free",
		"capabilities":abilities.duplicate(), "icon":"res://art/ui/decorations/%s.png"%id}

static func has_capability(id: String, capability: String) -> bool:
	return item(id).get("capabilities",[]).has(capability)

static func in_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in ids():
		if item(id).category==category: result.append(id)
	return result
