extends RefCounted
## Same dimensions and colours as the authored bamboo module; joints share posts.
const ConstructionMesh=preload("res://layout/construction_mesh.gd")
static var _pole_arrays: Array=[]
static func build(spans: Array[Dictionary], style: String = "bamboo") -> Node3D:
	assert(style in preload("res://layout/courtyard_plan.gd").FENCE_STYLES)
	var holder := Node3D.new()
	holder.name = "BoundaryFence"
	holder.set_meta("fence_spans",spans)
	holder.set_meta("fence_style",style)
	var bamboo := ConstructionMesh.new()
	var joints := ConstructionMesh.new()
	var posts: Dictionary = {}
	for span: Dictionary in spans:
		for p: Vector3 in [span.a,span.b]:
			var key := Vector2i(roundi(p.x*10000),roundi(p.z*10000))
			if not posts.has(key) or span.height>posts[key].height: posts[key]={"at":p,"height":span.height}
		for height: float in [.27,.67]:
			_pole(bamboo,span.a+Vector3.UP*height*span.height,span.b+Vector3.UP*height*span.height,.043)
		if style=="crossed":
			for ends: Vector2 in [Vector2(.27,.67),Vector2(.67,.27)]:
				_pole(bamboo,span.a+Vector3.UP*ends.x*span.height,span.b+Vector3.UP*ends.y*span.height,.025)
		elif style=="picket":
			var count: int=maxi(2,ceili(span.a.distance_to(span.b)/.18))
			for i: int in range(1,count):
				var at: Vector3=span.a.lerp(span.b,float(i)/count)
				_pole(bamboo,at+Vector3.UP*.15*span.height,at+Vector3.UP*(.77+sin(i*2.1)*.025)*span.height,.025)
	for post: Dictionary in posts.values():
		_pole(bamboo,post.at,post.at+Vector3.UP*.85*post.height,.055)
		for height: float in [.19,.52,.76]:
			_pole(joints,post.at+Vector3.UP*height*post.height,post.at+Vector3.UP*(height*post.height+.035),.064)
	for item: Array in [[bamboo,Color(.52,.46,.27)],[joints,Color(.33,.24,.15)]]:
		if spans.is_empty(): continue
		var mesh := MeshInstance3D.new()
		mesh.mesh=item[0].commit()
		var material := ShaderMaterial.new()
		material.shader=preload("res://scenes/environment/pigment.gdshader")
		material.set_shader_parameter("base_color",item[1])
		material.set_shader_parameter("wash_scale",3.5)
		mesh.material_override=material
		holder.add_child(mesh)
	var contacts:=preload("res://presentation/fence_contacts.gd").new()
	contacts.name="Contacts";holder.add_child(contacts)
	return holder

static func _pole(surface: ConstructionMesh,a: Vector3,b: Vector3,radius: float) -> void:
	var direction: Vector3 = b-a
	if _pole_arrays.is_empty():
		var shape:=CylinderMesh.new();shape.top_radius=1.0;shape.bottom_radius=1.0
		shape.height=1.0;shape.radial_segments=10;shape.rings=1
		_pole_arrays=shape.get_mesh_arrays()
	var basis := Basis(Quaternion(Vector3.UP,direction.normalized()))*Basis.from_scale(Vector3(radius,direction.length(),radius))
	surface.append(_pole_arrays,Transform3D(basis,(a+b)*.5))
