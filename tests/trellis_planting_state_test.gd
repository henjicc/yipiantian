extends SceneTree
const Farm=preload("res://farm/farm_state.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
const Slots=preload("res://layout/trellis_slots.gd")
const Store=preload("res://farm/farm_store.gd")
const Decorations=preload("res://farm/decoration_state.gd")
var checks: int=0
var failures: Array[String]=[]

func expect(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label);push_error(label)

func _initialize() -> void:
	var farm:=Farm.new(1000)
	var plan:=Plan.new()
	expect(farm.cell_ids("trellis").size()==10,"Default frame has ten independent roots")
	var before: Dictionary=farm.snapshot()
	expect(not farm.sow("field_01","cell_01","luffa",1000).ok,"Climber requires a frame")
	expect(not farm.sow("trellis","left_0","greens",1000).ok and farm.snapshot()==before,"Ground crop cannot occupy a trellis; rejection is atomic")
	expect(farm.sow("trellis","left_2","luffa",1000).ok,"Sow outer root")
	expect(farm.sow("trellis","right_0","luffa",1000).ok,"Opposite roots are independent")
	expect(farm.water("trellis","left_2",1000).ok,"Water climber")
	before=farm.snapshot()
	expect(not farm.water("trellis","left_2",1000).ok and farm.snapshot()==before,"Water bonus applies once")
	var old_positions: Dictionary=Slots.slots(plan)
	plan.construction.trellis=[6.0,1.25,2.8,plan.anchors.trellis.x,plan.anchors.trellis.z,45.0]
	plan=Plan.from_snapshot(plan.snapshot())
	expect(plan!=null and farm.apply_layout(plan.snapshot(),1100).ok,"Longer rotated and taller frame retains crops")
	expect(farm.cell_ids("trellis").size()==14 and farm.get_cell("trellis","left_3").stage=="empty","Expansion adds empty roots")
	expect(Slots.slots(plan).left_2==old_positions.left_2,"Expansion preserves root spacing and identity")
	expect(farm.get_cell("trellis","left_2").watered and farm.get_cell("trellis","left_2").growth_seconds==1000,"Resize settles elapsed time without resetting growth")
	before=farm.snapshot()
	plan.construction.trellis[0]=2.4
	plan=Plan.from_snapshot(plan.snapshot())
	expect(not farm.trellis_retains_crops(plan),"Preview identifies occupied roots lost to shortening")
	expect(not farm.apply_layout(plan.snapshot(),2000).ok and farm.snapshot()==before,"Shortening cannot remove a crop or advance time")
	plan=Plan.from_snapshot(before.layout);plan.construction.trellis[1]=.8
	plan=Plan.from_snapshot(plan.snapshot())
	expect(not farm.apply_layout(plan.snapshot(),2000).ok and farm.snapshot()==before,"Narrowing protects the planted opposite row")
	var restored:=Farm.new()
	expect(restored.restore_snapshot(before),"Current schema accepts planted trellis")
	restored.settle(4600)
	expect(restored.get_cell("trellis","left_2").stage=="mature" and restored.get_cell("trellis","right_0").stage=="young","Water and elapsed time use ordinary growth rules")
	expect(restored.harvest("trellis","left_2",4600).ok,"Harvest matured vine")
	expect(not restored.harvest("trellis","left_2",4600).ok and restored.snapshot().inventory.luffa==1,"Harvest gives exactly one basket")
	var folder: String=ProjectSettings.globalize_path("res://../.local/verification/trellis-state-%d"%Time.get_ticks_usec())
	var store:=Store.new(folder)
	store.load_state()
	expect(store.save(restored.snapshot(),Decorations.new().snapshot()).ok,"Save harvested and growing roots")
	var reopened: Dictionary=Store.new(folder).load_state()
	expect(reopened.ok and reopened.farm==restored.snapshot(),"Disk roundtrip preserves root identities, harvest and water")
	var corrupt: Dictionary=restored.snapshot();corrupt.fields.trellis.cells.right_0.crop_id="greens"
	expect(not restored.restore_snapshot(corrupt),"Reject wrong-support crop in a saved slot")
	plan=Plan.from_snapshot(restored.snapshot().layout);plan.construction.trellis[0]=2.4
	plan=Plan.from_snapshot(plan.snapshot())
	expect(restored.apply_layout(plan.snapshot(),4600).ok,"Shorten after harvesting removed roots")
	expect(restored.get_cell("trellis","right_0").crop_id=="luffa" and restored.snapshot().inventory.luffa==1,"Legal shrink retains central vine and prior inventory")
	print("TRELLIS_PLANTING_STATE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
