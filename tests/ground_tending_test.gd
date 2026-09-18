extends SceneTree
const Farm=preload("res://farm/farm_state.gd")
const Store=preload("res://farm/farm_store.gd")
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func run() -> void:
	var farm:=Farm.new(1000)
	var before: Dictionary=farm.snapshot()
	check(not farm.sow("field_06","cell_13","greens",1100).ok,"Uncleared soil cannot be planted")
	check(not farm.tidy("till","field_06","cell_13",1100).ok and farm.snapshot()==before,"Wrong tool neither advances time nor clears grass")
	check(farm.tidy("weed","field_06","cell_13",1100).ok,"Weeding succeeds")
	check(farm.get_cell("field_06","cell_13").ground=="rough","Grass removal leaves unturned ground")
	check(not farm.tidy("weed","field_06","cell_13",1101).ok,"Repeated removal is no-op")
	check(farm.tidy("till","field_06","cell_13",1101).ok,"Hoe makes ground plantable")
	check(farm.sow("field_06","cell_13","greens",1101).ok,"Plant reclaimed cell")
	check(not farm.tidy("weed","field_06","cell_13",1102).ok and not farm.tidy("till","field_06","cell_13",1102).ok,"Tools never remove planted crops")
	farm.settle(9999999999.0)
	check(farm.harvest("field_06","cell_13",9999999999.0).ok,"Reclaimed ground supports full harvest")
	check(farm.get_cell("field_06","cell_13").ground=="ready" and farm.get_cell("field_06","cell_14").ground=="weedy","Long absence preserves both tended and untouched ground")
	check(farm.snapshot().inventory.greens==1,"Tending earns no duplicate harvest")
	var layout: Dictionary=farm.snapshot().layout;layout.fence_style="crossed"
	check(farm.apply_layout(layout,9999999999.0).ok and farm.get_cell("field_06","cell_13").ground=="ready","Layout rebuild preserves tending")
	var invalid: Dictionary=farm.snapshot();invalid.fields.field_06.cells.cell_14.ground="readyish"
	check(not farm.restore_snapshot(invalid),"Malformed ground rejected")
	var path: String=ProjectSettings.globalize_path("res://../.local/verification/tending-state-%d"%Time.get_ticks_usec())
	var store:=Store.new(path);store.load_state()
	check(store.save(farm.snapshot(),load("res://farm/decoration_state.gd").new().snapshot()).ok,"Current schema saves")
	var loaded: Dictionary=Store.new(path).load_state()
	check(loaded.ok and loaded.farm.fields==farm.snapshot().fields,"Ground roundtrip")
	print("GROUND_TENDING failures=",failures);quit(0 if failures==0 else 1)
