extends SceneTree
## CPU mirror of the authored wind envelope against actual neighbouring surfaces.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var yard: Node3D = load("res://scenes/environment/courtyard.tscn").instantiate()
	root.add_child(yard); yard.set_process(false)
	var tree: Node3D = yard.get_node("WestTree")
	var mesh: MeshInstance3D = tree.get_child(0).find_children("*","MeshInstance3D",true,false)[0]
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var targets: Array[MeshInstance3D] = []
	var cache: Dictionary = {}
	var bounds: AABB = mesh.global_transform*mesh.mesh.get_aabb()
	for node: Node in yard.get_children():
		if (node.scene_file_path.contains("/modules/") and not node.scene_file_path.ends_with("island_bank.glb")) or node.name == "LivingDetails":
			for target: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
				if bounds.grow(.22).intersects(target.global_transform*target.mesh.get_aabb()):
					targets.append(target)
					cache[target] = target.mesh.generate_triangle_mesh()
	var hits: Dictionary = {}
	var phase: float = Vector2(mesh.global_position.x,mesh.global_position.z).dot(Vector2(.71,.43))
	for sample: int in 13:
		var time: float = sample*5.0
		var points := PackedVector3Array()
		for i: int in vertices.size():
			var p: Vector3 = mesh.global_transform*vertices[i]
			var weight: Color = colors[i]
			var breeze: float = sin(time*.72+phase)*.68+sin(time*1.13+phase*1.7)*.32
			var ripple: float = sin(p.dot(Vector3(4.1,2.7,3.6))+time*2.2)
			p += Vector3(.86,.04,.51)*breeze*.14*weight.r
			p += Vector3(.35,.12,-.75)*ripple*.025*weight.g
			p += Vector3(-.20,.10,.42)*sin(time*1.05+weight.b*3+phase)*.07*weight.r
			p += Vector3(.5,.25,-.4)*sin(time*3.1+weight.b*11+phase)*.025*weight.g
			points.append(p)
		for target: MeshInstance3D in targets:
			var matrix: Transform3D = target.global_transform.affine_inverse()
			for i: int in range(0,indices.size(),3):
				for edge: int in 3:
					if not cache[target].intersect_segment(matrix*points[indices[i+edge]],matrix*points[indices[i+(edge+1)%3]]).is_empty():
						var key: String = str(target.get_path())
						hits[key] = int(hits.get(key,0))+1
	print("OSMANTHUS_CLEARANCE samples=13 seconds=60 neighbours=%d intersecting_edges=%s" % [targets.size(),JSON.stringify(hits)])
	yard.free(); quit(0 if hits.is_empty() else 1)
