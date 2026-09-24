extends RefCounted
## Shared metric meshes; one batch per component and detail tier in each object.
const BRIDGE := "res://art/environment/procedural_bridge/"
const KIT := "res://art/environment/parametric_kit/"
static var sources: Dictionary = {}
var groups: Dictionary = {}

func add(part: String, pose: Transform3D, detail: String = "both") -> void:
	var key: String = part+":"+detail
	if not groups.has(key): groups[key] = []
	groups[key].append(pose)

func span(part: String, a: Vector3, b: Vector3, thickness: float = 1.0, detail: String = "both") -> void:
	var direction: Vector3 = b-a
	var basis := Basis(Quaternion(Vector3.BACK,direction.normalized()))
	add(part,Transform3D(basis.scaled_local(Vector3(thickness,thickness,direction.length())),(a+b)*.5),detail)

func build() -> Node3D:
	var root := Node3D.new()
	for key: String in groups:
		var terms: PackedStringArray = key.split(":")
		var part: String = terms[0]
		var detail: String = terms[1]
		for source: Dictionary in _source(part):
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.mesh = source.mesh
			batch.instance_count = groups[key].size()
			for i: int in batch.instance_count:
				batch.set_instance_transform(i,groups[key][i]*source.pose)
			var node := MultiMeshInstance3D.new()
			node.name = part+"_"+detail
			node.multimesh = batch
			if detail == "near": node.visibility_range_end = 26
			if detail == "far": node.visibility_range_begin = 26
			if detail != "both":
				node.visibility_range_end_margin = 0
				node.visibility_range_begin_margin = 0
				# Alpha HLOD fading sorts incorrectly against the depth-writing lake.
				node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			root.add_child(node)
	shared_detail_bounds(root)
	return root

static func shared_detail_bounds(root: Node3D) -> void:
	# Match the distance origin of all near/far components, including meshes with
	# slightly different reduced bounds. Both tiers switch as one complete object.
	var bounds := AABB()
	var first: bool=true
	for node: GeometryInstance3D in root.get_children():
		var local_bounds: AABB=node.transform*node.get_aabb()
		bounds=local_bounds if first else bounds.merge(local_bounds)
		first=false
	for node: GeometryInstance3D in root.get_children(): node.custom_aabb=bounds

static func _source(part: String) -> Array:
	if sources.has(part): return sources[part]
	var path: String = (BRIDGE if part in ["post","rail","beam","plank"] else KIT)+part+".glb"
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	var found: Array = []
	_collect(scene,Transform3D.IDENTITY,found)
	scene.free()
	sources[part] = found
	return found

static func _collect(node: Node3D,parent_pose: Transform3D,found: Array) -> void:
	var pose: Transform3D = parent_pose*node.transform
	if node is MeshInstance3D:
		found.append({"mesh":node.mesh,"pose":pose})
	for child: Node in node.get_children():
		if child is Node3D: _collect(child,pose,found)
