extends SceneTree
const Plan=preload("res://layout/courtyard_plan.gd")
const Space=preload("res://layout/island_space.gd")
const Construction=preload("res://layout/island_construction.gd")
const Routes=preload("res://layout/player_routes.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
var failures: int=0
var checks: int=0
func expect(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(label)
func _initialize() -> void:
	var plan:=Plan.new()
	expect(plan.supporting_island(Space.rectangle(Vector2(14,-3),Vector2.ONE))==1,"Whole footprint fits the east plateau")
	expect(plan.supporting_island(Space.rectangle(Vector2(-1,-1),Vector2.ONE))==0,"Main island retains its original support")
	expect(plan.supporting_island(Space.rectangle(Vector2(6,-2),Vector2(5,2)))==-1,"An object cannot bridge water by merging both land masses")
	expect(absf(plan.ground_height_at(Vector2(14,-3))-.11)<.0001,"East height uses its bank transform")
	var origin:=Vector3(14,20,-3)
	expect(plan.ground_ray(origin,Vector3.DOWN).distance_to(Vector3(14,.11,-3))<.0001,"Picking intersects the visible east surface")
	var snapshot: Dictionary=plan.snapshot()
	snapshot.fields[0].position=[14.5,.18,-2.5]
	var changed: RefCounted=Plan.from_snapshot(snapshot)
	expect(changed!=null,"East field height is admitted")
	expect(Plan.from_snapshot(JSON.parse_string(JSON.stringify(changed.snapshot()))).snapshot()==changed.snapshot(),"Different island heights survive JSON round trip")
	snapshot.fields[0].position[1]=.2
	expect(Plan.from_snapshot(snapshot)==null,"Wrong main height is rejected for an east field")
	snapshot=plan.snapshot();snapshot.construction.buildings.kitchen=[14,-3,90]
	snapshot.construction.trellis=[2.4,.8,2.2,15,-1,0]
	changed=Plan.from_snapshot(snapshot)
	expect(absf(changed.anchors.kitchen.y-.095)<.0001,"Kitchen retains its authored ground offset on east island")
	expect(absf(changed.anchors.trellis.y-.11)<.0001,"Trellis derives east soil height")
	var old_delta: Vector3=plan.slots.hanging_04-plan.anchors.kitchen
	var new_delta: Vector3=changed.slots.hanging_04-changed.anchors.kitchen
	expect(new_delta.distance_to(Basis(Vector3.UP,PI/2)*old_delta)<.0001,"Kitchen hanging support follows full rigid movement including height")
	expect(absf(changed.slots.hanging_03.y-(.11+2.2-.3))<.0001,"Trellis hanging height follows its east base")
	changed.routes=[{"id":1,"kind":"road","points":[[14,-3],[15,-3]],"openings":[]}]
	expect(Routes.terrain_issue(changed).is_empty(),"Road may be fully supported by east island")
	changed.routes=[{"id":1,"kind":"fence","points":[[7,-2],[11,-2]],"openings":[]}]
	expect(not Routes.terrain_issue(changed).is_empty(),"Fence may not bridge a water gap")
	var circulation:=Circulation.new();circulation._plan=plan
	circulation._add_route(PackedVector2Array([Vector2(5,-2),Vector2(14,-2)]))
	var both: Dictionary={};var correct: bool=true
	for line: PackedVector3Array in plan.paths:
		var midpoint: Vector3=(line[0]+line[-1])*.5
		var island: int=1 if midpoint.x>10 else 0;both[island]=true
		for p: Vector3 in line:
			if absf(p.y-(.095 if island==1 else .115))>.001: correct=false
	expect(both.size()==2 and correct,"Automatic paving splits at water and keeps each island's own height")
	print("MULTI_ISLAND_SPACE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
