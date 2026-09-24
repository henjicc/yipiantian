extends RefCounted
## Continuous authored wood; seeded crown placements always follow its sockets.
const Parts = preload("res://scenes/procedural_lab/kit_parts.gd")
const Wind = preload("res://presentation/plant_wind.gd")
const DEFAULTS := {"height":4.2,"spread":4.4,"density":.55,"bias":.25}
static var sockets: Dictionary = {}
static var wind := Wind.new()

static func plan(seed_text: String, options: Dictionary) -> Dictionary:
	if sockets.is_empty(): sockets=JSON.parse_string(FileAccess.get_file_as_string("res://art/environment/parametric_kit/tree_sockets.json"))
	var p: Dictionary=DEFAULTS.duplicate()
	for key: String in p: p[key]=options.get(key,p[key])
	p.height=clampf(p.height,3,5.8); p.spread=clampf(p.spread,2.8,6)
	p.density=clampf(p.density,0,1); p.bias=clampf(p.bias,0,.7)
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_text.strip_edges().hash()
	var shape: Dictionary={"width":p.spread/4.4,"height":p.height/4.2,"twist":rng.randf_range(-.36,.36),"bias":p.bias,"yaw":rng.randf()*TAU,"depth":rng.randf_range(1.18,1.40)}
	var clusters: Array[Transform3D]=[]
	var anchors: Array[Vector3]=[]
	var base_scale: float=sqrt(shape.width*shape.height)*lerpf(.76,1.05,p.density)
	for socket: Dictionary in sockets.sockets:
		var raw_at := Vector3(socket.at[0],socket.at[1],socket.at[2])
		var raw_axis := Vector3(socket.axis[0],socket.axis[1],socket.axis[2])
		var at: Vector3=_deform(raw_at,shape)
		var axis: Vector3=(_deform(raw_at+raw_axis*.02,shape)-at).normalized()
		anchors.append(at)
		var scale: float=base_scale*rng.randf_range(.86,1.13)
		var pose := Transform3D(Basis(Quaternion(Vector3.UP,axis))*Basis(Vector3.UP,rng.randf()*TAU),at)
		clusters.append(pose.scaled_local(Vector3.ONE*scale))
		# Several shoots may emerge at one terminal node; matching root axes keep
		# their joints closed while rotation changes the spread of their leaves.
		if rng.randf()<p.density*.60:
			pose.basis=pose.basis*Basis(Vector3.UP,PI*rng.randf_range(.65,1.35))
			clusters.append(pose.scaled_local(Vector3.ONE*scale*.82))
	# Bounds use real imported vertices, not a bounding-box corner proxy.
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for source: Dictionary in Parts._source("tree_trunk"):
		for s: int in source.mesh.get_surface_count():
			for vertex: Vector3 in source.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var v: Vector3=_deform(source.pose*vertex,shape)
				low=low.min(v); high=high.max(v)
	for pose: Transform3D in clusters:
		for source: Dictionary in Parts._source("tree_cluster"):
			for s: int in source.mesh.get_surface_count():
				for vertex: Vector3 in source.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					var v: Vector3=pose*source.pose*vertex
					low=low.min(v); high=high.max(v)
	var fit := Vector3(p.spread/maxf(high.x-low.x,high.z-low.z),p.height/(high.y-low.y),p.spread/maxf(high.x-low.x,high.z-low.z))
	var offset := Vector3(-(low.x+high.x)*.5,-low.y,-(low.z+high.z)*.5)*fit+Vector3.UP*.13
	for i: int in clusters.size(): clusters[i]=Transform3D(Basis.from_scale(fit),offset)*clusters[i]
	for i: int in anchors.size(): anchors[i]=anchors[i]*fit+offset
	return {"kind":"tree","seed":seed_text.strip_edges(),"settings":p,"shape":shape,"fit":fit,"offset":offset,"clusters":clusters,"anchors":anchors,"joint":anchors[0],"bounds":AABB(low*fit+offset,(high-low)*fit)}

static func _deform(v: Vector3,shape: Dictionary) -> Vector3:
	var crown: float=smoothstep(.45,2.5,v.y)
	var turned: Vector3=Basis(Vector3.UP,shape.twist*crown)*v
	turned.x*=lerpf(shape.height,shape.width,crown)
	turned.z*=lerpf(shape.height,shape.width*shape.depth,crown)
	turned.y*=shape.height
	turned.x+=shape.bias*crown*crown*.75
	return Basis(Vector3.UP,shape.yaw)*turned

static func _normal(at: Vector3,n: Vector3,data: Dictionary) -> Vector3:
	var epsilon: float=.002
	var centre: Vector3=_deform(at,data.shape)
	var jacobian := Basis((_deform(at+Vector3.RIGHT*epsilon,data.shape)-centre)*data.fit/epsilon,(_deform(at+Vector3.UP*epsilon,data.shape)-centre)*data.fit/epsilon,(_deform(at+Vector3.BACK*epsilon,data.shape)-centre)*data.fit/epsilon)
	return (jacobian.inverse().transposed()*n).normalized()

static func build(data: Dictionary) -> Node3D:
	var parts := Parts.new()
	for pose: Transform3D in data.clusters:
		parts.add("tree_cluster",pose,"near")
		parts.add("tree_cluster_low",pose,"far")
	var root: Node3D=parts.build()
	for node: Node in root.get_children():
		node.material_override=wind._convert(node.multimesh.mesh.surface_get_material(0))
		node.set_instance_shader_parameter("wind_authored",1.0)
		node.set_instance_shader_parameter("wind_motion",Vector4(.035,.18,0,.006))
		node.set_instance_shader_parameter("wind_authored_bend",.018)
		node.set_instance_shader_parameter("preserve_painted_color",0.0)
		node.extra_cull_margin=.15
	for detail: String in ["near","far"]:
		var mesh := ArrayMesh.new()
		for source: Dictionary in Parts._source("tree_trunk" if detail=="near" else "tree_trunk_low"):
			for s: int in source.mesh.get_surface_count():
				var arrays: Array=source.mesh.surface_get_arrays(s)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				for i: int in vertices.size():
					var at: Vector3=source.pose*vertices[i]
					normals[i]=_normal(at,source.pose.basis*normals[i],data)
					vertices[i]=_deform(at,data.shape)*data.fit+data.offset
				arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
				arrays[Mesh.ARRAY_TANGENT]=null
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				mesh.surface_set_material(mesh.get_surface_count()-1,source.mesh.surface_get_material(s))
		var trunk := MeshInstance3D.new()
		trunk.name="Framework_"+detail; trunk.mesh=mesh
		if detail=="near": trunk.visibility_range_end=26
		else: trunk.visibility_range_begin=26
		trunk.visibility_range_begin_margin=0; trunk.visibility_range_end_margin=0
		trunk.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		root.add_child(trunk)
	Parts.shared_detail_bounds(root)
	root.set_meta("plan",data)
	return root
