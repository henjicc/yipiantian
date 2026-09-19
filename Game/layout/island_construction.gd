extends RefCounted
## Persisted parameters for the first in-world construction slice. Coordinates are XZ.
const IslandSpace = preload("res://layout/island_space.gd")
const Buildings = preload("res://layout/building_layout.gd")
const BRIDGE_STYLES: Array[String] = ["平桥", "拱桥"]
const CELL: float = IslandSpace.CELL
const MAX_PATCHES: int = 256
const BRUSH_SIZE: float = 1.5
const Flocks=preload("res://layout/flock_layout.gd")

static func initial() -> Dictionary:
	return {"land":[],"trellis":[],"bridge":[],"flocks":Flocks.initial(),"buildings":Buildings.initial()}

static func numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for item: Variant in value:
		if not (item is int or item is float) or not is_finite(float(item)): return false
	return true

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=5 or not Buildings.valid(data.get("buildings")): return false
	if not data.get("land") is Array or data.land.size()>MAX_PATCHES: return false
	for patch: Variant in data.land:
		if not numbers(patch,4): return false
		if absf(patch[0])>18 or absf(patch[1])>18 or patch[2]<CELL or patch[3]<CELL or patch[2]>5 or patch[3]>5: return false
		for n: float in patch:
			if absf(n/CELL-roundf(n/CELL))>.0001: return false
	if not data.get("trellis") is Array or not data.get("bridge") is Array: return false
	if not data.trellis.is_empty():
		if not numbers(data.trellis,6): return false
		if data.trellis[0]<2 or data.trellis[0]>6 or data.trellis[1]<.8 or data.trellis[1]>2 or data.trellis[2]<1.6 or data.trellis[2]>3: return false
		if absf(data.trellis[3])>24 or absf(data.trellis[4])>24 or data.trellis[5]<-180 or data.trellis[5]>=180: return false
	if not data.bridge.is_empty():
		if not numbers(data.bridge,6): return false
		if float(data.bridge[5]) not in [0.0,1.0]: return false
		for i: int in 4:
			if absf(data.bridge[i])>24: return false
		if data.bridge[4]<.8 or data.bridge[4]>1.8: return false
		var distance: float=Vector2(data.bridge[0],data.bridge[1]).distance_to(Vector2(data.bridge[2],data.bridge[3]))
		if distance<2 or distance>9: return false
	return Flocks.valid(data.get("flocks"))

static func rectangle(values: Array) -> PackedVector2Array:
	return IslandSpace.rectangle(Vector2(values[0],values[1]), Vector2(values[2],values[3]))

static func paint(land: Array, outline: PackedVector2Array, point: Vector2) -> PackedVector2Array:
	var cell: Vector2=Vector2(IslandSpace.cell_at(point))*CELL
	var stamp: Array=[cell.x-CELL,cell.y-CELL,BRUSH_SIZE,BRUSH_SIZE]
	if absf(stamp[0])>18 or absf(stamp[1])>18 or land.size()>=MAX_PATCHES: return outline
	var polygon: PackedVector2Array=rectangle(stamp)
	if IslandSpace.supported(polygon,outline): return outline
	var merged: PackedVector2Array=land_outline(outline,[stamp])
	if not merged.is_empty():
		land.append(stamp)
		return merged
	return outline

static func nearest_edge(point: Vector2, outline: PackedVector2Array) -> Vector2:
	var nearest:=Vector2.INF;var distance: float=INF
	for i: int in outline.size():
		var p: Vector2=Geometry2D.get_closest_point_to_segment(point,outline[i],outline[(i+1)%outline.size()])
		if point.distance_squared_to(p)<distance: nearest=p;distance=point.distance_squared_to(p)
	return nearest

static func clear_water(point: Vector2, outline: PackedVector2Array, clearance: float) -> Vector2:
	for step: int in 8:
		var nearest: Vector2=nearest_edge(point,outline)
		var inside: bool=Geometry2D.is_point_in_polygon(point,outline)
		if not inside and nearest.distance_to(point)>=clearance-.01: break
		var direction: Vector2=(nearest-point if inside else point-nearest).normalized()
		if direction==Vector2.ZERO: direction=nearest.normalized()
		point=nearest+direction*(clearance+.05)
	return point

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

static func trellis_yaw(plan: RefCounted) -> float:
	return 0.0 if plan.construction.trellis.is_empty() else float(plan.construction.trellis[5])

static func trellis_pose(plan: RefCounted) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,deg_to_rad(trellis_yaw(plan))),plan.anchors.trellis)

static func trellis_parameters(plan: RefCounted) -> Array:
	var size: Vector3=trellis_size(plan)
	return [size.x,size.y,size.z,plan.anchors.trellis.x,plan.anchors.trellis.z,trellis_yaw(plan)]

static func trellis_footprint(plan: RefCounted) -> PackedVector2Array:
	var size: Vector3=trellis_size(plan)
	return IslandSpace.footprint(Vector2(size.y+.2,size.x+.088),trellis_pose(plan))

static func trellis_flower_center(plan: RefCounted) -> Vector3:
	var size: Vector3=trellis_size(plan)
	var pose: Transform3D=trellis_pose(plan)
	var candidates: Array[Vector3]=[]
	for side: float in [-1.0,1.0]:
		for end: float in [1.0,-1.0,0.0]:
			candidates.append(pose*Vector3(side*(size.y*.5+.55),0,end*minf(1.55,size.x*.5-.65)))
	for end: float in [1.0,-1.0]: candidates.append(pose*Vector3(0,0,end*(size.x*.5+.6)))
	for at: Vector3 in candidates:
		var roots: PackedVector2Array=IslandSpace.rectangle(Vector2(at.x,at.z)-Vector2.ONE*.36,Vector2.ONE*.72)
		if not IslandSpace.supported(roots,plan.plateau()): continue
		var occupied: bool=false
		for i: int in plan.fields.size():
			if IslandSpace.overlaps(roots,plan.field_polygon(i,.12)): occupied=true;break
		if not occupied: return at
	return candidates[0]

static func bridge_points(plan: RefCounted) -> Array[Vector3]:
	var v: Array=plan.construction.bridge
	if not v.is_empty(): return [Vector3(v[0],plan.ground_height,v[1]),Vector3(v[2],plan.ground_height+plan.anchors.east_bank.y,v[3])]
	var pose:=Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles.bridge)),plan.anchors.bridge)
	var a: Vector3=pose*Vector3(-2.6,0,0);var b: Vector3=pose*Vector3(2.6,0,0)
	a.y=plan.ground_height;b.y=plan.ground_height+plan.anchors.east_bank.y
	return [a,b]

static func bridge_style(plan: RefCounted) -> int:
	return 1 if plan.construction.bridge.is_empty() else int(plan.construction.bridge[5])

static func bridge_parameters(plan: RefCounted) -> Array:
	if not plan.construction.bridge.is_empty(): return plan.construction.bridge.duplicate()
	var ends: Array[Vector3]=bridge_points(plan)
	return [ends[0].x,ends[0].z,ends[1].x,ends[1].z,1.2,bridge_style(plan)]

static func bridge_crown(ends: Array[Vector3]) -> float:
	return maxf(.42,maxf(ends[0].y,ends[1].y)+.22)

static func bridge_profile(ends: Array[Vector3], style: int, t: float) -> Vector3:
	var point: Vector3=ends[0].lerp(ends[1],t)
	var crown: float=bridge_crown(ends)
	if style==1: point.y+=sin(PI*t)*(crown-(ends[0].y+ends[1].y)*.5)
	else:
		if t<.3: point.y=lerpf(ends[0].y,crown,t/.3)
		elif t>.7: point.y=lerpf(crown,ends[1].y,(t-.7)/.3)
		else: point.y=crown
	return point

static func bridge_approaches(plan: RefCounted) -> Array[PackedVector2Array]:
	var ends: Array[Vector3]=bridge_points(plan)
	var direction:=Vector3(ends[1].x-ends[0].x,0,ends[1].z-ends[0].z).normalized()
	var basis:=Basis(Vector3.UP,atan2(-direction.z,direction.x))
	var width: float=bridge_parameters(plan)[4]+.16
	return [IslandSpace.footprint(Vector2(.6,width),Transform3D(basis,ends[0]-direction*.3)),IslandSpace.footprint(Vector2(.6,width),Transform3D(basis,ends[1]+direction*.3))]

static func bridge_issue(plan: RefCounted) -> String:
	if plan.construction.bridge.is_empty(): return ""
	var ends: Array[Vector3]=bridge_points(plan)
	var east: PackedVector2Array=bridge_support(plan,1)
	var main: PackedVector2Array=bridge_support(plan,0)
	var horizontal:=Vector2(ends[1].x-ends[0].x,ends[1].z-ends[0].z)
	var crown: float=bridge_crown(ends)
	var rise: float=absf(ends[1].y-ends[0].y)+PI*(crown-(ends[0].y+ends[1].y)*.5) if bridge_style(plan)==1 else maxf(crown-ends[0].y,crown-ends[1].y)/.3
	if rise/horizontal.length()>.5: return "两岸高差太大，请拉长桥梁或改用平桥。"
	var approaches: Array[PackedVector2Array]=bridge_approaches(plan)
	var approach_a: PackedVector2Array=approaches[0];var approach_b: PackedVector2Array=approaches[1]
	if not IslandSpace.supported(approach_a,main): return "左桥头需要完整落在主岛平地上"
	if not IslandSpace.supported(approach_b,east): return "右桥头需要完整落在对岸平地上"
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
