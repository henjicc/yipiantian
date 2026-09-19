extends SceneTree

const Courtyard = preload("res://scenes/environment/courtyard.gd")
var _failures: int = 0
var _checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(label)

func _triangle_count(node: Node) -> int:
	var count: int = 0
	if node is MeshInstance3D and node.mesh != null:
		count += node.mesh.get_faces().size() / 3
	for child: Node in node.get_children():
		count += _triangle_count(child)
	return count

func _run() -> void:
	var scene: Node3D = Courtyard.new()
	root.add_child(scene)
	scene.set_process(false)
	var before: Dictionary = {}
	for slot: Dictionary in scene.get_decoration_slots():
		before[slot.id] = scene.get_slot_marker(slot.id).transform
	var boat: Node3D = scene.get_node("CoveredBoat")
	var base: Transform3D = boat.transform
	var highest: float = -INF
	var lowest: float = INF
	var lotus: Node3D = scene.get_node("Lotus0_0")
	var lotus_base: Transform3D = lotus.transform
	var lotus_high: float = -INF
	var lotus_low: float = INF
	var lotus_drift: float = 0.0
	var lotus_roll: float = 0.0
	for frame: int in 1200:
		scene._process(1.0/60.0)
		highest=maxf(highest,boat.position.y)
		lowest=minf(lowest,boat.position.y)
		lotus_high=maxf(lotus_high,lotus.position.y)
		lotus_low=minf(lotus_low,lotus.position.y)
		lotus_drift=maxf(lotus_drift,Vector2(lotus.position.x-lotus_base.origin.x,lotus.position.z-lotus_base.origin.z).length())
		lotus_roll=maxf(lotus_roll,absf(lotus.rotation.z))
	_expect(lotus_high-lotus_low > .04 and lotus_high-lotus_low < .06,"Lotus visibly rises and falls without jumping out of the water")
	_expect(lotus_drift > .02 and lotus_drift < .04,"Lotus drifts gently while staying in its authored cove")
	_expect(lotus_roll > .02 and lotus_roll < .035,"Lotus has visible bounded wave-driven tilt")
	_expect(lotus.scale.is_equal_approx(lotus_base.basis.get_scale()),"Lotus motion preserves authored model size")
	_expect(highest-lowest > .025 and highest-lowest < .06,"Boat has bounded, visible slow buoyancy")
	_expect(boat.position.distance_to(base.origin) < .06,"Boat remains moored near authored position")
	_expect(absf(boat.rotation.z)<.013 and absf(boat.rotation.x)<.006,"Boat tilt stays subtle around the waterline")
	_expect(boat.scale.is_equal_approx(Vector3.ONE*.85),"Animation preserves authored model scale and LOD pair")
	for key: String in ["Kitchen","WestTree","CoveredBoat","Lotus0_0"]:
		_expect(scene.get_asset_keys().has(key),"Generated asset retains independent detail: "+key)
	for id: String in before:
		_expect(scene.get_slot_marker(id).transform==before[id],"Ambient movement never changes decoration slots: "+id)
	var living: Node3D = scene.get_node("LivingDetails")
	# A double-sided material flips back-face normals. Wrong winding made the
	# jars appear black from the opposite shore despite outward vertex normals.
	var reversed_faces: int = 0
	for instance: Node in living.get_node("YardJarCluster").get_children():
		if not instance is MeshInstance3D:
			continue
		for surface_index: int in instance.mesh.get_surface_count():
			var arrays: Array = instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for face: int in range(0, indices.size() if not indices.is_empty() else vertices.size(), 3):
				var a: int = indices[face] if not indices.is_empty() else face
				var b: int = indices[face+1] if not indices.is_empty() else face+1
				var c: int = indices[face+2] if not indices.is_empty() else face+2
				var clockwise_normal: Vector3 = (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
				if clockwise_normal.dot(normals[a]+normals[b]+normals[c]) < -0.000001:
					reversed_faces += 1
	_expect(reversed_faces == 0, "Jar front faces agree with outward lighting normals")
	for child: Node in living.get_children():
		if child.name in ["PorchHarvestTable","SidePorchDryingRack","PorchFarmTools"]:
			_expect(child.get_child_count()<=8,"Fine prop parts merge by material: "+str(child.name))
	scene.set_window_warmth(1.0)
	_expect(living._house_materials.size()==2,"Both original house detail materials receive paper-window light")
	_expect(is_equal_approx(living._house_materials[0].get_shader_parameter("warmth"),1.0),"Warmth reaches original texture material instead of floating geometry")
	scene.set_night_weight(1.0)
	var lights: Array = living._lantern_lights
	_expect(lights.size()==7,"Two porch lanterns, two bounded bounce lights and three raised path lamps")
	_expect(is_equal_approx(lights[0].light_energy,1.15) and not lights[0].shadow_enabled,"Night weight controls bounded porch light budget")
	scene.set_window_warmth(0.0)
	_expect(lights[0].light_energy>0,"Interior window changes do not turn off outdoor lamps")
	scene.set_night_weight(0.0)
	for light: OmniLight3D in lights:
		_expect(is_zero_approx(light.light_energy) and not light.visible,"Outdoor lights are fully off in daylight")
	for mesh: MeshInstance3D in living._lantern_meshes:
		_expect(is_zero_approx(mesh.get_instance_shader_parameter("lantern_warmth")),"Lantern paper stops emitting during daylight")
	scene.set_night_weight(NAN)
	_expect(is_zero_approx(lights[0].light_energy),"Invalid night weight does not contaminate light state")
	var total: int = _triangle_count(living)
	print("LIVING_DETAILS_AUDIT triangles=%d child_groups=%d"%[total,living.get_child_count()])
	for child: Node in living.get_children():
		if child is Node3D and not child is MeshInstance3D:
			print("LIVING_GROUP name=%s triangles=%d draws=%d"%[child.name,_triangle_count(child),child.get_child_count()])
	root.remove_child(scene)
	scene.free()
	await process_frame
	print("LIVING_DETAILS_TEST checks=%d failures=%d"%[_checks,_failures])
	quit(0 if _failures==0 else 1)
