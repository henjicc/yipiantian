extends RefCounted
## Editable, disjoint polylines in ground coordinates. Closed runs omit the
## repeated first vertex; joining endpoints gives one shared post, never two.
const Path = preload("res://scenes/procedural_lab/railing_path.gd")
const SNAP: float = .45
const RADIUS: float = .35

static func from_plan(plan: Dictionary) -> Array:
	var paths: Array = []
	for run: Dictionary in plan.runs:
		var points: Array = []
		for point: Vector3 in run.points: points.append([point.x,point.z])
		paths.append({"points":points,"closed":run.closed})
	return paths

static func endpoint(paths: Array,at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance: float = SNAP
	for i: int in paths.size():
		if paths[i].closed: continue
		for side: int in [0,-1]:
			var point: Vector2 = v(paths[i].points[side])
			if at.distance_to(point) < distance:
				distance=at.distance_to(point)
				best={"path":i,"side":side,"point":point}
	return best

static func draw(paths: Array,stroke: Array,bay: float) -> Dictionary:
	if stroke.size() < 2: return {"error":"线太短，请画长一些"}
	var raw: Array = stroke.duplicate(true)
	var start: Dictionary = endpoint(paths,v(raw[0]))
	var end: Dictionary = endpoint(paths,v(raw[-1]))
	if not start.is_empty(): raw[0]=xy(start.point)
	if not end.is_empty(): raw[-1]=xy(end.point)
	if not start.is_empty() and not end.is_empty() and start.path==end.path and start.side==end.side:
		return {"error":"起点和终点接到了同一个断口"}
	var fitted: Dictionary = Path.fit(raw,bay)
	if fitted.has("error"): return fitted
	var points: Array = []
	for point: Vector2 in fitted.points: points.append(xy(point))
	var closed: bool = fitted.closed
	if closed and (not start.is_empty() or not end.is_empty()):
		return {"error":"请从一个断口连接到另一个断口"}
	var joined: Array = points
	if not start.is_empty():
		joined=paths[start.path].points.duplicate(true)
		if start.side==0: joined.reverse()
		joined.append_array(points.slice(1))
	if not end.is_empty():
		if not start.is_empty() and start.path==end.path:
			joined.pop_back(); closed=true
		else:
			var tail: Array = paths[end.path].points.duplicate(true)
			if end.side==-1: tail.reverse()
			joined.append_array(tail.slice(1))
	var result: Array = []
	for i: int in paths.size():
		if (not start.is_empty() and i==start.path) or (not end.is_empty() and i==end.path): continue
		result.append(paths[i].duplicate(true))
	result.append({"points":joined,"closed":closed})
	var error: String = validate(result,bay)
	return {"paths":result,"snaps":int(not start.is_empty())+int(not end.is_empty())} if error.is_empty() else {"error":error}

static func validate(paths: Array,bay: float) -> String:
	var length: float = 0
	for i: int in paths.size():
		var points: Array[Vector2] = vectors(paths[i].points)
		var checked: Dictionary = Path.layout(points,paths[i].closed,bay)
		if checked.has("error"): return checked.error
		length+=checked.length
		for j: int in range(i+1,paths.size()):
			var other: Array[Vector2] = vectors(paths[j].points)
			for a: int in range(points.size() if paths[i].closed else points.size()-1):
				for b: int in range(other.size() if paths[j].closed else other.size()-1):
					if Path._segments_near(points[a],points[(a+1)%points.size()],other[b],other[(b+1)%other.size()]):
						return "与已有栏杆交叉或靠得太近，请接到断口"
	return "栏杆总长度超过80米，请先擦除一些" if length>Path.MAX_LENGTH else ""

static func erase(paths: Array,stroke: Array) -> Array:
	var result: Array = paths.duplicate(true)
	for i: int in stroke.size():
		var a: Vector2 = v(stroke[maxi(0,i-1)])
		var b: Vector2 = v(stroke[i])
		# Swept samples prevent fast drags from leaving missed islands of railing.
		var count: int = maxi(1,ceili(a.distance_to(b)/(RADIUS*.5)))
		for step: int in count:
			var at: Vector2 = a.lerp(b,float(step+1)/count)
			var next: Array = []
			for path: Dictionary in result: next.append_array(_cut(path,at))
			result=next
	return result

static func _cut(path: Dictionary,at: Vector2) -> Array:
	var points: Array[Vector2] = vectors(path.points)
	var fragments: Array = []
	var piece: Array = []
	var cut: bool = false
	for i: int in range(points.size() if path.closed else points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var delta: Vector2 = b-a
		var offset: Vector2 = a-at
		var aa: float = delta.length_squared()
		var bb: float = 2*offset.dot(delta)
		var cc: float = offset.length_squared()-RADIUS*RADIUS
		var discriminant: float = bb*bb-4*aa*cc
		var lo: float = 1
		var hi: float = 0
		if discriminant > 0 and aa > .000001:
			lo=clampf((-bb-sqrt(discriminant))/(2*aa),0,1)
			hi=clampf((-bb+sqrt(discriminant))/(2*aa),0,1)
		if hi-lo <= .00001:
			_append_segment(piece,a,b)
			continue
		cut=true
		if lo > .00001: _append_segment(piece,a,a.lerp(b,lo))
		if not piece.is_empty(): fragments.append(piece); piece=[]
		if hi < .99999: _append_segment(piece,a.lerp(b,hi),b)
	if not cut: return [path]
	if not piece.is_empty(): fragments.append(piece)
	if path.closed and fragments.size()>1 and v(fragments[-1][-1]).is_equal_approx(v(fragments[0][0])):
		var tail: Array = fragments.pop_back()
		tail.append_array(fragments[0].slice(1)); fragments[0]=tail
	var result: Array = []
	for fragment: Array in fragments:
		# Remove only a short leftover at a cut boundary, never an untouched corner.
		while fragment.size()>1 and v(fragment[0]).distance_to(v(fragment[1]))<Path.MIN_EDGE: fragment.pop_front()
		while fragment.size()>1 and v(fragment[-1]).distance_to(v(fragment[-2]))<Path.MIN_EDGE: fragment.pop_back()
		if fragment.size()>1: result.append({"points":fragment,"closed":false})
	return result

static func _append_segment(piece: Array,a: Vector2,b: Vector2) -> void:
	if piece.is_empty(): piece.append(xy(a))
	piece.append(xy(b))

static func vectors(points: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Array in points: result.append(v(point))
	return result

static func v(point: Array) -> Vector2:
	return Vector2(point[0],point[1])

static func xy(point: Vector2) -> Array:
	return [point.x,point.y]
