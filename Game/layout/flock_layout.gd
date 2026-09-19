extends RefCounted
## Three current species share identity, region and usable-space rules.
const Navigation=preload("res://scenes/environment/animal_space.gd")
const Space=preload("res://layout/island_space.gd")
const KINDS: Array[String]=["duck","goose","hen"]
const TOOLS: Dictionary={"ducks":"duck","goose":"goose","hen":"hen"}
const SPECIES: Dictionary={
	"duck":{"name":"鸭群","prefix":"LakeDuck","limit":12,"area":3.0,"usable":1.3,"spacing":.75},
	"goose":{"name":"鹅群","prefix":"LakeGoose","limit":8,"area":4.0,"usable":1.8,"spacing":.95},
	"hen":{"name":"鸡群","prefix":"YardHen","limit":8,"area":1.5,"usable":.65,"spacing":.55},
}
static func initial() -> Dictionary:
	return {"duck":{"count":3,"area":[]},"goose":{"count":2,"area":[]},"hen":{"count":2,"area":[]}}

static func id(kind: String, index: int) -> String:
	return "%s%d"%[SPECIES[kind].prefix,index+1]

static func size(kind: String, index: int) -> float:
	if kind=="duck" and index==2: return .88
	if kind=="hen": return .88+(index%2)*.12
	return 1.0

static func start(kind: String, index: int, area: Array) -> Vector2:
	if not area.is_empty(): return Vector2(area[0],area[1])+Vector2(area[2],area[3])*.5+Vector2.from_angle(index*2.4)*sqrt(index)*SPECIES[kind].spacing
	match kind:
		"duck": return Vector2(-10.7+index*.8,1.7+index*.6)
		"goose": return Vector2(1.5+index*1.4,9.3)
	return Vector2(-.7+index*.8,4.62)

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=KINDS.size(): return false
	for kind: String in KINDS:
		var flock: Variant=data.get(kind)
		if not flock is Dictionary or flock.size()!=2: return false
		var count: Variant=flock.get("count")
		if not (count is int or count is float) or not is_finite(count) or floorf(count)!=count or count<0 or count>SPECIES[kind].limit: return false
		var area: Variant=flock.get("area")
		if not area is Array: return false
		if area.is_empty(): continue
		if area.size()!=4: return false
		for value: Variant in area:
			if not (value is int or value is float) or not is_finite(value): return false
		if absf(area[0])>24 or absf(area[1])>24 or area[2]<2 or area[3]<2 or area[2]>12 or area[3]>12: return false
		if area[2]*area[3]<count*SPECIES[kind].area: return false
	return true

static func terrain_issue(plan: RefCounted) -> String:
	for kind: String in KINDS:
		var flock: Dictionary=plan.construction.flocks[kind]
		if int(flock.count)==0 or flock.area.is_empty(): continue
		var polygon: PackedVector2Array=Space.rectangle(Vector2(flock.area[0],flock.area[1]),Vector2(flock.area[2],flock.area[3]))
		if kind=="hen":
			var ground: PackedVector2Array=load("res://layout/bridge_passage.gd").outline(plan,.21)
			if not Space.overlaps(polygon,ground): return "鸡群活动区域需要包含可到达的陆地或桥面。"
		elif not Space.water_clear(polygon,plan.water_banks()): return "%s活动区域需要留在水面上，请避开两岸的土坡。"%SPECIES[kind].name
		var bounds: Rect2=load("res://layout/bridge_passage.gd").bounds(plan) if kind=="hen" else plan.animal_areas.water
		if not bounds.encloses(Rect2(flock.area[0],flock.area[1],flock.area[2],flock.area[3])): return "请在小岛附近圈定活动区域。"
	return ""

static func space_issue(kind: String, count: int, space: RefCounted) -> String:
	if count==0: return ""
	if space.points.size()*Navigation.CELL*Navigation.CELL<count*SPECIES[kind].usable:
		return "%s的连通空间不足，请扩大区域、避开障碍或减少数量。"%SPECIES[kind].name
	return ""

static func separated_point(space: RefCounted, point: Vector2, placed: PackedVector2Array, spacing: float) -> Vector2:
	if space.points.is_empty(): return Vector2.INF
	var nearest: Vector2=space.nearest(point)
	var candidates: PackedVector2Array=PackedVector2Array([nearest])
	candidates.append_array(space.points)
	var best:=Vector2.INF;var distance: float=INF
	for p: Vector2 in candidates:
		var d: float=p.distance_squared_to(point)
		if d>=distance: continue
		var clear: bool=true
		for other: Vector2 in placed:
			if p.distance_squared_to(other)<spacing*spacing: clear=false;break
		if clear: best=p;distance=d
	return best

static func added_obstacle_issue(plan: RefCounted, kind: String, source: RefCounted, added: Array[PackedVector2Array]) -> String:
	var flock: Dictionary=plan.construction.flocks[kind]
	if flock.count==0 or flock.area.is_empty() or added.is_empty(): return ""
	var rect:=Rect2(flock.area[0],flock.area[1],flock.area[2],flock.area[3])
	var boundary: PackedVector2Array=Space.rectangle(rect.position,rect.size)
	var relevant: Array[PackedVector2Array]=[]
	for polygon: PackedVector2Array in added:
		if Space.overlaps(boundary,polygon): relevant.append(polygon)
	if relevant.is_empty(): return ""
	var region:=Navigation.new();region.configure(rect,source.radius,source.allowed)
	region.obstacles=source.obstacles.duplicate();region._obstacle_cells=source._obstacle_cells.duplicate(true)
	for polygon: PackedVector2Array in relevant: region.block(polygon)
	region.bake();region.keep_largest_component()
	return space_issue(kind,int(flock.count),region)

static func land_issue(plan: RefCounted, obstacles: Dictionary) -> String:
	var flock: Dictionary=plan.construction.flocks.hen
	if flock.count==0 or flock.area.is_empty(): return ""
	var region:=Navigation.new()
	var passage=load("res://layout/bridge_passage.gd")
	var inner: PackedVector2Array=passage.outline(plan,.21)
	if inner.is_empty(): return "鸡群没有足够平地，请先调整活动区域。"
	region.configure(Rect2(flock.area[0],flock.area[1],flock.area[2],flock.area[3]),.21,inner)
	for key: String in obstacles:
		if not key.begins_with("player_road_") and not passage.is_bridge(key): region.block(obstacles[key])
	for i: int in plan.fields.size(): region.block(plan.field_polygon(i))
	for span: Dictionary in plan.fences:
		var a:=Vector2(span.a.x,span.a.z);var b:=Vector2(span.b.x,span.b.z)
		var side: Vector2=(b-a).normalized().orthogonal()*.064
		region.block(PackedVector2Array([a-side,b-side,b+side,a+side]))
	region.bake();region.keep_largest_component()
	return space_issue("hen",int(flock.count),region)
