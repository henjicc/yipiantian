extends RefCounted
const Parts = preload("res://scenes/procedural_lab/kit_parts.gd")
const DEFAULTS := {"length":5.4,"height":1.05,"bay":1.35,"path":1,"slope":0.0,"width":1.8}

static func plan(seed_text: String, options: Dictionary, kind: String) -> Dictionary:
	var p: Dictionary = DEFAULTS.duplicate()
	for key: String in p: p[key] = options.get(key,p[key])
	p.length = clampf(p.length,2.4,8.0)
	p.height = clampf(p.height,.7,1.4) if kind == "railing" else clampf(p.height,1.6,2.8)
	p.bay = clampf(p.bay,.8,1.8)
	p.path = clampi(int(p.path),0,2)
	p.slope = clampf(p.slope,-.18,.18)
	p.width = clampf(p.width,1.0,3.0)
	var points: Array[Vector3] = []
	if kind == "railing":
		var corners: Array[Vector3] = []
		match int(p.path):
			0: corners = [Vector3(-p.length*.5,0,0),Vector3(p.length*.5,0,0)]
			1: corners = [Vector3(-p.length*.32,0,p.length*.18),Vector3(p.length*.12,0,p.length*.18),Vector3(p.length*.12,0,-p.length*.38)]
			2: corners = [Vector3(-p.length*.32,0,p.length*.14),Vector3(-p.length*.08,0,-p.length*.14),Vector3(p.length*.12,0,-p.length*.14),Vector3(p.length*.36,0,p.length*.14)]
		var path_length: float=0
		for i: int in range(corners.size()-1): path_length+=corners[i].distance_to(corners[i+1])
		for i: int in corners.size(): corners[i]*=p.length/path_length
		for i: int in range(corners.size()-1):
			var count: int = ceili(corners[i].distance_to(corners[i+1])/p.bay)
			for j: int in count: points.append(corners[i].lerp(corners[i+1],float(j)/count))
		points.append(corners[-1])
	else:
		var count: int = maxi(1,ceili(p.length/p.bay))
		for i: int in range(count+1):
			points.append(Vector3(lerpf(-p.length*.5,p.length*.5,float(i)/count),0,0))
	for i: int in points.size(): points[i].y = ground(points[i].x,p.slope)
	return {"seed":seed_text.strip_edges(),"settings":p,"kind":kind,"points":points}

static func ground(x: float,slope: float) -> float:
	return .13+x*slope

static func build(data: Dictionary) -> Node3D:
	var parts := Parts.new()
	var p: Dictionary = data.settings
	var points: Array = data.points
	var rng := RandomNumberGenerator.new()
	rng.seed = data.seed.hash()
	if data.kind == "railing":
		for i: int in points.size():
			var along: Vector3=points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
			along.y=0
			var basis := Basis(Quaternion(Vector3.BACK,along.normalized())).scaled_local(Vector3(1,p.height/.9,1))
			# A half turn only changes grain/edge wear on the symmetric solid post.
			basis=basis*Basis(Vector3.UP,rng.randi_range(0,1)*PI)
			parts.add("fence_post",Transform3D(basis,points[i]),"near")
			parts.add("fence_post_low",Transform3D(basis,points[i]),"far")
		for i: int in range(points.size()-1):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i+1]
			for h: float in [.29,.79]:
				_fence_member(parts,a+Vector3.UP*p.height*h,b+Vector3.UP*p.height*h)
			# Braces sit between the rails, on the same centre plane. Their ends
			# land inside the solid post, not on an arbitrary forward offset.
			var heights := Vector2(p.height*.29+.06,p.height*.79-.06)
			if i%2!=0: heights=Vector2(heights.y,heights.x)
			_fence_member(parts,a+Vector3.UP*heights.x,b+Vector3.UP*heights.y,.64)
	else:
		for point: Vector3 in points:
			for side: float in [-1.0,1.0]:
				var foot: Vector3 = point+Vector3(0,-.045,side*p.width*.5)
				var top: Vector3 = point+Vector3(0,p.height,side*p.width*.41)
				_bamboo(parts,foot,top,1.3,rng)
				_binding(parts,top-Vector3.UP*.075,(top-foot).normalized())
			_bamboo(parts,point+Vector3(0,p.height-.06,-p.width*.5-.12),point+Vector3(0,p.height-.06,p.width*.5+.12),1.0,rng)
		for side: float in [-1.0,1.0]:
			var a: Vector3 = points[0]+Vector3(0,p.height-.10,side*p.width*.41)
			var b: Vector3 = points[-1]+Vector3(0,p.height-.10,side*p.width*.41)
			_bamboo(parts,a-Vector3.RIGHT*.17,b+Vector3.RIGHT*.17,1.1,rng)
			for i: int in range(points.size()-1):
				var low: Vector3 = points[i]+Vector3(0,p.height*.52,side*p.width*.455)
				var high: Vector3 = points[i+1]+Vector3(0,p.height-.18,side*p.width*.42)
				_bamboo(parts,low,high,.80,rng)
				for at: Vector3 in [low,high]: _binding(parts,at,Vector3.UP)
		# Slender roof lattice is distributed by real spacing, not stretched as one mesh.
		var roof_count: int = maxi(3,ceili(p.length/.38))
		for i: int in range(roof_count+1):
			var t: float = float(i)/roof_count
			var at: Vector3 = points[0].lerp(points[-1],t)+Vector3.UP*(p.height+.01)
			_bamboo(parts,at+Vector3(0,0,-p.width*.5-.12),at+Vector3(0,0,p.width*.5+.12),.68,rng)
		for z: float in [-.22,0,.22]:
			_bamboo(parts,points[0]+Vector3(-.17,p.height+.06,z*p.width),points[-1]+Vector3(.17,p.height+.06,z*p.width),.58,rng)
	var root: Node3D = parts.build()
	root.set_meta("plan",data)
	return root

static func _fence_member(parts: RefCounted,a: Vector3,b: Vector3,thickness: float=1.0) -> void:
	var axis: Vector3=(b-a).normalized()
	# Both end caps remain inside the post's solid 0.17m section at every turn.
	parts.span("fence_rail",a+axis*.035,b-axis*.035,thickness)

static func _bamboo(parts: RefCounted,a: Vector3,b: Vector3,thickness: float,rng: RandomNumberGenerator) -> void:
	parts.span("bamboo",a,b,thickness,"near")
	parts.span("bamboo_low",a,b,thickness,"far")
	var length: float = a.distance_to(b)
	var count: int = maxi(1,roundi(length/.32))
	var axis: Vector3 = (b-a).normalized()
	for i: int in range(1,count):
		var t: float = (i+rng.randf_range(-.10,.10))/count
		var basis := Basis(Quaternion(Vector3.BACK,axis)).scaled_local(Vector3(thickness,thickness,1))
		parts.add("node",Transform3D(basis,a.lerp(b,t)),"near")

static func _binding(parts: RefCounted,at: Vector3,axis: Vector3) -> void:
	var basis := Basis(Quaternion(Vector3.BACK,axis))
	parts.add("binding",Transform3D(basis,at),"near")
