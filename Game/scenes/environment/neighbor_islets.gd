extends Node3D
## Generated complete homesteads in world space; distant tiers share source UVs.
const ROOT := "res://art/environment/islets/"
const EXPANSION := "res://art/environment/archipelago/"
const MarshPlants = preload("res://scenes/environment/marsh_plants.gd")
var _islets: Array[Dictionary] = []
var _low_quality: bool = false
var _lake_plants: Node3D

func _ready() -> void:
	_add("WillowNeighbor", "willow", Vector3(-16,-.68,-3), 28)
	_add("BambooNeighbor", "bamboo", Vector3(-23,-.65,-18), 35)
	_add("EasternCottage", "cottage", Vector3(10,-.62,-17), -28)
	_add("FarWillow", "willow", _world_position(-7,38,-.68), 65)
	_add("FarBamboo", "bamboo", _world_position(12,29,-.65), 15)
	# Coordinates are fixed in the world, composed as staggered inhabited shores.
	_far_islet("RiceHamlet", "rice_hamlet", -23, 37, 12)
	_far_islet("MulberryCourt", "mulberry_court", -8, 49, 42)
	_far_islet("BambooInlet", "bamboo_inlet", 8, 43, 10)
	_far_islet("CanalCourts", "canal_courts", 25, 38, -15)
	_far_islet("WillowMeadow", "willow_meadow", 2, 65, 26)
	for index: int in _islets.size():
		var entry: Dictionary = _islets[index]
		var plants := MarshPlants.new()
		plants.name = "WaterlinePlants"
		entry.node.add_child(plants)
		plants.populate(entry.high, 91820+index)
		entry.plants = plants
	_lake_plants=MarshPlants.new()
	_lake_plants.name="OpenWaterTrapa"
	add_child(_lake_plants)
	_lake_plants.populate_lake()

func _world_position(across: float, depth: float, height: float) -> Vector3:
	var heading := Basis(Vector3.UP,deg_to_rad(27.5))
	var point: Vector3 = heading*Vector3(across,0,-depth)
	point.y = height
	return point

func _far_islet(label: String, asset: String, across: float, depth: float, yaw: float) -> void:
	_add(label,asset,_world_position(across,depth,-.5),yaw,EXPANSION)

func _add(label: String, asset: String, at: Vector3, yaw: float, directory: String = ROOT) -> void:
	var holder := Node3D.new()
	holder.name = label
	add_child(holder)
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw)
	# All islands share the authored ten-metre span. Perspective alone changes
	# their apparent size; layout never scales a distant household down or up.
	var levels: Array[Node3D] = []
	for tier: String in ["high", "low"]:
		var node: Node3D = (load(directory+asset+"_"+tier+".glb") as PackedScene).instantiate()
		holder.add_child(node)
		levels.append(node)
		for geometry: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for surface: int in geometry.mesh.get_surface_count():
				var source: StandardMaterial3D = geometry.get_active_material(surface)
				var material := ShaderMaterial.new()
				material.shader = preload("res://scenes/environment/islet_surface.gdshader")
				material.set_shader_parameter("painted_color",source.albedo_texture)
				geometry.set_surface_override_material(surface, material)
	levels[1].visible = false
	_islets.append({"node":holder, "high":levels[0], "low":levels[1], "distant":false})

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return
	for entry: Dictionary in _islets:
		var distance: float = camera.global_position.distance_to(entry.node.global_position)
		# Hysteresis prevents tier flicker when orbiting across the boundary.
		var distant: bool = distance > (45.0 if entry.distant else 52.0)
		entry.high.visible = not (_low_quality or distant)
		entry.low.visible = _low_quality or distant
		entry.distant = distant
		if entry.has("plants"): entry.plants.set_low_detail(_low_quality or distant)

func set_low_detail_enabled(enabled: bool) -> void:
	_low_quality = enabled
	if _lake_plants != null: _lake_plants.set_low_detail(enabled)
	_process(0.0)

func waterline_sources() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for entry: Dictionary in _islets:
		# Source triangles, once at construction; hidden LOD must not be counted.
		if entry.node.position.length() < 28.0: result.append(entry.high)
	return result
