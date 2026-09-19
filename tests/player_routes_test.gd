extends SceneTree
const Routes=preload("res://layout/player_routes.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
const Space=preload("res://scenes/environment/animal_space.gd")
var failures: int=0
var checks: int=0
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures+=1;push_error(message)
func _initialize() -> void:
	var entries: Array=[{"id":1,"kind":"road","points":[[-2,7],[2,7]],"openings":[]},{"id":2,"kind":"fence","points":[[0,5],[0,9]],"openings":[]}]
	expect(Routes.valid(entries),"Valid crossing lines")
	var spans: Array[Dictionary]=Routes.fence_spans(entries,.13)
	var space:=Space.new();space.configure(Rect2(-3,4,6,6),.21)
	for span: Dictionary in spans:
		expect(not (span.a.z<7 and span.b.z>7),"Road crossing has no fence rail")
		space.block(Routes.strip(Vector2(span.a.x,span.a.z),Vector2(span.b.x,span.b.z),.08,.07))
	space.bake()
	expect(space.contains(Vector2(0,7)),"Road opening is traversable at animal radius")
	expect(not space.contains(Vector2(0,6)),"Fence actually blocks animal navigation")
	expect(not space.path(Vector2(-1,7),Vector2(1,7)).is_empty(),"Animal can find a route through the opening")
	entries[0].points=[[-2,5],[2,9]]
	for span: Dictionary in Routes.fence_spans(entries,.13):
		expect(not (span.a.z<7.7 and span.b.z>6.3),"Oblique road crossing leaves full-width opening")
	entries.remove_at(0);entries[0].openings=[[0,7]]
	expect(Routes.valid(entries),"Explicit gate is on its fence")
	for span: Dictionary in Routes.fence_spans(entries,.13):
		expect(not (span.a.z<7.64 and span.b.z>6.36),"Manual gate removes actual rails")
	entries[0].openings=[[2,7]]
	expect(not Routes.valid(entries),"Off-fence gate rejected")
	entries[0].openings=[]
	entries.append(entries[0].duplicate(true));expect(not Routes.valid(entries),"Duplicate identity rejected");entries.remove_at(1)
	entries[0].points[0]=[NAN,0];expect(not Routes.valid(entries),"Nonfinite geometry rejected")
	entries[0].points=[[0,5],[0,9]]
	var plan:=Plan.new();var construction: Dictionary=plan.construction.duplicate(true);construction.land=[[-3,5,5,5]];plan.apply_construction(construction)
	plan.routes=Routes.canonical(entries)
	expect(Routes.terrain_issue(plan).is_empty(),"Full fence supported by expanded terrain")
	var restored: RefCounted=Plan.from_snapshot(JSON.parse_string(JSON.stringify(plan.snapshot())))
	expect(restored!=null and restored.routes==plan.routes,"Route identity, line and openings survive JSON admission")
	expect(preload("res://layout/courtyard_presets.gd").arrange(plan,"original").routes==plan.routes,"Preset retains authored lines")
	expect(not Routes.placement_issue(plan,{"object":Routes.strip(Vector2(-1,7),Vector2(1,7),.5)}).is_empty(),"Fence cannot cut through existing object")
	var closed: Dictionary=plan.route_footprints().duplicate(true)
	plan.routes[0].openings=[[0.0,7.0]]
	expect(plan.route_footprints()!=closed,"Opening change invalidates the plan's cached solid fence")
	plan.construction.flocks.hen={"count":4,"area":[-2.0,6.0,3.0,3.0]}
	var area: PackedVector2Array=preload("res://layout/island_space.gd").rectangle(Vector2(-2,6),Vector2(3,3))
	expect(preload("res://layout/flock_layout.gd").land_issue(plan,{"player_road_test":area}).is_empty(),"Roads remain usable inside a configured hen area")
	expect(not preload("res://layout/flock_layout.gd").land_issue(plan,{"player_fence_test":area}).is_empty(),"Solid obstacles still protect configured hen capacity")
	plan.routes[0].points=[[20,20],[21,20]]
	expect(not Routes.terrain_issue(plan).is_empty(),"Whole route requires land support")
	var joined: Array=[{"id":1,"kind":"fence","points":[[-2,0],[2,0]],"openings":[]},{"id":2,"kind":"fence","points":[[0,0],[0,2]],"openings":[]}]
	var touching: int=0
	for span: Dictionary in Routes.fence_spans(joined,0):
		if span.a==Vector3.ZERO or span.b==Vector3.ZERO: touching+=1
	expect(touching==3,"T junction spans terminate at one shared post")
	joined[0].kind="road";joined[1].kind="road"
	var points: PackedVector2Array=Routes.road_points(joined)
	var separated: bool=true
	for i: int in points.size():
		for j: int in range(i+1,points.size()): separated=separated and points[i].distance_to(points[j])>=.2699
	expect(separated,"Crossing roads do not stack nearby stone instances")
	var many: Array=[]
	for i: int in 16:
		var line: Array=[]
		for j: int in 16: line.append([float(i)*.5,float(j)*.5])
		many.append({"id":i+1,"kind":"fence","points":line,"openings":[]})
	expect(Routes.valid(many),"256 points admitted within line and length limits")
	var started: int=Time.get_ticks_usec()
	var dense: Array[Dictionary]=Routes.fence_spans(many,0)
	print("ROUTE_256_POINTS_GEOMETRY_US ",Time.get_ticks_usec()-started)
	expect(dense.size()==240,"Dense valid network has all fence segments")
	many.append({"id":17,"kind":"fence","points":[[9,0],[9,1]],"openings":[]})
	expect(not Routes.valid(many),"Point limit prevents unbounded geometry")
	print("PLAYER_ROUTES checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
