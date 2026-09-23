extends Node3D
const Generator = preload("res://scenes/procedural_lab/island_generator.gd")
const Batch = preload("res://layout/construction_mesh.gd")
const Poles = preload("res://layout/fence_geometry.gd")
const Wind = preload("res://presentation/plant_wind.gd")
const PIGMENT = preload("res://scenes/environment/pigment.gdshader")
var plan: Dictionary
var markers := Node3D.new()
var bridge_targets: Array[Vector3] = []
var rack_targets: Array[Vector3] = []
var counts: Dictionary = {}
var _assets: Dictionary = {}
var _wind := Wind.new()
var _box: Array = BoxMesh.new().get_mesh_arrays()

func build(data: Dictionary) -> void:
	plan = data
	markers.name = "PlanningOverlay"
	add_child(markers)
	markers.visible = false
	for island: Dictionary in data.islands:
		var root := Node3D.new()
		root.position = v3(island.center)
		add_child(root)
		var bank := MeshInstance3D.new()
		bank.mesh = Generator.Bank.build(island.knots)
		bank.material_override = pigment(Color("827452"),true)
		root.add_child(bank)
		var paths := Batch.new()
		var road_rng := RandomNumberGenerator.new()
		road_rng.seed = (str(data.seed)+str(island.center)).hash()
		var stone_shape := CylinderMesh.new()
		stone_shape.top_radius = 1.0; stone_shape.bottom_radius = 1.0
		stone_shape.height = 1.0; stone_shape.radial_segments = 7
		var stone_arrays: Array = stone_shape.get_mesh_arrays()
		var placed: Array[Vector2] = []
		for path: PackedVector2Array in island.paths:
			var travelled: float = 0
			var next_step: float = .85
			for i: int in range(path.size()-1):
				var segment: float = path[i].distance_to(path[i+1])
				while next_step <= travelled+segment:
					var point: Vector2 = path[i].lerp(path[i+1],(next_step-travelled)/segment)
					var clear: bool = true
					for other: Vector2 in placed:
						if point.distance_to(other)<.32: clear = false
					if clear:
						var tangent: Vector2 = (path[i+1]-path[i]).normalized()
						var basis := Basis(Vector3.UP,-tangent.angle()+road_rng.randf_range(-.12,.12))
						paths.append(stone_arrays,Transform3D(basis*Basis.from_scale(Vector3(.23,.055,road_rng.randf_range(.36,.43))),v3(point,.157)))
						placed.append(point)
					next_step += .46
				travelled += segment
		finish(root,paths,Color("858875"))
		var plaza := CylinderMesh.new()
		plaza.top_radius = 1.05; plaza.bottom_radius = 1.05; plaza.height = .028
		var hub := MeshInstance3D.new()
		hub.mesh = plaza; hub.position.y = .147; hub.material_override = pigment(Color("92917a"))
		root.add_child(hub)
		for obj: Dictionary in island.objects:
			counts[obj.kind] = counts.get(obj.kind,0)+1
			var holder := Node3D.new()
			holder.position = v3(obj.at,Generator.GROUND)
			holder.rotation.y = obj.yaw
			root.add_child(holder)
			match obj.kind:
				"house": asset(holder,"res://art/environment/house/house_high.glb",4.25)
				"tree", "bamboo", "flowers":
					asset(holder,"res://art/environment/%s/%s_high.glb"%[obj.kind,obj.kind],obj.radius*1.85,obj.kind)
				"field": field(holder)
				"rack":
					rack(holder,data.settings.rack_length,data.settings.rack_height)
					rack_targets.append(v3(island.center+obj.at,1.0))
			var ring := PackedVector3Array()
			for k: int in 49:
				ring.append(v3(island.center+obj.at+Vector2.from_angle(k*TAU/48)*obj.radius,.19))
			line(markers,ring,Color("cbb876"),.025)
		var coast := PackedVector3Array()
		for p: Vector2 in island.land: coast.append(v3(island.center+p,.18))
		coast.append(coast[0])
		line(markers,coast,Color("d9e9b1"),.035)
	for link: Dictionary in data.links:
		bridge(link,data.settings)
		bridge_targets.append(v3((link.start+link.end)*.5,.6))

func pigment(color: Color, ground: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PIGMENT
	mat.set_shader_parameter("base_color",color)
	mat.set_shader_parameter("ground_treatment",1.0 if ground else 0.0)
	return mat

func asset(parent: Node3D, path: String, diagonal: float, wind_kind: String = "") -> void:
	if not _assets.has(path):
		var packed: PackedScene = load(path)
		var sample: Node3D = packed.instantiate()
		var bounds: AABB = bounds_of(sample,Transform3D.IDENTITY)
		_assets[path] = {"scene":packed,"bounds":bounds}
		sample.free()
	var record: Dictionary = _assets[path]
	var node: Node3D = record.scene.instantiate()
	var bounds: AABB = record.bounds
	# Preserve proportions and contact; the reserve radius encloses every roof/crown corner.
	var scale_value: float = diagonal/Vector2(bounds.size.x,bounds.size.z).length()
	node.scale = Vector3.ONE*scale_value
	node.position = -Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*scale_value
	parent.add_child(node)
	if not wind_kind.is_empty(): _wind.apply(node,wind_kind)

static func bounds_of(node: Node3D, parent_pose: Transform3D) -> AABB:
	var pose: Transform3D = parent_pose*node.transform
	var result := AABB()
	var found: bool = false
	if node is MeshInstance3D:
		result = pose*node.get_aabb(); found = true
	for child: Node in node.get_children():
		if not child is Node3D: continue
		var part: AABB = bounds_of(child,pose)
		if part.size == Vector3.ZERO: continue
		result = result.merge(part) if found else part
		found = true
	return result

func field(parent: Node3D) -> void:
	var soil := Batch.new()
	for row: int in 3:
		block(soil,Vector3((row-1)*.62,.065,0),Vector3(.5,.13,2.5))
	finish(parent,soil,Color("675039"))
	for row: int in 3:
		for col: int in 4:
			var plant := Node3D.new()
			plant.position = Vector3((row-1)*.62,.13,(col-1.5)*.59)
			parent.add_child(plant)
			asset(plant,"res://art/crops/tatsoi/tatsoi_mature.glb",.47,"tatsoi")

func rack(parent: Node3D, length: float, height: float) -> void:
	var rods := Batch.new()
	var ties := Batch.new()
	var bays: int = ceili(length/1.0)
	for i: int in bays+1:
		var x: float = -length*.5+length*i/bays
		for side: float in [-1.0,1.0]:
			var p := Vector3(x,0,side*.52)
			Poles._pole(rods,p,p+Vector3.UP*height,.045)
			for h: float in [.55,height-.08]:
				Poles._pole(ties,p+Vector3.UP*h,p+Vector3.UP*(h+.045),.055)
		Poles._pole(rods,Vector3(x,height,-.66),Vector3(x,height,.66),.035)
	for side: float in [-1.0,1.0]:
		for h: float in [.55,height]:
			Poles._pole(rods,Vector3(-length*.5,h,side*.52),Vector3(length*.5,h,side*.52),.033)
		# Diagonal bracing remains a fixed diameter as bay count changes.
		Poles._pole(rods,Vector3(-length*.5,.25,side*.52),Vector3(-length*.5+length/bays,height-.15,side*.52),.025)
	for i: int in ceili(length/.25)+1:
		var x: float = lerpf(-length*.5,length*.5,i/float(ceili(length/.25)))
		Poles._pole(rods,Vector3(x,height+.02,-.62),Vector3(x,height+.02,.62),.018)
	finish(parent,rods,Color("9d9260"))
	finish(parent,ties,Color("564d32"))

func bridge(link: Dictionary, settings: Dictionary) -> void:
	var a: Vector3 = v3(link.start,Generator.GROUND)
	var b: Vector3 = v3(link.end,Generator.GROUND)
	var length: float = a.distance_to(b)
	var side: Vector3 = Vector3.UP.cross((b-a).normalized())
	var deck := Batch.new()
	var rails := Batch.new()
	var piles := Batch.new()
	var n: int = ceili(length/.25)
	for i: int in n:
		var p: Vector3 = bridge_point(a,b,i/float(n),settings.arch)
		var q: Vector3 = bridge_point(a,b,(i+1)/float(n),settings.arch)
		beam(deck,p-Vector3.UP*.045,q-Vector3.UP*.045,settings.bridge_width,.09)
	var bays: int = ceili(length/.95)
	for edge: float in [-1.0,1.0]:
		for i: int in bays+1:
			var p: Vector3 = bridge_point(a,b,i/float(bays),settings.arch)+side*(edge*(settings.bridge_width*.5-.055))
			block(rails,p+Vector3.UP*.39,Vector3(.10,.78,.10))
			if i < bays:
				var q: Vector3 = bridge_point(a,b,(i+1)/float(bays),settings.arch)+side*(edge*(settings.bridge_width*.5-.055))
				for h: float in [.36,.76]: beam(rails,p+Vector3.UP*h,q+Vector3.UP*h,.065,.065)
		var supports: int = maxi(1,ceili(length/3.0))
		for i: int in supports+1:
			var p: Vector3 = bridge_point(a,b,i/float(supports),settings.arch)+side*(edge*(settings.bridge_width*.5-.16))
			Poles._pole(piles,Vector3(p.x,-1.1,p.z),p-Vector3.UP*.045,.105)
	finish(self,deck,Color("a59878"))
	finish(self,rails,Color("786548"))
	finish(self,piles,Color("635740"))

static func bridge_point(a: Vector3,b: Vector3,t: float,rise: float) -> Vector3:
	# Zero slope at both ends: the first plank meets the path without a step.
	return a.lerp(b,t)+Vector3.UP*rise*pow(sin(PI*t),2)

func block(batch: RefCounted, at: Vector3, size: Vector3) -> void:
	batch.append(_box,Transform3D(Basis.from_scale(size),at))

func beam(batch: RefCounted, a: Vector3, b: Vector3, width: float, height: float) -> void:
	if a.is_equal_approx(b): return
	var forward: Vector3 = (b-a).normalized()
	var side: Vector3 = Vector3.UP.cross(forward).normalized()
	var up: Vector3 = forward.cross(side)
	batch.append(_box,Transform3D(Basis(side,up,forward)*Basis.from_scale(Vector3(width,height,a.distance_to(b)+.008)),(a+b)*.5))

func finish(parent: Node3D,batch: RefCounted,color: Color) -> void:
	if batch.vertices.is_empty(): return
	var mesh := MeshInstance3D.new()
	mesh.mesh = batch.commit()
	mesh.material_override = pigment(color)
	parent.add_child(mesh)

func line(parent: Node3D,points: PackedVector3Array,color: Color,width: float) -> void:
	var batch := Batch.new()
	for i: int in range(points.size()-1): beam(batch,points[i],points[i+1],width,.012)
	finish(parent,batch,color)

static func v3(p: Vector2,y: float = 0) -> Vector3:
	return Vector3(p.x,y,p.y)
