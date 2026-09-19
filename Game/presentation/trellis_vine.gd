extends RefCounted
## Root-local climbing geometry. Growth and rewards are owned by FarmState.
const Surface=preload("res://layout/construction_mesh.gd")
const Poles=preload("res://layout/fence_geometry.gd")

static func build(stage: String, dimensions: Vector3, left: bool) -> Node3D:
	var root:=Node3D.new()
	var stems:=Surface.new();var veins:=Surface.new();var leaves:=Surface.new();var fruit:=Surface.new()
	var inward: float=1.0 if left else -1.0
	var height: float=.18 if stage=="sprout" else dimensions.z*(.63 if stage=="young" else .97)
	var steps: int=maxi(4,ceili(height/.09))
	var previous:=Vector3.ZERO
	for i: int in range(1,steps+1):
		var t: float=float(i)/steps
		var point:=Vector3(sin(t*TAU*3)*.025,height*t,cos(t*TAU*3)*.025)
		Poles._pole(stems,previous,point,.008 if stage=="sprout" else .012)
		previous=point
	var count: int=3 if stage=="sprout" else (7 if stage=="young" else 11)
	for i: int in count:
		var t: float=(i+1.0)/(count+1.0)
		var at:=Vector3(0,height*t,0)
		var angle: float=i*2.35
		var length: float=.11 if stage=="sprout" else .24+sin(i*1.7)*.035
		var direction:=Vector3(cos(angle),.16,sin(angle))
		var base: Vector3=at+direction*length*.55
		Poles._pole(stems,at,base,.005)
		_leaf(leaves,veins,base,direction,length)
	if stage!="sprout":
		# A thin growing string reaches the upper side rail; the vine wraps around it.
		var twine:=Surface.new()
		Poles._pole(twine,Vector3.ZERO,Vector3(0,dimensions.z-.015,0),.003)
		_mesh(root,twine,Color("9d9169"),"Twine",false)
	if stage=="mature":
		var end:=Vector3(inward*(dimensions.y*.45),height,-.05)
		Poles._pole(stems,previous,end,.012)
		_leaf(leaves,veins,end,Vector3(inward,.1,.25),.29)
		for i: int in 2:
			var at: Vector3=previous.lerp(end,.35+i*.5)+Vector3(0,-.05,(i-.5)*.17)
			Poles._pole(stems,previous.lerp(end,.35+i*.5),at,.005)
			_gourd(fruit,at,.40+i*.08,inward)
	_mesh(root,stems,Color("597047"),"Stems")
	_mesh(root,leaves,Color("79935b"),"Leaves")
	_mesh(root,veins,Color("4f6943"),"Veins",false)
	if not fruit.vertices.is_empty(): _mesh(root,fruit,Color("95ad65"),"Fruit")
	return root

static func _leaf(surface: Surface, veins: Surface, base: Vector3, direction: Vector3, size: float) -> void:
	var forward: Vector3=direction.normalized()
	var sideways: Vector3=Vector3.UP.cross(forward).normalized()
	var center: Vector3=base+forward*size*.48+Vector3.UP*size*.12
	var border:=PackedVector3Array()
	for i: int in 20:
		var angle: float=TAU*i/20.0
		var radius: float=.78+.22*cos(angle*5)
		border.append(base+forward*(.48+cos(angle)*radius*.54)*size+sideways*sin(angle)*radius*size*.53)
	for i: int in border.size():
		_triangle(surface,center,border[i],border[(i+1)%border.size()])
		if i%4==0: Poles._pole(veins,center+Vector3.UP*.002,border[i]+Vector3.UP*.002,.0015)
	Poles._pole(veins,base,center,.002)

static func _gourd(surface: Surface, at: Vector3, length: float, side: float) -> void:
	var rings: Array[PackedVector3Array]=[]
	for i: int in 13:
		var t: float=i/12.0
		var radius: float=.009+.045*pow(sin(PI*t),.45)
		var ring:=PackedVector3Array()
		for j: int in 20:
			var angle: float=TAU*j/20.0
			var rib: float=1.0 if j%2==0 else .87
			ring.append(at+Vector3(side*.055*t*t+cos(angle)*radius*rib,-length*t,sin(angle)*radius*rib))
		rings.append(ring)
	for i: int in 12:
		for j: int in 20:
			var k: int=(j+1)%20
			_triangle(surface,rings[i][j],rings[i+1][j],rings[i+1][k])
			_triangle(surface,rings[i][j],rings[i+1][k],rings[i][k])
	for j: int in 20:
		_triangle(surface,at,rings[0][(j+1)%20],rings[0][j])
		_triangle(surface,at+Vector3(side*.055,-length,0),rings[12][j],rings[12][(j+1)%20])

static func _triangle(surface: Surface,a: Vector3,b: Vector3,c: Vector3) -> void:
	var offset: int=surface.vertices.size()
	var normal: Vector3=(c-a).cross(b-a).normalized()
	var tangent: Vector3=(b-a).normalized()
	for point: Vector3 in [a,b,c]:
		surface.vertices.append(point);surface.normals.append(normal)
		surface.tangents.append_array(PackedFloat32Array([tangent.x,tangent.y,tangent.z,1]))
		surface.uvs.append(Vector2(point.x,point.y))
	for i: int in 3: surface.indices.append(offset+i)

static func _mesh(root: Node3D,surface: Surface,tint: Color,label: String,pickable: bool=true) -> void:
	var mesh:=MeshInstance3D.new();mesh.name=label;mesh.mesh=surface.commit()
	var material:=ShaderMaterial.new();material.shader=preload("res://scenes/environment/pigment.gdshader")
	material.set_shader_parameter("base_color",tint);material.set_shader_parameter("wash_scale",8.0)
	mesh.material_override=material;root.add_child(mesh)
	if pickable:
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		body.add_child(shape);root.add_child(body)
