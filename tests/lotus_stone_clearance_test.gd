extends SceneTree
## Actual high-detail leaf edges against shore meshes, including authored buoyancy.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var courtyard: Node3D = load("res://scenes/environment/courtyard.tscn").instantiate()
	root.add_child(courtyard)
	courtyard.set_process(false)
	var rocks: Array[MeshInstance3D] = []
	var triangles: Dictionary = {}
	var leaves: Array[MeshInstance3D] = []
	for node: Node in courtyard.get_children():
		if node.scene_file_path.get_file().begins_with("stone_") and not node.scene_file_path.ends_with("stone_bridge.glb"):
			for instance: Node in node.find_children("*", "MeshInstance3D", true, false):
				rocks.append(instance)
				if not triangles.has(instance.mesh):
					triangles[instance.mesh] = instance.mesh.generate_triangle_mesh()
		elif str(node.name).begins_with("Lotus"):
			for instance: Node in node.find_children("*", "MeshInstance3D", true, false):
				if instance.is_visible_in_tree():
					leaves.append(instance)
	var intersections: int = 0
	for sample: int in 13:
		if sample > 0:
			courtyard._process(5.0)
		for leaf: MeshInstance3D in leaves:
			var bounds: AABB = leaf.global_transform * leaf.mesh.get_aabb()
			for rock: MeshInstance3D in rocks:
				if not bounds.intersects(rock.global_transform * rock.mesh.get_aabb()):
					continue
				var faces: PackedVector3Array = leaf.mesh.get_faces()
				var to_rock: Transform3D = rock.global_transform.affine_inverse() * leaf.global_transform
				for index: int in range(0, faces.size(), 3):
					for edge: int in 3:
						var start: Vector3 = to_rock * faces[index + edge]
						var end: Vector3 = to_rock * faces[index + (edge + 1) % 3]
						if not triangles[rock.mesh].intersect_segment(start, end).is_empty():
							intersections += 1
	var passed: bool = not leaves.is_empty() and not rocks.is_empty() and intersections == 0
	print("LOTUS_STONE_CLEARANCE samples=13 seconds=60 leaves=%d rocks=%d intersecting_edges=%d passed=%s" % [leaves.size(), rocks.size(), intersections, passed])
	courtyard.free()
	await process_frame
	quit(0 if passed else 1)
