class_name FarmLayout
extends Node3D

const CropVisuals = preload("res://art/crops/crop_visual_catalog.gd")
const FarmState = preload("res://farm/farm_state.gd")
const PlantWind = preload("res://presentation/plant_wind.gd")
const SoilShader = preload("res://scenes/environment/soil.gdshader")
const FIELD_SIZE := Vector3(2.6, 0.16, 2.05)
var fields: Array[StaticBody3D] = []
var _frames: Array[Node3D] = []
var _crop_roots: Dictionary = {}
var _visual_keys: Dictionary = {}
var _soil_meshes: Dictionary = {}
var _ridge_meshes: Dictionary = {}
var _wet_soil: ShaderMaterial
var _soil: ShaderMaterial
var _ridge: ShaderMaterial
var _wet_ridge: ShaderMaterial
var _plant_wind := PlantWind.new()


func _ready() -> void:
	_soil = _soil_material("80684d", 0.0)
	_wet_soil = _soil_material("62533e", 1.0)
	_ridge = _soil_material("766046", 0.0)
	_wet_ridge = _soil_material("574933", 1.0)
	_make_fields()


func select_field(index: int) -> void:
	for i in _frames.size():
		_frames[i].visible = i == index


func field_id(index: int) -> String:
	return str(fields[index].get_meta("field_id"))


func show_field(field: Dictionary) -> void:
	# A stage/watering change affects visuals; advancing the timestamp alone does not.
	var key: String = "%s/%s/%s" % [field.crop_id, field.stage, field.watered]
	if _visual_keys.get(field.id) == key:
		return
	_visual_keys[field.id] = key
	_soil_meshes[field.id].material_override = _wet_soil if field.watered else _soil
	for ridge: MeshInstance3D in _ridge_meshes[field.id]:
		ridge.material_override = _wet_ridge if field.watered else _ridge
	var crops: Node3D = _crop_roots[field.id]
	var stage_key: String = "%s/%s" % [field.crop_id, field.stage]
	if crops.get_meta("stage_key", "") == stage_key:
		return
	crops.set_meta("stage_key", stage_key)
	for child: Node in crops.get_children():
		crops.remove_child(child)
		child.queue_free()
	if field.stage == "empty":
		return
	# Fixed anchors/heading across phases; only the approved stage resource changes.
	for a in 4:
		for b in 4:
			var crop: Node3D = CropVisuals.instantiate(field.crop_id, field.stage)
			crop.name = "Plant%d" % (a * 4 + b + 1)
			crop.position = Vector3(-0.90 + a * 0.60, FIELD_SIZE.y / 2.0 - CropVisuals.planting_depth(field.crop_id, field.stage), -0.66 + b * 0.44)
			crop.rotation.y = float(a * 4 + b) * 0.23
			crops.add_child(crop)
			_plant_wind.apply(crop, field.crop_id)


func _material(hex: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 0.95
	return material


func _soil_material(hex: String, wetness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SoilShader
	material.set_shader_parameter("soil_color", Color(hex))
	material.set_shader_parameter("wetness", wetness)
	return material


func _mesh(parent: Node3D, resource: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = resource
	instance.position = point
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, point: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var resource := BoxMesh.new()
	resource.size = dimensions
	return _mesh(parent, resource, point, material)


func _make_fields() -> void:
	var selected := _material("4d806c")
	selected.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for row in 2:
		for col in 3:
			var index: int = fields.size()
			var body := StaticBody3D.new()
			body.name = "Field%d" % (index + 1)
			body.position = Vector3(-3.3 + col * 3.25, 0.2, 0.0 + row * 2.8)
			body.collision_layer = 1
			body.collision_mask = 0
			body.set_meta("field_index", index)
			body.set_meta("field_id", FarmState.FIELD_IDS[index])
			add_child(body)
			fields.append(body)
			_soil_meshes[field_id(index)] = _box(body, Vector3.ZERO, FIELD_SIZE, _soil)
			_ridge_meshes[field_id(index)] = []
			var crops := Node3D.new()
			crops.name = "Crops"
			body.add_child(crops)
			_crop_roots[field_id(index)] = crops
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(FIELD_SIZE.x, 0.8, FIELD_SIZE.z)
			collision.shape = shape
			collision.position.y = 0.3
			body.add_child(collision)
			for ridge in 4:
				_ridge_meshes[field_id(index)].append(_box(body, Vector3(-0.9 + ridge * 0.6, 0.079, 0), Vector3(0.065, 0.012, 1.9), _ridge))
			var frame := Node3D.new()
			body.add_child(frame)
			_frames.append(frame)
			for side in [-1, 1]:
				_box(frame, Vector3(side * 1.39, 0.16, 0), Vector3(0.045, 0.04, 2.3), selected)
				_box(frame, Vector3(0, 0.16, side * 1.13), Vector3(2.8, 0.04, 0.045), selected)
			frame.visible = false
