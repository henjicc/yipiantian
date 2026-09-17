extends MultiMeshInstance3D
## Six bounded mesh instances: sparse September leaf fall, no physics bodies.
## Emission samples the actual authored crown; only the clear west garden bay is used.
const COUNT: int = 6
const PERIOD: float = 13.0
const FLOOR: float = 0.148
var _time: float = 0.0
var _anchors: Array[Vector3] = []
var _origins: Array[Vector3] = []
var _cycles: Array[int] = []
var _rng := RandomNumberGenerator.new()


func configure(tree: Node3D) -> void:
	_rng.seed = 9174101
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _leaf_mesh()
	multimesh.instance_count = COUNT
	# The high mesh is first; do not sample the hidden LOD as a second crown.
	_sample(tree.get_child(0))
	assert(not _anchors.is_empty(), "Osmanthus crown has no leaf emission points in the clear garden bay")
	for i: int in COUNT:
		_origins.append(_anchors[_rng.randi_range(0, _anchors.size()-1)])
		_cycles.append(0)
		multimesh.set_instance_color(i, Color("a9aa61").lerp(Color("7d9252"), float(i)/COUNT))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_update(0.0)


func _sample(node: Node) -> void:
	if node is MeshInstance3D:
		for surface: int in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i: int in range(0, vertices.size(), 13):
				if colors[i].g < 0.6:
					continue
				var point: Vector3 = to_local(node.global_transform * vertices[i])
				# Wind drifts +X/+Z. Keep trajectories inside the grass, away from the
				# fence at x=-6.65, the trellis, beds and ground_03 decoration slot.
				if point.x > -5.85 and point.x < -5.6 and point.z > 3.5 and point.z < 3.9 and point.y > 2.1:
					_anchors.append(point)
	for child: Node in node.get_children():
		_sample(child)


func _process(delta: float) -> void:
	if multimesh != null and not _anchors.is_empty():
		_update(delta)


func _update(delta: float) -> void:
	_time += delta
	for i: int in COUNT:
		var clock: float = _time + float(i)*PERIOD/COUNT
		var cycle: int = floori(clock/PERIOD)
		if cycle != _cycles[i]:
			_cycles[i] = cycle
			_origins[i] = _anchors[_rng.randi_range(0, _anchors.size()-1)]
		var age: float = fmod(clock, PERIOD)
		var fall: float = clampf(age/8.0, 0.0, 1.0)
		var p: Vector3 = _origins[i] + Vector3(0.38, 0, 0.22)*fall
		p.y = lerpf(_origins[i].y, FLOOR, pow(fall, 1.12))
		p.x += sin(age*1.6+i)*0.09*sin(PI*fall)
		p.z += cos(age*1.1+i)*0.08*sin(PI*fall)
		var airborne: float = 1.0-smoothstep(0.88, 1.0, fall)
		var scale_value: float = smoothstep(0.0, 0.3, age)*(1.0-smoothstep(11.0, PERIOD, age))
		var rotation_value := Vector3(sin(age*2.5+i)*0.8*airborne, i*1.9+age*0.5, cos(age*1.7+i)*0.7*airborne)
		var pose := Transform3D(Basis.from_euler(rotation_value).scaled(Vector3.ONE*maxf(0.001,scale_value)), p)
		multimesh.set_instance_transform(i, pose)


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
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.96
	material.metallic_specular = 0.08
	st.set_material(material)
	return st.commit()
