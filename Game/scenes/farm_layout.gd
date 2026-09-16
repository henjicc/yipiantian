class_name FarmLayout
extends Node3D

const CROP: PackedScene = preload("res://art/crops/greens/greens_mature.glb")
const FarmState = preload("res://farm/farm_state.gd")
const FIELD_SIZE := Vector3(2.6, 0.16, 2.05)
var fields: Array[StaticBody3D] = []
var _frames: Array[Node3D] = []
var _crop_roots: Dictionary = {}
var _visual_keys: Dictionary = {}
var _soil_meshes: Dictionary = {}
var _wet_soil: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _soil: StandardMaterial3D
var _wood: StandardMaterial3D
var _stone: StandardMaterial3D
var _leaf: StandardMaterial3D
var _roof: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 17
	_soil = _material("80684d")
	_wet_soil = _material("62533e")
	_wood = _material("88704f")
	_stone = _material("c4baa0")
	_leaf = _material("839873")
	_roof = _material("59676a")
	_make_landscape()
	_make_fields()
	_make_house()
	_make_fences()
	_make_tree(Vector3(-5.8, 0.12, -1.8), 1.0)
	_make_tree(Vector3(5.4, 0.12, -3.1), 1.12)


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
	var crops: Node3D = _crop_roots[field.id]
	for child: Node in crops.get_children():
		crops.remove_child(child)
		child.queue_free()
	if field.stage == "empty":
		return
	# Development stage stand-ins: 3.1 replaces these with the approved stage assets.
	for a in 3:
		for b in 3:
			var crop := CROP.instantiate() as Node3D
			crop.position = Vector3(-0.8 + a * 0.8, 0.09, -0.65 + b * 0.65)
			crop.rotation.y = float(a * 3 + b) * 0.23
			var size_factor: float = {"sprout": 0.28, "young": 0.62, "mature": 1.0}[field.stage]
			crop.scale = Vector3.ONE * size_factor
			if field.crop_id == "radish":
				crop.scale *= Vector3(0.7, 1.1, 0.7)
				_ball(crops, crop.position + Vector3(0, 0.07, 0), Vector3(0.16, 0.25, 0.16) * size_factor, _stone)
			crops.add_child(crop)
	var label := Label3D.new()
	label.text = "白萝卜 · 阶段示意" if field.crop_id == "radish" else ("阶段示意" if field.stage != "mature" else "可收获")
	label.position = Vector3(0, 0.55, -0.9)
	label.font_size = 34
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("f1ebd8")
	label.outline_modulate = Color("465650")
	crops.add_child(label)


func _material(hex: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 0.95
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


func _ball(parent: Node3D, point: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var resource := SphereMesh.new()
	resource.radial_segments = 12
	resource.rings = 6
	var instance := _mesh(parent, resource, point, material)
	instance.scale = dimensions
	return instance


func _post(parent: Node3D, point: Vector3, height: float, radius: float, material: Material) -> MeshInstance3D:
	var resource := CylinderMesh.new()
	resource.height = height
	resource.top_radius = radius * 0.85
	resource.bottom_radius = radius
	resource.radial_segments = 10
	return _mesh(parent, resource, point, material)


func _make_landscape() -> void:
	var water := _material("93b5ab")
	water.roughness = 0.75
	_box(self, Vector3(0, -0.42, 0), Vector3(180, 0.12, 180), water)
	var land := CylinderMesh.new()
	land.top_radius = 1.0
	land.bottom_radius = 1.04
	land.height = 0.5
	land.radial_segments = 64
	_mesh(self, land, Vector3(0, -0.15, 0), _material("a4a684")).scale = Vector3(7.5, 1, 6.25)
	for i in 42:
		var angle: float = TAU * float(i) / 42.0
		var p := Vector3(cos(angle) * 7.4, -0.15, sin(angle) * 6.2)
		_ball(self, p, Vector3(0.9, 0.6, 0.75), _stone)
	# A few grouped stepping stones define the routes without baking in gameplay.
	for x in 12:
		for z in 9:
			var p := Vector3(-5.5 + float(x), 0.14, -4.3 + float(z))
			if p.z < -0.9 or x == 3 or x == 6 or x == 9:
				var slab := _box(self, p, Vector3(0.86, 0.09, 0.8), _stone)
				slab.rotation.y = _rng.randf_range(-0.06, 0.06)
	for i in 18:
		var p := Vector3(_rng.randf_range(-15, 15), -0.32, _rng.randf_range(7, 15))
		_ball(self, p, Vector3(0.55, 0.025, 0.4), _leaf)


func _make_fields() -> void:
	var border := _material("ab9670")
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
			for side in [-1, 1]:
				_box(body, Vector3(side * 1.34, 0.04, 0), Vector3(0.09, 0.15, 2.2), border)
				_box(body, Vector3(0, 0.04, side * 1.08), Vector3(2.75, 0.15, 0.09), border)
			for ridge in 4:
				_box(body, Vector3(-0.9 + ridge * 0.6, 0.09, 0), Vector3(0.08, 0.035, 1.9), border)
			var frame := Node3D.new()
			body.add_child(frame)
			_frames.append(frame)
			for side in [-1, 1]:
				_box(frame, Vector3(side * 1.39, 0.16, 0), Vector3(0.045, 0.04, 2.3), selected)
				_box(frame, Vector3(0, 0.16, side * 1.13), Vector3(2.8, 0.04, 0.045), selected)
			frame.visible = false


func _make_house() -> void:
	var house := Node3D.new()
	house.position = Vector3(2.0, 0.13, -3.4)
	add_child(house)
	var plaster := _material("eadfc5")
	_box(house, Vector3(0, 0.14, 0), Vector3(4.8, 0.28, 3.35), _stone)
	_box(house, Vector3(0, 1.25, -0.25), Vector3(4.3, 2.2, 2.45), plaster)
	_box(house, Vector3(0, 0.9, 0.995), Vector3(0.83, 1.7, 0.1), _wood)
	for side in [-1, 1]:
		_box(house, Vector3(side * 1.32, 1.35, 1.02), Vector3(0.83, 0.86, 0.12), _wood)
		_box(house, Vector3(side * 1.32, 1.35, 1.1), Vector3(0.64, 0.67, 0.02), _material("d7bc85"))
		for bar in 4:
			_box(house, Vector3(side * 1.32 - 0.3 + bar * 0.2, 1.35, 1.13), Vector3(0.045, 0.7, 0.04), _wood)
		_post(house, Vector3(side * 2.05, 1.23, 1.36), 2.2, 0.09, _wood)
		_box(house, Vector3(side * 2.14, 1.27, -1.43), Vector3(0.12, 2.3, 0.12), _wood)
	# Two pitched planes and grouped battens suggest a tile roof at prototype scale.
	for side in [-1, 1]:
		var roof_half := _box(house, Vector3(0, 2.75, -0.3 + side * 0.88), Vector3(4.95, 0.15, 2.04), _roof)
		roof_half.rotation.x = side * deg_to_rad(24)
		for tile in 20:
			var strip := _box(house, Vector3(-2.35 + tile * 0.247, 2.83, -0.3 + side * 0.88), Vector3(0.045, 0.055, 2.04), _roof)
			strip.rotation.x = side * deg_to_rad(24)
	_box(house, Vector3(0, 3.19, -0.3), Vector3(5.0, 0.16, 0.17), _roof)
	_box(house, Vector3(0, 2.31, 1.39), Vector3(4.55, 0.16, 0.17), _wood)
	for step in 2:
		_box(house, Vector3(0, 0.08 - step * 0.04, 1.8 + step * 0.25), Vector3(1.3, 0.12, 0.45), _stone)
	var lantern := _material("c67e4d")
	for side in [-1, 1]:
		_ball(house, Vector3(side * 1.98, 1.84, 1.4), Vector3(0.27, 0.37, 0.27), lantern)
		_post(house, Vector3(side * 1.98, 2.1, 1.4), 0.2, 0.015, _wood)
	var gate := Node3D.new()
	gate.position = Vector3(-4.55, 0.12, -2.9)
	add_child(gate)
	for side in [-1, 1]:
		_post(gate, Vector3(side * 0.77, 0.9, 0), 1.8, 0.09, _wood)
	_box(gate, Vector3(0, 1.83, 0), Vector3(2, 0.16, 0.65), _roof)


func _make_fences() -> void:
	for i in 13:
		_post(self, Vector3(-6.0 + i, 0.52, 4.5), 0.85, 0.055, _wood)
	for level in [0.43, 0.75]:
		_box(self, Vector3(0, level, 4.5), Vector3(12, 0.06, 0.06), _wood)
	for i in 8:
		_post(self, Vector3(-6, 0.52, -3 + i), 0.85, 0.055, _wood)
	for level in [0.43, 0.75]:
		_box(self, Vector3(-6, level, 0.5), Vector3(0.06, 0.06, 7), _wood)


func _make_tree(point: Vector3, size_factor: float) -> void:
	var tree := Node3D.new()
	tree.position = point
	tree.scale = Vector3.ONE * size_factor
	add_child(tree)
	_post(tree, Vector3(0, 1.25, 0), 2.5, 0.18, _wood)
	for i in 5:
		var angle: float = float(i) * TAU / 5.0
		var p := Vector3(cos(angle) * 0.65, 2.4 + _rng.randf_range(0, 0.6), sin(angle) * 0.65)
		_ball(tree, p, Vector3(1.7, 1.2, 1.5), _leaf)
