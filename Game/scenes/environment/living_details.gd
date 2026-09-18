extends Node3D
## Authored porch props; four living areas can be replaced by player decorations.
const PIGMENT := preload("res://scenes/environment/pigment.gdshader")
const WINDOW_SHADER := preload("res://scenes/environment/house_warmth.gdshader")
const Assets = preload("res://scenes/environment/courtyard_assets.gd")
var _house_materials: Array[ShaderMaterial] = []
var _lantern_meshes: Array[MeshInstance3D] = []
var _window_lights: Array[OmniLight3D] = []
var _rope_segments: Array[MeshInstance3D] = []
var plan := preload("res://layout/courtyard_plan.gd").new()
var _rope_origin: Vector3
var _boat: Node3D
var _wood: ShaderMaterial
var _bamboo: ShaderMaterial
var _rope: ShaderMaterial
var _clay: ShaderMaterial
var _straw: ShaderMaterial
var _iron: ShaderMaterial

func _ready() -> void:
	_wood = _paint(Color("756042"), 5.0)
	_bamboo = _paint(Color("a89464"), 12.0)
	_rope = _paint(Color("a09672"), 15.0)
	_clay = _paint(Color("a8835d"), 6.0)
	_straw = _paint(Color("c0a068"), 10.0)
	_iron = _paint(Color("6d7166"), 8.0)
	_build_porch_group()
	_build_drying_rack()
	_build_tools()
	_build_mooring()
	_build_windows()
	_build_yard_props()
	# Every authored group merges by material; the animated mooring rope lives
	# directly on this node and is deliberately not part of any merged group.
	for child: Node in get_children():
		if child is Node3D and not child is MeshInstance3D:
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
			# Primitive meshes carry indices; lathes do not. Appending the latter
			# into an indexed surface otherwise leaves their vertices undrawn.
			var indexed:=SurfaceTool.new()
			indexed.create_from(child.mesh,0)
			indexed.index()
			surfaces[material].append_from(indexed.commit(),0,child.transform)
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

func _group(label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = plan.props[label][0]
	node.rotation.y = deg_to_rad(plan.props[label][1])
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
			# Godot front faces use clockwise winding; keep outward normals on the visible shell.
			for index: int in [0, 2, 1, 3, 5, 4]:
				var point: Vector3 = points[index]
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
		Assets.place(parent,"slices",at+Vector3(0,.033,0),radius*211.0,radius*1.65/.40)

func _build_porch_group() -> void:
	# Fit the table between the veranda posts at world X=2.15 and 3.80.
	# Baskets sit forward of the post shoes and outside the splayed table legs.
	var group := _group("PorchHarvestTable")
	# Five rounded slats and braced tapered legs, a shallow drying tray on top.
	for z: int in 5:
		_beam(group,Vector3(-.44,.62,-.24+z*.12),Vector3(.44,.62,-.24+z*.12),.041,_wood)
	for x: float in [-.33,.33]:
		for z: float in [-.18,.18]:
			_beam(group,Vector3(x*1.12,.02,z*1.1),Vector3(x,.61,z),.032,_wood)
		_beam(group,Vector3(x,.25,-.2),Vector3(x,.25,.2),.023,_wood)
	_beam(group,Vector3(-.33,.25,0),Vector3(.33,.25,0),.025,_wood)
	_tray(group,Vector3(.03,.67,0),.27,true)
	# Leave the front-left railing contact clear for the usable hoe blade.
	_basket(group,Vector3(-.50,0,-.02),.13,.30,true)
	_basket(group,Vector3(.66,0,.21),.13,.25,false)

func _build_drying_rack() -> void:
	var group := _group("SidePorchDryingRack")
	for x: float in [-.48,.48]:
		_beam(group,Vector3(x,0,.28),Vector3(x,1.45,-.25),.034,_bamboo)
		_beam(group,Vector3(x,0,-.32),Vector3(x,1.45,-.25),.031,_bamboo)
		_beam(group,Vector3(x,.25,.16),Vector3(x,.25,-.31),.019,_wood)
	for y: float in [.55,1.04]:
		for z: float in [-.22,.07]:
			_beam(group,Vector3(-.53,y,z),Vector3(.53,y,z),.025,_bamboo)
		_tray(group,Vector3(-.25,y+.03,-.04),.215,y<.8)
		if y>.8:
			var food: Node3D=Assets.place(group,"slices",Vector3(-.25,y+.063,-.04),45,.78)
			food.name="DryingContents"
		_tray(group,Vector3(.25,y+.03,-.04),.215,y<.8)
	_beam(group,Vector3(-.54,1.45,-.25),Vector3(.54,1.45,-.25),.033,_bamboo)
	_basket(group,Vector3(.74,0,.03),.22,.32,false)

func _build_tools() -> void:
	var group := _group("PorchFarmTools")
	var iron := _paint(Color("575b50"),8.0)
	_beam(group,Vector3(0,.1,.12),Vector3(.16,1.18,-.07),.018,_wood)
	_beam(group,Vector3(-.19,.10,.12),Vector3(.19,.10,.12),.022,iron)
	for i: int in 6:
		_beam(group,Vector3(-.17+i*.068,.10,.12),Vector3(-.17+i*.068,.025,.21),.009,iron)
	_beam(group,Vector3(.35,.06,.05),Vector3(.24,1.03,-.06),.021,_wood)
	_beam(group,Vector3(.22,.075,.04),Vector3(.46,.075,.04),.05,iron)

func _build_mooring() -> void:
	var rise: float=plan.ground_height-.13
	_rope_origin = plan.anchors.mooring + Vector3.UP * (.68+rise)
	for at: Vector3 in [plan.anchors.mooring,plan.anchors.mooring + Vector3(-.27,0,.63)]:
		_beam(self,at,at+Vector3.UP*(.82+rise),.071,_wood)
		_ring(self,at+Vector3.UP*(.66+rise),.075,.013,_rope)
		_ring(self,at+Vector3.UP*(.70+rise),.075,.013,_rope)
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
	var group := _group("WindowWarmth")
	for x: float in [-1.30,2.60]:
		var lantern: Node3D = Assets.place(group,"lantern",Vector3(x,1.91,-2.40))
		for mesh: MeshInstance3D in lantern.find_children("*","MeshInstance3D",true,false):
			_lantern_meshes.append(mesh)
		_beam(group,Vector3(x,2.48,-2.40),Vector3(x,2.62,-2.40),.009,_rope)
		var light:=OmniLight3D.new()
		light.name="PorchWarmLight"
		light.position=Vector3(x,2.16,-2.34)
		light.light_color=Color("ffd195")
		light.omni_range=4.2
		light.omni_attenuation=1.45
		light.shadow_enabled=false
		group.add_child(light)
		_window_lights.append(light)
		var spill := OmniLight3D.new()
		spill.name = "LanternGardenBounce"
		spill.position = Vector3(x,1.05,-.95)
		spill.light_color = Color("ebba7d")
		spill.omni_range = 3.4
		spill.omni_attenuation = 1.6
		spill.shadow_enabled = false
		spill.set_meta("energy_scale",.24)
		group.add_child(spill)
		_window_lights.append(spill)
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
			light.light_energy=strength*float(light.get_meta("energy_scale",1.15))
		for mesh: MeshInstance3D in _lantern_meshes:
			mesh.set_instance_shader_parameter("lantern_warmth",strength)


## Yard set dressing. Layout and animal navigation consume these actual meshes;
## the shared plan identifies the four replaceable living areas.
func _build_yard_props() -> void:
	_build_water_vats()
	_build_firewood()
	_build_stone_mill()
	_build_jar_cluster()
	_build_ground_trays()
	_build_basket_stack()
	_build_yard_bucket()
	_build_drying_line()
	_build_melon_pile()
	_build_seed_frames()


func _vessel(parent: Node3D, at: Vector3, radius: float, height: float, material: ShaderMaterial) -> void:
	# A thrown jar profile: narrow foot, full belly, turned-in shoulder, rolled lip,
	# then back down the inside so the open mouth reads from the overview angle.
	var profile: Array[Vector2] = [
		Vector2(.02, 0), Vector2(radius * .52, 0), Vector2(radius * .66, height * .08),
		Vector2(radius, height * .42), Vector2(radius * .92, height * .72),
		Vector2(radius * .68, height * .94), Vector2(radius * .72, height),
		Vector2(radius * .62, height * .99), Vector2(radius * .58, height * .80),
		Vector2(radius * .80, height * .44), Vector2(radius * .40, height * .10)]
	_lathe(parent, at, profile, material, 20)


func _log_billet(parent: Node3D, at: Vector3, length: float, radius: float, yaw: float) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius * 1.04
	shape.height = length
	shape.radial_segments = 7
	shape.rings = 1
	var node: MeshInstance3D = _mesh(parent, shape, at, _wood)
	node.quaternion = Quaternion(Vector3.UP, Vector3(cos(yaw), 0.0, sin(yaw)))


func _build_water_vats() -> void:
	var group := _group("YardWaterVats")
	_vessel(group, Vector3.ZERO, .40, .60, _clay)
	_vessel(group, Vector3(.66, 0, .18), .27, .40, _paint(Color("96785f"), 7.0))
	# Plank lid and a long-handled dipper resting across the smaller vat.
	for i: int in 3:
		var plank := BoxMesh.new()
		plank.size = Vector3(.115, .022, .44)
		_mesh(group, plank, Vector3(.66 + (i - 1) * .125, .405, .18), _wood)
	_beam(group, Vector3(.30, .44, -.16), Vector3(-.16, .68, -.30), .017, _bamboo)
	_lathe(group, Vector3(.30, .42, -.16), [Vector2(.005, 0), Vector2(.075, .01), Vector2(.082, .07), Vector2(.068, .072), Vector2(.062, .02), Vector2(.005, .018)], _bamboo, 14)


func _build_firewood() -> void:
	var group := _group("YardFirewood")
	_lathe(group, Vector3(-.52, 0, .10), [Vector2(.01, 0), Vector2(.21, 0), Vector2(.215, .34), Vector2(.20, .36), Vector2(.01, .36)], _wood, 14)
	# Axe left standing in the chopping block.
	_beam(group, Vector3(-.50, .34, .09), Vector3(-.40, .80, .02), .019, _bamboo)
	var head := BoxMesh.new()
	head.size = Vector3(.075, .155, .045)
	var blade: MeshInstance3D = _mesh(group, head, Vector3(-.494, .40, .086), _iron)
	blade.rotation = Vector3(0, 0, .21)
	for row: int in 4:
		var count: int = 5 - row / 2
		for i: int in count:
			var jitter: float = sin(row * 3.1 + i * 2.3) * .018
			_log_billet(group, Vector3(.30 + jitter, .075 + row * .135, -.42 + i * .168), .70, .066, PI * .5 + sin(row * 1.7 + i) * .05)
	_log_billet(group, Vector3(.06, .066, .34), .58, .062, 1.15)


func _build_stone_mill() -> void:
	var group := _group("YardStoneMill")
	var granite := _paint(Color("9ea49a"), 4.0)
	granite.set_shader_parameter("stone_treatment", 1.0)
	var pedestal := _paint(Color("8d928a"), 4.0)
	pedestal.set_shader_parameter("stone_treatment", 1.0)
	_lathe(group, Vector3.ZERO, [Vector2(.01, 0), Vector2(.26, 0), Vector2(.23, .30), Vector2(.01, .30)], pedestal, 16)
	_lathe(group, Vector3(0, .30, 0), [Vector2(.01, 0), Vector2(.47, .015), Vector2(.49, .075), Vector2(.47, .105), Vector2(.01, .105)], granite, 24)
	_lathe(group, Vector3(0, .405, 0), [Vector2(.01, 0), Vector2(.33, 0), Vector2(.335, .16), Vector2(.31, .175), Vector2(.09, .175), Vector2(.075, .12), Vector2(.01, .12)], granite, 24)
	_beam(group, Vector3(.33, .53, 0), Vector3(.72, .60, .10), .024, _wood)
	_basket(group, Vector3(-.62, 0, .34), .19, .27, false)


func _build_jar_cluster() -> void:
	var group := _group("YardJarCluster")
	var base:=Node3D.new()
	base.name="PickleBase"
	group.add_child(base)
	_vessel(base, Vector3.ZERO, .30, .46, _clay)
	_vessel(group, Vector3(.50, 0, .22), .22, .32, _paint(Color("8b7159"), 8.0))
	_vessel(group, Vector3(.24, 0, -.38), .17, .24, _paint(Color("b0905f"), 9.0))
	# Straw cap tied over the largest mouth.
	_lathe(base, Vector3(0, .44, 0), [Vector2(.245, 0), Vector2(.20, .055), Vector2(.10, .09), Vector2(.01, .10)], _straw, 16)
	_ring(base, Vector3(0, .445, 0), .235, .016, _rope)
	_merge_static_group(base)


func _build_ground_trays() -> void:
	var group := _group("YardGroundTrays")
	_tray(group, Vector3.ZERO, .30, true)
	_tray(group, Vector3(.58, .004, .26), .26, false)
	# The only saturated note on this side of the yard: drying chillies.
	Assets.place(group,"pepper",Vector3(.58,.031,.26),25,1.12)
	_tray(group, Vector3(.24, .008, -.44), .23, true)
	_basket(group, Vector3(-.52, 0, -.34), .20, .30, true)


func _build_basket_stack() -> void:
	var group := _group("YardBasketStack")
	_basket(group, Vector3.ZERO, .26, .34, false)
	_basket(group, Vector3(.02, .30, .01), .24, .30, false)
	_basket(group, Vector3(.52, 0, .28), .21, .29, true)
	for i: int in 4:
		_ring(group, Vector3(-.46, .022 + i * .028, .30), .15 - i * .012, .021, _rope)


func _build_yard_bucket() -> void:
	var group := _group("YardBucket")
	_lathe(group, Vector3.ZERO, [Vector2(.01, 0), Vector2(.145, 0), Vector2(.175, .26), Vector2(.175, .285), Vector2(.155, .29), Vector2(.15, .26), Vector2(.125, .02), Vector2(.01, .02)], _wood, 16)
	_ring(group, Vector3(0, .08, 0), .155, .011, _iron)
	_ring(group, Vector3(0, .25, 0), .172, .011, _iron)
	for i: int in 10:
		var a: float = i * PI / 10.0
		var b: float = (i + 1) * PI / 10.0
		_beam(group, Vector3(cos(a) * .17, .29 + sin(a) * .17, 0), Vector3(cos(b) * .17, .29 + sin(b) * .17, 0), .009, _iron)
	_lathe(group, Vector3(.38, 0, .16), [Vector2(.01, 0), Vector2(.10, 0), Vector2(.115, .19), Vector2(.10, .195), Vector2(.09, .02), Vector2(.01, .02)], _bamboo, 14)


func _build_drying_line() -> void:
	# A low A-frame in the front garden. Tall posts beside the veranda read as part
	# of its railing and hide the porch, so the herbs hang below eye level instead.
	var group := _group("YardDryingLine")
	for x: float in [-.74, .74]:
		_beam(group, Vector3(x, 0, -.26), Vector3(x, .70, 0), .027, _bamboo)
		_beam(group, Vector3(x, 0, .26), Vector3(x, .70, 0), .027, _bamboo)
		_beam(group, Vector3(x, .26, -.17), Vector3(x, .26, .17), .016, _bamboo)
	_beam(group, Vector3(-.80, .70, 0), Vector3(.80, .70, 0), .024, _bamboo)
	for i: int in 4:
		var x: float = -.55 + i * .36
		var size: float = .86+float(i%2)*.10
		var bundle: Node3D=Assets.place(group,"radish_bundle",Vector3(x,.69-.43*size,0),i*37.0,size)
		bundle.set_meta("drying_bundle",true)
		_beam(group,Vector3(x,.69,0),Vector3(x,.72,0),.007,_rope)
	_basket(group, Vector3(-1.02, 0, .18), .20, .28, true)


func _build_melon_pile() -> void:
	var group := _group("YardMelonPile")
	var straw_mat := BoxMesh.new()
	straw_mat.size = Vector3(.92, .030, .62)
	_mesh(group, straw_mat, Vector3(0, .015, 0), _straw)
	for i: int in 4:
		Assets.place(group,"pomelo",Vector3(-.19+(i%2)*.35,.03,-.14+int(i/2)*.27),i*103.0,.83+float(i%2)*.12)


func _build_seed_frames() -> void:
	var group := _group("YardSeedFrames")
	var earth := _paint(Color("6b573c"), 16.0)
	for frame_index: int in 2:
		var origin := Vector3(frame_index * .70, 0, frame_index * .16)
		var soil := BoxMesh.new()
		soil.size = Vector3(.56, .090, .38)
		_mesh(group, soil, origin + Vector3(0, .0650, 0), earth)
		for side: int in [-1, 1]:
			var long_rail := BoxMesh.new()
			long_rail.size = Vector3(.60, .115, .032)
			_mesh(group, long_rail, origin + Vector3(0, .0575, side * .198), _wood)
			var short_rail := BoxMesh.new()
			short_rail.size = Vector3(.032, .115, .38)
			_mesh(group, short_rail, origin + Vector3(side * .288, .0575, 0), _wood)
		for i: int in 12:
			var p := origin + Vector3(-.21+(i%4)*.14,.080,-.12+int(i/4)*.12)
			Assets.place(group,"seedling",p,i*137.5,.86+sin(i*1.8)*.10)
