extends Node3D
## Spatial truth and ambient scenery only; no farm state, unlock rules or saving.
const DECORATIONS = preload("res://farm/decoration_catalog.gd")
const PIGMENT = preload("res://scenes/environment/pigment.gdshader")
const STONE_ATLAS = preload("res://art/environment/modules/river_stones_color.png")
const LayeredLandscape = preload("res://scenes/environment/layered_landscape.gd")
const LivingDetails = preload("res://scenes/environment/living_details.gd")
const PlantWind = preload("res://presentation/plant_wind.gd")
const FallingLeaves = preload("res://presentation/falling_leaves.gd")
const GroundCover = preload("res://scenes/environment/ground_cover.gd")
const ContactShading = preload("res://presentation/contact_shading.gd")
const WaterContacts = preload("res://presentation/water_contacts.gd")
# World heights of the two surfaces props actually stand on in this courtyard.
const GROUND_LEVEL := 0.132
const DECK_LEVEL := 0.41
# Modules whose feet meet a visible surface and therefore need a contact pool.
const CONTACT_MODULES := ["veranda", "side_wing", "stone_bridge", "climbing_trellis", "bamboo_fence"]
const BOAT_ORIGIN := Vector3(9.0,-.50,4.3)
const ROOT := "res://art/environment/"
const SLOT_POSITIONS := {
	"ground_01": Vector3(-5.35,0.16,-1.85), "ground_02": Vector3(4.70,0.16,-1.8),
	"ground_03": Vector3(-5.0,0.16,4.7), "ground_04": Vector3(4.75,0.16,4.8),
	"hanging_01": Vector3(-2.5,2.27,-2.05), "hanging_02": Vector3(3.8,2.27,-2.05),
	"hanging_03": Vector3(-5.08,1.82,2.13), "hanging_04": Vector3(-4.85,1.98,-2.95),
}
var _lod_pairs: Dictionary = {}
var _slots: Node3D
var _water: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _plant_wind := PlantWind.new()
var _living: Node3D
var _boat: Node3D
var _floaters: Array[Node3D] = []
var _floater_origins: Array[Vector3] = []
var _motion_time: float = 0.0
var _contact_sources: Array[Node3D] = []
var _shore_sources: Array[Node3D] = []

func _ready() -> void:
	_rng.seed = 32026
	_build_ground()
	_build_architecture()
	var water_material: ShaderMaterial = _water.material_override
	water_material.set_shader_parameter("shore_distance", WaterContacts.build(_shore_sources, _water.position.y))
	water_material.set_shader_parameter("shore_contacts_enabled", true)
	_build_plants()
	var cover := GroundCover.new()
	cover.name = "GroundCover"
	add_child(cover)
	cover.build(self)
	_build_slots()
	_build_distance()
	_living=LivingDetails.new();_living.name="LivingDetails";add_child(_living)
	_living.configure_house(get_node("MainHouse"))
	_living.attach_boat(_boat)
	_build_contact_shading()

func _process(delta: float) -> void:
	_motion_time += delta
	# Waterline pivot, not the original bottom origin: the hull stays in the water.
	var roll: float = sin(_motion_time*.73)*.009 + sin(_motion_time*.39)*.003
	var pitch: float = sin(_motion_time*.55+.4)*.005
	_boat.rotation=Vector3(pitch,deg_to_rad(-24),roll)
	var pivot:=Vector3(0,.35/.85,0)
	_boat.position=BOAT_ORIGIN+Vector3.UP*(.021*sin(_motion_time*.81)) + Vector3.UP*.35 - _boat.basis*pivot
	var water_material: ShaderMaterial = _water.material_override
	if water_material.shader.resource_path == "res://atmosphere/quiet_water.gdshader":
		water_material.set_shader_parameter("boat_mask_enabled",true)
		water_material.set_shader_parameter("world_to_boat",_boat.global_transform.affine_inverse())
	for i: int in _floaters.size():
		var phase: float = _motion_time*.88+i*1.7
		var drift := Vector3(sin(phase*.61)*.025, sin(phase)*.024, cos(phase*.73)*.018)
		_floaters[i].position=_floater_origins[i]+drift
		_floaters[i].rotation.x=sin(phase*.79)*.020
		_floaters[i].rotation.z=sin(phase*.83)*.028
	_living.update_mooring()

func set_window_warmth(amount: float) -> void:
	if _living != null:_living.set_window_warmth(amount)

func _module(id: String, at: Vector3, yaw_degrees: float=0, scale_value: Vector3=Vector3.ONE) -> Node3D:
	var node: Node3D = (load(ROOT+"modules/"+id+".glb") as PackedScene).instantiate()
	add_child(node)
	node.position=at; node.rotation.y=deg_to_rad(yaw_degrees); node.scale=scale_value
	_apply_pigment(node, id)
	if id in CONTACT_MODULES: _contact_sources.append(node)
	if id == "island_bank" or id.begins_with("stone_"): _shore_sources.append(node)
	return node

func _apply_pigment(node: Node, module_id: String = "") -> void:
	if node is MeshInstance3D:
		# Layer 2 is the decal receiver set. The veranda joins the island so the
		# deck-level contact pools land on the platform its posts stand on.
		if module_id in ["island_bank", "veranda"]: node.set_layer_mask_value(2,true)
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(surface)
			if original is StandardMaterial3D:
				var painted := ShaderMaterial.new()
				painted.shader=PIGMENT
				painted.set_shader_parameter("base_color",original.albedo_color)
				painted.set_shader_parameter("wash_scale",3.5)
				if module_id.begins_with("stone_") and original.albedo_texture != null:
					painted.set_shader_parameter("painted_rock",true)
					painted.set_shader_parameter("rock_color",STONE_ATLAS)
				painted.set_shader_parameter("stone_treatment", 1.0 if module_id.begins_with("stone_") else 0.0)
				painted.set_shader_parameter("ground_treatment", 1.0 if module_id == "island_bank" else 0.0)
				painted.set_shader_parameter("foundation_treatment", 1.0 if module_id in ["veranda","side_wing"] else 0.0)
				node.set_surface_override_material(surface,painted)
	for child in node.get_children(): _apply_pigment(child, module_id)

func _asset(id: String, key: String, at: Vector3, yaw_degrees: float=0, size: float=1.0) -> Node3D:
	var holder := Node3D.new();holder.name=key;add_child(holder)
	holder.position=at;holder.rotation.y=deg_to_rad(yaw_degrees);holder.scale=Vector3.ONE*size
	var high: Node3D=(load(ROOT+id+"/"+id+"_high.glb") as PackedScene).instantiate()
	var low: Node3D=(load(ROOT+id+"/"+id+"_low.glb") as PackedScene).instantiate()
	holder.add_child(high);holder.add_child(low);low.visible=false
	if id in ["tree","osmanthus","bamboo","flowers","lotus","trellis"]:
		_plant_wind.apply(high,id);_plant_wind.apply(low,id)
	_lod_pairs[key]=[high,low]
	return holder

func _build_ground() -> void:
	_module("island_bank",Vector3.ZERO)
	_water=MeshInstance3D.new();_water.name="WaterSurface"
	var plane:=PlaneMesh.new();plane.size=Vector2(180,180);_water.mesh=plane
	var water_material:=ShaderMaterial.new();water_material.shader=load("res://atmosphere/quiet_water.gdshader")
	_water.material_override=water_material;_water.position.y=-0.25;add_child(_water)
	# Nonuniform stone groups follow the bank, leaving visible grassy lobes and gaps.
	var rim: Array[Vector2]=[Vector2(-7.5,-7.6),Vector2(-4.8,-8.4),Vector2(-1,-8.2),Vector2(2.5,-7.9),Vector2(5.6,-6.5),Vector2(6.5,-3.8),Vector2(6.4,-.8),Vector2(6.8,1.3),Vector2(5.8,4.8),Vector2(3.5,6.1),Vector2(.7,6.7),Vector2(-2.5,6.1),Vector2(-5.5,5.6),Vector2(-7.2,3.2),Vector2(-7.6,.2),Vector2(-7.1,-3.6)]
	for i in rim.size():
		var a:Vector2=rim[i];var b:Vector2=rim[(i+1)%rim.size()]
		var count:int=ceili(a.distance_to(b)/.88)
		for j in count:
			if _rng.randf()<.24:continue
			var p:Vector2=a.lerp(b,float(j)/count)+Vector2(_rng.randf_range(-.14,.14),_rng.randf_range(-.14,.14))
			var rock := _module("stone_%d"%_rng.randi_range(0,4),Vector3(p.x,-.43,p.y),_rng.randf_range(0,360),Vector3(_rng.randf_range(.85,1.45),_rng.randf_range(2.5,4.3),_rng.randf_range(.8,1.45)))
			# Open a root bay for the west osmanthus; keep the seeded draws stable.
			if i == 12 and j == 1:
				rock.position = Vector3(-6.65,-.43,5.4)
			_tint_stone(rock,Color("7d887d")*_rng.randf_range(.88,1.12))
	# Broken shelves at the visible waterline interrupt the former even bead border.
	var shelves: Array[Vector3] = [Vector3(-7.1,-.48,2.7),Vector3(-6.2,-.48,4.7),Vector3(-4.0,-.48,6.0),Vector3(-1.1,-.50,6.5),Vector3(2.0,-.46,6.4),Vector3(5.7,-.45,5.55),Vector3(6.5,-.43,2.5)]
	for i in shelves.size():
		_tint_stone(_module("stone_%d" % (i%5),shelves[i],17+i*47,Vector3(1.45,4.8 if i%2==0 else 3.5,1.18)),Color("79867e"))
		_tint_stone(_module("stone_%d" % ((i+2)%5),shelves[i]+Vector3(.35,-.05,.37),-25+i*33,Vector3(.88,2.0,.9)),Color("929784"))
	# Winding flat stone footpaths, with irregular joints, no checkerboard paving.
	var routes:Array[Array]=[[Vector3(-6.0,.115,2.9),Vector3(-5.25,.115,-1.7),Vector3(-2,.115,-1.8),Vector3(2.5,.115,-1.7),Vector3(6.2,.115,-.6)],[Vector3(-4.9,.115,4.65),Vector3(-.5,.115,4.65),Vector3(4.8,.115,4.7)],[Vector3(-1.68,.115,-1),Vector3(-1.68,.115,4.1)],[Vector3(1.57,.115,-1),Vector3(1.57,.115,4.1)]]
	for route in routes:
		for k in range(route.size()-1):
			var a:Vector3=route[k];var b:Vector3=route[k+1];var count:int=ceili(a.distance_to(b)/.48)
			for j in count:
				var p:Vector3=a.lerp(b,float(j)/count);p.x+=_rng.randf_range(-.055,.055);p.z+=_rng.randf_range(-.07,.07)
				# Untinted slabs came out near white and became the brightest thing on
				# the island, pulling attention off the beds. Warm grey flagstones.
				# Only flat slabs and low wedges serve as footpath stones. Consume the
				# same random draw so the rest of the established scene stays stable.
				var shape: int = _rng.randi_range(0,4)
				_tint_stone(_module("stone_%d" % (1 if shape < 3 else 2),p,_rng.randf_range(-18,18),Vector3(.64,.28,.72)),Color("93907e")*_rng.randf_range(.90,1.08))

func _tint_stone(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(index)
			if material is ShaderMaterial:
				material.set_shader_parameter("base_color",color)
				material.set_shader_parameter("stone_treatment",1.0)
	for child in node.get_children():_tint_stone(child,color)

func _build_architecture() -> void:
	_asset("house","MainHouse",Vector3(.65,.13,-4.65))
	_module("veranda",Vector3(.65,.13,-2.40))
	_module("side_wing",Vector3(-4.3,.13,-5.0))
	var trellis: Node3D = _module("climbing_trellis",Vector3(-5.80,.13,1.05),90)
	trellis.name = "EntranceTrellis"
	_module("stone_bridge",Vector3(8.1,-.04,-.15),-9)
	_boat=_asset("boat","CoveredBoat",BOAT_ORIGIN,-24,.85)
	# Opposite landing is a small bank, with irregular rock margins, not a floating bridge end.
	_module("island_bank",Vector3(12.65,-.02,-2.8),0,Vector3(.40,1,.46))
	for i in 7:
		var t:float=i/6.0
		var position_on_bank:=Vector3(11.05+t*4.1,-.40,.2+sin(t*PI)*.40)
		_tint_stone(_module("stone_%d"%(i%5),position_on_bank,i*39,Vector3(.85,2.8+(i%3)*.7,.8)),Color("829184"))
	for i in 4:_module("bamboo_fence",Vector3(-4.8+i*2.0,.14,-7.2))
	for z in [-2.8,-.6,3.6]:_module("bamboo_fence",Vector3(-6.65,.14,z),90)
	for z in [-4.1,-2.0]:_module("bamboo_fence",Vector3(5.7,.14,z),75)
	# Low front rail gives the vegetable garden a boundary; corner decoration slots stay open.
	for x in [-3.0,-.85,1.3]:_module("bamboo_fence",Vector3(x,.14,5.15),0,Vector3(1,.68,1))
	# The right bay contains the harvest table; the old bench occupied its legs
	# and was partly buried in the raised veranda platform.
	_build_porch_bench(Vector3(-3.65,.14,-2.9),.65)

func _build_porch_bench(at: Vector3, width: float) -> void:
	var bench := Node3D.new();bench.name="PorchBench";add_child(bench);bench.position=at
	var material := ShaderMaterial.new();material.shader=PIGMENT
	material.set_shader_parameter("base_color",Color("87724f"))
	var parts: Array[Array] = [[Vector3(width,.075,.35),Vector3(0,.39,0)],[Vector3(width*.8,.06,.06),Vector3(0,.18,0)]]
	for x in [-width*.34,width*.34]:
		for z in [-.105,.105]:parts.append([Vector3(.075,.37,.075),Vector3(x,.19,z)])
	for part in parts:
		var mesh := MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=part[0];mesh.mesh=shape;mesh.position=part[1]
		mesh.material_override=material;bench.add_child(mesh)
	_contact_sources.append(bench)

func _build_plants() -> void:
	var osmanthus: Node3D = _asset("osmanthus","WestTree",Vector3(-6.05,.13,4.3),15,1.0)
	_contact_sources.append(osmanthus.get_child(0))
	var falling := FallingLeaves.new()
	falling.name = "OsmanthusLeaves"
	add_child(falling)
	falling.configure(osmanthus)
	_asset("tree","RearTree",Vector3(3.75,.13,-6.1),-27,1.07)
	_asset("tree","EastBankTree",Vector3(12.4,.12,-4.2),-35,.72)
	_asset("tree","RearSmallTree",Vector3(-2.5,.13,-7.45),80,.67)
	_asset("tree","RearWestCanopy",Vector3(-5.75,.13,-6.8),-72,.83)
	_asset("tree","RearEastCanopy",Vector3(5.5,.13,-5.95),57,.83)
	_asset("tree","FarBankCompanion",Vector3(14.0,.1,-5.2),19,.65)
	var bamboo_positions:Array[Vector3]=[Vector3(-7,.13,-5.2),Vector3(-7.1,.13,-.5),Vector3(5.4,.13,-5.7),Vector3(6.3,.13,2.0),Vector3(13.8,.10,-.8),Vector3(-6.6,.13,-6.6),Vector3(4.7,.13,-7.0),Vector3(5.9,.13,-3.5)]
	for i in bamboo_positions.size():_asset("bamboo","Bamboo%d"%i,bamboo_positions[i],_rng.randf_range(0,360),_rng.randf_range(.70,1.05))
	var reeds: Array[Vector3] = [Vector3(-7.15,.05,2.7),Vector3(-6.55,.04,4.35),Vector3(-4.1,.06,5.85),Vector3(-2.15,.06,6.2),Vector3(.7,.06,6.25),Vector3(3.1,.07,5.85),Vector3(6.0,.06,4.3),Vector3(6.1,.08,3.5),Vector3(6.15,.08,-1.6),Vector3(11.0,.03,-.85),Vector3(14.2,.03,-.35)]
	for i in reeds.size():_asset("bamboo","BankReeds%d"%i,reeds[i],i*53,_rng.randf_range(.30,.43))
	var flower_centres:Array[Vector3]=[Vector3(-5.8,.13,3.45),Vector3(5.25,.13,3.75),Vector3(-5.7,.13,-2.8),Vector3(5.3,.13,-3.0),Vector3(-3.8,.13,5.6),Vector3(2.4,.13,5.7),Vector3(-6.25,.11,4.9),Vector3(-1.8,.13,5.75),Vector3(.2,.13,5.95),Vector3(4.0,.12,5.6),Vector3(6.0,.13,1.0),Vector3(-6.85,.12,2.25),Vector3(11.35,.1,-.8),Vector3(13.6,.1,-1.5),Vector3(-3.4,.13,-2.05)]
	for i in flower_centres.size():
		_grass_patch(flower_centres[i]-Vector3(0,.01,0),i)
		for j in 3:
			_asset("flowers","Flowers%d_%d"%[i,j],flower_centres[i]+Vector3(_rng.randf_range(-.26,.26),-.035,_rng.randf_range(-.22,.22)),i*37+j*62,_rng.randf_range(.95,1.40))
	# Loose lily coves sit around the waterline, not in a repeated necklace in front of the boat.
	# The open river is the composition's pale negative space, but an unbroken slab
	# of it reads as an unfinished surface. Loose outer coves give it something to
	# interrupt, still clear of the bank, the bridge span and the mooring.
	var lily_coves: Array[Vector3] = [Vector3(-6.35,-.40,7.25),Vector3(-.9,-.40,8.05),Vector3(5.35,-.40,7.4),Vector3(10.8,-.40,2.0),Vector3(-9.8,-.40,3.6),Vector3(-11.2,-.40,-1.8),Vector3(-7.9,-.40,9.2),Vector3(1.6,-.40,10.8),Vector3(8.9,-.40,7.9)]
	for i in lily_coves.size():
		for j in (4 if i < 4 else 5):
			var angle:float=j*2.4+i*.7
			var lotus: Node3D=_asset("lotus","Lotus%d_%d"%[i,j],lily_coves[i]+Vector3(cos(angle)*.72,0,sin(angle)*.6),i*41+j*79,_rng.randf_range(.82,1.15))
			_floaters.append(lotus);_floater_origins.append(lotus.position)

func _grass_patch(at: Vector3, index: int) -> void:
	# Small opaque curved blades fill the soil contact below the existing flower assets.
	# One static mesh per patch; no alpha cards, animation or per-frame work.
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 30:
		var angle: float = _rng.randf_range(0,TAU)
		var outward:=Vector3(cos(angle),0,sin(angle))
		var across:=Vector3(-outward.z,0,outward.x)
		var origin:=outward*_rng.randf_range(0,.40)
		var height:float=_rng.randf_range(.22,.42)
		var width:float=_rng.randf_range(.024,.047)
		for part in 4:
			var a:float=part/4.0;var b:float=(part+1)/4.0
			var pa:=origin+Vector3.UP*height*a+outward*height*a*a*.6
			var pb:=origin+Vector3.UP*height*b+outward*height*b*b*.6
			var wa:float=width*(1-a);var wb:float=width*(1-b)
			for point in [pa-across*wa,pa+across*wa,pb+across*wb]:surface.add_vertex(point)
			if part < 3:
				for point in [pa-across*wa,pb+across*wb,pb-across*wb]:surface.add_vertex(point)
	surface.generate_normals()
	var mesh:=MeshInstance3D.new();mesh.name="BankGrass%d"%index;mesh.mesh=surface.commit();mesh.position=at
	var material:=ShaderMaterial.new();material.shader=PIGMENT;material.set_shader_parameter("base_color",Color("697f4f"));material.set_shader_parameter("wash_scale",8.0)
	mesh.material_override=material;add_child(mesh)
	_plant_wind.apply(mesh,"grass")

func _build_slots() -> void:
	_slots=Node3D.new();_slots.name="DecorationSlots";add_child(_slots)
	assert(SLOT_POSITIONS.size()==DECORATIONS.SLOT_TYPES.size())
	for id:String in SLOT_POSITIONS:
		assert(DECORATIONS.SLOT_TYPES.has(id))
		var marker:=Marker3D.new();marker.name=id;marker.position=SLOT_POSITIONS[id];_slots.add_child(marker)
	# Every hanging position has a real cantilever / cord ending at its top ring.
	for id in ["hanging_01","hanging_02"]:
		var p:Vector3=SLOT_POSITIONS[id]
		_support_line(Vector3(p.x,2.50,-2.72),Vector3(p.x,2.50,p.z),.037,Color("62543a"))
		_support_line(Vector3(p.x,2.50,p.z),p,.012,Color("89794c"))
	_support_line(Vector3(-5.4,2.09,2.13),Vector3(-5.08,2.09,2.13),.025,Color("89794c"))
	_support_line(Vector3(-5.08,2.09,2.13),SLOT_POSITIONS.hanging_03,.012,Color("89794c"))
	_support_line(Vector3(-4.85,2.55,-3.77),Vector3(-4.85,2.55,-2.95),.035,Color("62543a"))
	_support_line(Vector3(-4.85,2.10,-3.77),Vector3(-4.85,2.55,-3.0),.025,Color("62543a"))
	_support_line(Vector3(-4.85,2.55,-2.95),SLOT_POSITIONS.hanging_04,.012,Color("89794c"))

func _support_line(a:Vector3,b:Vector3,radius:float,color:Color)->void:
	var node:=MeshInstance3D.new();node.name="LanternSupport"
	var shape:=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=a.distance_to(b);shape.radial_segments=10;node.mesh=shape
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=.95;node.material_override=material
	add_child(node);node.position=(a+b)/2
	var axis:Vector3=(b-a).normalized()
	node.quaternion=Quaternion(Vector3.UP,axis)

func _build_distance() -> void:
	var landscape := LayeredLandscape.new()
	landscape.name = "DistantLandscape"
	add_child(landscape)

func _build_contact_shading() -> void:
	var shading: Node3D = ContactShading.new()
	shading.name = "ContactShading"
	add_child(shading)
	for source: Node3D in _contact_sources:
		shading.collect(source, [GROUND_LEVEL, DECK_LEVEL])
	shading.collect(get_node("MainHouse"), [GROUND_LEVEL])
	shading.collect(_living, [GROUND_LEVEL, DECK_LEVEL])
	shading.bake()


func get_water_surface() -> MeshInstance3D:
	return _water

func get_backdrop_material() -> ShaderMaterial:
	return get_node("DistantLandscape").material

func get_decoration_slots() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for id:String in SLOT_POSITIONS:
		result.append({"id":id,"type":DECORATIONS.SLOT_TYPES[id],"transform":get_slot_marker(id).transform,"allowed_turns":DECORATIONS.allowed_turns(id),"radius":.45 if id.begins_with("ground") else .2})
	return result

func get_slot_marker(id: String) -> Marker3D:
	return _slots.get_node_or_null(NodePath(id)) as Marker3D

func get_decoration_scene(item_id: String, low_detail: bool=false) -> PackedScene:
	var asset_id:String="jar" if item_id=="pot" else item_id
	if not DECORATIONS.IDS.has(item_id):return null
	return load("res://art/decorations/%s/%s_%s.glb"%[asset_id,asset_id,"low" if low_detail else "high"]) as PackedScene

func set_asset_detail(key: String, low_detail: bool) -> void:
	if not _lod_pairs.has(key):return
	_lod_pairs[key][0].visible=not low_detail;_lod_pairs[key][1].visible=low_detail

func set_low_detail_enabled(enabled: bool) -> void:
	for key:String in _lod_pairs:set_asset_detail(key,enabled)

func get_asset_keys() -> Array:
	return _lod_pairs.keys()
