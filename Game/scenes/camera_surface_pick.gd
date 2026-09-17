extends RefCounted
## Click-time visual picking: scenery has no physics collision bodies.
## Cache only meshes whose bounds the ray actually reaches; release on mode exit.
var _triangles: Dictionary = {}


func pick(camera: Camera3D, screen_point: Vector2, fallback_depth: float) -> Vector3:
	var start := camera.project_ray_origin(screen_point)
	var end := start + camera.project_ray_normal(screen_point) * camera.far
	var hit := _visit(camera.get_parent(), camera, start, end)
	return hit if hit != Vector3.INF else camera.project_position(screen_point, fallback_depth)


func clear() -> void:
	_triangles.clear()


func _visit(node: Node, camera: Camera3D, start: Vector3, end: Vector3) -> Vector3:
	# Camera-relative framing and painted distant scenery are not inspection targets.
	if node == camera or node.name == "DistantRiverPanorama":
		return Vector3.INF
	if node is Node3D and not node.is_visible_in_tree():
		return Vector3.INF
	var nearest := Vector3.INF
	if node is GeometryInstance3D and (node.layers & camera.cull_mask) != 0:
		if node is MeshInstance3D and node.mesh != null:
			nearest = _mesh_hit(node.mesh, node.global_transform, start, end)
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
			var count: int = node.multimesh.instance_count
			if node.multimesh.visible_instance_count >= 0:
				count = mini(count, node.multimesh.visible_instance_count)
			for index: int in count:
				var hit := _mesh_hit(node.multimesh.mesh, node.global_transform * node.multimesh.get_instance_transform(index), start, end)
				if hit != Vector3.INF:
					nearest = hit
					end = hit
	if nearest != Vector3.INF:
		end = nearest
	for child: Node in node.get_children():
		var hit := _visit(child, camera, start, end)
		if hit != Vector3.INF:
			nearest = hit
			end = hit
	return nearest


func _mesh_hit(mesh: Mesh, pose: Transform3D, start: Vector3, end: Vector3) -> Vector3:
	if is_zero_approx(pose.basis.determinant()):
		return Vector3.INF
	var inverse := pose.affine_inverse()
	var local_start := inverse * start
	var local_end := inverse * end
	if mesh.get_aabb().intersects_segment(local_start, local_end) == null:
		return Vector3.INF
	if not _triangles.has(mesh):
		_triangles[mesh] = mesh.generate_triangle_mesh()
	var triangles: TriangleMesh = _triangles[mesh]
	if triangles == null:
		return Vector3.INF
	var hit := triangles.intersect_segment(local_start, local_end)
	return pose * hit.position if not hit.is_empty() else Vector3.INF
