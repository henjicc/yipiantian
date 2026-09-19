extends RefCounted
## The same actual meshes and poses feed startup routes and interactive placement.
const Living = preload("res://presentation/living_decoration.gd")
const Space = preload("res://scenes/environment/animal_space.gd")

static func build(environment: Node3D, id: String) -> Node3D:
	if id in ["bench","drying_rack","tea_table"]:
		return Living.build(environment.get_node("LivingDetails"),id)
	return environment.get_decoration_scene(id).instantiate()

static func pose(node: Node3D, entry: Dictionary, plan: RefCounted) -> void:
	var at: Vector3=plan.slots[entry.slot_id] if not entry.slot_id.is_empty() else Vector3(entry.position[0],plan.ground_height+.005,entry.position[1])
	var yaw: float=float(entry.quarter_turn)*PI/2
	if entry.slot_id=="hanging_03": yaw+=deg_to_rad(preload("res://layout/island_construction.gd").trellis_yaw(plan))
	node.global_transform=Transform3D(Basis(Vector3.UP,yaw),at)

static func footprints(instances: Dictionary, ground_height: float) -> Dictionary:
	var result: Dictionary={}
	for id: String in instances:
		var polygon: PackedVector2Array=Space.cached_footprint(instances[id],ground_height-.08,ground_height+1.17)
		if polygon.size()>=3: result["decoration_"+id]=polygon
	return result
