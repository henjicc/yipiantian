extends SceneTree
const Farm=preload("res://farm/farm_state.gd")
const Memories=preload("res://farm/garden_memories.gd")
const Store=preload("res://farm/farm_store.gd")
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func run() -> void:
	var farm:=Farm.new(1000)
	check(Memories.entries(farm.snapshot()).size()==2,"Morning and evening can be revisited without waiting")
	var before: Dictionary=farm.snapshot()
	check(farm.remember("company",1001) and not farm.remember("company",1002),"Only first sighting persists")
	check(not farm.remember("invented",1001),"Unknown observation rejected")
	check(farm.apply_layout(farm.snapshot().layout,1001).ok and not farm.snapshot().memories.marks.has("arrange"),"Unchanged layout does not invent a memory")
	var layout: Dictionary=farm.snapshot().layout;layout.fence_style="crossed"
	check(farm.apply_layout(layout,1001).ok and farm.snapshot().memories.marks.has("arrange"),"Actual layout change is remembered")
	var photo: Dictionary={"id":"0123456789abcdef0123456789abcdef","title":"湖边","utc":1002.0}
	check(farm.photo_action("add",photo),"Photo admitted")
	check(not farm.photo_action("add",photo),"Repeated capture receipt rejected")
	check(not farm.photo_action("rename",{"id":photo.id,"title":"\n"}),"Control character title rejected")
	check(farm.photo_action("rename",{"id":photo.id,"title":"九月湖边"}),"Rename")
	check(not Memories.valid_id("../../outside") and not Memories.valid_id("G".repeat(32)),"Photo paths constrained to hex IDs")
	check(farm.snapshot().inventory==before.inventory and farm.snapshot().harvested==before.harvested,"Photos don't alter farming")
	var populated: Dictionary=farm.snapshot();populated.harvested.greens=1;populated.neighbors.willow.pending=true
	check(farm.restore_snapshot(populated),"Real facts accepted")
	var ids: Array=[]
	for entry: Dictionary in Memories.entries(farm.snapshot()): ids.append(entry.id)
	check("crop:greens" in ids and "neighbor:willow:0" in ids and "crop:radish" not in ids,"Entries reflect actual harvest and delivered chapter only")
	var invalid: Dictionary=farm.snapshot();invalid.memories.photos[0].id="../../outside"
	check(not farm.restore_snapshot(invalid),"Unsafe disk metadata rejected")
	var directory: String=ProjectSettings.globalize_path("res://../.local/verification/garden-state-%d"%Time.get_ticks_usec())
	var store:=Store.new(directory);store.load_state()
	check(store.save(farm.snapshot(),load("res://farm/decoration_state.gd").new().snapshot()).ok,"Store current schema")
	var loaded: Dictionary=Store.new(directory).load_state()
	check(loaded.ok and loaded.farm.memories==farm.snapshot().memories,"Roundtrip photos and observations")
	farm.settle(9999999999.0)
	check(farm.snapshot().memories==loaded.farm.memories,"Long absence preserves album")
	check(farm.photo_action("remove",{"id":photo.id}) and not farm.photo_action("remove",{"id":photo.id}),"Remove once without changing other records")
	print("GARDEN_MEMORIES failures=",failures);quit(0 if failures==0 else 1)
