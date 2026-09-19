extends RefCounted
## Shared walkable bank union and waterfowl clearance for the editable bridge.
const Construction=preload("res://layout/island_construction.gd")
const Space=preload("res://layout/island_space.gd")
const Navigation=preload("res://scenes/environment/animal_space.gd")
# Current full-size goose reaches Y=.24 while swimming; include bob and head room.
const WATER_TOP: float=.30
const WATER_RADIUS: float=.46

static func strip(a: Vector2,b: Vector2,width: float) -> PackedVector2Array:
	var side: Vector2=(b-a).normalized().orthogonal()*width*.5
	return PackedVector2Array([a-side,b-side,b+side,a+side])

static func is_bridge(key: String) -> bool:
	return key in ["AdaptiveBridge","AuthoredBridge"]

static func deck_strip(plan: RefCounted) -> PackedVector2Array:
	var ends: Array[Vector3]=Construction.bridge_points(plan)
	return strip(Vector2(ends[0].x,ends[0].z),Vector2(ends[1].x,ends[1].z),Construction.bridge_parameters(plan)[4]-.072)

static func outline(plan: RefCounted, clearance: float) -> PackedVector2Array:
	var ground: PackedVector2Array=plan.plateau()
	for part: PackedVector2Array in [deck_strip(plan),Construction.bridge_support(plan,1)]:
		var merged: Array[PackedVector2Array]=Geometry2D.merge_polygons(ground,part)
		if merged.size()!=1: return PackedVector2Array()
		ground=merged[0]
	if clearance==0: return ground
	var inner: Array[PackedVector2Array]=Geometry2D.offset_polygon(ground,-clearance)
	return inner[0] if inner.size()==1 else PackedVector2Array()

static func bounds(plan: RefCounted) -> Rect2:
	var result: Rect2=plan.land_bounds()
	for point: Vector2 in Construction.bridge_support(plan,1): result=result.expand(point)
	return result

static func approach_issue(plan: RefCounted, obstacles: Dictionary) -> String:
	for approach: PackedVector2Array in Construction.bridge_approaches(plan):
		for key: String in obstacles:
			if is_bridge(key) or key.begins_with("player_road_"): continue
			if Space.overlaps(approach,obstacles[key]): return "桥头出口被挡住了，请为整座桥的宽度留出通路。"
		for i: int in plan.fields.size():
			if Space.overlaps(approach,plan.field_polygon(i,.12)): return "桥头出口碰到了田地，请留出通路。"
	return ""

static func dressing_overlap(plan: RefCounted, deck: PackedVector2Array, dressing: PackedVector2Array) -> bool:
	if Space.overlaps(deck,dressing): return true
	for approach: PackedVector2Array in Construction.bridge_approaches(plan):
		if Space.overlaps(approach,dressing): return true
	return false

static func supports(plan: RefCounted) -> PackedVector3Array:
	var ends: Array[Vector3]=Construction.bridge_points(plan)
	var direction:=Vector3(ends[1].x-ends[0].x,0,ends[1].z-ends[0].z)
	var spans: int=ceili(direction.length()/.9)
	var side: Vector3=Vector3.UP.cross(direction.normalized())
	var result:=PackedVector3Array()
	for edge: float in [-1.0,1.0]:
		for i: int in range(2,spans,2):
			result.append(Construction.bridge_profile(ends,Construction.bridge_style(plan),float(i)/spans)+side*edge*plan.construction.bridge[4]*.5)
	return result

static func water_shapes(plan: RefCounted) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	if plan.construction.bridge.is_empty(): return _stone_water_shapes(plan)
	for support: Vector3 in supports(plan):
		result.append(Space.rectangle(Vector2(support.x,support.z)-Vector2.ONE*.055,Vector2.ONE*.11))
	var ends: Array[Vector3]=Construction.bridge_points(plan)
	var a:=Vector2(ends[0].x,ends[0].z);var b:=Vector2(ends[1].x,ends[1].z)
	var pieces: int=ceili(a.distance_to(b)/.22)
	var first: int=-1
	for i: int in pieces+1:
		var low: bool=false
		if i<pieces:
			var y0: float=Construction.bridge_profile(ends,Construction.bridge_style(plan),float(i)/pieces).y
			var y1: float=Construction.bridge_profile(ends,Construction.bridge_style(plan),float(i+1)/pieces).y
			low=minf(y0,y1)-.075<WATER_TOP
		if low and first<0: first=i
		if not low and first>=0:
			var direction: Vector2=(b-a).normalized()*.02
			result.append(strip(a.lerp(b,float(first)/pieces)-direction,a.lerp(b,float(i)/pieces)+direction,plan.construction.bridge[4]+.02))
			first=-1
	return result

static func water_issue(plan: RefCounted, obstacles: Array[PackedVector2Array]) -> String:
	return "桥下没有足够通行空间，请调整位置、跨度或桥型。" if water_crossing(plan,obstacles).is_empty() else ""

static func plan_water_issue(plan: RefCounted, obstacles: Dictionary) -> String:
	var shapes: Array[PackedVector2Array]=plan.water_banks()
	shapes.append_array(water_shapes(plan))
	for key: String in obstacles:
		if not is_bridge(key) and not key.begins_with("player_road_"): shapes.append(obstacles[key])
	return water_issue(plan,shapes)

static func water_crossing(plan: RefCounted, obstacles: Array[PackedVector2Array]) -> PackedVector2Array:
	var ends: Array[Vector3]=Construction.bridge_points(plan)
	var a:=Vector2(ends[0].x,ends[0].z);var b:=Vector2(ends[1].x,ends[1].z)
	var water:=Navigation.new();water.configure(Rect2(a,Vector2.ZERO).expand(b).grow(2),WATER_RADIUS)
	for shape: PackedVector2Array in obstacles: water.block(shape)
	var side: Vector2=(b-a).normalized().orthogonal()*(Construction.bridge_parameters(plan)[4]*.5+.8)
	for i: int in range(1,64):
		var center: Vector2=a.lerp(b,float(i)/64)
		if water.clear_segment(center-side,center+side): return PackedVector2Array([center-side,center+side])
	return PackedVector2Array()

static func _stone_water_shapes(plan: RefCounted) -> Array[PackedVector2Array]:
	# Same 22 masonry sections as ArtSource/Environment/build_modules.py.
	# Full end strips also enclose its paired abutments; the arch stays open.
	var pose:=Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles.bridge)),plan.anchors.bridge)
	var result: Array[PackedVector2Array]=[]
	for i: int in 22:
		var x0: float=-2.3+4.6*i/22;var x1: float=-2.3+4.6*(i+1)/22
		var y0: float=plan.anchors.bridge.y+.20+1.05*sin(PI*(x0/4.6+.5))-.48-.035
		var y1: float=plan.anchors.bridge.y+.20+1.05*sin(PI*(x1/4.6+.5))-.48-.035
		if minf(y0,y1)>=WATER_TOP: continue
		var centre: Vector3=pose*Vector3((x0+x1)*.5,0,0)
		result.append(Space.footprint(Vector2(x1-x0+.03,2.0),Transform3D(pose.basis,centre)))
	return result
