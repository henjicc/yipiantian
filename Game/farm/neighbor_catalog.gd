extends RefCounted
## Persistent identities and non-expiring, repeatable neighbour wishes.
const Crops = preload("res://farm/crop_catalog.gd")
const IDS: Array[String] = ["willow", "bamboo", "ferry"]
const HOMES := {
	"willow": {"name":"柳岸 · 林婶", "wishes":[
		["一碗新绿","今早洗好了锅，想炒一碗新鲜叶菜。你田里有什么，就带什么来吧。","leaf",1],
		["秋汤","灶上煨着水，添些根菜，汤就甜了。","root",1],
		["留一缕香","想给晚饭添些香气，葱、蒜、香菜都好。","aromatic",1]],
		"gifts":["radish","mustard"], "thanks":"菜篮收到了。我也留了些自家收成，挑一篮带回去吧。"},
	"bamboo": {"name":"竹汀 · 许伯", "wishes":[
		["竹下小菜","竹椅修好了，想坐在院里吃顿便饭。带一篮你爱种的菜来就好。","any",1],
		["一碟脆香","今日想炒一碟脆生生的芹菜。","stem",1],
		["两碗青绿","隔壁要来坐坐，凑两篮叶菜，品种混着也好。","leaf",2]],
		"gifts":["celery","carrot"], "thanks":"正合适，饭桌又添一道菜。这两样是我刚收的，带走你喜欢的。"},
	"ferry": {"name":"渡口 · 阿舟", "wishes":[
		["归舟晚饭","船拴好了，想煮一锅暖汤。带一篮根菜来吧。","root",1],
		["灶边香气","屋里有饭香，还缺一点葱蒜香。香菜也行。","aromatic",1],
		["湖边小聚","傍晚在湖边摆两碟小菜，带两篮任意蔬菜就够。","any",2]],
		"gifts":["scallion","tatsoi"], "thanks":"谢谢你送来的菜。船上还带回两样收成，选一篮，回家慢慢吃。"},
}

static func wish(id: String, round_index: int) -> Dictionary:
	var entry: Array = HOMES[id].wishes[round_index%HOMES[id].wishes.size()]
	return {"title":entry[0],"letter":entry[1],"group":entry[2],"amount":entry[3]}

static func accepts(id: String, round_index: int, crop: String) -> bool:
	var definition: Dictionary = Crops.definition(crop)
	if definition.is_empty(): return false
	var group: String = wish(id,round_index).group
	return group=="any" or definition.group==group

static func initial_state() -> Dictionary:
	var result: Dictionary = {}
	for id: String in IDS: result[id]={"round":0,"pending":false,"last_gift":""}
	return result

static func valid(data: Dictionary) -> bool:
	if data.size()!=IDS.size(): return false
	for id: String in IDS:
		if not data.get(id) is Dictionary: return false
		var entry: Dictionary = data[id]
		if entry.size()!=3 or not entry.get("pending") is bool or not entry.get("last_gift") is String: return false
		var index: Variant = entry.get("round")
		if not (index is int or index is float) or not is_finite(float(index)) or index<0 or index>2147483646 or floorf(index)!=index: return false
		if index==0 and not entry.last_gift.is_empty(): return false
		if index>0 and entry.last_gift not in HOMES[id].gifts: return false
	return true
