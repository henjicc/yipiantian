extends Node3D
const Routes=preload("res://layout/player_routes.gd")
const Fence=preload("res://layout/fence_geometry.gd")
var roads: Node3D
var fence: Node3D
var _stones: Dictionary={}
var _spans: Array[Dictionary]=[]
var _style: String=""

func update(plan: RefCounted, environment: Node3D) -> void:
	if roads==null:
		roads=Node3D.new();roads.name="Roads";roads.set_meta("garden_paths",true);add_child(roads)
	var wanted: Dictionary={}
	for p: Vector2 in Routes.road_points(plan.routes):
		wanted[p]=true
		if not _stones.has(p):
			var rng:=RandomNumberGenerator.new();rng.seed=hash(p)
			var stone: Node3D=environment.make_path_stone(Vector3(p.x,plan.ground_height_at(p)-.015,p.y),rng)
			roads.add_child(stone);_stones[p]=stone
	for key: Vector2 in _stones.keys():
		if not wanted.has(key): _stones[key].free();_stones.erase(key)
		else: _stones[key].position.y=plan.ground_height_at(key)-.015
	var spans: Array[Dictionary]=Routes.fence_spans(plan.routes,plan.ground_height)
	for span: Dictionary in spans:
		span.a.y=plan.ground_height_at(Vector2(span.a.x,span.a.z))
		span.b.y=plan.ground_height_at(Vector2(span.b.x,span.b.z))
	if spans!=_spans or _style!=plan.fence_style:
		if is_instance_valid(fence): fence.free()
		fence=Fence.build(spans,plan.fence_style);fence.name="Fences";add_child(fence)
		_spans=spans;_style=plan.fence_style
