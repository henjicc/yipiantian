extends SceneTree
## Earn every input through crops or neighbor replies; advance only the supplied UTC.
const Farm=preload("res://farm/farm_state.gd")
const Decor=preload("res://farm/decoration_state.gd")
const Catalog=preload("res://farm/decoration_catalog.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
var checks: int=0
var failures: int=0

func expect(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)

func first_reward(exchange: bool) -> void:
	var farm:=Farm.new(1000)
	var decor:=Decor.new()
	expect(farm.harvest("field_03","cell_06",1000).ok,"Opening crop supplies first basket")
	var ingredient: String="greens"
	var recipe: String="leaf_stir"
	if exchange:
		expect(farm.share_basket("willow",0,{"greens":1}).ok,"Optional neighbor route uses the same first harvest")
		expect(farm.claim_gift("willow",0,"radish").ok,"Immediate reply provides a cookable ingredient")
		ingredient="radish";recipe="root_soup"
	var seconds: float=Farm.Kitchen.RECIPES[recipe].seconds
	expect(farm.kitchen_action("start",{"recipe":recipe,"crop":ingredient},0,1000).ok,"One harvested or exchanged basket starts first meal")
	var during: Dictionary=farm.snapshot()
	var plan:=Plan.new();plan.expand_shore(2,2)
	expect(farm.apply_layout(plan.snapshot(),1001).ok and farm.snapshot().inventory==during.inventory and farm.snapshot().kitchen==during.kitchen,"Zero food and running kitchen do not gate land construction")
	expect(decor.place("bench","ground_01",0).ok and decor.place("tea_table","ground_02",0).ok,"Starting furniture costs no ingredients")
	expect(not farm.kitchen_action("collect",{"station":"stove"},1,1000+seconds-.01).ok,"Displayed recipe time is a real wait")
	expect(farm.kitchen_action("collect",{"station":"stove"},1,1000+seconds).ok,"First meal completes at the advertised time")
	expect(farm.kitchen_action("share",{"recipe":recipe,"neighbor":"willow"},2,1000+seconds).ok,"One finished serving earns the reward")
	decor.unlock(farm.snapshot().harvested,farm.snapshot().kitchen)
	expect(decor.snapshot().drying_rack.unlocked and Farm.Crops.total_harvested(farm.snapshot().harvested)==1 and Farm.Crops.total_harvested(farm.snapshot().inventory)==0,"First useful reward requires one original harvest, with no hidden purchase")
	expect(Catalog.progress("pot",farm.snapshot().harvested,farm.snapshot().kitchen).contains("1/3"),"Consumed and exchanged harvest still counts toward decoration progress")
	print("FIRST_REWARD route=", "exchange" if exchange else "direct", " baskets=1 wait_seconds=",seconds)

func _initialize() -> void: _run.call_deferred()

func recipe_choices() -> void:
	# UI-only regression fixture: the old selected leaf is gone, another leaf exists.
	var farm:=Farm.new(1000)
	var data: Dictionary=farm.snapshot();data.inventory.spinach=1
	farm.restore_snapshot(data)
	var book:=preload("res://ui/harvest_book.gd").new()
	root.add_child(book);book.tab="kitchen";book.decorations=Decor.new().snapshot()
	book.update_time(1000);book.present(data);await process_frame
	expect(book.kitchen_page.crop=="spinach" and not book._root.find_child("StartCooking",true,false).disabled,"Depleted selected ingredient falls back to another usable leaf")
	var actions: Array[Dictionary]=[]
	book.kitchen_requested.connect(func(action: String,request: Dictionary,_revision: int) -> void: actions.append({"action":action,"request":request}))
	book._root.find_child("StartCooking",true,false).pressed.emit()
	expect(actions.back().request.crop=="spinach","Visible ingredient selection and cooking request agree")
	farm.kitchen_action("start",actions.back().request,0,1000)
	farm.kitchen_action("collect",{"station":"stove"},1,1020)
	book.update_time(1020);book.refresh(farm.snapshot());await process_frame
	var recipient: OptionButton=book._root.find_child("MealRecipient",true,false)
	recipient.select(1);recipient.item_selected.emit(1);await process_frame
	var share: Button=book._root.find_child("FirstMealShare",true,false)
	expect(share.text.contains("许伯"),"Changing recipient updates the first-reward action label")
	share.pressed.emit()
	expect(actions.back().request.neighbor=="bamboo","Sharing recipient matches the visible action")
	book.dismiss();book.queue_free();await process_frame

func _run() -> void:
	first_reward(false);first_reward(true)
	# A compact parallel planting session, not artificial inventory or harvest totals.
	var farm:=Farm.new(1000)
	var decor:=Decor.new()
	farm.harvest("field_03","cell_06",1000)
	farm.water("field_04","cell_06",1000);farm.water("field_06","cell_06",1000)
	for i: int in range(1,13):
		var cell: String="cell_%02d"%i
		expect(farm.sow("field_01",cell,"greens",1000).ok and farm.water("field_01",cell,1000).ok,"Seeds and watering have no inventory gate")
	expect(farm.sow("field_02","cell_01","chrysanthemum",1000).ok and farm.water("field_02","cell_01",1000).ok,"Third variety is available from the start")
	var checkpoints: Dictionary={}
	for minute: float in [18.0,24.0,27.3]:
		var now: float=1000+minute*60
		farm.settle(now)
		for field: String in farm.field_ids():
			for cell: String in farm.cell_ids(field):
				if farm.get_cell(field,cell).stage=="mature": farm.harvest(field,cell,now)
		var before: Dictionary=farm.snapshot().inventory
		for unlocked: String in decor.unlock(farm.snapshot().harvested,farm.snapshot().kitchen): checkpoints[unlocked]=minute
		expect(farm.snapshot().inventory==before,"Harvest milestone never spends earned food")
	expect(checkpoints.get("pot",INF)<=18 and checkpoints.get("flowerpot",INF)<=24 and checkpoints.get("lantern",INF)<=30,"Optional decoration milestones are reachable in one parallel crop cycle")
	expect(Farm.Crops.total_harvested(farm.snapshot().harvested)==16 and Farm.Crops.varieties(farm.snapshot().harvested)==3,"Milestones came from sixteen actual harvests of three varieties")
	var inventory: Dictionary=farm.snapshot().inventory
	for id: String in ["pot","flowerpot","lantern"]:
		var slot: String="hanging_01" if id=="lantern" else ("ground_01" if id=="pot" else "ground_02")
		expect(decor.place(id,slot,0).ok and decor.remove(id).ok and decor.place(id,slot,1).ok,"Unlocked object can be placed, stored and moved without another purchase")
	expect(farm.snapshot().inventory==inventory,"All optional placements leave food unchanged")
	print("DECORATION_PACING minutes=",checkpoints," baskets=16 varieties=3")
	await recipe_choices()
	print("CONSTRUCTION_PACING_STATE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
