extends RefCounted
## A disposable layout, independent of FarmState. All distances are metres.
const Bank = preload("res://layout/bank_geometry.gd")
const DEFAULTS := {"count": 3, "radius": 7.5, "coast": .65, "gap": 3.0, "density": 14,
	"bridge_width": 1.5, "arch": .65, "rack_length": 3.0, "rack_height": 2.1}
const GROUND := .13

static func generate(seed_text: String, options: Dictionary) -> Dictionary:
	var settings: Dictionary = DEFAULTS.duplicate()
	settings.merge(options, true)
	settings.count = clampi(int(settings.count), 1, 5)
	settings.radius = clampf(float(settings.radius), 6.5, 10)
	settings.coast = clampf(float(settings.coast), 0, 1)
	settings.gap = clampf(float(settings.gap), 2, 7)
	settings.density = clampi(int(settings.density), 0, 28)
	settings.bridge_width = clampf(float(settings.bridge_width), 1.1, 2.2)
	settings.arch = clampf(float(settings.arch), 0, 1.2)
	settings.rack_length = clampf(float(settings.rack_length), 2, 4)
	settings.rack_height = clampf(float(settings.rack_height), 1.5, 2.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_text.strip_edges().hash()
	var islands: Array[Dictionary] = []
	for i: int in int(settings.count):
		var phase := Vector3(rng.randf()*TAU, rng.randf()*TAU, rng.randf()*TAU)
		var knots := PackedVector2Array()
		# Positive, low-frequency radial harmonics make a simple, star-shaped coast.
		# The central area stays broad enough for usable land; no needle peninsulas.
		for k: int in 24:
			var a: float = k*TAU/24.0
			var r: float = settings.radius * (1 + settings.coast * (.13*sin(a*2+phase.x)+.09*sin(a*3+phase.y)+.045*sin(a*5+phase.z)))
			knots.append(Vector2(cos(a),sin(a))*r)
		var outline: PackedVector2Array = Bank.contour(knots)
		var land := PackedVector2Array()
		var bound: float = 0
		for p: Vector2 in outline:
			land.append(p*.93) # inside the outer flat ring, leaving a grass shoulder
			bound = maxf(bound, p.length()*1.075)
		var center := Vector2.ZERO
		if i > 0:
			# Pack a small connected archipelago; rejection uses the full submerged skirt.
			var best_score: float = INF
			for attempt: int in 100:
				var parent: Dictionary = islands[rng.randi_range(0,i-1)]
				var angle: float = rng.randf()*TAU
				var candidate: Vector2 = parent.center + Vector2.from_angle(angle)*(bound+parent.bound+settings.gap)
				var clear: bool = true
				for other: Dictionary in islands:
					if candidate.distance_to(other.center) < bound+other.bound+settings.gap-.01:
						clear = false
				if clear and candidate.length_squared() < best_score:
					best_score = candidate.length_squared()
					center = candidate
			# A deterministic outer candidate also guarantees placement if packing rejects all.
			if best_score == INF:
				var right: float = 0
				for other: Dictionary in islands: right = maxf(right, other.center.x+other.bound)
				center = Vector2(right+bound+settings.gap,0)
		islands.append({"center":center,"knots":knots,"land":land,"bound":bound,"paths":[],"bridge_zones":[],"objects":[]})
	var links: Array[Dictionary] = []
	var joined: Array[int] = [0]
	while joined.size() < islands.size():
		var best: Dictionary = {}
		var distance: float = INF
		for a: int in joined:
			for b: int in islands.size():
				if b in joined: continue
				var delta: Vector2 = islands[b].center-islands[a].center
				if delta.length() >= distance: continue
				var blocked: bool = false
				for c: int in islands.size():
					if c == a or c == b: continue
					if Geometry2D.get_closest_point_to_segment(islands[c].center,islands[a].center,islands[b].center).distance_to(islands[c].center) < islands[c].bound+settings.bridge_width:
						blocked = true
				if blocked: continue
				var start: Vector2 = landing(islands[a], delta.normalized(), settings.bridge_width)
				var finish: Vector2 = landing(islands[b], -delta.normalized(), settings.bridge_width)
				distance = delta.length()
				best = {"a":a,"b":b,"start":start+islands[a].center,"end":finish+islands[b].center}
		if best.is_empty():
			return {"error":"未能找到避开其他岛屿的桥线，请换一个种子。"}
		links.append(best)
		joined.append(best.b)
		for pair: Array in [[best.a,best.start],[best.b,best.end]]:
			var island: Dictionary = islands[pair[0]]
			island.paths.append(make_path(Vector2.ZERO, pair[1]-island.center, island.land, rng, .62))
			island.bridge_zones.append({"path":PackedVector2Array([best.start-island.center,best.end-island.center]),"radius":settings.bridge_width*.5+.12})
	for i: int in islands.size():
		var island: Dictionary = islands[i]
		# Reserve paths first, then place the full footprints. Later vegetation cannot block them.
		place_object(island, "house", 2.25, rng, true)
		place_object(island, "field", 1.85, rng, true)
		place_object(island, "field", 1.85, rng, true)
		place_object(island, "rack", sqrt(pow(settings.rack_length*.5+.15,2)+.75*.75), rng, true)
		for j: int in int(settings.density):
			place_object(island, "tree" if j%3==0 else ("bamboo" if j%3==1 else "flowers"), 1.05 if j%3==0 else .65, rng, false)
	return {"seed":seed_text.strip_edges(),"settings":settings,"islands":islands,"links":links,"error":""}

static func fits_disk(point: Vector2, radius: float, land: PackedVector2Array) -> bool:
	# Count a vertex only once. Godot 4.7.2's finite-ray helper can double-count
	# a coast vertex and reject an interior point (seed 边界-0, dense preset).
	var inside: bool = false
	for i: int in land.size():
		var a: Vector2 = land[i]
		var b: Vector2 = land[(i+1)%land.size()]
		if (a.y>point.y) != (b.y>point.y):
			if point.x < (b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x: inside = not inside
		if Geometry2D.get_closest_point_to_segment(point,a,b).distance_to(point) < radius:
			return false
	return inside

static func landing(island: Dictionary, direction: Vector2, width: float) -> Vector2:
	var p := Vector2.ZERO
	# The entire bridge mouth and a short approach remain on the flat plateau.
	for step: int in int(island.bound/.1):
		var candidate: Vector2 = direction*step*.1
		if not fits_disk(candidate,width*.5+.3,island.land): break
		p = candidate
	return p

static func make_path(a: Vector2, b: Vector2, land: PackedVector2Array, rng: RandomNumberGenerator, half_width: float) -> PackedVector2Array:
	var delta: Vector2 = b-a
	var bend: Vector2 = (a+b)*.5+Vector2(-delta.y,delta.x).normalized()*rng.randf_range(-.65,.65)
	var points := PackedVector2Array()
	var valid: bool = true
	for i: int in 21:
		var t: float = i/20.0
		var p: Vector2 = a.lerp(bend,t).lerp(bend.lerp(b,t),t)
		points.append(p)
		if not fits_disk(p,half_width,land): valid = false
	return points if valid else PackedVector2Array([a,b])

static func distance_to_path(point: Vector2, path: PackedVector2Array) -> float:
	var distance: float = INF
	for i: int in range(path.size()-1):
		distance = minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,path[i],path[i+1])))
	return distance

static func place_object(island: Dictionary, kind: String, radius: float, rng: RandomNumberGenerator, accessible: bool) -> void:
	for attempt: int in 180:
		var p: Vector2 = Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(2.7,island.bound*.85)
		if not fits_disk(p,radius+.18,island.land): continue
		if p.length() < radius+1.1: continue
		var clear: bool = true
		for obj: Dictionary in island.objects:
			if p.distance_to(obj.at) < radius+obj.radius+.25: clear = false
		for path: PackedVector2Array in island.paths:
			if distance_to_path(p,path) < radius+.70: clear = false
		for zone: Dictionary in island.bridge_zones:
			if distance_to_path(p,zone.path) < radius+zone.radius: clear = false
		if not clear: continue
		var access: PackedVector2Array = PackedVector2Array([Vector2.ZERO,p-p.normalized()*(radius+.10)])
		if accessible:
			for obj: Dictionary in island.objects:
				if distance_to_path(obj.at,access) < obj.radius+.65: clear = false
			for j: int in 21:
				if not fits_disk(access[0].lerp(access[1],j/20.0),.62,island.land): clear = false
			if not clear: continue
			island.paths.append(access)
		island.objects.append({"kind":kind,"at":p,"radius":radius,"yaw":atan2(-p.x,-p.y) if accessible else rng.randf()*TAU})
		return
