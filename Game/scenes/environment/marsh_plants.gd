extends Node3D
## Seeded clumps follow an actual mesh/water intersection, never a guessed ellipse.
## Two batched emergent species plus floating Trapa; no per-stalk physics/nodes.
const ROOT := "res://art/environment/archipelago/"
const SURFACE = preload("res://scenes/environment/marsh_surface.gdshader")
static var _sources: Dictionary = {}
var _tiers: Array[Node3D] = []
var shoreline_points: PackedVector3Array = []
var clump_count := 0

func populate(island: Node3D, seed_value: int) -> void:
	var bins: Dictionary = {}
	_slice(island,bins)
	var keys: Array = bins.keys()
	keys.sort()
	for key: int in keys: shoreline_points.append(bins[key])
	if shoreline_points.is_empty():
		push_error("No waterline found for "+str(get_parent().name))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placements := {"reed":[],"cattail":[],"trapa":[]}
	# Sparse groups, unplanted landing gaps, variable height and yaw. About half
	# the shore stays open; open water remains connected between households.
	for index: int in shoreline_points.size():
		if sin(index*.41+seed_value) < -.15 or index%5 != 0: continue
		var point: Vector3 = shoreline_points[index]
		# Preserve the canonical front landing/access gap. A timber pier's piles
		# also intersect the water plane but must not be treated as planting soil.
		if point.z>1.0 and absf(point.x)<1.45: continue
		var outward := Vector3(point.x,0,point.z).normalized()
		var tangent := Vector3(-outward.z,0,outward.x)
		for member: int in rng.randi_range(2,4):
			var species: String = "reed" if rng.randf()>.34 else "cattail"
			var position_on_shore := point+tangent*rng.randf_range(-.35,.35)+outward*rng.randf_range(-.10,.20)
			position_on_shore.y = to_local(Vector3(0,-.36,0)).y
			var size: float = rng.randf_range(.43,.82)
			placements[species].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,size*rng.randf_range(.85,1.15),size)),position_on_shore))
		for member: int in rng.randi_range(3,6):
			var position_on_water := point+outward*rng.randf_range(.25,1.05)+tangent*rng.randf_range(-.7,.7)
			# Flattened rosette roots below water, leaf blade just above it.
			position_on_water.y = to_local(Vector3(0,-.263,0)).y
			var size: float = rng.randf_range(.60,1.10)
			placements.trapa.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,.32,size)),position_on_water))
	for tier: String in ["high","low"]:
		var group := Node3D.new()
		group.name = tier
		add_child(group)
		_tiers.append(group)
		for species: String in placements:
			_batch(group,species,tier,placements[species])
	for species: String in placements: clump_count += placements[species].size()
	set_low_detail(true)

func populate_lake() -> void:
	var transforms: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed=91839
	var heading := Basis(Vector3.UP,deg_to_rad(27.5))
	for cove: Vector2 in [Vector2(-16,2),Vector2(-11,15),Vector2(-21,23),Vector2(11,8),Vector2(21,23),Vector2(0,32)]:
		var centre: Vector3=heading*Vector3(cove.x,0,-cove.y)
		for index: int in 12:
			var angle: float=rng.randf()*TAU
			var radius: float=sqrt(rng.randf())*1.05
			var point:=centre+Vector3(cos(angle)*radius,-.263,sin(angle)*radius*.6)
			var size: float=rng.randf_range(.6,1.1)
			transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,.32,size)),point))
	for tier: String in ["high","low"]:
		var group:=Node3D.new()
		group.name=tier
		add_child(group)
		_tiers.append(group)
		_batch(group,"trapa",tier,transforms)
	clump_count=transforms.size()
	set_low_detail(false)

func _slice(node: Node3D, bins: Dictionary) -> void:
	if node is MeshInstance3D:
		var faces: PackedVector3Array = node.mesh.get_faces()
		for index: int in range(0,faces.size(),3):
			var triangle: Array[Vector3] = [node.to_global(faces[index]),node.to_global(faces[index+1]),node.to_global(faces[index+2])]
			var hits: Array[Vector3] = []
			for edge: int in 3:
				var a: Vector3 = triangle[edge]
				var b: Vector3 = triangle[(edge+1)%3]
				if (a.y<=-.25 and b.y>-.25) or (b.y<=-.25 and a.y>-.25): hits.append(to_local(a.lerp(b,(-.25-a.y)/(b.y-a.y))))
			if hits.size()!=2: continue
			var point: Vector3 = (hits[0]+hits[1])*.5
			var bin_id: int = posmod(roundi(atan2(point.z,point.x)/TAU*96),96)
			if not bins.has(bin_id) or Vector2(point.x,point.z).length_squared()>Vector2(bins[bin_id].x,bins[bin_id].z).length_squared(): bins[bin_id]=point
	for child: Node in node.get_children():
		if child is Node3D: _slice(child,bins)

func _batch(parent: Node3D, species: String, tier: String, transforms: Array) -> void:
	var key: String = species+"_"+tier
	if not _sources.has(key):
		var source: Node3D = (load(ROOT+key+".glb") as PackedScene).instantiate()
		var geometry: MeshInstance3D = source.find_children("*","MeshInstance3D",true,false)[0]
		_sources[key]={"mesh":geometry.mesh,"texture":geometry.get_active_material(0).albedo_texture}
		source.free()
	var source: Dictionary = _sources[key]
	var material := ShaderMaterial.new()
	material.shader=SURFACE
	material.set_shader_parameter("painted_color",source.texture)
	material.set_shader_parameter("floating",species=="trapa")
	var mesh := MultiMesh.new()
	mesh.transform_format=MultiMesh.TRANSFORM_3D
	mesh.mesh=source.mesh
	mesh.instance_count=transforms.size()
	for index: int in transforms.size(): mesh.set_instance_transform(index,transforms[index])
	var batch := MultiMeshInstance3D.new()
	batch.name=species
	batch.multimesh=mesh
	batch.material_override=material
	batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.extra_cull_margin=.12
	parent.add_child(batch)

func set_low_detail(enabled: bool) -> void:
	if _tiers.size()!=2: return
	_tiers[0].visible=not enabled
	_tiers[1].visible=enabled
