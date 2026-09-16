extends Node3D
## Spatial truth only: no farm state, unlock rules, saving, lighting or water animation.
const DECORATIONS = preload("res://farm/decoration_catalog.gd")
const PIGMENT = preload("res://scenes/environment/pigment.gdshader")
const BACKDROP = preload("res://scenes/environment/backdrop.gdshader")
const ROOT := "res://art/environment/"
const SLOT_POSITIONS := {
	"ground_01": Vector3(-5.35,0.16,-1.85), "ground_02": Vector3(4.70,0.16,-1.8),
	"ground_03": Vector3(-5.0,0.16,4.7), "ground_04": Vector3(4.75,0.16,4.8),
	"hanging_01": Vector3(-2.5,2.27,-2.05), "hanging_02": Vector3(3.8,2.27,-2.05),
	"hanging_03": Vector3(-6.1,1.82,1.4), "hanging_04": Vector3(-4.85,1.98,-2.95),
}
var _lod_pairs: Dictionary = {}
var _slots: Node3D
var _water: MeshInstance3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 32026
	_build_ground()
	_build_architecture()
	_build_plants()
	_build_slots()
	_build_distance()

func _module(id: String, at: Vector3, yaw_degrees: float=0, scale_value: Vector3=Vector3.ONE) -> Node3D:
	var node: Node3D = (load(ROOT+"modules/"+id+".glb") as PackedScene).instantiate()
	add_child(node)
	node.position=at; node.rotation.y=deg_to_rad(yaw_degrees); node.scale=scale_value
	_apply_pigment(node)
	return node

func _apply_pigment(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(surface)
			if original is StandardMaterial3D:
				var painted := ShaderMaterial.new()
				painted.shader=PIGMENT
				painted.set_shader_parameter("base_color",original.albedo_color)
				painted.set_shader_parameter("wash_scale",3.5)
				node.set_surface_override_material(surface,painted)
	for child in node.get_children(): _apply_pigment(child)

func _asset(id: String, key: String, at: Vector3, yaw_degrees: float=0, size: float=1.0) -> Node3D:
	var holder := Node3D.new();holder.name=key;add_child(holder)
	holder.position=at;holder.rotation.y=deg_to_rad(yaw_degrees);holder.scale=Vector3.ONE*size
	var high: Node3D=(load(ROOT+id+"/"+id+"_high.glb") as PackedScene).instantiate()
	var low: Node3D=(load(ROOT+id+"/"+id+"_low.glb") as PackedScene).instantiate()
	holder.add_child(high);holder.add_child(low);low.visible=false
	_lod_pairs[key]=[high,low]
	return holder

func _build_ground() -> void:
	_module("island_bank",Vector3.ZERO)
	_water=MeshInstance3D.new();_water.name="WaterSurface"
	var plane:=PlaneMesh.new();plane.size=Vector2(180,180);_water.mesh=plane
	var water_material:=ShaderMaterial.new();water_material.shader=load("res://scenes/environment/water_start.gdshader")
	_water.material_override=water_material;_water.position.y=-0.25;add_child(_water)
	# Nonuniform stone groups follow the bank, leaving visible grassy lobes and gaps.
	var rim: Array[Vector2]=[Vector2(-7.5,-7.6),Vector2(-4.8,-8.4),Vector2(-1,-8.2),Vector2(2.5,-7.9),Vector2(5.6,-6.5),Vector2(6.5,-3.8),Vector2(6.4,-.8),Vector2(6.8,1.3),Vector2(5.8,4.8),Vector2(3.5,6.1),Vector2(.7,6.7),Vector2(-2.5,6.1),Vector2(-5.5,5.6),Vector2(-7.2,3.2),Vector2(-7.6,.2),Vector2(-7.1,-3.6)]
	for i in rim.size():
		var a:Vector2=rim[i];var b:Vector2=rim[(i+1)%rim.size()]
		var count:int=ceili(a.distance_to(b)/.67)
		for j in count:
			if _rng.randf()<.17:continue
			var p:Vector2=a.lerp(b,float(j)/count)+Vector2(_rng.randf_range(-.14,.14),_rng.randf_range(-.14,.14))
			_module("stone_%d"%_rng.randi_range(0,4),Vector3(p.x,-.29,p.y),_rng.randf_range(0,360),Vector3(_rng.randf_range(.8,1.55),_rng.randf_range(1.3,2.5),_rng.randf_range(.7,1.3)))
	# Winding flat stone footpaths, with irregular joints, no checkerboard paving.
	var routes:Array[Array]=[[Vector3(-6.0,.115,2.9),Vector3(-5.25,.115,-1.7),Vector3(-2,.115,-1.8),Vector3(2.5,.115,-1.7),Vector3(6.2,.115,-.6)],[Vector3(-4.9,.115,4.65),Vector3(-.5,.115,4.65),Vector3(4.8,.115,4.7)],[Vector3(-1.68,.115,-1),Vector3(-1.68,.115,4.1)],[Vector3(1.57,.115,-1),Vector3(1.57,.115,4.1)]]
	for route in routes:
		for k in range(route.size()-1):
			var a:Vector3=route[k];var b:Vector3=route[k+1];var count:int=ceili(a.distance_to(b)/.48)
			for j in count:
				var p:Vector3=a.lerp(b,float(j)/count);p.x+=_rng.randf_range(-.055,.055);p.z+=_rng.randf_range(-.07,.07)
				_module("stone_%d"%_rng.randi_range(0,4),p,_rng.randf_range(-18,18),Vector3(.64,.18,.72))
	for row in 2:
		for col in 3:
			_module("field_frame",Vector3(-3.3+col*3.25,.17,row*2.8))

func _build_architecture() -> void:
	_asset("house","MainHouse",Vector3(.65,.13,-4.65))
	_module("veranda",Vector3(.65,.13,-2.40))
	_module("side_wing",Vector3(-4.3,.13,-5.0))
	_asset("trellis","EntranceTrellis",Vector3(-6.2,.13,1.1),14,1.10)
	_module("entrance_canopy",Vector3(-6.10,.13,3.68),-8)
	_module("stone_bridge",Vector3(8.1,-.04,-.15),-9)
	_asset("boat","CoveredBoat",Vector3(8.0,-.60,3.3),-24,.85)
	# Opposite landing is a small bank, with irregular rock margins, not a floating bridge end.
	_module("island_bank",Vector3(12.65,-.02,-2.8),0,Vector3(.40,1,.46))
	for i in 4:_module("bamboo_fence",Vector3(-4.8+i*2.0,.14,-7.2))
	for z in [-2.8,-.6,3.6]:_module("bamboo_fence",Vector3(-6.65,.14,z),90)
	for z in [-4.1,-2.0]:_module("bamboo_fence",Vector3(5.7,.14,z),75)

func _build_plants() -> void:
	_asset("tree","WestTree",Vector3(-5.8,.13,-3.45),32,.87)
	_asset("tree","RearTree",Vector3(3.75,.13,-6.1),-27,1.07)
	_asset("tree","EastBankTree",Vector3(12.4,.12,-4.2),-35,.72)
	_asset("tree","RearSmallTree",Vector3(-2.5,.13,-7.45),80,.67)
	var bamboo_positions:Array[Vector3]=[Vector3(-7,.13,-5.2),Vector3(-7.1,.13,-.5),Vector3(5.4,.13,-5.7),Vector3(5.8,.13,2.0),Vector3(13.8,.10,-.8)]
	for i in bamboo_positions.size():_asset("bamboo","Bamboo%d"%i,bamboo_positions[i],_rng.randf_range(0,360),_rng.randf_range(.70,1.05))
	var flower_centres:Array[Vector3]=[Vector3(-5.5,.13,3.9),Vector3(4.9,.13,3.9),Vector3(-5.5,.13,-2.5),Vector3(5.0,.13,-3.4),Vector3(-3.8,.13,5.6),Vector3(2.4,.13,5.7)]
	for i in flower_centres.size():
		for j in 3:
			_asset("flowers","Flowers%d_%d"%[i,j],flower_centres[i]+Vector3(_rng.randf_range(-.38,.38),-.015,_rng.randf_range(-.32,.32)),_rng.randf_range(0,360),_rng.randf_range(.65,1.0))
	for i in 11:
		var angle:float=lerpf(-1.0,1.0,float(i)/10)
		_asset("lotus","Lotus%d"%i,Vector3(6.3+sin(angle)*1.4,-.35,5.7+cos(angle)*.6),_rng.randf_range(0,360),_rng.randf_range(.6,1.0))

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
	_support_line(Vector3(-6.1,2.14,1.15),Vector3(-6.1,2.14,1.4),.025,Color("89794c"))
	_support_line(Vector3(-6.1,2.14,1.4),SLOT_POSITIONS.hanging_03,.012,Color("89794c"))
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
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments:int=96
	# Full ring covers every legal yaw/pan; lower skirt remains behind the water.
	for i in segments:
		var a:float=float(i)/segments;var b:float=float(i+1)/segments
		var pa:=Vector3(sin(a*TAU)*65,0,cos(a*TAU)*65)
		var pb:=Vector3(sin(b*TAU)*65,0,cos(b*TAU)*65)
		for pair in [[pa+Vector3(0,-50,0),Vector2(a*2,1)],[pa+Vector3(0,20,0),Vector2(a*2,0)],[pb+Vector3(0,20,0),Vector2(b*2,0)],[pa+Vector3(0,-50,0),Vector2(a*2,1)],[pb+Vector3(0,20,0),Vector2(b*2,0)],[pb+Vector3(0,-50,0),Vector2(b*2,1)]]:
			surface.set_uv(pair[1]);surface.add_vertex(pair[0])
	var backdrop:=MeshInstance3D.new();backdrop.name="DistantRiverPanorama";backdrop.mesh=surface.commit()
	var material:=ShaderMaterial.new();material.shader=BACKDROP
	material.set_shader_parameter("landscape",load(ROOT+"backdrop/river-distance.png"));backdrop.material_override=material
	backdrop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(backdrop)

func get_water_surface() -> MeshInstance3D:
	return _water

func get_backdrop_material() -> ShaderMaterial:
	var backdrop: MeshInstance3D=get_node("DistantRiverPanorama")
	return backdrop.material_override as ShaderMaterial

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
