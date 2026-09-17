extends SceneTree

const Farm = preload("res://farm/farm_state.gd")
const Crops = preload("res://farm/crop_catalog.gd")
const START: float = 1800000000.0

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_initial_state_and_isolation()
	_test_mixed_cells()
	_test_stages_and_actions()
	_test_elapsed_time_equivalence()
	_test_clock_rollback_and_jump()
	_test_invalid_actions_are_atomic()
	_test_snapshot_validation()
	_test_variable_fields()
	for failure: String in failures:
		push_error(failure)
	print("FARM_STATE_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_initial_state_and_isolation() -> void:
	var farm := Farm.new(START)
	var initial: Dictionary = farm.snapshot()
	_expect(initial.fields.size() == 6, "Six stable fields")
	_expect(Crops.total_harvested(initial.harvested) == 0 and initial.harvested.size() == 12, "Tutorial crops do not award baskets automatically")
	_expect(farm.get_cell("field_01", "cell_06").stage == "empty" and farm.get_cell("field_02", "cell_06").stage == "empty", "Two initial empty fields")
	_expect(farm.get_cell("field_03", "cell_06").stage == "mature", "First harvest available immediately")
	_expect(is_equal_approx(farm.get_cell("field_04", "cell_06").progress, 0.2), "Initial greens progress")
	_expect(is_equal_approx(farm.get_cell("field_05", "cell_06").progress, 0.1) and is_equal_approx(farm.get_cell("field_06", "cell_06").progress, 0.6), "Initial radish progress")
	for field: Dictionary in initial.fields.values():
		_expect(field.cells.size() == 16, "Sixteen stable cells in every field")
		for cell: Dictionary in field.cells.values():
			_expect(not cell.watered and cell.last_settled_utc_seconds == START, "Fresh cells share injected baseline and are unwatered")
	initial.fields.field_03.cells.cell_06.crop_id = "invalid"
	initial.harvested.greens = 999
	var view: Dictionary = farm.get_cell("field_03", "cell_06")
	view.growth_seconds = 0.0
	_expect(farm.get_cell("field_03", "cell_06").stage == "mature" and farm.snapshot().harvested.greens == 0, "Returned views cannot mutate authority")
	var definition: Dictionary = Crops.definition("greens")
	definition.duration_seconds = 1.0
	farm.harvest("field_03", "cell_06", START)
	farm.sow("field_03", "cell_06", "greens", START)
	farm.water("field_03", "cell_06", START)
	_expect(Crops.definition("greens").duration_seconds == 1800.0 and is_equal_approx(farm.get_cell("field_03", "cell_06").progress, 0.2), "Definition edits and player actions cannot rewrite crop configuration")


func _test_mixed_cells() -> void:
	var farm := Farm.new(START)
	_expect(Farm.CELL_IDS.size() == 16 and Farm.CELL_IDS[0] == "cell_01" and Farm.CELL_IDS[15] == "cell_16", "Stable row-major cell IDs")
	_expect(farm.get_field("field_01").cells.cell_01 == farm.get_cell("field_01", "cell_01"), "Field view contains full derived cell views")
	_expect(farm.get_cell("field_01", "cell_01").field_id == "field_01", "Cell view retains parent field identity")
	for cell_id: String in Farm.CELL_IDS:
		var crop_id: String = "greens" if Farm.CELL_IDS.find(cell_id) % 2 == 0 else "radish"
		_expect(farm.sow("field_01", cell_id, crop_id, START).ok, "All sixteen cells can be planted independently")
	var before: Dictionary = farm.snapshot()
	_expect(farm.water("field_01", "cell_01", START).ok, "Water selected mixed crop cell")
	for cell_id: String in Farm.CELL_IDS:
		if cell_id != "cell_01":
			_expect(farm.snapshot().fields.field_01.cells[cell_id] == before.fields.field_01.cells[cell_id], "Water does not change neighbouring cells")
	farm.settle(START + 1800.0)
	_expect(farm.get_cell("field_01", "cell_01").stage == "mature" and farm.get_cell("field_01", "cell_02").stage != "mature", "Mixed durations are independent")
	before = farm.snapshot()
	var harvested: Dictionary = farm.harvest("field_01", "cell_01", START + 1800.0)
	_expect(harvested.ok and harvested.reward_amount == 1 and harvested.changed_fields == ["field_01"], "One cell gives one basket and one field refresh")
	for cell_id: String in Farm.CELL_IDS:
		if cell_id != "cell_01":
			_expect(farm.snapshot().fields.field_01.cells[cell_id] == before.fields.field_01.cells[cell_id], "Harvest preserves neighbouring crops")
	before = farm.snapshot()
	_expect(farm.sow("field_01", "cell_17", "greens", START).reason == "invalid_cell", "Unknown cell rejected")
	_expect(farm.water("field_01", "", START).reason == "invalid_cell", "No implicit whole-field watering")
	_expect(farm.harvest("field_01", "", START).reason == "invalid_cell" and farm.snapshot() == before, "No implicit whole-field harvesting")
	_expect(farm.get_field("missing").is_empty() and farm.get_cell("field_01", "missing").is_empty(), "Missing views are empty")
	var view: Dictionary = farm.get_field("field_01")
	view.cells.cell_02.crop_id = "greens"
	_expect(farm.get_cell("field_01", "cell_02").crop_id == "radish", "Field view is deeply isolated")
	var settled: Dictionary = farm.settle(START + 86400.0)
	_expect(settled.changed_fields.size() == 6, "96 changed cell clocks emit six unique field IDs")


func _test_stages_and_actions() -> void:
	for crop_id: String in Crops.crop_ids():
		var farm := Farm.new(START)
		var duration: float = Crops.definition(crop_id).duration_seconds
		_expect(farm.sow("field_01", "cell_06", crop_id, START).ok, "Sow %s with unlimited seeds" % crop_id)
		_expect(farm.get_cell("field_01", "cell_06").stage == "sprout", "Zero progress is sprout")
		farm.settle(START + duration * 0.35 - 0.01)
		_expect(farm.get_cell("field_01", "cell_06").stage == "sprout", "Below 35 percent stays sprout")
		farm.settle(START + duration * 0.35)
		_expect(farm.get_cell("field_01", "cell_06").stage == "young", "35 percent is young")
		farm.settle(START + duration - 0.01)
		_expect(farm.get_cell("field_01", "cell_06").stage == "young", "Just before maturity stays young")
		var result: Dictionary = farm.harvest("field_01", "cell_06", START + duration)
		_expect(result.ok and result.reward_crop_id == crop_id and result.reward_amount == 1, "Harvest settles exactly to maturity and awards one basket")
		_expect(farm.get_cell("field_01", "cell_06").stage == "empty" and farm.snapshot().harvested[crop_id] == 1, "Harvest clears selected cell")
		_expect(not farm.harvest("field_01", "cell_06", START + duration).ok and farm.snapshot().harvested[crop_id] == 1, "Repeated harvest cannot duplicate rewards")
		_expect(farm.sow("field_01", "cell_06", crop_id, START + duration).ok and not farm.get_cell("field_01", "cell_06").watered, "Next round starts cleanly")
		var moist := Farm.new(START)
		moist.sow("field_01", "cell_01", crop_id, START)
		moist.water("field_01", "cell_01", START + 60.0)
		var benefit: float = Crops.definition(crop_id).water_progress
		_expect(is_equal_approx(moist.get_cell("field_01", "cell_01").growth_seconds, 60.0 + duration * benefit), "Species water benefit applied after old-time settlement")
		var dry := Farm.new(START)
		dry.sow("field_01", "cell_01", crop_id, START)
		moist.settle(START + duration * (1.0 - benefit))
		dry.settle(START + duration * (1.0 - benefit))
		_expect(moist.get_cell("field_01", "cell_01").stage == "mature" and dry.get_cell("field_01", "cell_01").stage != "mature", "Water cuts the configured duration for " + crop_id)
	var watered := Farm.new(START)
	watered.sow("field_01", "cell_06", "greens", START)
	_expect(watered.water("field_01", "cell_06", START + 900.0).ok, "Water action settles old progress first")
	_expect(is_equal_approx(watered.get_cell("field_01", "cell_06").progress, 0.7), "Water adds 20 percent of full duration")
	var before_repeat: Dictionary = watered.snapshot()
	_expect(not watered.water("field_01", "cell_06", START + 1000.0).ok and watered.snapshot() == before_repeat, "Repeated water is a total no-op")
	watered.settle(START + 1440.0)
	_expect(watered.get_cell("field_01", "cell_06").stage == "mature", "One watering reduces greens wait to 24 minutes")
	var near_mature := Farm.new(START)
	near_mature.sow("field_01", "cell_06", "greens", START)
	near_mature.water("field_01", "cell_06", START + 1700.0)
	_expect(near_mature.get_cell("field_01", "cell_06").progress == 1.0, "Water crossing maturity caps at full progress")
	_expect(near_mature.snapshot().harvested.greens == 0, "Maturity never auto-harvests")


func _test_elapsed_time_equivalence() -> void:
	var online := Farm.new(START)
	var offline := Farm.new(START)
	online.sow("field_01", "cell_06", "radish", START)
	offline.sow("field_01", "cell_06", "radish", START)
	for second: int in range(1, 2401):
		online.settle(START + float(second))
	offline.settle(START + 2400.0)
	_expect(online.snapshot() == offline.snapshot(), "2400 online settlements equal one offline settlement")
	online.water("field_01", "cell_06", START + 2400.0)
	offline.water("field_01", "cell_06", START + 2400.0)
	var restored := Farm.new(0.0)
	_expect(restored.restore_snapshot(offline.snapshot()), "Restore saved crop and watering state")
	for second: int in range(2401, 4321):
		online.settle(START + float(second))
	restored.settle(START + 4320.0)
	_expect(online.snapshot() == restored.snapshot(), "Restored offline state matches continued online watering growth")
	_expect(restored.get_cell("field_01", "cell_06").stage == "mature", "Watered radish matures after 72 minutes")
	var once: Dictionary = restored.snapshot()
	restored.settle(START + 4320.0)
	_expect(restored.snapshot() == once, "Repeated settlement at same timestamp is idempotent")


func _test_clock_rollback_and_jump() -> void:
	var farm := Farm.new(START)
	farm.sow("field_01", "cell_06", "greens", START)
	farm.settle(START + 300.0)
	var latest: Dictionary = farm.snapshot()
	farm.settle(START - 3600.0)
	farm.settle(START + 299.0)
	farm.settle(START + 300.0)
	_expect(farm.snapshot() == latest, "Rollback and catch-up preserve newer baseline without extra growth")
	_expect(farm.sow("field_02", "cell_06", "radish", START - 1000.0).ok, "Sowing during rollback is accepted")
	_expect(farm.get_cell("field_02", "cell_06").last_settled_utc_seconds == START + 300.0, "Rollback sowing retains newer empty-field baseline")
	farm.settle(START + 301.0)
	_expect(farm.get_cell("field_01", "cell_06").growth_seconds == 301.0 and farm.get_cell("field_02", "cell_06").growth_seconds == 1.0, "Only time after newer baseline counts")
	var far_future: float = START + 86400.0 * 365.0
	farm.settle(far_future)
	_expect(farm.get_cell("field_01", "cell_06").progress == 1.0 and farm.get_cell("field_02", "cell_06").progress == 1.0, "One-year forward jump caps each current round")
	_expect(Crops.total_harvested(farm.snapshot().harvested) == 0, "Forward jump never awards automatic baskets")
	farm.harvest("field_01", "cell_06", START)
	farm.sow("field_01", "cell_06", "greens", START)
	farm.settle(far_future)
	_expect(farm.get_cell("field_01", "cell_06").growth_seconds == 0.0 and farm.snapshot().harvested.greens == 1, "Harvest and resow under rollback cannot reuse the prior round's time")
	farm.settle(far_future + 1.0)
	_expect(farm.get_cell("field_01", "cell_06").growth_seconds == 1.0, "Clock resumes after catching newer baseline")


func _test_invalid_actions_are_atomic() -> void:
	var farm := Farm.new(START)
	var before: Dictionary = farm.snapshot()
	_expect(not farm.sow("field_01", "cell_06", "unknown", START + 99.0).ok, "Reject invalid crop")
	_expect(not farm.sow("missing", "cell_06", "greens", START + 99.0).ok, "Reject invalid field")
	_expect(not farm.sow("field_04", "cell_06", "greens", START + 99.0).ok, "Reject occupied field")
	_expect(not farm.water("field_01", "cell_06", START + 99.0).ok, "Reject empty-field watering")
	_expect(not farm.water("field_03", "cell_06", START + 99.0).ok, "Reject mature watering")
	_expect(not farm.harvest("field_01", "cell_06", START + 99.0).ok, "Reject empty-field harvest")
	_expect(not farm.harvest("field_04", "cell_06", START + 99.0).ok, "Reject immature harvest")
	_expect(not farm.water("field_04", "cell_06", START + 1800.0).ok, "Water is rejected if old-state settlement already reaches maturity")
	_expect(farm.snapshot() == before, "All failed actions preserve complete authority including timestamps")
	for invalid_time: float in [-1.0, INF, NAN]:
		_expect(not farm.settle(invalid_time).ok and not farm.sow("field_01", "cell_06", "greens", invalid_time).ok, "Reject nonfinite or negative UTC")
	_expect(farm.snapshot() == before and farm.get_cell("missing", "cell_06").is_empty(), "Invalid input cannot mutate farm")


func _test_snapshot_validation() -> void:
	var farm := Farm.new(START)
	var original: Dictionary = farm.snapshot()
	var json_value: Dictionary = JSON.parse_string(JSON.stringify(original))
	_expect(farm.restore_snapshot(json_value), "JSON numeric representation restores valid farm")
	json_value.fields.field_04.cells.cell_06.growth_seconds = 999.0
	_expect(farm.get_cell("field_04", "cell_06").growth_seconds == 360.0, "Restore deep copies nested data")
	var corruptions: Array[Dictionary] = []
	var candidate: Dictionary = original.duplicate(true)
	candidate.fields.erase("field_06")
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_04.cells.cell_06.crop_id = "missing"
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_04.cells.cell_06.growth_seconds = 1800.1
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_01.cells.cell_06.watered = true
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_05.cells.cell_06.watered = true
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_04.cells.cell_06.last_settled_utc_seconds = INF
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.harvested.greens = 0.5
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.harvested.greens = -1
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.harvested.greens = "2"
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.harvested.greens = 9007199254740992
	corruptions.append(candidate)
	for malformed_cell: String in ["missing", "extra", "renamed", "extra_field_key", "legacy_shape"]:
		candidate = original.duplicate(true)
		match malformed_cell:
			"missing": candidate.fields.field_01.cells.erase("cell_16")
			"extra": candidate.fields.field_01.cells.cell_17 = candidate.fields.field_01.cells.cell_01.duplicate()
			"renamed":
				candidate.fields.field_01.cells.unknown = candidate.fields.field_01.cells.cell_16
				candidate.fields.field_01.cells.erase("cell_16")
			"extra_field_key": candidate.fields.field_01.crop_id = "greens"
			"legacy_shape": candidate.fields.field_01 = candidate.fields.field_01.cells.cell_06
		corruptions.append(candidate)
	for broken: Dictionary in corruptions:
		_expect(not farm.restore_snapshot(broken) and farm.snapshot() == original, "Malformed restore preserves prior valid farm")
	candidate = original.duplicate(true)
	candidate.harvested.greens = Farm.MAX_HARVEST_COUNT
	_expect(farm.restore_snapshot(candidate), "Maximum exact count is valid")
	var before_harvest: Dictionary = farm.snapshot()
	_expect(not farm.harvest("field_03", "cell_06", START).ok and farm.snapshot() == before_harvest, "Count overflow cannot lose mature crop")


func _test_variable_fields() -> void:
	var farm := Farm.new(START)
	farm.sow("field_01","cell_06","spinach",START)
	farm.water("field_01","cell_06",START)
	var before: Dictionary = farm.get_cell("field_01","cell_06")
	var plan := Farm.Plan.new()
	plan.fields[0] = Farm.Plan.resized_field(plan.fields[0],5,3,Vector2(3.2,1.61))
	plan.fields[0].yaw = 17.0
	plan.fields[0].position += Vector3(.1,0,.15)
	_expect(plan.fields[0].cells[6]=="cell_06", "New column preserves the occupied row/column ID")
	_expect(farm.apply_layout(plan.snapshot(),START).ok,"Variable rows/columns and moved field accepted")
	_expect(farm.get_cell("field_01","cell_06")==before,"Resizing preserves crop species, water, growth and identity")
	_expect(farm.cell_ids("field_01").size()==15 and farm.get_cell("field_01","cell_17").stage=="empty", "New column starts empty")
	_expect(farm.sow("field_01","cell_17","lettuce",START).ok, "Added IDs are actionable")
	var occupied: Dictionary = farm.snapshot()
	var shrink := Farm.Plan.new()
	_expect(farm.apply_layout(shrink.snapshot(),START+500).reason=="occupied_cell_removed" and farm.snapshot()==occupied,"Shrinking cannot erase a planted new column or advance time")
	plan.fields.reverse()
	_expect(farm.apply_layout(plan.snapshot(),START).ok and farm.field_ids()[5]=="field_01" and farm.get_cell("field_01","cell_06")==before,"Reordering uses IDs, never array indices, for crops")
	var extra: Dictionary = plan.fields[5].duplicate(true)
	extra.id = "field_07"
	extra.position = Vector3(-3.3,.2,6.9)
	plan.fields.append(extra)
	_expect(farm.apply_layout(plan.snapshot(),START).ok and farm.field_ids().size()==7,"Additional field gets independent planting cells")
	_expect(farm.get_cell("field_07","cell_06").crop_id.is_empty(),"New field does not copy crops sharing local cell ID")
	var restored := Farm.new()
	_expect(restored.restore_snapshot(JSON.parse_string(JSON.stringify(farm.snapshot()))),"Variable layout and state restore through JSON")
	_expect(restored.snapshot()==farm.snapshot(),"JSON restores the same normalized spatial and crop state")
	var valid: Dictionary = farm.snapshot()
	for flaw: String in ["missing_layout","duplicate_field","duplicate_cell","zero_rows","huge_rows","tiny_cells","nonfinite","missing_data","extra_data"]:
		var bad: Dictionary = valid.duplicate(true)
		match flaw:
			"missing_layout": bad.erase("layout")
			"duplicate_field": bad.layout.fields[1].id = bad.layout.fields[0].id
			"duplicate_cell": bad.layout.fields[0].cells[1] = bad.layout.fields[0].cells[0]
			"zero_rows": bad.layout.fields[0].rows = 0
			"huge_rows": bad.layout.fields[0].rows = 1000000000
			"tiny_cells": bad.layout.fields[0].size = [.21,.30]
			"nonfinite": bad.layout.fields[0].yaw = NAN
			"missing_data": bad.fields.field_07.cells.erase("cell_06")
			"extra_data": bad.fields.field_07.cells.cell_999 = bad.fields.field_07.cells.cell_06.duplicate()
		_expect(not restored.restore_snapshot(bad) and restored.snapshot()==valid,"Reject malformed variable layout atomically: "+flaw)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
