extends MultiMeshInstance3D
## Fourteen bounded GPU instances: sparse September petals/leaves, no physics bodies.
## Emission samples the actual authored crown; only the clear west garden bay is used.
const COUNT: int = 14
var _anchors: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()


func configure(tree: Node3D) -> void:
	_rng.seed = 9174101
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _leaf_mesh()
	multimesh.instance_count = COUNT
	# The high mesh is first; do not sample the hidden LOD as a second crown.
	_sample(tree.get_child(0))
	assert(not _anchors.is_empty(), "Osmanthus crown has no leaf emission points in the clear garden bay")
	for i: int in COUNT:
		var origin: Vector3 = _anchors[_rng.randi_range(0, _anchors.size()-1)]
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, origin))
		multimesh.set_instance_custom_data(i, Color(float(i)/COUNT, origin.y, _rng.randf(), 1.0))
		multimesh.set_instance_color(i, Color("efe1aa") if i % 3 != 0 else Color("a9aa61"))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-6.5,0,3.0),Vector3(1.5,5.0,2.4))
	set_process(false)


func _sample(node: Node) -> void:
	if node is MeshInstance3D:
		for surface: int in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i: int in range(0, vertices.size(), 13):
				if colors.size() > i and colors[i].g < 0.6:
					continue
				var point: Vector3 = to_local(node.global_transform * vertices[i])
				# Wind drifts +X/+Z. Keep trajectories inside the grass, away from the
				# fence at x=-6.65, the trellis, beds and ground_03 decoration slot.
				if point.x > -6.15 and point.x < -5.55 and point.z > 3.45 and point.z < 4.1 and point.y > 1.8:
					_anchors.append(point)
	for child: Node in node.get_children():
		_sample(child)


func _leaf_mesh() -> ArrayMesh:
	# A gently folded, eight-triangle leaf. Source tree appearance stays Tripo;
	# these small animation instances are local geometry, not a second AI asset.
	var points: Array[Vector3] = [Vector3(0,0,-.10),Vector3(-.034,0,-.055),Vector3(-.045,0,0),Vector3(-.029,0,.05),Vector3(0,0,.085),Vector3(.029,0,.05),Vector3(.045,0,0),Vector3(.034,0,-.055)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in points.size():
		st.add_vertex(Vector3(0,.009,0))
		st.add_vertex(points[(i+1)%points.size()])
		st.add_vertex(points[i])
	st.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = preload("res://presentation/falling_petals.gdshader")
	st.set_material(material)
	return st.commit()
