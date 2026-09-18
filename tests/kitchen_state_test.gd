extends SceneTree
const Farm=preload("res://farm/farm_state.gd")
const Kitchen=preload("res://farm/kitchen.gd")
const Crops=preload("res://farm/crop_catalog.gd")
var failures: int=0
var checks: int=0
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void:
	var farm:=Farm.new(1000)
	var fixture: Dictionary=farm.snapshot()
	for crop: String in Crops.crop_ids(): fixture.inventory[crop]=10
	expect(farm.restore_snapshot(fixture),"Kitchen initial state is valid")
	var covered: Dictionary={}
	var share_index: int=0
	for recipe: String in Kitchen.RECIPES:
		var rule: Dictionary=Kitchen.RECIPES[recipe]
		for crop: String in Crops.crop_ids():
			if not Kitchen.accepts(recipe,crop): continue
			covered[crop]=true
			var before: Dictionary=farm.snapshot()
			var revision: int=before.kitchen.revision
			expect(farm.kitchen_action("start",{"recipe":recipe,"crop":crop},revision,1000).ok,"Start "+recipe+" with "+crop)
			var started: Dictionary=farm.snapshot()
			expect(started.inventory[crop]==before.inventory[crop]-1 and started.harvested==before.harvested,"Only raw inventory consumed")
			expect(not farm.kitchen_action("start",{"recipe":recipe,"crop":crop},revision,1000).ok and farm.snapshot()==started,"Stale callback cannot cook twice")
			expect(not farm.kitchen_action("start",{"recipe":recipe,"crop":crop},revision+1,1000).ok and farm.snapshot()==started,"Occupied station rejects atomically")
			expect(not farm.kitchen_action("collect",{"station":rule.station},revision+1,999).ok and farm.snapshot()==started,"Rollback cannot finish food")
			expect(not farm.kitchen_action("collect",{"station":rule.station},revision+1,1000+rule.seconds-.01).ok,"No early collection")
			var reopened:=Farm.new()
			expect(reopened.restore_snapshot(JSON.parse_string(JSON.stringify(started))),"Pending job roundtrips")
			expect(reopened.snapshot()==started,"Reload retains canonical numeric types and all kitchen values")
			farm=reopened
			expect(farm.kitchen_action("collect",{"station":rule.station},revision+1,1000+31536000).ok,"Offline year leaves finished food waiting")
			var cooked: Dictionary=farm.snapshot()
			expect(cooked.kitchen.stock[recipe]==before.kitchen.stock[recipe]+1 and cooked.kitchen.display==recipe,"Collect stocks and displays dish")
			expect(not farm.kitchen_action("collect",{"station":rule.station},revision+2,1000+31536000).ok and farm.snapshot()==cooked,"Empty station cannot grant twice")
			for neighbor: String in [Kitchen.Neighbors.IDS[share_index%3]]:
				share_index+=1
				var prior: Dictionary=farm.snapshot()
				var rev: int=prior.kitchen.revision
				if prior.kitchen.stock[recipe]==0: break
				expect(farm.kitchen_action("share",{"recipe":recipe,"neighbor":neighbor},rev,2000).ok,"Share cooked dish")
				var shared: Dictionary=farm.snapshot()
				expect(shared.inventory==prior.inventory and shared.harvested==prior.harvested and shared.neighbors==prior.neighbors,"Meal sharing does not replay raw basket rewards")
				expect(shared.kitchen.records[recipe].shared==prior.kitchen.records[recipe].shared+1,"Journal records sharing")
				expect(not farm.kitchen_action("share",{"recipe":recipe,"neighbor":neighbor},rev,2000).ok and farm.snapshot()==shared,"Repeated sharing is atomic no-op")
			expect(farm.snapshot().kitchen.display=="","Last shared portion clears table display")
			expect(Farm.new().restore_snapshot(farm.snapshot()),"Every transaction preserves loadable state")
	expect(covered.size()==12,"All twelve crops have kitchen uses")
	var stable: Dictionary=farm.snapshot()
	for broken: String in ["count","crop","recipient","time","display"]:
		var bad: Dictionary=stable.duplicate(true)
		match broken:
			"count": bad.kitchen.stock.leaf_stir+=1
			"crop": bad.kitchen.records.leaf_stir.last_crop="carrot"
			"recipient": bad.kitchen.records.leaf_stir.last_to="unknown"
			"time": bad.kitchen.jobs.stove={"recipe":"leaf_stir","crop":"greens","start_utc":1000,"finish_utc":-1}
			"display": bad.kitchen.display="leaf_stir"
		expect(not farm.restore_snapshot(bad) and farm.snapshot()==stable,"Reject corrupt kitchen "+broken)
	print("KITCHEN_STATE checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
