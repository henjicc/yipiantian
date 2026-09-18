extends RefCounted
## Facts already owned by farm systems are derived, not copied into a second log.
const Crops=preload("res://farm/crop_catalog.gd")
const Neighbors=preload("res://farm/neighbor_catalog.gd")
const Kitchen=preload("res://farm/kitchen.gd")
const Animals=preload("res://farm/animal_companions.gd")
const MARKS: Array[String]=["dawn","dusk","company","arrange"]
const MAX_PHOTOS: int=256
static func initial_state() -> Dictionary:
	return {"marks":{},"photos":[]}
static func valid_id(id: Variant) -> bool:
	if not id is String or id.length()!=32: return false
	for c: String in id:
		if c not in "0123456789abcdef": return false
	return true
static func valid_title(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length()>40: return false
	for i: int in value.length():
		if value.unicode_at(i)<32 or value.unicode_at(i)==127: return false
	return true
static func valid(state: Dictionary) -> bool:
	if state.size()!=2 or not state.get("marks") is Dictionary or not state.get("photos") is Array: return false
	if state.photos.size()>MAX_PHOTOS: return false
	for id: Variant in state.marks:
		var value: Variant=state.marks[id]
		if id not in MARKS or not (value is int or value is float) or not is_finite(value) or value<0 or value>253402300799.0: return false
	var ids: Array[String]=[]
	for photo: Variant in state.photos:
		if not photo is Dictionary or photo.size()!=3 or not valid_id(photo.get("id")) or not valid_title(photo.get("title")): return false
		var time: Variant=photo.get("utc")
		if not (time is int or time is float) or not is_finite(time) or time<0 or time>253402300799.0 or photo.id in ids: return false
		ids.append(photo.id)
	return true
static func mark(state: Dictionary,id: String,now: float) -> bool:
	if id not in MARKS or state.marks.has(id) or not is_finite(now) or now<0 or now>253402300799.0: return false
	state.marks[id]=now
	return true
static func photo_action(state: Dictionary,action: String,photo: Dictionary) -> bool:
	var index: int=-1
	for i: int in state.photos.size():
		if state.photos[i].id==photo.get("id"): index=i;break
	if action=="add":
		if index>=0 or state.photos.size()>=MAX_PHOTOS: return false
		var candidate: Dictionary=state.duplicate(true);candidate.photos.append(photo)
		if not valid(candidate): return false
		state.photos.append(photo.duplicate(true));return true
	if index<0: return false
	if action=="rename" and valid_title(photo.get("title")):
		state.photos[index].title=photo.title;return true
	if action=="remove": state.photos.remove_at(index);return true
	return false
static func entries(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for setting: Array in [["dawn","晨光入院","太阳缓缓照进菜畦，水面也亮了。","sun.svg"],["dusk","灯下的小院","日色慢慢退去，廊灯照着门前的一小块地。","moon.svg"]]:
		result.append({"id":setting[0],"title":setting[1],"text":setting[2],"icon":"res://art/ui/"+setting[3],"recorded":data.memories.marks.has(setting[0])})
	if data.memories.marks.has("company"):
		result.append({"id":"company","title":"湖上有伴","text":"两只水禽靠近了，顺着彼此的方向游了一段。后来又各自停下，探一探水。","icon":"res://art/ui/animals/duck.png","recorded":true})
	if data.memories.marks.has("arrange"):
		result.append({"id":"arrange","title":"小院换了模样","text":"挪一件摆设，或把田地重新理一理。还是这座小院，已经有了自己的安排。","icon":"res://art/ui/decorations/bench.png","recorded":true})
	for id: String in Crops.crop_ids():
		if data.harvested[id]<1: continue
		result.append({"id":"crop:"+id,"title":Crops.definition(id).name+"初收","text":"第一次把自己种的%s收进菜篮。以后拿去做菜、分给邻居，这一篮都已经记在这里。"%Crops.definition(id).name,"icon":Crops.icon_path(id),"recorded":true})
	for id: String in Neighbors.IDS:
		var history: Array=Neighbors.Stories.history(id,data.neighbors[id])
		for i: int in history.size():
			var chapter: Dictionary=history[i]
			result.append({"id":"neighbor:"+id+":"+str(i),"title":chapter.title,"text":Neighbors.HOMES[id].name+" · "+chapter.reply,"icon":"res://art/ui/basket.svg","recorded":true})
	for id: String in Animals.IDS:
		if data.animals[id].visits<1: continue
		result.append({"id":"animal:"+id,"title":"和"+data.animals[id].name+"打个招呼","text":"和%s打过招呼，也可以一起安静待一会儿。它还有自己的路要走，不必时时照看。"%data.animals[id].name,"icon":"res://art/ui/animals/%s.png"%Animals.kind(id),"recorded":true})
	for id: String in Kitchen.RECIPES:
		if data.kitchen.records[id].made<1: continue
		result.append({"id":"kitchen:"+id,"title":Kitchen.RECIPES[id].name,"text":Kitchen.RECIPES[id].entry,"icon":Crops.icon_path(data.kitchen.records[id].last_crop),"recorded":true})
	return result
