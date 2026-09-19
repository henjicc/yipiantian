extends RefCounted
## Durable identity and voluntary interaction; no hunger or time-based loss.
const IDS: Array[String]=["LakeDuck1","LakeDuck2","LakeDuck3","LakeGoose1","LakeGoose2","YardHen1","YardHen2"]
const NAMES: Array[String]=["小满","点点","团团","白露","云朵","栗子","阿黄"]
const FOOD: Array[String]=["greens","lettuce","spinach","tatsoi"]
const LIMIT: int=2147483646
static func kind(id: String) -> String:
	return "hen" if id.begins_with("YardHen") else ("goose" if id.begins_with("LakeGoose") else "duck")
static func preferences(id: String) -> Array[String]:
	return ["随它喜欢","屋西","屋东","院前","田边"] if kind(id)=="hen" else ["随它喜欢","西岸","荷湾","前湖","渡口"]
static func initial_state() -> Dictionary:
	var result: Dictionary={}
	for i: int in IDS.size(): result[IDS[i]]={"name":NAMES[i],"preference":-1,"visits":0,"shared":0,"revision":0}
	return result

static func include_ducks(data: Dictionary, count: int) -> void:
	for i: int in count:
		var id: String="LakeDuck%d"%(i+1)
		if not data.has(id): data[id]={"name":"小鸭%d"%(i+1),"preference":-1,"visits":0,"shared":0,"revision":0}
static func valid_name(value: Variant) -> bool:
	if not value is String or value.length()<1 or value.length()>12 or value!=value.strip_edges(): return false
	for i: int in value.length():
		if value.unicode_at(i)<32 or value.unicode_at(i)==127: return false
	return true
static func valid(data: Dictionary) -> bool:
	if data.size()<IDS.size() or data.size()>16: return false
	for id: String in IDS:
		if not data.has(id): return false
	for id: String in data:
		if id not in IDS:
			var suffix: String=id.trim_prefix("LakeDuck")
			if not suffix.is_valid_int() or int(suffix)<4 or int(suffix)>12 or id!="LakeDuck%d"%int(suffix): return false
		var entry: Variant=data.get(id)
		if not entry is Dictionary or entry.size()!=5 or not valid_name(entry.get("name")): return false
		for field: String in ["preference","visits","shared","revision"]:
			var number: Variant=entry.get(field)
			if not (number is int or number is float) or not is_finite(number) or floorf(number)!=number: return false
			if number<(-1 if field=="preference" else 0) or number>(3 if field=="preference" else LIMIT): return false
		if entry.shared>entry.visits or entry.visits>entry.revision: return false
	return true
static func act(data: Dictionary,inventory: Dictionary,id: String,action: String,value: Variant,revision: int) -> Dictionary:
	if not data.has(id): return {"ok":false,"reason":"invalid_animal"}
	var entry: Dictionary=data[id]
	if entry.revision!=revision: return {"ok":false,"reason":"stale_action"}
	if entry.revision>=LIMIT: return {"ok":false,"reason":"limit"}
	match action:
		"name":
			if not valid_name(value): return {"ok":false,"reason":"invalid_name"}
			entry.name=value
		"preference":
			if not value is int or value < -1 or value > 3: return {"ok":false,"reason":"invalid_preference"}
			entry.preference=value
		"feed":
			if value not in FOOD or inventory.get(value,0)<1: return {"ok":false,"reason":"insufficient_food"}
			if entry.shared>=LIMIT or entry.visits>=LIMIT: return {"ok":false,"reason":"limit"}
			inventory[value]-=1
			entry.shared+=1
			entry.visits+=1
		"call":
			if entry.visits>=LIMIT: return {"ok":false,"reason":"limit"}
			entry.visits+=1
		_: return {"ok":false,"reason":"invalid_action"}
	entry.revision+=1
	return {"ok":true,"reason":""}
