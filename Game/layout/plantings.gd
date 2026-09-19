extends RefCounted
## Persisted player clumps, separate from automatic shoreline dressing.
const Space=preload("res://layout/island_space.gd")
const KINDS: Array[String]=["lotus","reed","cattail","trapa"]
const MAX_CLUMPS: int=160
const EXTENTS={"lotus":Vector2(.9,.83),"reed":Vector2(1.19,.58),"cattail":Vector2(1.18,.83),"trapa":Vector2(.53,.53)}
const SCALES={"lotus":1.0,"reed":.65,"cattail":.65,"trapa":1.0}

static func valid(entries: Variant) -> bool:
	if not entries is Array or entries.size()>MAX_CLUMPS: return false
	var ids: Dictionary={}
	for entry: Variant in entries:
		if not entry is Dictionary or entry.size()!=3 or not entry.get("kind") in KINDS: return false
		var id: Variant=entry.get("id")
		if not (id is float or id is int) or not is_finite(float(id)) or id!=floorf(id) or id<1 or id>2147483647 or ids.has(id): return false
		ids[id]=true
		if not entry.get("pose") is Array or entry.pose.size()!=4: return false
		for value: Variant in entry.pose:
			if not (value is float or value is int) or not is_finite(float(value)): return false
		if absf(entry.pose[0])>30 or absf(entry.pose[1])>30 or entry.pose[2]<0 or entry.pose[2]>=360 or entry.pose[3]<.8 or entry.pose[3]>1.2: return false
	return true

static func canonical(entries: Array) -> Array:
	var result: Array=entries.duplicate(true)
	for entry: Dictionary in result:
		entry.id=int(entry.id)
		for i: int in 4: entry.pose[i]=float("%.4f"%entry.pose[i])
		entry.pose[2]=fposmod(entry.pose[2],360)
	return result

static func position(entry: Dictionary) -> Vector2:
	return Vector2(entry.pose[0],entry.pose[1])

static func pose(entry: Dictionary) -> Transform3D:
	var size: float=entry.pose[3]*SCALES[entry.kind]
	var scale:=Vector3.ONE*size
	if entry.kind=="trapa": scale.y=.32
	var level: float={"lotus":-.40,"reed":-.36,"cattail":-.36,"trapa":-.263}[entry.kind]
	return Transform3D(Basis(Vector3.UP,deg_to_rad(entry.pose[2])).scaled(scale),Vector3(entry.pose[0],level,entry.pose[1]))

static func footprint(entry: Dictionary) -> PackedVector2Array:
	return Space.footprint(EXTENTS[entry.kind],pose(entry),.06)

static func footprints(entries: Array) -> Dictionary:
	var result: Dictionary={}
	for entry: Dictionary in entries: result["player_plant_%d"%entry.id]=footprint(entry)
	return result

static func overlaps_player(polygon: PackedVector2Array, entries: Array) -> bool:
	for entry: Dictionary in entries:
		if Space.overlaps(polygon,footprint(entry)): return true
	return false

static func nearest_bank(point: Vector2, banks: Array[PackedVector2Array]) -> float:
	var distance: float=INF
	for bank: PackedVector2Array in banks:
		for i: int in bank.size(): distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,bank[i],bank[(i+1)%bank.size()])))
	return distance

static func habitat_issue(entry: Dictionary, plan: RefCounted, banks: Array[PackedVector2Array]) -> String:
	if not plan.buildable_bounds().grow(7).has_point(position(entry)): return "请在小岛附近布置植物。"
	if not Space.water_clear(footprint(entry),banks): return "水生植物需要放在水面上，请避开岛岸。"
	if entry.kind in ["reed","cattail"] and nearest_bank(position(entry),banks)>1.4: return "芦苇和香蒲需要靠近岸边。"
	return ""

static func terrain_issue(plan: RefCounted) -> String:
	var banks: Array[PackedVector2Array]=plan.water_banks()
	for entry: Dictionary in plan.plants:
		if not habitat_issue(entry,plan,banks).is_empty(): return "这里有亲手布置的水草，请先调整植物再修改土地。"
	return ""

static func make_entry(id: int, kind: String, point: Vector2) -> Dictionary:
	var rng:=RandomNumberGenerator.new();rng.seed=hash(Vector3i(roundi(point.x*100),roundi(point.y*100),KINDS.find(kind)+1))
	return canonical([{"id":id,"kind":kind,"pose":[point.x,point.y,rng.randf()*359.9,rng.randf_range(.8,1.2)]}])[0]

static func brush_points(point: Vector2, radius: float, density: int, kind: String) -> PackedVector2Array:
	var result:=PackedVector2Array()
	var spacing: float=.7 if kind!="trapa" else .45
	var low:=Vector2i(((point-Vector2.ONE*radius)/spacing).floor())
	var high:=Vector2i(((point+Vector2.ONE*radius)/spacing).ceil())
	for y: int in range(low.y,high.y+1):
		for x: int in range(low.x,high.x+1):
			var rng:=RandomNumberGenerator.new();rng.seed=hash(Vector3i(x,y,KINDS.find(kind)+13))
			if rng.randf()>[.25,.55,.9][density-1]: continue
			var at:=Vector2(x,y)*spacing+Vector2(rng.randf_range(-.2,.2),rng.randf_range(-.2,.2))*spacing
			if at.distance_to(point)<=radius: result.append(at)
	return result
