extends RefCounted
## Stable original shore samples; only newly exposed/submerged edges change.
const Marsh=preload("res://scenes/environment/marsh_plants.gd")
const Plants=preload("res://layout/plantings.gd")

static func _new_land(point: Vector2, plan: RefCounted) -> bool:
	for patch: Array in plan.construction.land:
		if Rect2(patch[0],patch[1],patch[2],patch[3]).grow(.1).has_point(point): return true
	return false

static func _distance(point: Vector2, outline: PackedVector2Array) -> float:
	var result: float=INF
	for i: int in outline.size(): result=minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,outline[i],outline[(i+1)%outline.size()])))
	return result

static func added_points(plan: RefCounted) -> PackedVector2Array:
	var result:=PackedVector2Array()
	if plan.construction.land.is_empty(): return result
	var base: RefCounted=load("res://layout/courtyard_plan.gd").new()
	if plan.shore_expansion!=Vector2.ZERO: base.expand_shore(plan.shore_expansion.x,plan.shore_expansion.y)
	for i: int in plan.rim.size():
		var a: Vector2=plan.rim[i];var b: Vector2=plan.rim[(i+1)%plan.rim.size()]
		var count: int=ceili(a.distance_to(b)/.8)
		for j: int in count:
			var point: Vector2=a.lerp(b,(j+.5)/count)
			if _distance(point,base.rim)>.28: result.append(point)
	return result

static func stones(plan: RefCounted) -> Array[Dictionary]:
	var base: RefCounted=load("res://layout/courtyard_plan.gd").new()
	if plan.shore_expansion!=Vector2.ZERO: base.expand_shore(plan.shore_expansion.x,plan.shore_expansion.y)
	var result: Array[Dictionary]=[]
	var rng:=RandomNumberGenerator.new();rng.seed=32026
	var plateau: PackedVector2Array=plan.plateau()
	for i: int in base.rim.size():
		var a: Vector2=base.rim[i];var b: Vector2=base.rim[(i+1)%base.rim.size()]
		var count: int=ceili(a.distance_to(b)/.88)
		for j: int in count:
			if rng.randf()<.24: continue
			var point: Vector2=a.lerp(b,float(j)/count)+Vector2(rng.randf_range(-.14,.14),rng.randf_range(-.14,.14))
			var entry: Dictionary={"asset":"stone_%d"%rng.randi_range(0,4),"at":Vector3(point.x,-.43,point.y),"yaw":rng.randf_range(0,360),"size":Vector3(rng.randf_range(.85,1.45),rng.randf_range(2.5,4.3),rng.randf_range(.8,1.45))}
			if i==12 and j==1: entry.at=base.root_bay
			entry.color=Color("7d887d")*rng.randf_range(.88,1.12)
			var at:=Vector2(entry.at.x,entry.at.z)
			if not _new_land(at,plan) or not Geometry2D.is_point_in_polygon(at,plateau): result.append(entry)
	for i: int in base.shelves.size():
		var point: Vector3=base.shelves[i]
		if _new_land(Vector2(point.x,point.z),plan) and Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),plateau): continue
		result.append({"asset":"stone_%d"%(i%5),"at":point,"yaw":17+i*47,"size":Vector3(1.45,4.8 if i%2==0 else 3.5,1.18),"color":Color("79867e")})
		result.append({"asset":"stone_%d"%((i+2)%5),"at":point+Vector3(.35,-.05,.37),"yaw":-25+i*33,"size":Vector3(.88,2,.9),"color":Color("929784")})
	for p: Vector2 in added_points(plan):
		rng.seed=hash(Vector2i((p*100).round()))
		if rng.randf()<.25: continue
		result.append({"asset":"stone_%d"%rng.randi_range(0,4),"at":Vector3(p.x,-.43,p.y),"yaw":rng.randf_range(0,360),"size":Vector3(rng.randf_range(.85,1.3),3.2,rng.randf_range(.8,1.3)),"color":Color("7d887d")*rng.randf_range(.88,1.12)})
	return result

static func plants(plan: RefCounted) -> Node3D:
	var holder:=Node3D.new();holder.name="NewShorePlants"
	var placements: Dictionary={"reed":[],"trapa":[]}
	for p: Vector2 in added_points(plan):
		var rng:=RandomNumberGenerator.new();rng.seed=hash(Vector2i((p*100).round()))
		if rng.randf()<.55: continue
		# Brush shores extrude locally, including the inner corner of an L stroke.
		var outward: Vector2=p.normalized();var distance: float=INF
		for i: int in plan.rim.size():
			var a: Vector2=plan.rim[i];var b: Vector2=plan.rim[(i+1)%plan.rim.size()]
			var nearest: Vector2=Geometry2D.get_closest_point_to_segment(p,a,b)
			if p.distance_squared_to(nearest)<distance:
				distance=p.distance_squared_to(nearest);var along: Vector2=(b-a).normalized();outward=Vector2(along.y,-along.x)
		var at: Vector2=p*.96+outward*.7
		var size: float=rng.randf_range(.42,.65)
		placements.reed.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(at.x,-.36,at.y)))
		at+=outward*.55
		placements.trapa.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,.32,size)),Vector3(at.x,-.263,at.y)))
	var builder:=Marsh.new()
	for species: String in placements:
		for i: int in range(placements[species].size()-1,-1,-1):
			var footprint: PackedVector2Array=Plants.Space.footprint(Plants.EXTENTS[species],placements[species][i],.06)
			if Plants.overlaps_player(footprint,plan.plants): placements[species].remove_at(i)
		if not placements[species].is_empty(): builder._batch(holder,species,"low",placements[species])
	builder.free()
	return holder
