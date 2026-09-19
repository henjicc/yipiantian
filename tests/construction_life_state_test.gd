extends SceneTree
const Farm=preload("res://farm/farm_state.gd")
const Decor=preload("res://farm/decoration_state.gd")
const Kitchen=preload("res://farm/kitchen.gd")
const Store=preload("res://farm/farm_store.gd")
var checks: int=0
var failures: int=0

func expect(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(label)

func _initialize() -> void:
	var farm:=Farm.new(1000)
	var decor:=Decor.new()
	expect(not decor.snapshot().drying_rack.unlocked,"Portable rack begins locked")
	expect(not decor.place_at("drying_rack",Vector2(-3,7),0).ok,"Locked rack cannot be placed")
	expect(farm.harvest("field_03","cell_06",1000).ok,"First harvest supplies ingredients")
	expect(farm.kitchen_action("start",{"recipe":"leaf_stir","crop":"greens"},0,1000).ok,"Cook harvest with existing stove")
	expect(farm.kitchen_action("collect",{"station":"stove"},1,1020).ok,"Collect actual cooked dish")
	decor.unlock(farm.snapshot().harvested,farm.snapshot().kitchen)
	expect(not decor.snapshot().drying_rack.unlocked,"Cooking alone does not falsely count sharing")
	expect(farm.kitchen_action("share",{"recipe":"leaf_stir","neighbor":"bamboo"},2,1020).ok,"Share cooked meal with existing neighbor")
	expect(decor.unlock(farm.snapshot().harvested,farm.snapshot().kitchen)==["drying_rack"],"First meal unlocks a construction item")
	expect(decor.unlock(farm.snapshot().harvested,farm.snapshot().kitchen).is_empty(),"Unlock is idempotent")
	var snapshot: Dictionary=farm.snapshot()
	snapshot.inventory.radish=3
	expect(farm.restore_snapshot(snapshot),"Fixture provides root ingredients for capacity comparison")
	var request: Dictionary={"recipe":"root_dry","crop":"radish","station":"garden_rack"}
	expect(not farm.kitchen_action("start",request,3,1020,decor.snapshot()).ok and farm.snapshot()==snapshot,"Unlocked but unplaced rack gives no production capacity")
	expect(decor.place_at("drying_rack",Vector2(-3,7),0).ok,"Place earned rack")
	expect(farm.kitchen_action("start",{"recipe":"root_dry","crop":"radish"},3,1020,decor.snapshot()).ok,"Original drying station remains available")
	expect(farm.kitchen_action("start",request,4,1020,decor.snapshot()).ok,"Placed rack adds independent simultaneous production")
	snapshot=farm.snapshot()
	expect(snapshot.inventory.radish==1 and not snapshot.kitchen.jobs.rack.is_empty() and not snapshot.kitchen.jobs.garden_rack.is_empty(),"Two jobs consume exactly two baskets")
	expect(not farm.kitchen_action("start",request,4,1020,decor.snapshot()).ok and farm.snapshot()==snapshot,"Duplicate callback cannot spend again")
	var without: Dictionary=decor.snapshot();without.drying_rack.position=[]
	expect(not Kitchen.placement_valid(snapshot.kitchen,without),"Active job prevents removing its support")
	decor.place_at("drying_rack",Vector2(-2,7),1)
	expect(Kitchen.placement_valid(snapshot.kitchen,decor.snapshot()) and farm.snapshot()==snapshot,"Moving and rotating support preserves processing")
	var store:=Store.new(ProjectSettings.globalize_path("res://../.local/verification/construction-life-state-%d"%Time.get_ticks_usec()))
	store.load_state()
	expect(store.save(snapshot,decor.snapshot()).ok,"Persist both working stations and moved support")
	expect(not store.save(snapshot,without).ok,"Storage rejects an orphan production job")
	var loaded: Dictionary=Store.new(store.directory).load_state()
	expect(loaded.ok and loaded.farm==snapshot and loaded.decorations==decor.snapshot(),"Rejected removal preserves last valid disk state")
	expect(farm.restore_snapshot(loaded.farm),"Reopen working stations")
	expect(farm.kitchen_action("collect",{"station":"rack"},5,1110).ok,"Collect baseline batch")
	expect(farm.kitchen_action("collect",{"station":"garden_rack"},6,1110).ok,"Collect additional batch")
	expect(farm.snapshot().kitchen.stock.root_dry==2 and farm.snapshot().inventory.radish==1,"Both completed batches grant once")
	expect(Kitchen.placement_valid(farm.snapshot().kitchen,without),"Empty rack can be removed after collection")
	var capped: Dictionary=farm.snapshot().kitchen
	capped.records.root_dry.made=Kitchen.LIMIT-1;capped.stock.root_dry=Kitchen.LIMIT-1
	var inventory: Dictionary={"radish":2}
	expect(Kitchen.act(capped,inventory,"start",request,capped.revision,1200,decor.snapshot()).ok,"One remaining output capacity can be reserved")
	var before: Dictionary=capped.duplicate(true)
	expect(not Kitchen.act(capped,inventory,"start",{"recipe":"root_dry","crop":"radish"},capped.revision,1200,decor.snapshot()).ok and capped==before and inventory.radish==1,"Parallel jobs cannot overbook output count limit")
	print("CONSTRUCTION_LIFE_STATE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
