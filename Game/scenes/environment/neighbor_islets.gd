extends Node3D
## Generated complete homesteads in world space; distant tiers share source UVs.
const ROOT := "res://art/environment/islets/"
var _islets: Array[Dictionary] = []
var _low_quality: bool = false
var _materials: Array[ShaderMaterial] = []
var _haze := Color.TRANSPARENT

func _ready() -> void:
	_add("WillowNeighbor", "willow", Vector3(-16,-.68,-3), 28, .85)
	_add("BambooNeighbor", "bamboo", Vector3(-23,-.65,-18), 35, .90)
	_add("EasternCottage", "cottage", Vector3(10,-.62,-17), -28, .85)
	_add("FarWillow", "willow", Vector3(-16.5,-.48,-17), 65, .48)
	_add("FarBamboo", "bamboo", Vector3(2.1,-.46,-25), 15, .48)

func _add(label: String, asset: String, at: Vector3, yaw: float, size: float) -> void:
	var holder := Node3D.new()
	holder.name = label
	add_child(holder)
	holder.position = at
	holder.rotation.y = deg_to_rad(yaw)
	holder.scale = Vector3.ONE*size
	var levels: Array[Node3D] = []
	for tier: String in ["high", "low"]:
		var node: Node3D = (load(ROOT+asset+"_"+tier+".glb") as PackedScene).instantiate()
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
				_materials.append(material)
	levels[1].visible = false
	_islets.append({"node":holder, "high":levels[0], "low":levels[1], "distant":false})

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return
	var haze: Color = get_world_3d().environment.fog_light_color
	if haze != _haze:
		_haze = haze
		for material: ShaderMaterial in _materials: material.set_shader_parameter("haze_color",haze)
	for entry: Dictionary in _islets:
		var distance: float = camera.global_position.distance_to(entry.node.global_position)/entry.node.scale.x
		# Hysteresis prevents tier flicker when orbiting across the boundary.
		var distant: bool = distance > (45.0 if entry.distant else 52.0)
		entry.high.visible = not (_low_quality or distant)
		entry.low.visible = _low_quality or distant
		entry.distant = distant

func set_low_detail_enabled(enabled: bool) -> void:
	_low_quality = enabled
	_process(0.0)

func waterline_sources() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for entry: Dictionary in _islets:
		# Source triangles, once at construction; hidden LOD must not be counted.
		if entry.node.position.length() < 28.0: result.append(entry.high)
	return result
