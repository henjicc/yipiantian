extends RefCounted
## Persisted parameters for the first in-world construction slice. Coordinates are XZ.
const CELL: float = .5
const MAX_PATCHES: int = 16
const MAX_DUCKS: int = 12

static func initial() -> Dictionary:
	return {"land":[],"trellis":[],"bridge":[],"ducks":{"count":3,"area":[]}}

static func numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for item: Variant in value:
		if not (item is int or item is float) or not is_finite(float(item)): return false
	return true

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=4: return false
	if not data.get("land") is Array or data.land.size()>MAX_PATCHES: return false
	for patch: Variant in data.land:
		if not numbers(patch,4): return false
		if absf(patch[0])>18 or absf(patch[1])>18 or patch[2]<CELL or patch[3]<CELL or patch[2]>5 or patch[3]>5: return false
		for n: float in patch:
			if absf(n/CELL-roundf(n/CELL))>.0001: return false
	if not data.get("trellis") is Array or not data.get("bridge") is Array: return false
	if not data.trellis.is_empty():
		if not numbers(data.trellis,3): return false
		if data.trellis[0]<2 or data.trellis[0]>6 or data.trellis[1]<.8 or data.trellis[1]>2 or data.trellis[2]<1.6 or data.trellis[2]>3: return false
	if not data.bridge.is_empty():
		if not numbers(data.bridge,5): return false
		for i: int in 4:
			if absf(data.bridge[i])>24: return false
		if data.bridge[4]<.8 or data.bridge[4]>1.8: return false
		var distance: float=Vector2(data.bridge[0],data.bridge[1]).distance_to(Vector2(data.bridge[2],data.bridge[3]))
		if distance<2 or distance>9: return false
	var flock: Variant=data.get("ducks")
	if not flock is Dictionary or flock.size()!=2 or not numbers([flock.get("count")],1): return false
	if flock.count<0 or flock.count>MAX_DUCKS or floorf(flock.count)!=flock.count or not flock.get("area") is Array: return false
	if not flock.area.is_empty():
		if not numbers(flock.area,4): return false
		if absf(flock.area[0])>24 or absf(flock.area[1])>24 or flock.area[2]<2 or flock.area[3]<2 or flock.area[2]>12 or flock.area[3]>12: return false
		if flock.area[2]*flock.area[3]<flock.count*3.0: return false
	return true

static func rectangle(values: Array) -> PackedVector2Array:
	var p:=Vector2(values[0],values[1]);var s:=Vector2(values[2],values[3])
	return PackedVector2Array([p,p+Vector2(s.x,0),p+s,p+Vector2(0,s.y)])

static func land_outline(original: PackedVector2Array, patches: Array) -> PackedVector2Array:
	var outline: PackedVector2Array=original.duplicate()
	for values: Array in patches:
		var patch: PackedVector2Array=rectangle(values)
		# Require area overlap, not a point/edge touch which leaves a fragile neck.
		if Geometry2D.intersect_polygons(outline,patch).is_empty(): return PackedVector2Array()
		var merged: Array[PackedVector2Array]=Geometry2D.merge_polygons(outline,patch)
		if merged.size()!=1: return PackedVector2Array()
		outline=merged[0]
	if Geometry2D.is_polygon_clockwise(outline): outline.reverse()
	return outline

static func trellis_size(plan: RefCounted) -> Vector3:
	var v: Array=plan.construction.trellis
	return Vector3(4.65,1.25,2.2) if v.is_empty() else Vector3(v[0],v[1],v[2])

static func bridge_points(plan: RefCounted) -> Array[Vector3]:
	var v: Array=plan.construction.bridge
	if not v.is_empty(): return [Vector3(v[0],plan.ground_height,v[1]),Vector3(v[2],plan.ground_height,v[3])]
	var pose:=Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles.bridge)),plan.anchors.bridge)
	var a: Vector3=pose*Vector3(-2.6,0,0);var b: Vector3=pose*Vector3(2.6,0,0)
	a.y=plan.ground_height;b.y=plan.ground_height
	return [a,b]

static func bridge_issue(plan: RefCounted) -> String:
	if plan.construction.bridge.is_empty(): return ""
	var ends: Array[Vector3]=bridge_points(plan)
	var east: PackedVector2Array=bridge_support(plan,1)
	var main: PackedVector2Array=bridge_support(plan,0)
	var direction: Vector3=(ends[1]-ends[0]).normalized()
	var side:=Vector2(-direction.z,direction.x)*(float(plan.construction.bridge[4])*.5+.08)
	for offset: Vector2 in [side,-side]:
		if not Geometry2D.is_point_in_polygon(Vector2(ends[0].x,ends[0].z)+offset,main): return "左桥头需要完整落在主岛平地上"
		if not Geometry2D.is_point_in_polygon(Vector2(ends[1].x,ends[1].z)+offset,east): return "右桥头需要完整落在对岸平地上"
	return ""

static func bridge_support(plan: RefCounted, end: int) -> PackedVector2Array:
	if end==0: return plan.plateau()
	var result:=PackedVector2Array()
	var geometry=preload("res://layout/bank_geometry.gd")
	var pose:=Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles.east_bank)),plan.anchors.east_bank)
	for p: Vector2 in geometry.ring(geometry.contour(plan.east_rim),.96,plan.bank_width):
		var world: Vector3=pose*Vector3(p.x,0,p.y)
		result.append(Vector2(world.x,world.z))
	return result

static func snap_bridge_end(plan: RefCounted, point: Vector2, end: int, width: float) -> Vector2:
	var inset: Array[PackedVector2Array]=Geometry2D.offset_polygon(bridge_support(plan,end),-width*.5-.12)
	var nearest: Vector2=point;var distance: float=.75
	for polygon: PackedVector2Array in inset:
		if Geometry2D.is_point_in_polygon(point,polygon): return point
		for i: int in polygon.size():
			var candidate: Vector2=Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])
			if point.distance_to(candidate)<distance: nearest=candidate;distance=point.distance_to(candidate)
	return nearest
