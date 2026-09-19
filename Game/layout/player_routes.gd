extends RefCounted
## Authored lines remain independent of automatically routed garden paths.
const Space=preload("res://layout/island_space.gd")
const KINDS: Array[String]=["road","fence"]
const MAX_LINES: int=64
const MAX_POINTS: int=256
const ROAD_HALF: float=.34
const GATE_HALF: float=.65

static func point(value: Array) -> Vector2:
	return Vector2(value[0],value[1])

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _point(value: Variant) -> bool:
	return value is Array and value.size()==2 and _number(value[0]) and _number(value[1]) and absf(value[0])<=30 and absf(value[1])<=30

static func valid(value: Variant) -> bool:
	if not value is Array or value.size()>MAX_LINES: return false
	var ids: Dictionary={};var count: int=0;var length: float=0
	for entry: Variant in value:
		if not entry is Dictionary or entry.size()!=4: return false
		if not _number(entry.get("id")) or entry.id!=int(entry.id) or entry.id<1 or entry.id>2147483647 or ids.has(int(entry.id)): return false
		ids[int(entry.id)]=true
		if entry.get("kind") not in KINDS or not entry.get("points") is Array or not entry.get("openings") is Array: return false
		if entry.points.size()<2 or entry.points.size()>64 or entry.openings.size()>32: return false
		if entry.kind=="road" and not entry.openings.is_empty(): return false
		count+=entry.points.size()
		if count>MAX_POINTS: return false
		for p: Variant in entry.points:
			if not _point(p) or point(p).distance_to(Space.snap(point(p)))>.001: return false
		for i: int in range(1,entry.points.size()):
			var distance: float=point(entry.points[i-1]).distance_to(point(entry.points[i]))
			if distance<.49: return false
			length+=distance
		if length>256: return false
		for opening: Variant in entry.openings:
			if not _point(opening) or nearest_on_line(entry,point(opening)).distance_to(point(opening))>.005: return false
	return true

static func canonical(entries: Array) -> Array:
	var result: Array=entries.duplicate(true)
	for entry: Dictionary in result:
		entry.id=int(entry.id)
		for values: Array in entry.points+entry.openings:
			for i: int in 2: values[i]=float("%.4f"%values[i])
	return result

static func nearest_on_line(entry: Dictionary, target: Vector2) -> Vector2:
	var result:=Vector2.INF;var distance: float=INF
	for i: int in range(1,entry.points.size()):
		var at: Vector2=Geometry2D.get_closest_point_to_segment(target,point(entry.points[i-1]),point(entry.points[i]))
		if target.distance_squared_to(at)<distance: result=at;distance=target.distance_squared_to(at)
	return result

static func strip(a: Vector2,b: Vector2,half: float,cap: float=0.0) -> PackedVector2Array:
	var direction: Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)*half
	return PackedVector2Array([a-direction*cap-side,b+direction*cap-side,b+direction*cap+side,a-direction*cap+side])

static func road_polygons(entries: Array, margin: float=0) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]=[]
	for entry: Dictionary in entries:
		if entry.kind!="road": continue
		for i: int in range(1,entry.points.size()): result.append(strip(point(entry.points[i-1]),point(entry.points[i]),ROAD_HALF+margin,ROAD_HALF+margin))
	return result

static func road_points(entries: Array) -> PackedVector2Array:
	var result:=PackedVector2Array();var buckets: Dictionary={}
	for entry: Dictionary in entries:
		if entry.kind!="road": continue
		for i: int in range(1,entry.points.size()):
			var a: Vector2=point(entry.points[i-1]);var b: Vector2=point(entry.points[i])
			var length: float=a.distance_to(b)
			for j: int in range(ceili(length/.4)+1):
				var p: Vector2=a.lerp(b,minf(1,j*.4/length)).snapped(Vector2.ONE*.0001)
				var cell:=Vector2i((p/.27).floor());var duplicate: bool=false
				for y: int in range(-1,2):
					for x: int in range(-1,2):
						for old: Vector2 in buckets.get(cell+Vector2i(x,y),[]):
							if old.distance_squared_to(p)<.27*.27: duplicate=true;break
				if duplicate: continue
				result.append(p)
				if not buckets.has(cell): buckets[cell]=[]
				buckets[cell].append(p)
	return result

static func fence_spans(entries: Array, height: float) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var roads: Array[PackedVector2Array]=road_polygons(entries,.30)
	var seen: Dictionary={}
	var segments: Array[Dictionary]=[]
	for entry: Dictionary in entries:
		if entry.kind!="fence": continue
		for i: int in range(1,entry.points.size()):
			var a: Vector2=point(entry.points[i-1]);var b: Vector2=point(entry.points[i])
			segments.append({"a":a,"b":b,"bounds":Rect2(a,Vector2.ZERO).expand(b).grow(.001)})
	for entry: Dictionary in entries:
		if entry.kind!="fence": continue
		for i: int in range(1,entry.points.size()):
			var a: Vector2=point(entry.points[i-1]);var b: Vector2=point(entry.points[i])
			var length: float=a.distance_to(b);var axis: Vector2=(b-a)/length
			var cuts: Array[Vector2]=[]
			# Clip against whole expanded road strips: diagonal crossings need wider gaps.
			for polygon: PackedVector2Array in roads:
				for part: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a,b]),polygon):
					if part.size()>=2: cuts.append(Vector2((part[0]-a).dot(axis),(part[-1]-a).dot(axis)))
			for opening: Array in entry.openings:
				var p: Vector2=point(opening);var projection: float=(p-a).dot(axis)
				var perpendicular: float=absf((p-a).cross(axis))
				if perpendicular<GATE_HALF:
					var reach: float=sqrt(GATE_HALF*GATE_HALF-perpendicular*perpendicular)
					if projection+reach>0 and projection-reach<length: cuts.append(Vector2(maxf(0,projection-reach),minf(length,projection+reach)))
			cuts.sort_custom(func(x: Vector2,y: Vector2) -> bool: return x.x<y.x)
			var pieces: Array[Vector2]=[];var cursor: float=0
			for cut: Vector2 in cuts:
				if cut.x>cursor: pieces.append(Vector2(cursor,cut.x))
				cursor=maxf(cursor,cut.y)
			if cursor<length: pieces.append(Vector2(cursor,length))
			for piece: Vector2 in pieces:
				if piece.y-piece.x<.18: continue
				var joins: Array[float]=[piece.x,piece.y]
				# All fence crossings and collinear endpoints share a real post.
				var bounds:=Rect2(a+axis*piece.x,Vector2.ZERO).expand(a+axis*piece.y).grow(.001)
				for other: Dictionary in segments:
					if not bounds.intersects(other.bounds): continue
					var c: Vector2=other.a;var d: Vector2=other.b
					var hit: Variant=Geometry2D.segment_intersects_segment(a,b,c,d)
					var candidates: Array[Vector2]=[c,d]
					if hit!=null: candidates.append(hit)
					for p: Vector2 in candidates:
						var at: float=(p-a).dot(axis)
						if absf((p-a).cross(axis))<.001 and at>piece.x+.001 and at<piece.y-.001 and not joins.has(at): joins.append(at)
				joins.sort()
				for j: int in range(1,joins.size()):
					var span_length: float=joins[j]-joins[j-1]
					if span_length<.001: continue
					var count: int=maxi(1,ceili(span_length/1.35))
					for k: int in count:
						var start: Vector2=a+axis*(joins[j-1]+span_length*k/count)
						var end: Vector2=a+axis*(joins[j-1]+span_length*(k+1)/count)
						var key: String=str(start.snapped(Vector2.ONE*.0001))+str(end.snapped(Vector2.ONE*.0001))
						var reverse: String=str(end.snapped(Vector2.ONE*.0001))+str(start.snapped(Vector2.ONE*.0001))
						if seen.has(key) or seen.has(reverse): continue
						seen[key]=true
						result.append({"a":Vector3(start.x,height,start.y),"b":Vector3(end.x,height,end.y),"height":1.0})
	return result

static func footprints(entries: Array) -> Dictionary:
	var result: Dictionary={};var index: int=0
	for polygon: PackedVector2Array in road_polygons(entries):
		result["player_road_%d"%index]=polygon;index+=1
	index=0
	for span: Dictionary in fence_spans(entries,0):
		result["player_fence_%d"%index]=strip(Vector2(span.a.x,span.a.z),Vector2(span.b.x,span.b.z),.08,.07);index+=1
	return result

static func replace_obstacles(obstacles: Dictionary, plan: RefCounted) -> Dictionary:
	var result: Dictionary=obstacles.duplicate(true)
	for key: String in result.keys():
		if key.begins_with("player_road_") or key.begins_with("player_fence_"): result.erase(key)
	result.merge(plan.route_footprints())
	return result

static func terrain_issue(plan: RefCounted) -> String:
	var ground: PackedVector2Array=plan.plateau()
	for polygon: PackedVector2Array in plan.route_footprints().values():
		if not Space.supported(polygon,ground): return "道路和围栏需要完整落在岛上，请为岸边留出空间。"
	return ""

static func placement_issue(plan: RefCounted, obstacles: Dictionary) -> String:
	var message: String=terrain_issue(plan)
	if not message.is_empty(): return message
	var index:=Space.new()
	for key: String in obstacles:
		if key.begins_with("player_road_") or key.begins_with("player_fence_"): continue
		index.add(key,obstacles[key])
	for i: int in plan.fields.size(): index.add("field_%d"%i,plan.field_polygon(i,.08))
	for key: String in plan.route_footprints():
		var polygon: PackedVector2Array=plan.route_footprints()[key]
		for blocker: String in index.collisions(polygon):
			if blocker=="AdaptiveBridge" and key.begins_with("player_road_"):
				var ends: Array[Vector3]=preload("res://layout/island_construction.gd").bridge_points(plan)
				var a:=Vector2(ends[0].x,ends[0].z);var b:=Vector2(ends[1].x,ends[1].z)
				var walking: PackedVector2Array=strip(a,b,plan.construction.bridge[4]*.5-.06,.08)
				var fits: bool=true
				for overlap: PackedVector2Array in Geometry2D.intersect_polygons(polygon,obstacles[blocker]):
					if not Space.supported(overlap,walking): fits=false;break
				if fits: continue
			return "请避开田块、建筑和已布置的物件。"
	return ""
