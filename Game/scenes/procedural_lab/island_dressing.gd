extends RefCounted
## The main courtyard's meshes, ground cover and marsh materials on a new shoreline.
const Generator = preload("res://scenes/procedural_lab/island_generator.gd")
const Cover = preload("res://scenes/environment/ground_cover.gd")
const Marsh = preload("res://scenes/environment/marsh_plants.gd")
const PIGMENT = preload("res://scenes/environment/pigment.gdshader")
static var _stones: Array[Mesh] = []
static var _stone_material: ShaderMaterial

static func stones() -> Array[Mesh]:
	if not _stones.is_empty(): return _stones
	for i: int in 5:
		var scene: Node3D = (load("res://art/environment/modules/stone_%d.glb"%i) as PackedScene).instantiate()
		var geometry: MeshInstance3D = scene.find_children("*","MeshInstance3D",true,false)[0]
		_stones.append(geometry.mesh)
		scene.free()
	_stone_material = ShaderMaterial.new()
	_stone_material.shader = PIGMENT
	_stone_material.set_shader_parameter("base_color",Color("999c88"))
	_stone_material.set_shader_parameter("wash_scale",3.5)
	_stone_material.set_shader_parameter("painted_rock",true)
	_stone_material.set_shader_parameter("stone_treatment",1.0)
	_stone_material.set_shader_parameter("rock_color",load("res://art/environment/modules/river_stones_color.png"))
	return _stones

static func stone(parent: Node3D,index: int,pose: Transform3D,tint: Color) -> void:
	var shapes: Array[Mesh] = stones()
	var node := MeshInstance3D.new()
	node.mesh = shapes[index%5]
	node.material_override = _stone_material
	node.transform = pose
	node.set_instance_shader_parameter("stone_color",tint)
	parent.add_child(node)

static func bridge_clear(island: Dictionary,point: Vector2,margin: float) -> bool:
	for zone: Dictionary in island.bridge_zones:
		if Geometry2D.get_closest_point_to_segment(point,zone.path[0],zone.path[1]).distance_to(point) < zone.radius+margin:
			return false
	return true

static func build(parent: Node3D,island: Dictionary,seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var outline: PackedVector2Array = Generator.Bank.contour(island.knots)
	var marsh := Marsh.new()
	marsh.name = "ShorePlants"
	parent.add_child(marsh)
	var plants := {"reed":[],"cattail":[],"trapa":[]}
	var distance: float = 0
	for i: int in outline.size():
		var point: Vector2 = outline[i]
		distance += point.distance_to(outline[(i+1)%outline.size()])
		if distance < .72: continue
		distance = 0
		var tangent: Vector2 = (outline[(i+1)%outline.size()]-outline[(i-1+outline.size())%outline.size()]).normalized()
		var outward := Vector2(tangent.y,-tangent.x)
		var phase: float = point.angle()
		var grouping: float = sin(phase*3+seed_value*.001)+.5*sin(phase*7+seed_value*.013)
		if not bridge_clear(island,point,.95): continue
		if grouping > -.55:
			for member: int in (2 if grouping > .5 else 1):
				var at: Vector2 = point + tangent*rng.randf_range(-.28,.28)+outward*rng.randf_range(-.16,.35)
				var size := Vector3(rng.randf_range(.7,1.4),rng.randf_range(2.1,3.8),rng.randf_range(.7,1.2))
				if not bridge_clear(island,at,maxf(size.x,size.z)*.65): continue
				stone(parent,rng.randi_range(0,4),Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(size),Vector3(at.x,-.43,at.y)),Color("889181"))
		if grouping < .1 or rng.randf() < .35: continue
		for member: int in rng.randi_range(2,4):
			var at: Vector2 = point+outward*rng.randf_range(.18,.5)+tangent*rng.randf_range(-.4,.4)
			var size: float = rng.randf_range(.45,.83)
			if not bridge_clear(island,at,.6): continue
			var species: String = "reed" if rng.randf()>.4 else "cattail"
			plants[species].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,size,size)),Vector3(at.x,-.36,at.y)))
		for member: int in rng.randi_range(2,5):
			var at: Vector2 = point+outward*rng.randf_range(.7,1.3)+tangent*rng.randf_range(-.5,.5)
			var size: float = rng.randf_range(.6,1.1)
			if not bridge_clear(island,at,.5): continue
			plants.trapa.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,.32,size)),Vector3(at.x,-.263,at.y)))
	for species: String in plants:
		if not plants[species].is_empty(): marsh._batch(marsh,species,"high",plants[species])
	grass(parent,island,rng)

static func grass(parent: Node3D,island: Dictionary,rng: RandomNumberGenerator) -> void:
	var maker := Cover.new()
	maker._rng.seed = rng.randi()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	# Same blade geometry and material as the main island, in uneven patches.
	for i: int in int(island.bound*island.bound*320):
		var p := Vector2(rng.randf_range(-island.bound,island.bound),rng.randf_range(-island.bound,island.bound))
		var patchiness: float = .40+.24*sin(p.x*1.9+sin(p.y*1.3))+.18*sin(p.y*3.1-p.x*.6)
		if rng.randf()>patchiness or not Generator.fits_disk(p,.03,island.land): continue
		var clear: bool = bridge_clear(island,p,.10)
		for obj: Dictionary in island.objects:
			var local: Vector2 = (p-obj.at).rotated(obj.yaw)
			var half_size := Vector2(2.6,1.95) if obj.kind=="house" else Vector2(1.08,1.32)
			if obj.kind in ["house","field"]:
				if absf(local.x)<half_size.x and absf(local.y)<half_size.y: clear = false; break
			elif obj.kind!="rack" and p.distance_to(obj.at)<.22: clear = false; break
		if not clear: continue
		for path: PackedVector2Array in island.paths:
			for j: int in range(path.size()-1):
				if Geometry2D.get_closest_point_to_segment(p,path[j],path[j+1]).distance_to(p)<.37: clear = false; break
			if not clear: break
		if not clear: continue
		maker._tuft(surface,Vector3(p.x,Generator.GROUND+.005,p.y),rng.randf_range(.065,.16),4)
		count += 1
	if count>0:
		var mesh := MeshInstance3D.new()
		mesh.name = "CourtyardMeadow"
		mesh.mesh = surface.commit()
		var material := ShaderMaterial.new()
		material.shader = preload("res://scenes/environment/meadow.gdshader")
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mesh)
	maker.free()
