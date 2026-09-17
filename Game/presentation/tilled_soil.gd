extends RefCounted
## One continuous height field across logical cells. Planting remains presentation only.

static func height_at(p: Vector2) -> float:
	var edge: float = minf(1.2 - absf(p.x), .88 - absf(p.y))
	var fade: float = smoothstep(0.0, .13, edge)
	var furrow: float = sin((p.y + .88) * TAU / .44 + sin(p.x * 5.0) * .16)
	var lumps: float = sin(p.x * 17.0 + p.y * 8.0) * sin(p.y * 21.0 - p.x * 6.0)
	return fade * (.010 * furrow + .008 * lumps + .004 * sin(p.x * 37.0 + p.y * 29.0))


static func patch(center: Vector3, span: Vector2, field_seed: int = 0) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in 16:
		for col: int in 20:
			for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var uv := Vector2((col+offset.x)/20.0, (row+offset.y)/16.0)
				var local: Vector2 = (uv - Vector2.ONE * .5) * span
				var p: Vector2 = local + Vector2(center.x, center.z)
				var e: float = .002
				var dx: float = (height_at(p + Vector2(e,0)) - height_at(p - Vector2(e,0))) / (2.0*e)
				var dz: float = (height_at(p + Vector2(0,e)) - height_at(p - Vector2(0,e))) / (2.0*e)
				surface.set_uv(uv)
				surface.set_color(Color(0,0,0,1))
				surface.set_normal(Vector3(-dx, 1.0, -dz).normalized())
				surface.add_vertex(Vector3(local.x, height_at(p), local.y))
	# Irregular aggregate clusters, merged with the cell: no per-grain node or physics.
	var rng := RandomNumberGenerator.new()
	rng.seed = 71003 + field_seed*100003 + roundi((center.x+1.2)*1000.0) + roundi((center.z+.88)*10000.0)
	var crumb := SphereMesh.new()
	crumb.radial_segments = 7
	crumb.rings = 2
	crumb.radius = 1.0
	crumb.height = 2.0
	var arrays: Array = crumb.surface_get_arrays(0)
	var clusters: Array[Vector2] = []
	for i: int in 5:
		clusters.append(Vector2(rng.randf_range(-.23,.23),rng.randf_range(-.15,.15)))
	for index: int in 192:
		var contact: bool = index >= 164
		var p := Vector2(rng.randf_range(-.275,.275),rng.randf_range(-.195,.195))
		if index < 80:
			p = clusters[index%5] + Vector2(rng.randf_range(-.05,.05),rng.randf_range(-.04,.04))
		if contact:
			var angle: float = rng.randf()*TAU
			p = Vector2(cos(angle)*rng.randf_range(.035,.09),sin(angle)*rng.randf_range(.035,.07))
		var size: float = lerpf(.006,.027,pow(rng.randf(),1.3))
		if contact: size = rng.randf_range(.010,.022)
		var basis := Basis(Vector3.UP, rng.randf()*TAU).scaled(Vector3(size, size*rng.randf_range(.55,.9), size*rng.randf_range(.6,1.4)))
		var normal_basis: Basis = basis.inverse().transposed()
		var at := Vector3(p.x, height_at(p + Vector2(center.x,center.z)) - size*rng.randf_range(.15,.40), p.y)
		var phase: float = rng.randf()*TAU
		for vertex_index: int in arrays[Mesh.ARRAY_INDEX]:
			var source: Vector3 = arrays[Mesh.ARRAY_VERTEX][vertex_index]
			var shape: float = 1.0 + .20*sin(source.x*4.1+source.y*3.7+phase)*cos(source.z*3.3-phase)
			var vertex: Vector3 = at + basis * source * shape
			surface.set_normal((normal_basis * arrays[Mesh.ARRAY_NORMAL][vertex_index]).normalized())
			surface.set_uv(Vector2(vertex.x/span.x+.5,vertex.z/span.y+.5))
			surface.set_color(Color(1 if contact else 0,0,0,1))
			surface.add_vertex(vertex)
	surface.index()
	return surface.commit()
