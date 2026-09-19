extends SceneTree
const Plants=preload("res://layout/plantings.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
const Display=preload("res://presentation/player_plants.gd")
var failures: int=0
var checks: int=0
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if OS.get_cmdline_user_args().has("--shore"):
		if DisplayServer.get_name()=="headless":
			push_error("Shore MultiMesh transform checks require the real rendering backend; omit --headless.");quit(1);return
		shore_checks();print("SHORE_PLANTS checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1);return
	var plan:=Plan.new()
	for kind: String in Plants.KINDS: plan.plants.append(Plants.make_entry(plan.plants.size()+1,kind,Vector2(-10,7)))
	var encoded: Dictionary=plan.snapshot()
	var restored: RefCounted=Plan.from_snapshot(JSON.parse_string(JSON.stringify(encoded)))
	expect(restored!=null and restored.snapshot()==encoded,"Four species survive exact JSON round trip")
	var arranged: RefCounted=preload("res://layout/courtyard_presets.gd").arrange(plan,"front")
	expect(arranged.plants==plan.plants,"Existing courtyard presets preserve player planting")
	var editor:=preload("res://ui/courtyard_editor.gd").new();root.add_child(editor)
	editor.present(encoded,{},{});editor._values.west.value=2.5
	expect(editor.draft.plants==plan.plants,"Existing courtyard expansion controls preserve player planting")
	editor.free()
	for mutation: Dictionary in [{"id":1.5},{"id":0},{"id":INF},{"kind":"tree"},{"pose":[0,0,NAN,1]},{"pose":[0,0,360,1]},{"pose":[0,0,0,4]},{"pose":[31,0,0,1]},{"extra":true}]:
		var bad: Dictionary=encoded.duplicate(true);bad.plants[0].merge(mutation,true)
		expect(Plan.from_snapshot(bad)==null,"Malformed persisted plant rejected: "+str(mutation))
	var bad: Dictionary=encoded.duplicate(true);bad.plants[1].id=bad.plants[0].id
	expect(Plan.from_snapshot(bad)==null,"Duplicate plant identity rejected")
	bad=encoded.duplicate(true);bad.plants=[]
	for i: int in Plants.MAX_CLUMPS+1: bad.plants.append(Plants.make_entry(i+1,"trapa",Vector2(i*.1,10)))
	expect(Plan.from_snapshot(bad)==null,"Unbounded imported clump count rejected")
	var sparse: PackedVector2Array=Plants.brush_points(Vector2(-4,9),3,1,"lotus")
	var dense: PackedVector2Array=Plants.brush_points(Vector2(-4,9),3,3,"lotus")
	expect(dense.size()>sparse.size(),"Density changes how much of the region is planted")
	var nested: bool=true
	for point: Vector2 in sparse: nested=nested and point in dense
	expect(nested,"Increasing density keeps earlier world positions")
	expect(dense==Plants.brush_points(Vector2(-4,9),3,3,"lotus"),"Same brush region is deterministic")
	var entries: Array=[]
	for i: int in 160: entries.append(Plants.make_entry(i+1,"trapa" if i%2==0 else "lotus",Vector2(i%16-8,i/16-5)*.47))
	var occupied: Dictionary=Plants.index_entries(entries)
	var mismatches: int=0
	for tolerance: float in [0,.001]:
		for kind: String in ["trapa","lotus"]:
			for i: int in 200:
				var candidate: Dictionary=Plants.make_entry(999,kind,Vector2(i%20-10,i/20-5)*.49+Vector2(.03,.17))
				var expected: bool=false
				for entry: Dictionary in entries:
					var gap: float=(.32 if kind=="trapa" and entry.kind=="trapa" else .5)-tolerance
					expected=expected or Plants.position(candidate).distance_to(Plants.position(entry))<gap
				if Plants.too_close(candidate,occupied,tolerance)!=expected: mismatches+=1
	expect(mismatches==0,"Spatial clump spacing matches exhaustive clearance across 800 mixed-kind queries")
	var single: Dictionary=Plants.make_entry(1,"trapa",Vector2(-.5,-.5))
	var one: Dictionary=Plants.index_entries([single])
	expect(not Plants.too_close(single,one),"A moving clump never collides with its own identity")
	Plants.index_entry(one,Plants.make_entry(2,"trapa",Vector2(-.2,-.5)))
	expect(Plants.too_close(single,one),"New clumps enter the brush spacing index immediately")
	var banks: Array[PackedVector2Array]=plan.water_banks()
	expect(not Plants.habitat_issue(Plants.make_entry(1,"lotus",Vector2.ZERO),plan,banks).is_empty(),"Dry land rejects aquatic plants")
	expect(not Plants.habitat_issue(Plants.make_entry(1,"reed",Vector2(-10,12)),plan,banks).is_empty(),"Deep water rejects emergent reeds")
	for kind: String in Plants.KINDS:
		for tier: String in ["high","low"]:
			var data: Dictionary=Display.source(kind,tier)
			var bounds: AABB=data.mesh.get_aabb()
			var extent: Vector2=Plants.EXTENTS[kind]*.5
			expect(bounds.position.x>=-extent.x-.01 and bounds.end.x<=extent.x+.01 and bounds.position.z>=-extent.y-.01 and bounds.end.z<=extent.y+.01,"Protected footprint contains source mesh: "+kind+"_"+tier)
	print("PLANTINGS checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

func shore_checks() -> void:
	var dressing=preload("res://presentation/shore_dressing.gd")
	var plan:=Plan.new()
	var construction: Dictionary=plan.construction.duplicate(true)
	construction.land=[[0,5,2,3]]
	construction.east_land=[[15,-5,4,4],[18,-5,4,4],[15,-2,4,3],[18,-2,4,3]]
	expect(plan.apply_construction(construction),"Two-island shore fixture has valid connected land")
	var raw: Dictionary={"reed":[],"trapa":[]}
	for island: int in 2: dressing._add_plants(plan,island,raw)
	expect(not raw.reed.is_empty() and not raw.trapa.is_empty(),"Both automatic species are present in the shore fixture")
	var base: Dictionary=compare_shore_plants(plan)
	for i: int in Plants.MAX_CLUMPS:
		var entry: Dictionary=Plants.make_entry(i+1,Plants.KINDS[i%4],Vector2(-20+(i%16)*.5,15+floori(i/16.0)*.5))
		entry.pose[2]=fposmod(i*37.0,360);entry.pose[3]=.8+(i%5)*.1
		plan.plants.append(entry)
	expect(compare_shore_plants(plan)==base,"A full distant player garden leaves automatic shore poses intact")
	# Rotated mixed species on both shores must displace automatic plants.
	# Their real footprints, not just their centres, determine exclusions.
	var count: int=mini(raw.reed.size(),Plants.MAX_CLUMPS)
	for i: int in count:
		var at: Vector3=raw.reed[i].origin
		plan.plants[i].pose[0]=at.x+.08;plan.plants[i].pose[1]=at.z-.06
	var occupied: Dictionary=compare_shore_plants(plan)
	expect(occupied.reed.size()<base.reed.size(),"Hand-placed plants still take priority over automatic reeds")
	for i: int in count:
		plan.plants[i].pose[0]=-20+(i%16)*.5;plan.plants[i].pose[1]=15+floori(i/16.0)*.5
	expect(compare_shore_plants(plan)==base,"Moving player clumps away restores the same automatic poses")
	plan.plants.clear()
	expect(compare_shore_plants(plan)==base,"Removing player clumps does not leave stale shore exclusions")

func compare_shore_plants(plan: RefCounted) -> Dictionary:
	var dressing=preload("res://presentation/shore_dressing.gd")
	var expected: Dictionary={"reed":[],"trapa":[]}
	for island: int in 2: dressing._add_plants(plan,island,expected)
	var started: int=Time.get_ticks_usec()
	for species: String in expected:
		for i: int in range(expected[species].size()-1,-1,-1):
			var footprint: PackedVector2Array=Plants.Space.footprint(Plants.EXTENTS[species],expected[species][i],.06)
			if Plants.overlaps_player(footprint,plan.plants): expected[species].remove_at(i)
	var exhaustive_ms: float=(Time.get_ticks_usec()-started)/1000.0
	started=Time.get_ticks_usec()
	var shown: Node3D=dressing.plants(plan)
	var bounded_ms: float=(Time.get_ticks_usec()-started)/1000.0
	var actual: Dictionary={"reed":[],"trapa":[]};var matches: bool=true
	for batch: MultiMeshInstance3D in shown.get_children():
		for i: int in batch.multimesh.instance_count: actual[String(batch.name)].append(batch.multimesh.get_instance_transform(i))
	for species: String in expected:
		matches=matches and actual[species].size()==expected[species].size()
		for i: int in mini(actual[species].size(),expected[species].size()):
			matches=matches and actual[species][i].is_equal_approx(expected[species][i])
	expect(matches,"Batched shore transforms match exhaustive player-footprint filtering")
	print("SHORE_FILTER_SAMPLE ",{"players":plan.plants.size(),"exhaustive_filter_ms":exhaustive_ms,"bounded_full_build_ms":bounded_ms,"counts":[actual.reed.size(),actual.trapa.size()]})
	shown.free();return actual
