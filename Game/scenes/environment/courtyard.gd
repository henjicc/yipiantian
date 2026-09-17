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
const BankGeometry = preload("res://layout/bank_geometry.gd")
const Circulation = preload("res://layout/courtyard_circulation.gd")
const FenceGeometry = preload("res://layout/fence_geometry.gd")
const Space = preload("res://scenes/environment/animal_space.gd")
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
var circulation := Circulation.new()
var layout_obstacles: Dictionary = {}

func _ready() -> void:
	_rng.seed = 32026
	_build_ground()
	_build_architecture()
	var neighbors := NeighborIslets.new()
	neighbors.name = "NeighborIslets"
	add_child(neighbors)
	_shore_sources.append_array(neighbors.waterline_sources())
	_build_plants()
	_build_slots()
	_build_distance()
	_living=LivingDetails.new();_living.name="LivingDetails";_living.plan=plan;add_child(_living)
	_living.configure_house(get_node("MainHouse"))
	_living.attach_boat(_boat)
	layout_obstacles = _circulation_obstacles()
	circulation.build(plan,layout_obstacles)
	_build_paths()
	var fence: Node3D = FenceGeometry.build(plan.fences)
	add_child(fence)
	_contact_sources.append(fence)
	var cover := GroundCover.new()
	cover.name = "GroundCover"
	add_child(cover)
	cover.build(self)
	var water_material: ShaderMaterial = _water.material_override
	water_material.set_shader_parameter("shore_distance", WaterContacts.build(_shore_sources, _water.position.y))
	water_material.set_shader_parameter("shore_contacts_enabled", true)
	_build_contact_shading()
	var animals := CourtyardAnimals.new()
	animals.name = "CourtyardAnimals"
	add_child(animals)

func _circulation_obstacles() -> Dictionary:
	var result: Dictionary = {}
	for node: Node3D in get_children():
		if node.name in ["WaterSurface","DistantLandscape","NeighborIslets","DecorationSlots","OsmanthusLeaves","LivingDetails"]: continue
		if node.has_meta("bank_role") or String(node.name).begins_with("BankGrass"): continue
		# Include shoreline rocks and flower clumps too: a route through them
		# would look open in layout data but still be blocked to the actual hens.
		var bottom: float = .05 if node.name in ["MainHouse","Kitchen","PorchDeck","EntranceTrellis"] else .23
		var polygon: PackedVector2Array = Space.footprint(node,bottom,.75)
		if polygon.size()>=3: result[String(node.name)] = polygon
	for prop: Node in _living.get_children():
		if prop is Node3D and plan.props.has(String(prop.name)) and prop.position.y<.3:
			var polygon: PackedVector2Array = Space.footprint(prop,.05,.70)
			if polygon.size()>=3: result[String(prop.name)] = polygon
	return result

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

func _bank(role: String, outline: PackedVector2Array, at: Vector3, yaw_degrees: float = 0) -> Node3D:
	var node := Node3D.new()
	node.name = "MainBank" if role == "main" else "EastBank"
	node.set_meta("bank_role", role)
	node.position = at
	node.rotation.y = deg_to_rad(yaw_degrees)
	var surface := MeshInstance3D.new()
	surface.name = "RoundedShore"
	surface.mesh = BankGeometry.build(outline, plan.ground_height, plan.bank_width)
	node.add_child(surface)
	add_child(node)
	_apply_pigment(node, "island_bank_v2" if role == "main" else "east_bank_v2")
	_shore_sources.append(node)
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
	_bank("main", plan.rim, Vector3.ZERO)
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
				rock.position = plan.root_bay
			_tint_stone(rock,Color("7d887d")*_rng.randf_range(.88,1.12))
	# Broken shelves at the visible waterline interrupt the former even bead border.
	var shelves: Array[Vector3] = plan.shelves
	for i in shelves.size():
		_tint_stone(_module("stone_%d" % (i%5),shelves[i],17+i*47,Vector3(1.45,4.8 if i%2==0 else 3.5,1.18)),Color("79867e"))
		_tint_stone(_module("stone_%d" % ((i+2)%5),shelves[i]+Vector3(.35,-.05,.37),-25+i*33,Vector3(.88,2.0,.9)),Color("929784"))
func _build_paths() -> void:
	# A separate seed makes a route change independent of all surrounding foliage.
	var road_rng := RandomNumberGenerator.new()
	road_rng.seed=931772
	var placed := PackedVector2Array()
	var routes: Array[PackedVector3Array] = plan.paths
	for route in routes:
		for k in range(route.size()-1):
			var a:Vector3=route[k];var b:Vector3=route[k+1];var count:int=maxi(1,ceili(a.distance_to(b)/.40))
			for j in count:
				var p:Vector3=a.lerp(b,float(j)/count)
				var point := Vector2(p.x,p.z)
				var duplicate: bool = false
				for old: Vector2 in placed:
					if old.distance_squared_to(point)<.27*.27: duplicate=true;break
				if duplicate: continue
				placed.append(point)
				var shape: int = 1 if road_rng.randf()<.65 else 2
				var stone: Node3D = _module("stone_%d"%shape,p,road_rng.randf_range(-180,180),Vector3(.40,.28,.40))
				stone.set_meta("path_stone",true)
				_tint_stone(stone,Color("93907e")*road_rng.randf_range(.90,1.08))

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
	_module("veranda",plan.anchors.veranda,plan.angles.veranda).name = "PorchDeck"
	var kitchen: Node3D = _life_asset("kitchen","Kitchen",plan.anchors.kitchen,plan.angles.kitchen)
	_contact_sources.append(kitchen.get_child(0))
	for mesh: MeshInstance3D in kitchen.find_children("*","MeshInstance3D",true,false):
		mesh.set_instance_shader_parameter("ground_contact",Vector2(.13,.14))
	var trellis: Node3D = _module("climbing_trellis",plan.anchors.trellis,plan.angles.trellis)
	trellis.name = "EntranceTrellis"
	_module("stone_bridge",plan.anchors.bridge,plan.angles.bridge)
	_boat=_asset("boat","CoveredBoat",plan.anchors.boat,plan.angles.boat,.85)
	# Opposite landing is a small bank, with irregular rock margins, not a floating bridge end.
	_bank("east", plan.east_rim, plan.anchors.east_bank, plan.angles.east_bank)
	for index: int in 7:
		var point: Vector3 = plan.east_path[0].lerp(plan.east_path[1],index/6.0)
		_tint_stone(_module("stone_1",point,24+index*13,Vector3(.82,.25,.65)),Color("93907e"))
	for i in 7:
		var position_on_bank: Vector3 = plan.east_stones[i]
		_tint_stone(_module("stone_%d"%(i%5),position_on_bank,i*39,Vector3(.85,2.8+(i%3)*.7,.8)),Color("829184"))
	# The right bay contains the harvest table; the old bench occupied its legs
	# and was partly buried in the raised veranda platform.

func _build_plants() -> void:
	_rng.seed=87311
	for tree: Dictionary in plan.trees:
		_life_asset(tree.asset,tree.id,tree.at,tree.yaw,tree.size,tree.wind)
	var osmanthus: Node3D = get_node("WestTree")
	_contact_sources.append(osmanthus.get_child(0))
	var falling := FallingLeaves.new()
	falling.name = "OsmanthusLeaves"
	add_child(falling)
	falling.configure(osmanthus)
	var bamboo_positions: Array[Vector3] = plan.bamboo_positions
	for i in bamboo_positions.size():_life_asset("bamboo","Bamboo%d"%i,bamboo_positions[i]-Vector3.UP*.025,_rng.randf_range(0,360),_rng.randf_range(.70,1.05),"bamboo")
	var reeds: Array[Vector3] = plan.reeds
	for i in reeds.size():_life_asset("bamboo","BankReeds%d"%i,reeds[i],i*53,_rng.randf_range(.30,.43),"bamboo")
	var flower_centres: Array[Vector3] = plan.flower_centres
	for i in flower_centres.size():
		_grass_patch(flower_centres[i]-Vector3(0,.01,0),i)
		for j in 2:
			_life_asset("chrysanthemum","Flowers%d_%d"%[i,j],flower_centres[i]+Vector3(_rng.randf_range(-.22,.22),-.025,_rng.randf_range(-.20,.20)),i*37+j*62,_rng.randf_range(.80,1.1),"flowers")
	# Loose lily coves sit around the waterline, not in a repeated necklace in front of the boat.
	# The open river is the composition's pale negative space, but an unbroken slab
	# of it reads as an unfinished surface. Loose outer coves give it something to
	# interrupt, still clear of the bank, the bridge span and the mooring.
	var lily_coves: Array[Vector3] = plan.lily_coves
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
	shading.configure_bounds(plan.land_bounds().grow(.6))
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
