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
	for frame: int in 1200:
		scene._process(1.0/60.0)
		highest=maxf(highest,boat.position.y)
		lowest=minf(lowest,boat.position.y)
	_expect(highest-lowest > .025 and highest-lowest < .06,"Boat has bounded, visible slow buoyancy")
	_expect(boat.position.distance_to(base.origin) < .06,"Boat remains moored near authored position")
	_expect(absf(boat.rotation.z)<.013 and absf(boat.rotation.x)<.006,"Boat tilt stays subtle around the waterline")
	_expect(boat.scale.is_equal_approx(Vector3.ONE*.85),"Animation preserves authored model scale and LOD pair")
	_expect(scene.get_asset_keys().size()==90,"Asset instances retain independent existing detail contract")
	for id: String in before:
		_expect(scene.get_slot_marker(id).transform==before[id],"Ambient movement never changes decoration slots: "+id)
	var living: Node3D = scene.get_node("LivingDetails")
	for child: Node in living.get_children():
		if child.name in ["PorchHarvestTable","SidePorchDryingRack","PorchFarmTools"]:
			_expect(child.get_child_count()<=8,"Fine prop parts merge by material: "+str(child.name))
	scene.set_window_warmth(1.0)
	_expect(living._house_materials.size()==2,"Both original house detail materials receive paper-window light")
	_expect(is_equal_approx(living._house_materials[0].get_shader_parameter("warmth"),1.0),"Warmth reaches original texture material instead of floating geometry")
	var lights: Array = living._window_lights
	_expect(lights.size()==2,"Two local porch lights exist independently of unlocked decorations")
	_expect(is_equal_approx(lights[0].light_energy,.7) and not lights[0].shadow_enabled,"Window warmth controls bounded local light budget")
	scene.set_window_warmth(0.0)
	_expect(is_zero_approx(lights[0].light_energy),"Window lights respond to daylight control")
	scene.set_window_warmth(NAN)
	_expect(is_zero_approx(lights[0].light_energy),"Invalid warmth does not contaminate light state")
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
