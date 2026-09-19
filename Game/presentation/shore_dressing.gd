extends RefCounted
## Stable original shore samples; only newly exposed/submerged edges change.
const Marsh=preload("res://scenes/environment/marsh_plants.gd")
const Plants=preload("res://layout/plantings.gd")

static func _new_land(point: Vector2, plan: RefCounted, island: int=0) -> bool:
	for patch: Array in plan.land_patches(island):
		if Rect2(patch[0],patch[1],patch[2],patch[3]).grow(.1).has_point(point): return true
	return false

static func _distance(point: Vector2, outline: PackedVector2Array) -> float:
	var result: float=INF
	for i: int in outline.size(): result=minf(result,point.distance_to(Geometry2D.get_closest_point_to_segment(point,outline[i],outline[(i+1)%outline.size()])))
	return result

static func _retained_stone(point: Vector2,plan: RefCounted,plateau: PackedVector2Array,island: int=0) -> bool:
	if not _new_land(point,plan,island): return true
	return not Geometry2D.is_point_in_polygon(point,plateau) and _distance(point,plan.island_pose(island)*plan.island_rim(island))<.6

static func added_points(plan: RefCounted,island: int=0) -> PackedVector2Array:
	var result:=PackedVector2Array()
	if plan.land_patches(island).is_empty(): return result
	var base: RefCounted=load("res://layout/courtyard_plan.gd").new()
	if plan.shore_expansion!=Vector2.ZERO: base.expand_shore(plan.shore_expansion.x,plan.shore_expansion.y)
	var original: PackedVector2Array=preload("res://layout/bank_geometry.gd").contour(base.island_rim(island))
	original=base.island_pose(island)*original
	var outline: PackedVector2Array=plan.island_pose(island)*plan.island_rim(island)
	var original_vertices: Dictionary={}
	for i: int in original.size(): original_vertices[Vector2i((original[i]*1000).round())]=i
	for i: int in outline.size():
		var a: Vector2=outline[i];var b: Vector2=outline[(i+1)%outline.size()]
		var old_a: int=original_vertices.get(Vector2i((a*1000).round()),-1)
		var old_b: int=original_vertices.get(Vector2i((b*1000).round()),-1)
		# Most vertices belong to the unchanged sampled shore. Only new edges
		# need distance queries and additional dressing candidates.
		if old_a>=0 and old_b==(old_a+1)%original.size(): continue
		var count: int=ceili(a.distance_to(b)/.8)
		for j: int in count:
			var point: Vector2=a.lerp(b,(j+.5)/count)
			if _distance(point,original)>.28: result.append(point)
	return result

static func stones(plan: RefCounted,island: int=0) -> Array[Dictionary]:
	var base: RefCounted=load("res://layout/courtyard_plan.gd").new()
	if plan.shore_expansion!=Vector2.ZERO: base.expand_shore(plan.shore_expansion.x,plan.shore_expansion.y)
	var result: Array[Dictionary]=[]
	var rng:=RandomNumberGenerator.new();rng.seed=32026
	var plateau: PackedVector2Array=plan.plateau(island)
	if island==1:
		for i: int in base.east_stones.size():
			var at: Vector3=base.east_stones[i]
			if _retained_stone(Vector2(at.x,at.z),plan,plateau,1):
				result.append({"asset":"stone_%d"%(i%5),"at":at,"yaw":i*39,"size":Vector3(.85,2.8+(i%3)*.7,.8),"color":Color("829184")})
	for i: int in (base.rim.size() if island==0 else 0):
		var a: Vector2=base.rim[i];var b: Vector2=base.rim[(i+1)%base.rim.size()]
		var count: int=ceili(a.distance_to(b)/.88)
		for j: int in count:
			if rng.randf()<.24: continue
			var point: Vector2=a.lerp(b,float(j)/count)+Vector2(rng.randf_range(-.14,.14),rng.randf_range(-.14,.14))
			var entry: Dictionary={"asset":"stone_%d"%rng.randi_range(0,4),"at":Vector3(point.x,-.43,point.y),"yaw":rng.randf_range(0,360),"size":Vector3(rng.randf_range(.85,1.45),rng.randf_range(2.5,4.3),rng.randf_range(.8,1.45))}
			if i==12 and j==1: entry.at=base.root_bay
			entry.color=Color("7d887d")*rng.randf_range(.88,1.12)
			var at:=Vector2(entry.at.x,entry.at.z)
			if _retained_stone(at,plan,plateau): result.append(entry)
	for i: int in (base.shelves.size() if island==0 else 0):
		var point: Vector3=base.shelves[i]
		if not _retained_stone(Vector2(point.x,point.z),plan,plateau): continue
		result.append({"asset":"stone_%d"%(i%5),"at":point,"yaw":17+i*47,"size":Vector3(1.45,4.8 if i%2==0 else 3.5,1.18),"color":Color("79867e")})
		result.append({"asset":"stone_%d"%((i+2)%5),"at":point+Vector3(.35,-.05,.37),"yaw":-25+i*33,"size":Vector3(.88,2,.9),"color":Color("929784")})
	for p: Vector2 in added_points(plan,island):
		rng.seed=hash(Vector2i((p*100).round()))
		if rng.randf()<.25: continue
		result.append({"asset":"stone_%d"%rng.randi_range(0,4),"at":Vector3(p.x,-.43,p.y),"yaw":rng.randf_range(0,360),"size":Vector3(rng.randf_range(.85,1.3),3.2,rng.randf_range(.8,1.3)),"color":Color("7d887d")*rng.randf_range(.88,1.12)})
	return result

static func plants(plan: RefCounted) -> Node3D:
	var holder:=Node3D.new();holder.name="NewShorePlants"
	var placements: Dictionary={"reed":[],"trapa":[]}
	for island: int in 2:
		_add_plants(plan,island,placements)
	# Player footprints are unchanged during this generation. Prepare them once;
	# cheap bounds reject distant clumps before the original exact overlap test.
	var protected: Array[PackedVector2Array]=[]
	var bounds: Array[Rect2]=[]
	for entry: Dictionary in plan.plants:
		var footprint: PackedVector2Array=Plants.footprint(entry)
		protected.append(footprint);bounds.append(_bounds(footprint))
	var builder:=Marsh.new()
	for species: String in placements:
		for i: int in range(placements[species].size()-1,-1,-1):
			var footprint: PackedVector2Array=Plants.Space.footprint(Plants.EXTENTS[species],placements[species][i],.06)
			var area: Rect2=_bounds(footprint)
			for j: int in protected.size():
				if area.intersects(bounds[j],true) and Plants.Space.overlaps(footprint,protected[j]):
					placements[species].remove_at(i);break
		if not placements[species].is_empty(): builder._batch(holder,species,"low",placements[species])
	builder.free()
	return holder

static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var result:=Rect2(polygon[0],Vector2.ZERO)
	for point: Vector2 in polygon: result=result.expand(point)
	return result

static func _add_plants(plan: RefCounted,island: int,placements: Dictionary) -> void:
	var pose: Transform2D=plan.island_pose(island)
	var outline: PackedVector2Array=pose*plan.island_rim(island)
	for p: Vector2 in added_points(plan,island):
		var rng:=RandomNumberGenerator.new();rng.seed=hash(Vector2i((p*100).round()))
		if rng.randf()<.55: continue
		# Brush shores extrude locally, including the inner corner of an L stroke.
		var outward: Vector2=p.normalized();var distance: float=INF
		for i: int in outline.size():
			var a: Vector2=outline[i];var b: Vector2=outline[(i+1)%outline.size()]
			var nearest: Vector2=Geometry2D.get_closest_point_to_segment(p,a,b)
			if p.distance_squared_to(nearest)<distance:
				distance=p.distance_squared_to(nearest);var along: Vector2=(b-a).normalized();outward=Vector2(along.y,-along.x)
		var at: Vector2=pose*(pose.affine_inverse()*p*.96)+outward*.7
		var size: float=rng.randf_range(.42,.65)
		placements.reed.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),Vector3(at.x,-.36,at.y)))
		at+=outward*.55
		placements.trapa.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,.32,size)),Vector3(at.x,-.263,at.y)))
