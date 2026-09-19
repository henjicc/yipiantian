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
