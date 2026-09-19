extends RefCounted
## Recipes and kitchen transactions. UTC completion never depends on animations.
const Crops=preload("res://farm/crop_catalog.gd")
const Neighbors=preload("res://farm/neighbor_catalog.gd")
const Decorations=preload("res://farm/decoration_state.gd")
const LIMIT: int=2147483646
const STATIONS: Array[String]=["stove","jar","rack","garden_rack"]
const STATION_NAMES := {"stove":"灶上","jar":"陶罐","rack":"廊下晒架","garden_rack":"小晒架"}
const RECIPES := {
	"leaf_stir":{"name":"清炒时蔬","groups":["leaf"],"station":"stove","seconds":20,"asset":"stir_fry","method":"择洗 → 切段 → 清炒","entry":"菜刚离田，洗去泥土，热锅轻炒。叶子软下来，仍留一点脆。"},
	"stem_stir":{"name":"清炒芹菜","groups":["stem"],"station":"stove","seconds":25,"asset":"stir_fry","method":"择洗 → 切段 → 清炒","entry":"芹菜切成小段，沿锅边翻几回。把清脆和香气一起盛出来。"},
	"root_soup":{"name":"家常菜根汤","groups":["root"],"station":"stove","seconds":35,"asset":"root_soup","method":"洗净 → 切块 → 煨汤","entry":"根菜慢慢煨软，汤里有了甜味。临窗坐一会儿，一碗热汤就很合适。"},
	"herb_relish":{"name":"香蔬小菜","groups":["aromatic"],"station":"jar","seconds":45,"asset":"pickled_greens","method":"洗净 → 切碎 → 拌腌","entry":"葱蒜或香菜切碎，拌成一小罐。打开盖子，先闻到的是自家田里的香气。"},
	"leaf_pickle":{"name":"家常腌菜","groups":["leaf"],"station":"jar","seconds":60,"asset":"pickled_greens","method":"择洗 → 揉盐 → 入罐","entry":"青绿的叶子揉软，收进陶罐里。风味慢慢沉下来，留作下一顿的小菜。"},
	"root_dry":{"name":"秋晒菜干","groups":["root"],"station":"rack","seconds":90,"asset":"slices","method":"洗净 → 切片 → 摊晒","entry":"菜片在竹匾里摊开，留些空隙给风。收起时轻了些，秋天的味道却留下来了。"},
}

static func initial_state() -> Dictionary:
	var state: Dictionary={"revision":0,"jobs":{},"stock":{},"records":{},"display":""}
	for station: String in STATIONS: state.jobs[station]={}
	for recipe: String in RECIPES:
		state.stock[recipe]=0
		state.records[recipe]={"made":0,"shared":0,"last_crop":"","last_to":""}
	return state

static func accepts(recipe: String, crop: String) -> bool:
	return RECIPES.has(recipe) and Crops.CROP_GROUPS.get(crop,"") in RECIPES[recipe].groups

static func ready(job: Dictionary, now: float) -> bool:
	return not job.is_empty() and now>=job.finish_utc

static func extra_rack_placed(decorations: Dictionary) -> bool:
	var item: Dictionary=decorations.get("drying_rack",{})
	return item.get("unlocked",false) and Decorations.is_placed(item)

static func supports(station: String,recipe: String) -> bool:
	return RECIPES.has(recipe) and (station==RECIPES[recipe].station or (station=="garden_rack" and RECIPES[recipe].station=="rack"))

static func placement_valid(state: Dictionary,decorations: Dictionary) -> bool:
	return state.jobs.garden_rack.is_empty() or extra_rack_placed(decorations)

static func act(state: Dictionary, inventory: Dictionary, action: String, request: Dictionary, revision: int, now: float, decorations: Dictionary={}) -> Dictionary:
	if not is_finite(now) or now<0: return {"ok":false,"reason":"invalid_time"}
	if revision!=state.revision: return {"ok":false,"reason":"stale_kitchen"}
	if revision>=LIMIT: return {"ok":false,"reason":"inventory_limit"}
	var recipe: String=request.get("recipe","") if request.get("recipe","") is String else ""
	match action:
		"start":
			var crop: String=request.get("crop","") if request.get("crop","") is String else ""
			if not accepts(recipe,crop): return {"ok":false,"reason":"wrong_crop"}
			var rule: Dictionary=RECIPES[recipe]
			var station: Variant=request.get("station",rule.station)
			if not station is String or not supports(station,recipe): return {"ok":false,"reason":"invalid_station"}
			if station=="garden_rack" and not extra_rack_placed(decorations): return {"ok":false,"reason":"station_unavailable"}
			if not state.jobs[station].is_empty(): return {"ok":false,"reason":"station_busy"}
			if inventory[crop]<1: return {"ok":false,"reason":"insufficient_food"}
			var reserved: int=0
			for job: Dictionary in state.jobs.values():
				if job.get("recipe","")==recipe: reserved+=1
			if state.records[recipe].made+reserved>=LIMIT: return {"ok":false,"reason":"inventory_limit"}
			inventory[crop]-=1
			state.jobs[station]={"recipe":recipe,"crop":crop,"start_utc":now,"finish_utc":now+rule.seconds}
		"collect":
			var station: Variant=request.get("station")
			if station not in STATIONS: return {"ok":false,"reason":"invalid_station"}
			var job: Dictionary=state.jobs[station]
			if not ready(job,now): return {"ok":false,"reason":"not_ready"}
			recipe=job.recipe
			state.stock[recipe]+=1
			state.records[recipe].made+=1
			state.records[recipe].last_crop=job.crop
			state.jobs[station]={}
			state.display=recipe
		"display", "share":
			if not RECIPES.has(recipe) or state.stock[recipe]<1: return {"ok":false,"reason":"no_dish"}
			if action=="display":
				if state.display==recipe: return {"ok":false,"reason":"already_displayed"}
				state.display=recipe
			else:
				var neighbor: Variant=request.get("neighbor")
				if neighbor not in Neighbors.IDS: return {"ok":false,"reason":"invalid_neighbor"}
				state.stock[recipe]-=1
				state.records[recipe].shared+=1
				state.records[recipe].last_to=neighbor
				if state.stock[recipe]==0 and state.display==recipe: state.display=""
		_:
			return {"ok":false,"reason":"invalid_action"}
	state.revision+=1
	return {"ok":true,"reason":""}

static func share_reply(recipe: String, neighbor: String) -> String:
	var food: String=RECIPES[recipe].name
	match neighbor:
		"willow": return "这份%s我摆在窗边了。今天少忙一道菜，多坐一会儿。——林婶"%food
		"bamboo": return "%s收到了，竹活先放一放。你种的菜，经你一做，又是另一种好味道。——许伯"%food
		_: return "带回来的%s正好配这一顿饭。下回靠岸，还想来尝你的手艺。——阿舟"%food

static func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=LIMIT and floorf(value)==value

static func valid(state: Dictionary) -> bool:
	if state.size()!=5 or not _count(state.get("revision")) or not state.get("display") is String: return false
	for key: String in ["jobs","stock","records"]:
		if not state.get(key) is Dictionary: return false
	if state.jobs.size()!=STATIONS.size() or state.stock.size()!=RECIPES.size() or state.records.size()!=RECIPES.size(): return false
	for recipe: String in RECIPES:
		if not _count(state.stock.get(recipe)) or not state.records.get(recipe) is Dictionary: return false
		var record: Dictionary=state.records[recipe]
		if record.size()!=4 or not _count(record.get("made")) or not _count(record.get("shared")): return false
		if record.made!=record.shared+state.stock[recipe]: return false
		if not record.get("last_crop") is String or not record.get("last_to") is String: return false
		if (record.made==0 and record.last_crop!="") or (record.made>0 and not accepts(recipe,record.last_crop)): return false
		if (record.shared==0 and record.last_to!="") or (record.shared>0 and record.last_to not in Neighbors.IDS): return false
	if state.display!="" and (not RECIPES.has(state.display) or state.stock[state.display]<=0): return false
	for station: String in STATIONS:
		if not state.jobs.get(station) is Dictionary: return false
		var job: Dictionary=state.jobs[station]
		if job.is_empty(): continue
		if job.size()!=4 or not job.get("recipe") is String or not job.get("crop") is String: return false
		if not accepts(job.recipe,job.crop) or not supports(station,job.recipe): return false
		for key: String in ["start_utc","finish_utc"]:
			if not (job.get(key) is int or job.get(key) is float) or not is_finite(float(job[key])) or job[key]<0: return false
		if not is_equal_approx(job.finish_utc-job.start_utc,float(RECIPES[job.recipe].seconds)): return false
		if state.records[job.recipe].made>=LIMIT: return false
	for recipe: String in RECIPES:
		var reserved: int=0
		for job: Dictionary in state.jobs.values():
			if job.get("recipe","")==recipe: reserved+=1
		if state.records[recipe].made+reserved>LIMIT: return false
	return true
