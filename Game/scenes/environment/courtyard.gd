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
const NeighborIslets = preload("res://scenes/environment/neighbor_islets.gd")
const CourtyardAssets = preload("res://scenes/environment/courtyard_assets.gd")
const CourtyardAnimals = preload("res://scenes/environment/courtyard_animals.gd")
# World heights of the two surfaces props actually stand on in this courtyard.
const GROUND_LEVEL := 0.132
const DECK_LEVEL := 0.41
# Modules whose feet meet a visible surface and therefore need a contact pool.
const CONTACT_MODULES := ["veranda", "side_wing", "stone_bridge", "climbing_trellis", "bamboo_fence"]
const ROOT := "res://art/environment/"
var plan := preload("res://layout/courtyard_plan.gd").new()
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
	var neighbors := NeighborIslets.new()
	neighbors.name = "NeighborIslets"
	add_child(neighbors)
	_shore_sources.append_array(neighbors.waterline_sources())
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
	_living=LivingDetails.new();_living.name="LivingDetails";_living.plan=plan;add_child(_living)
	_living.configure_house(get_node("MainHouse"))
	_living.attach_boat(_boat)
	_build_contact_shading()
	var animals := CourtyardAnimals.new()
	animals.name = "CourtyardAnimals"
	add_child(animals)

func _process(delta: float) -> void:
	_motion_time += delta
	# Waterline pivot, not the original bottom origin: the hull stays in the water.
	var roll: float = sin(_motion_time*.73)*.009 + sin(_motion_time*.39)*.003
	var pitch: float = sin(_motion_time*.55+.4)*.005
	_boat.rotation=Vector3(pitch,deg_to_rad(plan.angles.boat),roll)
	var pivot:=Vector3(0,.35/.85,0)
	_boat.position=plan.anchors.boat+Vector3.UP*(.021*sin(_motion_time*.81)) + Vector3.UP*.35 - _boat.basis*pivot
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
	if id in ["island_bank_v2", "east_bank_v2"] or id.begins_with("stone_"): _shore_sources.append(node)
	return node

func _apply_pigment(node: Node, module_id: String = "") -> void:
	if node is MeshInstance3D:
		# Layer 2 is the decal receiver set. The veranda joins the island so the
		# deck-level contact pools land on the platform its posts stand on.
		if module_id in ["island_bank_v2", "east_bank_v2", "veranda"]: node.set_layer_mask_value(2,true)
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(surface)
			if original is StandardMaterial3D:
				var painted := ShaderMaterial.new()
				painted.shader=PIGMENT
				painted.set_shader_parameter("base_color",original.albedo_color)
				if module_id in ["island_bank_v2", "east_bank_v2"]:
					painted.set_shader_parameter("base_color",Color("827452"))
				painted.set_shader_parameter("wash_scale",3.5)
				if module_id.begins_with("stone_") and original.albedo_texture != null:
					painted.set_shader_parameter("painted_rock",true)
					painted.set_shader_parameter("rock_color",STONE_ATLAS)
				painted.set_shader_parameter("stone_treatment", 1.0 if module_id.begins_with("stone_") else 0.0)
				painted.set_shader_parameter("ground_treatment", 1.0 if module_id in ["island_bank_v2", "east_bank_v2"] else 0.0)
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
	_module("island_bank_v2",Vector3.ZERO)
	_water=MeshInstance3D.new();_water.name="WaterSurface"
	var plane:=PlaneMesh.new();plane.size=Vector2(180,180);_water.mesh=plane
	var water_material:=ShaderMaterial.new();water_material.shader=load("res://atmosphere/quiet_water.gdshader")
	_water.material_override=water_material;_water.position.y=-0.25;add_child(_water)
	# Nonuniform stone groups follow the bank, leaving visible grassy lobes and gaps.
	var rim: PackedVector2Array = plan.rim
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
	var routes: Array[PackedVector3Array] = plan.paths
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
	_asset("house","MainHouse",plan.anchors.house,plan.angles.house)
	_module("veranda",plan.anchors.veranda,plan.angles.veranda)
	var kitchen: Node3D = _life_asset("kitchen","Kitchen",plan.anchors.kitchen,plan.angles.kitchen)
	_contact_sources.append(kitchen.get_child(0))
	for mesh: MeshInstance3D in kitchen.find_children("*","MeshInstance3D",true,false):
		mesh.set_instance_shader_parameter("ground_contact",Vector2(.13,.14))
	var trellis: Node3D = _module("climbing_trellis",plan.anchors.trellis,plan.angles.trellis)
	trellis.name = "EntranceTrellis"
	_module("stone_bridge",plan.anchors.bridge,plan.angles.bridge)
	_boat=_asset("boat","CoveredBoat",plan.anchors.boat,plan.angles.boat,.85)
	# Opposite landing is a small bank, with irregular rock margins, not a floating bridge end.
	_module("east_bank_v2",plan.anchors.east_bank,plan.angles.east_bank)
	for index: int in 7:
		var point := Vector3(10.52,.112,.23).lerp(Vector3(13.35,.112,-1.45),index/6.0)
		_tint_stone(_module("stone_1",point,24+index*13,Vector3(.82,.25,.65)),Color("93907e"))
	for i in 7:
		var t:float=i/6.0
		var position_on_bank:=Vector3(11.05+t*4.1,-.40,.2+sin(t*PI)*.40)
		_tint_stone(_module("stone_%d"%(i%5),position_on_bank,i*39,Vector3(.85,2.8+(i%3)*.7,.8)),Color("829184"))
	for fence: Dictionary in plan.fences:
		_module("bamboo_fence",fence.position,fence.yaw,Vector3(1,fence.height,1))
	# The right bay contains the harvest table; the old bench occupied its legs
	# and was partly buried in the raised veranda platform.

func _build_plants() -> void:
	var osmanthus: Node3D = _life_asset("osmanthus","WestTree",Vector3(-6.05,.09,4.3),15,1.0,"osmanthus")
	_contact_sources.append(osmanthus.get_child(0))
	var falling := FallingLeaves.new()
	falling.name = "OsmanthusLeaves"
	add_child(falling)
	falling.configure(osmanthus)
	_life_asset("osmanthus","RearTree",Vector3(3.8,.09,-6.25),-27,1.12,"osmanthus")
	_life_asset("willow","EastBankTree",Vector3(13.15,.09,-4.8),-35,.96,"osmanthus")
	_life_asset("bamboo","RearSmallTree",Vector3(-2.5,.10,-7.45),80,1.05,"bamboo")
	_life_asset("willow","RearWestCanopy",Vector3(-5.9,.09,-7.0),-72,.85,"osmanthus")
	_life_asset("bamboo","RearEastCanopy",Vector3(5.5,.10,-5.95),57,.95,"bamboo")
	var bamboo_positions:Array[Vector3]=[Vector3(-7,.13,-5.2),Vector3(-7.1,.13,-.5),Vector3(5.4,.13,-5.7),Vector3(6.3,.13,2.0),Vector3(13.8,.10,-.8),Vector3(-6.6,.13,-6.6),Vector3(4.7,.13,-7.0),Vector3(5.9,.13,-3.5)]
	for i in bamboo_positions.size():_life_asset("bamboo","Bamboo%d"%i,bamboo_positions[i]-Vector3.UP*.025,_rng.randf_range(0,360),_rng.randf_range(.70,1.05),"bamboo")
	var reeds: Array[Vector3] = [Vector3(-7.15,.05,2.7),Vector3(-6.55,.04,4.35),Vector3(-4.1,.06,5.85),Vector3(-2.15,.06,6.2),Vector3(.7,.06,6.25),Vector3(3.1,.07,5.85),Vector3(6.0,.06,4.3),Vector3(6.1,.08,3.5),Vector3(6.15,.08,-1.6),Vector3(11.0,.03,-.85),Vector3(14.2,.03,-.35)]
	for i in reeds.size():_life_asset("bamboo","BankReeds%d"%i,reeds[i],i*53,_rng.randf_range(.30,.43),"bamboo")
	var flower_centres:Array[Vector3]=[Vector3(-5.8,.13,3.45),Vector3(5.25,.13,3.75),Vector3(-5.7,.13,-2.8),Vector3(5.3,.13,-3.0),Vector3(-3.8,.13,5.6),Vector3(2.4,.13,5.7),Vector3(-6.25,.11,4.9),Vector3(-1.8,.13,5.75),Vector3(.2,.13,5.95),Vector3(4.0,.12,5.6),Vector3(6.0,.13,1.0),Vector3(-6.85,.12,2.25),Vector3(11.35,.1,-.8),Vector3(13.6,.1,-1.5),Vector3(-3.4,.13,-2.05)]
	for i in flower_centres.size():
		_grass_patch(flower_centres[i]-Vector3(0,.01,0),i)
		for j in 2:
			_life_asset("chrysanthemum","Flowers%d_%d"%[i,j],flower_centres[i]+Vector3(_rng.randf_range(-.22,.22),-.025,_rng.randf_range(-.20,.20)),i*37+j*62,_rng.randf_range(.80,1.1),"flowers")
	# Loose lily coves sit around the waterline, not in a repeated necklace in front of the boat.
	# The open river is the composition's pale negative space, but an unbroken slab
	# of it reads as an unfinished surface. Loose outer coves give it something to
	# interrupt, still clear of the bank, the bridge span and the mooring.
	var lily_coves: Array[Vector3] = [Vector3(-6.35,-.40,7.25),Vector3(-.9,-.40,8.05),Vector3(5.35,-.40,7.4),Vector3(14.0,-.40,3.4),Vector3(-9.8,-.40,3.6),Vector3(-11.2,-.40,-1.8),Vector3(-7.9,-.40,9.2),Vector3(1.6,-.40,10.8),Vector3(8.9,-.40,7.9)]
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
	assert(plan.slots.size()==DECORATIONS.SLOT_TYPES.size())
	for id:String in plan.slots:
		assert(DECORATIONS.SLOT_TYPES.has(id))
		var marker:=Marker3D.new();marker.name=id;marker.position=plan.slots[id];_slots.add_child(marker)
	# Every hanging position has a real cantilever / cord ending at its top ring.
	for id in ["hanging_01","hanging_02"]:
		var p:Vector3=plan.slots[id]
		_support_line(Vector3(p.x,2.50,-2.72),Vector3(p.x,2.50,p.z),.037,Color("62543a"))
		_support_line(Vector3(p.x,2.50,p.z),p,.012,Color("89794c"))
	_support_line(Vector3(-5.4,2.09,2.13),Vector3(-5.08,2.09,2.13),.025,Color("89794c"))
	_support_line(Vector3(-5.08,2.09,2.13),plan.slots.hanging_03,.012,Color("89794c"))
	_support_line(Vector3(-4.85,2.55,-3.77),Vector3(-4.85,2.55,-2.95),.035,Color("62543a"))
	_support_line(Vector3(-4.85,2.10,-3.77),Vector3(-4.85,2.55,-3.0),.025,Color("62543a"))
	_support_line(Vector3(-4.85,2.55,-2.95),plan.slots.hanging_04,.012,Color("89794c"))

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


func _life_asset(id: String, key: String, at: Vector3, yaw: float = 0.0, size: float = 1.0, wind: String = "") -> Node3D:
	var holder := Node3D.new()
	holder.name = key
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw)
	holder.scale = Vector3.ONE * size
	add_child(holder)
	var high: Node3D = CourtyardAssets.instantiate_asset(id)
	var low: Node3D = CourtyardAssets.instantiate_asset(id,"low")
	holder.add_child(high)
	holder.add_child(low)
	low.hide()
	_lod_pairs[key] = [high,low]
	if not wind.is_empty():
		_plant_wind.apply(holder,wind)
		for mesh: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
			mesh.set_instance_shader_parameter("leaf_paint_strength",.28)
	return holder


func get_water_surface() -> MeshInstance3D:
	return _water

func get_backdrop_material() -> ShaderMaterial:
	return get_node("DistantLandscape").material

func get_decoration_slots() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for id:String in plan.slots:
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
	get_node("NeighborIslets").set_low_detail_enabled(enabled)

func get_asset_keys() -> Array:
	return _lod_pairs.keys()
