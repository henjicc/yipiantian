extends SceneTree

const Farm = preload("res://farm/farm_state.gd")
const Crops = preload("res://farm/crop_catalog.gd")
const START: float = 1800000000.0

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_initial_state_and_isolation()
	_test_stages_and_actions()
	_test_elapsed_time_equivalence()
	_test_clock_rollback_and_jump()
	_test_invalid_actions_are_atomic()
	_test_snapshot_validation()
	for failure: String in failures:
		push_error(failure)
	print("FARM_STATE_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_initial_state_and_isolation() -> void:
	var farm := Farm.new(START)
	var initial: Dictionary = farm.snapshot()
	_expect(initial.fields.size() == 6, "Six stable fields")
	_expect(initial.harvested == {"greens": 0, "radish": 0}, "Tutorial crops do not award baskets automatically")
	_expect(farm.get_field("field_01").stage == "empty" and farm.get_field("field_02").stage == "empty", "Two initial empty fields")
	_expect(farm.get_field("field_03").stage == "mature", "First harvest available immediately")
	_expect(is_equal_approx(farm.get_field("field_04").progress, 0.2), "Initial greens progress")
	_expect(is_equal_approx(farm.get_field("field_05").progress, 0.1) and is_equal_approx(farm.get_field("field_06").progress, 0.6), "Initial radish progress")
	for field: Dictionary in initial.fields.values():
		_expect(not field.watered and field.last_settled_utc_seconds == START, "Fresh fields share injected baseline and are unwatered")
	initial.fields.field_03.crop_id = "invalid"
	initial.harvested.greens = 999
	var view: Dictionary = farm.get_field("field_03")
	view.growth_seconds = 0.0
	_expect(farm.get_field("field_03").stage == "mature" and farm.snapshot().harvested.greens == 0, "Returned views cannot mutate authority")
	var definition: Dictionary = Crops.definition("greens")
	definition.duration_seconds = 1.0
	farm.harvest("field_03", START)
	farm.sow("field_03", "greens", START)
	farm.water("field_03", START)
	_expect(Crops.definition("greens").duration_seconds == 1800.0 and is_equal_approx(farm.get_field("field_03").progress, 0.2), "Definition edits and player actions cannot rewrite crop configuration")


func _test_stages_and_actions() -> void:
	for crop_id: String in Crops.crop_ids():
		var farm := Farm.new(START)
		var duration: float = Crops.definition(crop_id).duration_seconds
		_expect(farm.sow("field_01", crop_id, START).ok, "Sow %s with unlimited seeds" % crop_id)
		_expect(farm.get_field("field_01").stage == "sprout", "Zero progress is sprout")
		farm.settle(START + duration * 0.35 - 0.01)
		_expect(farm.get_field("field_01").stage == "sprout", "Below 35 percent stays sprout")
		farm.settle(START + duration * 0.35)
		_expect(farm.get_field("field_01").stage == "young", "35 percent is young")
		farm.settle(START + duration - 0.01)
		_expect(farm.get_field("field_01").stage == "young", "Just before maturity stays young")
		var result: Dictionary = farm.harvest("field_01", START + duration)
		_expect(result.ok and result.reward_crop_id == crop_id and result.reward_amount == 1, "Harvest settles exactly to maturity and awards one basket")
		_expect(farm.get_field("field_01").stage == "empty" and farm.snapshot().harvested[crop_id] == 1, "Harvest clears entire field")
		_expect(not farm.harvest("field_01", START + duration).ok and farm.snapshot().harvested[crop_id] == 1, "Repeated harvest cannot duplicate rewards")
		_expect(farm.sow("field_01", crop_id, START + duration).ok and not farm.get_field("field_01").watered, "Next round starts cleanly")
	var watered := Farm.new(START)
	watered.sow("field_01", "greens", START)
	_expect(watered.water("field_01", START + 900.0).ok, "Water action settles old progress first")
	_expect(is_equal_approx(watered.get_field("field_01").progress, 0.7), "Water adds 20 percent of full duration")
	var before_repeat: Dictionary = watered.snapshot()
	_expect(not watered.water("field_01", START + 1000.0).ok and watered.snapshot() == before_repeat, "Repeated water is a total no-op")
	watered.settle(START + 1440.0)
	_expect(watered.get_field("field_01").stage == "mature", "One watering reduces greens wait to 24 minutes")
	var near_mature := Farm.new(START)
	near_mature.sow("field_01", "greens", START)
	near_mature.water("field_01", START + 1700.0)
	_expect(near_mature.get_field("field_01").progress == 1.0, "Water crossing maturity caps at full progress")
	_expect(near_mature.snapshot().harvested.greens == 0, "Maturity never auto-harvests")


func _test_elapsed_time_equivalence() -> void:
	var online := Farm.new(START)
	var offline := Farm.new(START)
	online.sow("field_01", "radish", START)
	offline.sow("field_01", "radish", START)
	for second: int in range(1, 2401):
		online.settle(START + float(second))
	offline.settle(START + 2400.0)
	_expect(online.snapshot() == offline.snapshot(), "2400 online settlements equal one offline settlement")
	online.water("field_01", START + 2400.0)
	offline.water("field_01", START + 2400.0)
	var restored := Farm.new(0.0)
	_expect(restored.restore_snapshot(offline.snapshot()), "Restore saved crop and watering state")
	for second: int in range(2401, 4321):
		online.settle(START + float(second))
	restored.settle(START + 4320.0)
	_expect(online.snapshot() == restored.snapshot(), "Restored offline state matches continued online watering growth")
	_expect(restored.get_field("field_01").stage == "mature", "Watered radish matures after 72 minutes")
	var once: Dictionary = restored.snapshot()
	restored.settle(START + 4320.0)
	_expect(restored.snapshot() == once, "Repeated settlement at same timestamp is idempotent")


func _test_clock_rollback_and_jump() -> void:
	var farm := Farm.new(START)
	farm.sow("field_01", "greens", START)
	farm.settle(START + 300.0)
	var latest: Dictionary = farm.snapshot()
	farm.settle(START - 3600.0)
	farm.settle(START + 299.0)
	farm.settle(START + 300.0)
	_expect(farm.snapshot() == latest, "Rollback and catch-up preserve newer baseline without extra growth")
	_expect(farm.sow("field_02", "radish", START - 1000.0).ok, "Sowing during rollback is accepted")
	_expect(farm.get_field("field_02").last_settled_utc_seconds == START + 300.0, "Rollback sowing retains newer empty-field baseline")
	farm.settle(START + 301.0)
	_expect(farm.get_field("field_01").growth_seconds == 301.0 and farm.get_field("field_02").growth_seconds == 1.0, "Only time after newer baseline counts")
	var far_future: float = START + 86400.0 * 365.0
	farm.settle(far_future)
	_expect(farm.get_field("field_01").progress == 1.0 and farm.get_field("field_02").progress == 1.0, "One-year forward jump caps each current round")
	_expect(farm.snapshot().harvested == {"greens": 0, "radish": 0}, "Forward jump never awards automatic baskets")
	farm.harvest("field_01", START)
	farm.sow("field_01", "greens", START)
	farm.settle(far_future)
	_expect(farm.get_field("field_01").growth_seconds == 0.0 and farm.snapshot().harvested.greens == 1, "Harvest and resow under rollback cannot reuse the prior round's time")
	farm.settle(far_future + 1.0)
	_expect(farm.get_field("field_01").growth_seconds == 1.0, "Clock resumes after catching newer baseline")


func _test_invalid_actions_are_atomic() -> void:
	var farm := Farm.new(START)
	var before: Dictionary = farm.snapshot()
	_expect(not farm.sow("field_01", "unknown", START + 99.0).ok, "Reject invalid crop")
	_expect(not farm.sow("missing", "greens", START + 99.0).ok, "Reject invalid field")
	_expect(not farm.sow("field_04", "greens", START + 99.0).ok, "Reject occupied field")
	_expect(not farm.water("field_01", START + 99.0).ok, "Reject empty-field watering")
	_expect(not farm.water("field_03", START + 99.0).ok, "Reject mature watering")
	_expect(not farm.harvest("field_01", START + 99.0).ok, "Reject empty-field harvest")
	_expect(not farm.harvest("field_04", START + 99.0).ok, "Reject immature harvest")
	_expect(not farm.water("field_04", START + 1800.0).ok, "Water is rejected if old-state settlement already reaches maturity")
	_expect(farm.snapshot() == before, "All failed actions preserve complete authority including timestamps")
	for invalid_time: float in [-1.0, INF, NAN]:
		_expect(not farm.settle(invalid_time).ok and not farm.sow("field_01", "greens", invalid_time).ok, "Reject nonfinite or negative UTC")
	_expect(farm.snapshot() == before and farm.get_field("missing").is_empty(), "Invalid input cannot mutate farm")


func _test_snapshot_validation() -> void:
	var farm := Farm.new(START)
	var original: Dictionary = farm.snapshot()
	var json_value: Dictionary = JSON.parse_string(JSON.stringify(original))
	_expect(farm.restore_snapshot(json_value), "JSON numeric representation restores valid farm")
	json_value.fields.field_04.growth_seconds = 999.0
	_expect(farm.get_field("field_04").growth_seconds == 360.0, "Restore deep copies nested data")
	var corruptions: Array[Dictionary] = []
	var candidate: Dictionary = original.duplicate(true)
	candidate.fields.erase("field_06")
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_04.crop_id = "missing"
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_04.growth_seconds = 1800.1
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_01.watered = true
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_05.watered = true
	corruptions.append(candidate)
	candidate = original.duplicate(true)
	candidate.fields.field_04.last_settled_utc_seconds = INF
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
	for broken: Dictionary in corruptions:
		_expect(not farm.restore_snapshot(broken) and farm.snapshot() == original, "Malformed restore preserves prior valid farm")
	candidate = original.duplicate(true)
	candidate.harvested.greens = Farm.MAX_HARVEST_COUNT
	_expect(farm.restore_snapshot(candidate), "Maximum exact count is valid")
	var before_harvest: Dictionary = farm.snapshot()
	_expect(not farm.harvest("field_03", START).ok and farm.snapshot() == before_harvest, "Count overflow cannot lose mature crop")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
