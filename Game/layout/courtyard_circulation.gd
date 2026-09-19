extends RefCounted
## Derived paths and fence spans. No saved nodes, crops or per-frame navigation.
const Space = preload("res://scenes/environment/animal_space.gd")
var road := Space.new()
var endpoints: Dictionary = {}
var issues: Array[String] = []
var _network := PackedVector2Array()
var _plan: RefCounted

static func field_placement_issues(plan: RefCounted, obstacles: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var plateau: PackedVector2Array = plan.plateau()
	for i: int in plan.fields.size():
		var field: Dictionary = plan.fields[i]
		var polygon: PackedVector2Array = plan.field_polygon(i,.14)
		if not Geometry2D.clip_polygons(polygon,plateau).is_empty(): result.append(field.id+":outside_ground")
		for j: int in i:
			if not Geometry2D.intersect_polygons(polygon,plan.field_polygon(j,.14)).is_empty(): result.append(field.id+":overlaps:"+plan.fields[j].id)
		for key: String in obstacles:
			if not Geometry2D.intersect_polygons(polygon,obstacles[key]).is_empty(): result.append(field.id+":overlaps:"+key)
	return result

func build(plan: RefCounted, obstacles: Dictionary) -> void:
	_plan = plan
	plan.paths.clear()
	plan.fences.clear()
	issues.clear()
	endpoints.clear()
	_network.clear()
	var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(plan.plateau(),-.25)
	if inner.is_empty():
		issues.append("island_too_small")
		return
	road = Space.new()
	road.configure(plan.land_bounds(),.22,inner[0])
	for polygon: PackedVector2Array in obstacles.values(): road.block(polygon)
	for i: int in plan.fields.size(): road.block(plan.field_polygon(i,.035))
	road.bake()
	if road.points.is_empty():
		issues.append("no_walkable_ground")
		return
	# The 5.3m bottom step is an entrance edge, not a single blocked point
	# directly behind the centre bed. Choose the closest accessible approach to
	# the door along that real edge; never route stones over the raised porch.
	var porch_pose := Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles.veranda)),plan.anchors.veranda)
	var root := Vector2.INF
	var entry_offset: float = INF
	for i: int in 51:
		var offset: float = -2.5+i*.1
		var approach: Vector3 = porch_pose*Vector3(offset,0,1.19+.30)
		var target := Vector2(approach.x,approach.z)
		var snapped: Vector2 = road.nearest(target)
		if snapped.distance_to(target)>.13: continue
		if absf(offset)<entry_offset:
			root=snapped
			entry_offset=absf(offset)
	if not root.is_finite():
		issues.append("house_door_blocked")
		return
	_network.append(root)
	endpoints.house = root
	var bridge: Vector3 = Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles.bridge)),plan.anchors.bridge)*Vector3(-2.60,0,0)
	if not plan.construction.bridge.is_empty(): bridge=preload("res://layout/island_construction.gd").bridge_points(plan)[0]
	_connect(Vector2(bridge.x,bridge.z),"bridge",.65)
	var kitchen: Vector3 = plan.anchors.kitchen+Vector3(0,0,1.8)
	_connect(Vector2(kitchen.x,kitchen.z),"kitchen",.8)
	var mooring: Vector3 = plan.anchors.mooring
	_connect(Vector2(mooring.x,mooring.z),"mooring",1.5)
	var trellis: Vector3 = plan.anchors.trellis+Vector3(.9,0,0)
	_connect(Vector2(trellis.x,trellis.z),"trellis",.65)
	for i: int in plan.fields.size():
		var field: Dictionary = plan.fields[i]
		var half: Vector2 = field.size*.5+Vector2.ONE*.34
		var best := PackedVector2Array()
		var best_length: float = INF
		for side: Vector2 in [Vector2(0,-half.y),Vector2(0,half.y),Vector2(-half.x,0),Vector2(half.x,0)]:
			var world: Vector3 = plan.field_transform(i)*Vector3(side.x,0,side.y)
			var goal := Vector2(world.x,world.z)
			var snapped: Vector2 = road.nearest(goal)
			if snapped.distance_to(goal)>.25: continue
			var route: PackedVector2Array = _route_to(snapped)
			var length: float = _length(route)
			if not route.is_empty() and length<best_length:
				best = route
				best_length = length
		if best.is_empty(): issues.append(field.id+":unreachable")
		else:
			endpoints[field.id] = best[-1]
			_add_route(best)
	_build_fences(obstacles)

func _connect(target: Vector2, key: String, tolerance: float) -> void:
	var snapped: Vector2 = road.nearest(target)
	if snapped.distance_to(target)>tolerance:
		issues.append(key+":blocked")
		return
	var route: PackedVector2Array = _route_to(snapped)
	if route.is_empty():
		# The nearest free sample can belong to a tiny pocket behind shoreline
		# rocks. Try reachable approaches within the same entrance tolerance;
		# never extend that tolerance or bridge across a blocked segment.
		var candidates: Array[Vector2] = []
		for point: Vector2 in road.points:
			if point.distance_to(target)<=tolerance: candidates.append(point)
		candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(target)<b.distance_squared_to(target))
		for point: Vector2 in candidates:
			route=_route_to(point)
			if not route.is_empty():
				snapped=point
				break
		if route.is_empty():
			issues.append(key+":unreachable")
			return
	endpoints[key] = snapped
	_add_route(route)

func _route_to(target: Vector2) -> PackedVector2Array:
	var source: Vector2 = _network[0]
	for point: Vector2 in _network:
		if point.distance_squared_to(target)<source.distance_squared_to(target): source=point
	var route: PackedVector2Array = road.path(source,target)
	if route.is_empty(): return route
	if not route[0].is_equal_approx(source): route.insert(0,source)
	return route

func _add_route(route: PackedVector2Array) -> void:
	var world := PackedVector3Array()
	for point: Vector2 in route: world.append(Vector3(point.x,_plan.ground_height-.015,point.y))
	if world.size()>1: _plan.paths.append(world)
	for i: int in maxi(1,route.size()-1):
		var a: Vector2 = route[i]
		var b: Vector2 = route[mini(i+1,route.size()-1)]
		var count: int = maxi(1,ceili(a.distance_to(b)/.4))
		for j: int in range(count+1): _network.append(a.lerp(b,float(j)/count))

static func _length(route: PackedVector2Array) -> float:
	var result: float = 0
	for i: int in range(route.size()-1): result+=route[i].distance_to(route[i+1])
	return result

func _build_fences(obstacles: Dictionary) -> void:
	var inset: Array[PackedVector2Array] = Geometry2D.offset_polygon(_plan.plateau(),-.65)
	if inset.is_empty(): return
	var outline: PackedVector2Array = inset[0]
	outline.append(outline[0])
	var fence_space := Space.new()
	fence_space.configure(_plan.land_bounds(),.12,_plan.plateau())
	for polygon: PackedVector2Array in obstacles.values(): fence_space.block(polygon)
	for i: int in _plan.fields.size(): fence_space.block(_plan.field_polygon(i,.12))
	var total: float = _length(outline)
	var count: int = ceili(total/1.35)
	var posts := PackedVector2Array()
	var segment: int = 0
	var distance: float = 0
	for i: int in count:
		var goal: float = total*i/count
		while segment<outline.size()-2 and distance+outline[segment].distance_to(outline[segment+1])<goal:
			distance+=outline[segment].distance_to(outline[segment+1])
			segment+=1
		posts.append(outline[segment].lerp(outline[segment+1],(goal-distance)/outline[segment].distance_to(outline[segment+1])))
	for i: int in posts.size():
		var a: Vector2 = posts[i]
		var b: Vector2 = posts[(i+1)%posts.size()]
		if not fence_space.clear_segment(a,b): continue
		var opening: bool = false
		for key: String in ["bridge","mooring"]:
			if endpoints.has(key) and Geometry2D.get_closest_point_to_segment(endpoints[key],a,b).distance_to(endpoints[key])<1.0: opening=true
		# A garden-side gap and all crossing paths remain passable; no invisible
		# continuous collision around the whole island is created by the fence mesh.
		var west: Vector3 = _plan.anchors.trellis
		if (a.y+b.y)*.5>west.z-.8 and (a.y+b.y)*.5<west.z+.8 and a.x<west.x: opening=true
		for path: PackedVector3Array in _plan.paths:
			for j: int in range(path.size()-1):
				var p := Vector2(path[j].x,path[j].z)
				var q := Vector2(path[j+1].x,path[j+1].z)
				if segment_distance(a,b,p,q)<.55: opening=true
		if not opening:
			_plan.fences.append({"a":Vector3(a.x,_plan.ground_height+.01,a.y),"b":Vector3(b.x,_plan.ground_height+.01,b.y),"height":.68 if (a.y+b.y)*.5>2.0 else 1.0})

static func segment_distance(a: Vector2,b: Vector2,p: Vector2,q: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a,b,p,q)!=null: return 0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a,p,q)),b.distance_to(Geometry2D.get_closest_point_to_segment(b,p,q))),minf(p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b)),q.distance_to(Geometry2D.get_closest_point_to_segment(q,a,b))))
