extends SceneTree
## Cross-system return journey with earned food, a pending gift and unfinished cooking.
const Farm=preload("res://farm/farm_state.gd")
const Store=preload("res://farm/farm_store.gd")
const Decor=preload("res://farm/decoration_state.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
const Crops=preload("res://farm/crop_catalog.gd")
const Neighbors=preload("res://farm/neighbor_catalog.gd")
const Memories=preload("res://farm/garden_memories.gd")
var farm: RefCounted=Farm.new(1000)
var decor: RefCounted=Decor.new()
var store: RefCounted
var now: float=1000
var failures: int=0
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func crop_basket(crop: String,cell: String="cell_01") -> void:
	check(farm.sow("field_01",cell,crop,now).ok,"Sow one available cell: "+crop)
	now+=Crops.definition(crop).duration_seconds
	check(farm.harvest("field_01",cell,now).ok,"One unwatered crop matures without pressure: "+crop)
	decor.unlock(farm.snapshot().harvested)
func kitchen(action: String,request: Dictionary) -> void:
	check(farm.kitchen_action(action,request,int(farm.snapshot().kitchen.revision),now).ok,"Kitchen "+action)
func checkpoint() -> void:
	var before: Dictionary=farm.snapshot();var furniture: Dictionary=decor.snapshot()
	check(store.save(before,furniture).ok,"All systems commit together")
	store=Store.new(store.directory)
	var loaded: Dictionary=store.load_state()
	check(loaded.ok and loaded.farm==before and loaded.decorations==furniture,"Disk return preserves complete farm and decorations")
	farm=Farm.new();decor=Decor.new()
	check(farm.restore_snapshot(loaded.farm) and decor.restore_snapshot(loaded.decorations),"Return restores authority")
func _initialize() -> void:
	var folder: String=ProjectSettings.globalize_path("res://../.local/verification/life-return-%d"%Time.get_ticks_usec())
	store=Store.new(folder);check(store.load_state().ok,"Isolated new farm")
	check(farm.harvest("field_03","cell_06",now).ok,"First ready basket")
	check(farm.share_basket("willow",0,{"greens":1}).ok,"First story with one basket")
	check(farm.animal_action("YardHen1","name","小秋",0).ok,"Animal named")
	check(farm.animal_action("YardHen1","call",null,1).ok,"Free companionship without food")
	var plan:=Plan.new();plan.expand_shore(2,2)
	check(farm.apply_layout(plan.snapshot(),now).ok,"Layout changes retain existing crops and progress")
	check(decor.place("bench","ground_01",0).ok,"Free furniture before grinding")
	check(farm.set_season("after_rain"),"Any-time seasonal choice")
	checkpoint()
	now+=365*86400;var before: Dictionary=farm.snapshot();farm.settle(now)
	for key: String in ["harvested","inventory","neighbors","animals","kitchen","layout","season","memories"]:
		check(farm.snapshot()[key]==before[key],"A year away preserves "+key)
	check(farm.claim_gift("willow",0,"radish").ok,"Pending reply survives long absence")
	before=farm.snapshot()
	check(not farm.claim_gift("willow",0,"mustard").ok and farm.snapshot()==before,"Stale gift cannot be claimed twice after return")
	kitchen("start",{"recipe":"root_soup","crop":"radish"})
	check(farm.harvest("field_04","cell_06",now).ok,"Old immature crop is now mature, not rotten")
	check(farm.share_basket("bamboo",0,{"greens":1}).ok,"Another pending story coexists with cooking")
	checkpoint();before=farm.snapshot();now+=180*86400;farm.settle(now)
	check(farm.snapshot().kitchen==before.kitchen and farm.snapshot().neighbors==before.neighbors,"Cooking and pending gift remain available together")
	var revision: int=farm.snapshot().kitchen.revision
	kitchen("collect",{"station":"stove"});before=farm.snapshot()
	check(not farm.kitchen_action("collect",{"station":"stove"},revision,now).ok and farm.snapshot()==before,"Repeated collect cannot duplicate food")
	kitchen("share",{"recipe":"root_soup","neighbor":"willow"})
	check(farm.claim_gift("bamboo",0,"celery").ok,"Return gift also available after cooking")
	# Finish all three authored stories with one or two reused cells, never 96 crops.
	for home: String in Neighbors.IDS:
		while farm.snapshot().neighbors[home].round<3:
			var index: int=farm.snapshot().neighbors[home].round
			var wish: Dictionary=Neighbors.wish(home,index);var chosen: String=""
			for crop: String in Crops.crop_ids():
				if Neighbors.accepts(home,index,crop): chosen=crop;break
			for i: int in wish.amount:
				crop_basket(chosen,"cell_01" if i==0 else "cell_02")
			check(farm.share_basket(home,index,{chosen:wish.amount}).ok,"Earned basket advances "+home)
			check(farm.claim_gift(home,index,Neighbors.HOMES[home].gifts[0]).ok,"Choose optional reply")
		check(Neighbors.Stories.history(home,farm.snapshot().neighbors[home]).size()==3,"Complete story remains readable")
	# Every crop has a kitchen use; a single cell can earn all varieties and unlocks.
	for crop: String in Crops.crop_ids():
		crop_basket(crop)
		var selected: String=""
		for recipe: String in Farm.Kitchen.RECIPES:
			if Farm.Kitchen.accepts(recipe,crop): selected=recipe;break
		check(not selected.is_empty(),"Kitchen use for "+crop)
		kitchen("start",{"recipe":selected,"crop":crop});now+=100
		kitchen("collect",{"station":Farm.Kitchen.RECIPES[selected].station})
	check(decor.snapshot().lantern.unlocked,"Varied modest harvest unlocks last decoration")
	check(Memories.entries(farm.snapshot()).size()>=25,"Harvest, food, neighbors, animal and layout produce derived memories")
	checkpoint();before=farm.snapshot();now+=5*365*86400;farm.settle(now)
	for key: String in ["inventory","harvested","neighbors","kitchen","animals","layout","season","memories"]:
		check(farm.snapshot()[key]==before[key],"Long final return preserves "+key)
	checkpoint()
	print("LIFE_RETURN failures=",failures," total_harvest=",Crops.total_harvested(farm.snapshot().harvested)," evidence=",folder)
	quit(0 if failures==0 else 1)
