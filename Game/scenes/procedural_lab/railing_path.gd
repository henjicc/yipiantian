extends RefCounted
## Ground-space fitting. Keep deliberate corners; remove sub-post-scale jitter.
const TOLERANCE: float = .12
const MIN_EDGE: float = .28
const MAX_LENGTH: float = 80.0

static func fit(stroke: Array, bay: float) -> Dictionary:
	var raw: Array[Vector2] = []
	for value: Variant in stroke:
		var point := Vector2(value[0],value[1])
		if not point.is_finite(): return {"error":"路径含有无效坐标"}
		if raw.is_empty() or raw[-1].distance_to(point) >= .04: raw.append(point)
	if raw.size() < 2: return {"error":"线太短，请画长一些"}
	var length: float = 0
	for i: int in range(raw.size()-1): length += raw[i].distance_to(raw[i+1])
	if length < .65: return {"error":"线太短，请画长一些"}
	if length > MAX_LENGTH: return {"error":"本次路径过长，请分段绘制"}
	var closed: bool = length > 2.0 and raw[0].distance_to(raw[-1]) < .45
	if closed: raw[-1] = raw[0]
	var corners: Array[Vector2] = _simplify(raw)
	if closed: corners.pop_back()
	# Tiny residual corners cannot hold distinct solid posts. Merge them before
	# subdividing spans, including the closing seam.
	var changed: bool = true
	while changed and corners.size() > (3 if closed else 2):
		changed = false
		for i: int in range(corners.size() if closed else corners.size()-1):
			var next: int = (i+1)%corners.size()
			if corners[i].distance_to(corners[next]) < MIN_EDGE:
				corners.remove_at(i if next == corners.size()-1 or next == 0 else next)
				changed = true
				break
	return layout(corners,closed,bay)

static func layout(corners: Array[Vector2],closed: bool,bay: float) -> Dictionary:
	var edges: int = corners.size() if closed else corners.size()-1
	if corners.size() < 2: return {"error":"线太短，请画长一些"}
	if closed and corners.size() < 3: return {"error":"围栏范围太小，请画大一些"}
	for i: int in edges:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1)%corners.size()]
		if a.distance_to(b) < MIN_EDGE: return {"error":"转角太挤，请画宽一些"}
		if closed or i > 0:
			var incoming: Vector2 = (a-corners[posmod(i-1,corners.size())]).normalized()
			if incoming.dot((b-a).normalized()) < -.8:
				return {"error":"回折太急，请把转弯画宽一些"}
		for j: int in range(i+2,edges):
			if closed and i == 0 and j == edges-1: continue
			var c: Vector2 = corners[j]
			var d: Vector2 = corners[(j+1)%corners.size()]
			if _segments_near(a,b,c,d): return {"error":"路径交叉或靠得太近，请重新画线"}
	var points: Array[Vector2] = []
	var length: float = 0
	for i: int in edges:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1)%corners.size()]
		length += a.distance_to(b)
		var count: int = maxi(1,ceili(a.distance_to(b)/bay))
		for j: int in count: points.append(a.lerp(b,float(j)/count))
	if not closed: points.append(corners[-1])
	return {"points":points,"closed":closed,"length":length}

static func _simplify(points: Array[Vector2]) -> Array[Vector2]:
	var furthest: int = -1
	var distance: float = TOLERANCE
	for i: int in range(1,points.size()-1):
		var gap: float = _distance(points[i],points[0],points[-1])
		if gap > distance: distance=gap; furthest=i
	if furthest < 0: return [points[0],points[-1]]
	var left: Array[Vector2] = _simplify(points.slice(0,furthest+1))
	left.pop_back()
	left.append_array(_simplify(points.slice(furthest)))
	return left

static func _distance(point: Vector2,a: Vector2,b: Vector2) -> float:
	var delta: Vector2 = b-a
	var t: float = clampf((point-a).dot(delta)/maxf(delta.length_squared(),.000001),0,1)
	return point.distance_to(a+delta*t)

static func _segments_near(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> bool:
	if Geometry2D.segment_intersects_segment(a,b,c,d) != null: return true
	return minf(minf(_distance(a,c,d),_distance(b,c,d)),minf(_distance(c,a,b),_distance(d,a,b))) < .22
