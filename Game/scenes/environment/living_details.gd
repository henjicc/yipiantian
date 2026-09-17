extends Node3D
## Authored static porch props; positions deliberately stay outside farm and decoration slots.
const PIGMENT := preload("res://scenes/environment/pigment.gdshader")
const WINDOW_SHADER := preload("res://scenes/environment/house_warmth.gdshader")
var _house_materials: Array[ShaderMaterial] = []
var _window_lights: Array[OmniLight3D] = []
var _rope_segments: Array[MeshInstance3D] = []
var _rope_origin := Vector3(6.32, 0.38, 3.85)
var _boat: Node3D
var _wood: ShaderMaterial
var _bamboo: ShaderMaterial
var _rope: ShaderMaterial

func _ready() -> void:
	_wood = _paint(Color("756042"), 5.0)
	_bamboo = _paint(Color("a89464"), 12.0)
	_rope = _paint(Color("a09672"), 15.0)
	_build_porch_group()
	_build_drying_rack()
	_build_tools()
	_build_mooring()
	_build_windows()
	for child: Node in get_children():
		if child is Node3D and child.name in ["PorchHarvestTable","SidePorchDryingRack","PorchFarmTools","WindowWarmth"]:
			_merge_static_group(child)

func _merge_static_group(group: Node3D) -> void:
	# Small hand-built wicker parts share material, so retain their shape in few draws.
	var surfaces: Dictionary = {}
	for child: Node in group.get_children():
		if child is MeshInstance3D:
			var material: Material=child.material_override
			if not surfaces.has(material):
				var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[material]=surface
			surfaces[material].append_from(child.mesh,0,child.transform)
			group.remove_child(child)
			child.free()
	for material: Material in surfaces:
		var combined: MeshInstance3D = _mesh(group,surfaces[material].commit(),Vector3.ZERO,material)
		if group.name == "WindowWarmth":combined.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _paint(color: Color, frequency: float = 4.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PIGMENT
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("wash_scale", frequency)
	return material

func _group(label: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	node.rotation.y = deg_to_rad(yaw)
	add_child(node)
	return node

func _mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _beam(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius * 0.96
	shape.bottom_radius = radius
	shape.height = a.distance_to(b)
	shape.radial_segments = 10
	shape.rings = 1
	var node := _mesh(parent, shape, (a + b) * 0.5, material)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return node

func _lathe(parent: Node3D, at: Vector3, profile: Array[Vector2], material: Material, segments: int = 32) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j: int in range(profile.size() - 1):
		for i: int in segments:
			var a: float = float(i) / segments * TAU
			var b: float = float(i + 1) / segments * TAU
			var p: Vector2 = profile[j]
			var q: Vector2 = profile[j + 1]
			var points: Array[Vector3] = [Vector3(cos(a)*p.x,p.y,sin(a)*p.x),Vector3(cos(b)*q.x,q.y,sin(b)*q.x),Vector3(cos(b)*p.x,p.y,sin(b)*p.x),Vector3(cos(a)*p.x,p.y,sin(a)*p.x),Vector3(cos(a)*q.x,q.y,sin(a)*q.x),Vector3(cos(b)*q.x,q.y,sin(b)*q.x)]
			for point: Vector3 in points:
				var normal := Vector3(point.x, 0.0, point.z).normalized() * (q.y-p.y) + Vector3.UP * (p.x-q.x)
				surface.set_normal(normal.normalized())
				surface.add_vertex(point)
	return _mesh(parent, surface.commit(), at, material)

func _ring(parent: Node3D, at: Vector3, radius: float, thickness: float, material: Material) -> void:
	var profile: Array[Vector2] = []
	for i: int in 7:
		var angle: float = float(i) / 6.0 * TAU
		profile.append(Vector2(radius + cos(angle)*thickness, sin(angle)*thickness))
	_lathe(parent, at, profile, material)

func _basket(parent: Node3D, at: Vector3, radius: float, height: float, handle: bool) -> void:
	# Open interior, rolled rim, horizontal binding and vertical wicker ribs.
	var profile: Array[Vector2] = [Vector2(.01,0),Vector2(radius*.72,0),Vector2(radius*.86,height*.12),Vector2(radius,height*.88),Vector2(radius,height),Vector2(radius-.025,height+.01),Vector2(radius-.04,height*.88),Vector2(radius*.70,.04),Vector2(.01,.04)]
	_lathe(parent, at, profile, _bamboo)
	for level: int in 6:
		var t: float = float(level+1)/7.0
		_ring(parent, at+Vector3.UP*height*t, lerpf(radius*.86,radius,clampf((t-.12)/.76,0.0,1.0))+.007, .007, _rope)
	for i: int in 16:
		var angle: float = i*TAU/16.0
		var radial := Vector3(cos(angle),0,sin(angle))
		_beam(parent,at+radial*radius*.82+Vector3.UP*.05,at+radial*(radius+.008)+Vector3.UP*height*.95,.006,_rope)
	if handle:
		for i: int in 12:
			var a: float = i*PI/12.0
			var b: float = (i+1)*PI/12.0
			_beam(parent,at+Vector3(cos(a)*radius,height+sin(a)*radius*.88,0),at+Vector3(cos(b)*radius,height+sin(b)*radius*.88,0),.014,_wood)

func _tray(parent: Node3D, at: Vector3, radius: float, harvest: bool) -> void:
	_lathe(parent,at,[Vector2(.005,0),Vector2(radius*.92,0),Vector2(radius,.045),Vector2(radius,.075),Vector2(radius-.025,.075),Vector2(radius*.89,.022),Vector2(.005,.022)],_bamboo)
	_ring(parent,at+Vector3.UP*.068,radius-.01,.012,_wood)
	for i: int in range(-5,6):
		var offset: float = i*radius/6.0
		var half: float = sqrt(radius*radius*.8-offset*offset)
		_beam(parent,at+Vector3(offset,.026,-half),at+Vector3(offset,.026,half),.004,_rope)
		_beam(parent,at+Vector3(-half,.027,offset),at+Vector3(half,.027,offset),.004,_rope)
	if harvest:
		var dried := _paint(Color("bc8c47"),12.0)
		for i: int in 13:
			var angle: float = i*2.399
			var distance: float = radius*.69*sqrt(float(i)/13.0)
			var shape := SphereMesh.new()
			shape.radius=.043;shape.height=.03;shape.radial_segments=8;shape.rings=4
			_mesh(parent,shape,at+Vector3(cos(angle)*distance,.06,sin(angle)*distance),dried)

func _build_porch_group() -> void:
	var group := _group("PorchHarvestTable",Vector3(2.20,.40,-2.68),-4)
	# Five rounded slats and braced tapered legs, a shallow drying tray on top.
	for z: int in 5:
		_beam(group,Vector3(-.44,.62,-.24+z*.12),Vector3(.44,.62,-.24+z*.12),.041,_wood)
	for x: float in [-.33,.33]:
		for z: float in [-.18,.18]:
			_beam(group,Vector3(x*1.12,.02,z*1.1),Vector3(x,.61,z),.032,_wood)
		_beam(group,Vector3(x,.25,-.2),Vector3(x,.25,.2),.023,_wood)
	_beam(group,Vector3(-.33,.25,0),Vector3(.33,.25,0),.025,_wood)
	_tray(group,Vector3(.03,.67,0),.27,true)
	_basket(group,Vector3(-.63,0,.04),.24,.37,true)
	_basket(group,Vector3(.58,0,-.08),.18,.27,false)

func _build_drying_rack() -> void:
	var group := _group("SidePorchDryingRack",Vector3(-3.70,.14,-2.66),-9)
	for x: float in [-.48,.48]:
		_beam(group,Vector3(x,0,.28),Vector3(x,1.45,-.25),.034,_bamboo)
		_beam(group,Vector3(x,0,-.32),Vector3(x,1.45,-.25),.031,_bamboo)
		_beam(group,Vector3(x,.25,.16),Vector3(x,.25,-.31),.019,_wood)
	for y: float in [.55,1.04]:
		for z: float in [-.22,.07]:
			_beam(group,Vector3(-.53,y,z),Vector3(.53,y,z),.025,_bamboo)
		_tray(group,Vector3(-.25,y+.03,-.04),.215,true)
		_tray(group,Vector3(.25,y+.03,-.04),.215,y<.8)
	_beam(group,Vector3(-.54,1.45,-.25),Vector3(.54,1.45,-.25),.033,_bamboo)
	_basket(group,Vector3(.74,0,.03),.22,.32,false)

func _build_tools() -> void:
	var group := _group("PorchFarmTools",Vector3(-2.50,.43,-2.90),12)
	var iron := _paint(Color("575b50"),8.0)
	_beam(group,Vector3(0,.1,.12),Vector3(.16,1.18,-.07),.018,_wood)
	_beam(group,Vector3(-.19,.10,.12),Vector3(.19,.10,.12),.022,iron)
	for i: int in 6:
		_beam(group,Vector3(-.17+i*.068,.10,.12),Vector3(-.17+i*.068,.025,.21),.009,iron)
	_beam(group,Vector3(.35,.06,.05),Vector3(.24,1.03,-.06),.021,_wood)
	_beam(group,Vector3(.22,.075,.04),Vector3(.46,.075,.04),.05,iron)

func _build_mooring() -> void:
	for at: Vector3 in [Vector3(6.32,-.30,3.85),Vector3(6.05,-.3,4.48)]:
		_beam(self,at,at+Vector3.UP*.82,.071,_wood)
		_ring(self,at+Vector3.UP*.66,.075,.013,_rope)
		_ring(self,at+Vector3.UP*.70,.075,.013,_rope)
	for i: int in 12:
		_rope_segments.append(_beam(self,Vector3.ZERO,Vector3.UP*.1,.011,_rope))

func attach_boat(boat: Node3D) -> void:
	_boat = boat
	update_mooring()

func update_mooring() -> void:
	if _boat == null:return
	var finish: Vector3 = to_local(_boat.to_global(Vector3(-.95,.70,.70)))
	for i: int in _rope_segments.size():
		var a: float = float(i)/_rope_segments.size()
		var b: float = float(i+1)/_rope_segments.size()
		var p: Vector3 = _rope_origin.lerp(finish,a)-Vector3.UP*sin(a*PI)*.16
		var q: Vector3 = _rope_origin.lerp(finish,b)-Vector3.UP*sin(b*PI)*.16
		var node: MeshInstance3D = _rope_segments[i]
		node.position=(p+q)*.5
		node.scale.y=p.distance_to(q)/.1
		node.quaternion=Quaternion(Vector3.UP,(q-p).normalized())

func _build_windows() -> void:
	var group := _group("WindowWarmth",Vector3.ZERO)
	for x: float in [-1.30,2.60]:
		var light:=OmniLight3D.new()
		light.name="PorchWarmLight"
		light.position=Vector3(x,1.62,-2.68)
		light.light_color=Color("ffd195")
		light.omni_range=2.45
		light.omni_attenuation=1.65
		light.shadow_enabled=false
		group.add_child(light)
		_window_lights.append(light)
	set_window_warmth(.16)

func configure_house(node: Node) -> void:
	if node is MeshInstance3D:
		for index: int in node.mesh.get_surface_count():
			var original: Material=node.get_active_material(index)
			if original is StandardMaterial3D and original.albedo_texture != null:
				var material:=ShaderMaterial.new()
				material.shader=WINDOW_SHADER
				material.set_shader_parameter("house_color",original.albedo_texture)
				material.set_shader_parameter("color_tint",original.albedo_color)
				node.set_surface_override_material(index,material)
				_house_materials.append(material)
	for child: Node in node.get_children():configure_house(child)

func set_window_warmth(amount: float) -> void:
	if is_finite(amount):
		var strength:float=clampf(amount,0.0,1.0)
		for material: ShaderMaterial in _house_materials:
			material.set_shader_parameter("warmth",strength)
		for light: OmniLight3D in _window_lights:
			light.light_energy=strength*.70
