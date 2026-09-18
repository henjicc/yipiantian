extends SceneTree
const Farm=preload("res://farm/farm_state.gd")
const Crops=preload("res://farm/crop_catalog.gd")
const Neighbors=preload("res://farm/neighbor_catalog.gd")
const Decorations=preload("res://farm/decoration_state.gd")
var checks: int=0
var failures: Array[String]=[]

func expect(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message)

func _initialize() -> void:
	var farm:=Farm.new(1000)
	expect(farm.harvest("field_03","cell_06",1000).ok,"Initial harvest")
	expect(farm.snapshot().inventory.greens==1 and farm.snapshot().harvested.greens==1,"Harvest credits both ledgers")
	var before: Dictionary=farm.snapshot()
	for basket: Dictionary in [{},{"greens":0},{"greens":-1},{"greens":.5},{"greens":2},{"carrot":1},{"unknown":1},{"greens":NAN}]:
		expect(not farm.share_basket("willow",0,basket).ok and farm.snapshot()==before,"Invalid basket is atomic: "+str(basket))
	expect(farm.share_basket("willow",0,{"greens":1}).ok,"First harvest can immediately be shared")
	expect(farm.snapshot().inventory.greens==0 and farm.snapshot().harvested.greens==1,"Sharing spends only food")
	before=farm.snapshot()
	expect(not farm.share_basket("willow",0,{"greens":1}).ok and farm.snapshot()==before,"Repeated delivery cannot charge twice")
	var restored:=Farm.new()
	expect(restored.restore_snapshot(JSON.parse_string(JSON.stringify(before))),"Pending reply survives JSON")
	restored.settle(1000+3600*24*365)
	expect(restored.snapshot().neighbors==before.neighbors and restored.snapshot().inventory==before.inventory,"Offline year does not expire food, wishes or gifts")
	expect(restored.claim_gift("willow",0,"radish").ok,"Claim chosen gift after return")
	before=restored.snapshot()
	expect(before.inventory.radish==1 and before.harvested.radish==0,"Gift is usable food, not fake harvest progress")
	expect(not restored.claim_gift("willow",0,"mustard").ok and restored.snapshot()==before,"Stale callback cannot claim alternate gift")
	var supplied: Dictionary=farm.snapshot()
	for id: String in Crops.crop_ids(): supplied.inventory[id]=100
	supplied.neighbors=Neighbors.initial_state()
	expect(farm.restore_snapshot(supplied),"Stock fixture")
	var earned: Dictionary=farm.snapshot().harvested
	for id: String in Neighbors.IDS:
		for round_index: int in 9:
			expect(Neighbors.Stories.history(id,farm.snapshot().neighbors[id]).size()==mini(round_index,3),"History only contains delivered chapters")
			var wish: Dictionary=Neighbors.wish(id,round_index)
			expect(wish.has("reply")== (round_index<3),"Complete story is followed by repeatable daily wishes")
			var basket: Dictionary={}
			var remaining: int=wish.amount
			for crop: String in Crops.crop_ids():
				if remaining>0 and Neighbors.accepts(id,round_index,crop):
					basket[crop]=1
					remaining-=1
			expect(remaining==0 and farm.share_basket(id,round_index,basket).ok,"Each household has sustainable varied wishes")
			expect(Neighbors.Stories.delivered(id,farm.snapshot().neighbors[id])==mini(round_index+1,3),"Scene chapter appears on durable delivery, before claiming the gift")
			var replay_before: Dictionary=farm.snapshot()
			var letters: Array[Dictionary]=Neighbors.Stories.history(id,replay_before.neighbors[id])
			letters[0].title="reader-local change"
			expect(farm.snapshot()==replay_before and Neighbors.Stories.history(id,replay_before.neighbors[id])[0].title!="reader-local change","Reading letters cannot mutate state or shared story content")
			before=farm.snapshot()
			expect(not farm.claim_gift(id,round_index,"lettuce").ok and farm.snapshot()==before,"Unlisted gifts rejected atomically")
			var gift: String=Neighbors.HOMES[id].gifts[round_index%2]
			expect(farm.claim_gift(id,round_index,gift).ok,"Both gift choices work")
			expect(farm.snapshot().neighbors[id].round==round_index+1,"Exactly one round advances")
	expect(farm.snapshot().harvested==earned,"Twenty-seven exchanges never reduce or inflate harvests")
	for crop: String in Crops.crop_ids():
		var accepted: bool=false
		for id: String in Neighbors.IDS:
			for index: int in 3: accepted=accepted or Neighbors.accepts(id,index,crop)
		expect(accepted,"Every crop has a sharing use: "+crop)
	before=farm.snapshot()
	for value: Variant in [-1,.5,"2",INF,9007199254740992]:
		var invalid: Dictionary=before.duplicate(true)
		invalid.inventory.greens=value
		expect(not farm.restore_snapshot(invalid) and farm.snapshot()==before,"Invalid stock cannot replace state")
	var invalid: Dictionary=before.duplicate(true)
	invalid.neighbors.willow.round=.5
	expect(not farm.restore_snapshot(invalid),"Invalid visit token rejected")
	invalid=before.duplicate(true)
	invalid.neighbors.willow.pending="true"
	expect(not farm.restore_snapshot(invalid),"Invalid pending state rejected")
	var plan: RefCounted=Farm.Plan.from_snapshot(before.layout)
	plan.fields[0].yaw=15
	expect(farm.apply_layout(plan.snapshot(),1000).ok and farm.snapshot().inventory==before.inventory and farm.snapshot().neighbors==before.neighbors,"Layout editing preserves food and pending exchanges")
	var boundary:=Farm.new(1000)
	var limit: Dictionary=boundary.snapshot()
	limit.inventory.greens=Farm.MAX_HARVEST_COUNT
	expect(boundary.restore_snapshot(limit),"Inventory exact upper bound accepted")
	expect(not boundary.harvest("field_03","cell_06",1000).ok and boundary.snapshot()==limit,"Full inventory cannot discard mature crop")
	limit=boundary.snapshot()
	limit.neighbors.willow={"round":2147483646,"pending":false,"last_gift":"radish"}
	expect(boundary.restore_snapshot(limit),"Visit upper boundary accepted")
	expect(not boundary.share_basket("willow",2147483646,{"greens":1}).ok and boundary.snapshot()==limit,"Visit cap cannot charge food for an unclaimable reply")
	for failure: String in failures: push_error(failure)
	print("NEIGHBOR_STATE_TEST checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
