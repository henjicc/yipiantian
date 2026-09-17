class_name FarmLayout
extends Node3D

const CropVisuals = preload("res://art/crops/crop_visual_catalog.gd")
const FarmState = preload("res://farm/farm_state.gd")
const PlantWind = preload("res://presentation/plant_wind.gd")
const SoilShader = preload("res://scenes/environment/soil.gdshader")
const PigmentShader = preload("res://scenes/environment/pigment.gdshader")
const TilledSoil = preload("res://presentation/tilled_soil.gd")
const PlantingSoilBurst = preload("res://presentation/planting_soil_burst.gd")
const FIELD_SIZE := Vector3(2.6, 0.16, 2.05)
const CELL_SPAN := Vector2(0.60, 0.44)
const CELL_ORIGIN := Vector2(-1.20, -0.88)
var fields: Array[StaticBody3D] = []
var _crop_roots: Dictionary = {}
var _visual_keys: Dictionary = {}
var _soil_meshes: Dictionary = {}
var _cell_crops: Dictionary = {}
var _planting_tweens: Dictionary = {}
var _planted: Dictionary = {}
var _wet_soil: ShaderMaterial
var _soil: ShaderMaterial
var _ridge: ShaderMaterial
var _coping: ShaderMaterial
var _plant_wind := PlantWind.new()


func _ready() -> void:
	# Pale soil sat at the same value as the sage crops, so neither read. Rich
	# earth gives the leaves something to stand against, as in the reference.
	_soil = _soil_material(0.0)
	_wet_soil = _soil_material(1.0)
	_ridge = _soil_material(0.0)
	_coping = ShaderMaterial.new()
	_coping.shader = PigmentShader
	_coping.set_shader_parameter("base_color", Color("6f6c5b"))
	_coping.set_shader_parameter("wash_scale", 5.5)
	_coping.set_shader_parameter("stone_treatment", 1.0)
	_coping.set_shader_parameter("painted_rock", true)
	_coping.set_shader_parameter("rock_color", preload("res://art/environment/modules/river_stones_color.png"))
	_make_fields()


func select_field(index: int) -> void:
	for i: int in fields.size():
		for patch: MeshInstance3D in _soil_meshes[field_id(i)].values():
			patch.set_instance_shader_parameter("field_selected", 1.0 if i == index else 0.0)


func field_id(index: int) -> String:
	return str(fields[index].get_meta("field_id"))


static func cell_center(cell_id: String) -> Vector3:
	var index: int = FarmState.CELL_IDS.find(cell_id)
	assert(index >= 0)
	return Vector3(-0.90 + (index % 4) * CELL_SPAN.x, FIELD_SIZE.y * 0.5, -0.66 + int(index / 4) * CELL_SPAN.y)


func cell_at(index: int, world_position: Vector3) -> String:
	var point: Vector3 = fields[index].to_local(world_position)
	var offset := Vector2(point.x, point.z) - CELL_ORIGIN
	# Exact soil coordinates, independent of leaf size, species, LOD and stage.
	if offset.x < 0.0 or offset.y < 0.0 or offset.x >= CELL_SPAN.x * 4.0 or offset.y >= CELL_SPAN.y * 4.0:
		return ""
	var col: int = floori(offset.x / CELL_SPAN.x)
	var row: int = floori(offset.y / CELL_SPAN.y)
	return FarmState.CELL_IDS[row * 4 + col]


func select_cell(index: int, cell_id: String) -> void:
	for i: int in fields.size():
		for id: String in FarmState.CELL_IDS:
			_soil_meshes[field_id(i)][id].set_instance_shader_parameter("cell_selected", 1.0 if i == index and id == cell_id else 0.0)


func show_field(field: Dictionary) -> void:
	for cell_id: String in FarmState.CELL_IDS:
		var cell: Dictionary = field.cells[cell_id]
		var identity: String = field.id + "/" + cell_id
		var key: String = "%s/%s/%s" % [cell.crop_id, cell.stage, cell.watered]
		if _visual_keys.get(identity) == key:
			continue
		_visual_keys[identity] = key
		_soil_meshes[field.id][cell_id].material_override = _wet_soil if cell.watered else _soil
		var root_size: float = {"empty": 1.0, "sprout": .38, "young": .68, "mature": 1.0}[cell.stage]
		# Retain the former contact footprint while an emptied patch retracts.
		if cell.stage != "empty":
			_soil_meshes[field.id][cell_id].set_instance_shader_parameter("root_size", root_size)
			_soil_meshes[field.id][cell_id].set_instance_shader_parameter("root_radius", CropVisuals.soil_radius(cell.crop_id,cell.stage))
		_update_planting(identity, _soil_meshes[field.id][cell_id], cell.stage != "empty")
		var stage_key: String = "%s/%s" % [cell.crop_id, cell.stage]
		var existing: Node3D = _cell_crops[field.id].get(cell_id)
		if existing != null and existing.get_meta("stage_key") == stage_key:
			continue
		if existing != null:
			existing.get_parent().remove_child(existing)
			existing.queue_free()
			_cell_crops[field.id].erase(cell_id)
		if cell.stage == "empty":
			continue
		var crop: Node3D = CropVisuals.instantiate(cell.crop_id, cell.stage)
		crop.name = cell_id
		crop.set_meta("cell_id", cell_id)
		crop.set_meta("field_id", field.id)
		crop.set_meta("stage_key", stage_key)
		crop.position = cell_center(cell_id) - Vector3.UP * CropVisuals.planting_depth(cell.crop_id, cell.stage)
		crop.position.y += TilledSoil.height_at(Vector2(crop.position.x, crop.position.z)) - .008
		crop.rotation.y = float(FarmState.CELL_IDS.find(cell_id)) * 0.23
		_crop_roots[field.id].add_child(crop)
		_cell_crops[field.id][cell_id] = crop
		_plant_wind.apply(crop, cell.crop_id)
		var soil_y: float = crop.global_position.y + CropVisuals.planting_depth(cell.crop_id,cell.stage) + .008
		for plant_mesh: MeshInstance3D in crop.find_children("*", "MeshInstance3D", true, false):
			plant_mesh.set_instance_shader_parameter("root_soil", Vector2(soil_y,.045*root_size))


func _update_planting(identity: String, patch: MeshInstance3D, planted: bool) -> void:
	var initial: bool = not _planted.has(identity)
	if not initial and _planted[identity] == planted:
		return
	_planted[identity] = planted
	if _planting_tweens.has(identity):
		_planting_tweens[identity].kill()
		_planting_tweens.erase(identity)
	var target: float = 1.0 if planted else 0.0
	if initial:
		patch.set_instance_shader_parameter("planted", target)
		return
	if planted:
		var burst := PlantingSoilBurst.new()
		burst.position = patch.position + Vector3.UP * .055
		patch.get_parent().add_child(burst)
	var current: float = float(patch.get_instance_shader_parameter("planted"))
	var tween: Tween = create_tween()
	_planting_tweens[identity] = tween
	tween.tween_method(func(value: float) -> void: patch.set_instance_shader_parameter("planted", value), current, target, .42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void: _planting_tweens.erase(identity))


func _soil_material(wetness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SoilShader
	material.set_shader_parameter("wetness", wetness)
	material.set_shader_parameter("loam_albedo", preload("res://art/environment/soil/loam_baked_albedo.png"))
	material.set_shader_parameter("loam_normal", preload("res://art/environment/soil/loam_baked_normal.png"))
	material.set_shader_parameter("loam_surface", preload("res://art/environment/soil/loam_baked_surface.png"))
	return material


func _mesh(parent: Node3D, resource: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = resource
	instance.position = point
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _make_fields() -> void:
	var earthen_bank: ArrayMesh = _earthen_bank()
	var coping: ArrayMesh = _coping_kerb()
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
			# Logical patches share continuous heights/normals, not tile-edge grooves.
			_mesh(body, earthen_bank, Vector3.ZERO, _ridge)
			_mesh(body, coping, Vector3.ZERO, _coping)
			_soil_meshes[field_id(index)] = {}
			_cell_crops[field_id(index)] = {}
			for cell_id: String in FarmState.CELL_IDS:
				var center: Vector3 = cell_center(cell_id)
				var patch: MeshInstance3D = _mesh(body, TilledSoil.patch(center, CELL_SPAN, index), center, _soil)
				patch.name = "Soil_" + cell_id
				patch.extra_cull_margin = .09
				patch.set_instance_shader_parameter("cell_center", Vector2(center.x, center.z))
				_soil_meshes[field_id(index)][cell_id] = patch
			var crops := Node3D.new()
			crops.name = "Crops"
			body.add_child(crops)
			_crop_roots[field_id(index)] = crops
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = FIELD_SIZE
			collision.shape = shape
			body.add_child(collision)


func _coping_kerb() -> ArrayMesh:
	# Kerb stones laid around each bed. These reuse the five image-guided Tripo rocks
	# already used on the island rim rather than a generated block: full yaw, mixed
	# shapes, uneven bedding depth and real gaps are what stop a kerb reading as a
	# row of identical loaves. One shared mesh serves all six beds; it is decoration
	# only and never takes part in collision or cell hit-testing.
	var stones: Array[Mesh] = []
	for index: int in 5:
		var packed: PackedScene = load("res://art/environment/modules/stone_%d.glb" % index)
		var root: Node3D = packed.instantiate()
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			stones.append((node as MeshInstance3D).mesh)
			break
		root.free()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91744
	var half := Vector2(1.315, 0.995)
	var runs: Array[Array] = [
		[Vector2(-half.x, -half.y), Vector2(half.x, -half.y)], [Vector2(half.x, half.y), Vector2(-half.x, half.y)],
		[Vector2(half.x, -half.y), Vector2(half.x, half.y)], [Vector2(-half.x, half.y), Vector2(-half.x, -half.y)]]
	for run: Array in runs:
		var start: Vector2 = run[0]
		var finish: Vector2 = run[1]
		var span: float = start.distance_to(finish)
		var count: int = maxi(3, roundi(span / 0.305))
		var along: Vector2 = (finish - start) / span
		var across := Vector2(-along.y, along.x)
		for i: int in count:
			# Corners always carry a stone; elsewhere an occasional gap lets the
			# earth bank and grass through, as a hand-laid edge actually does.
			var corner: bool = i == 0
			if not corner and rng.randf() < 0.05:
				continue
			var centre: Vector2 = start + along * (span * (i + 0.5) / count) + across * rng.randf_range(-0.045, 0.030)
			_kerb_stone(surface, stones, rng, centre, across, 1.18 if corner else rng.randf_range(0.86, 1.08))
			if rng.randf() < 0.16:
				_kerb_stone(surface, stones, rng, centre + along * rng.randf_range(0.10, 0.17) + across * rng.randf_range(0.10, 0.16), across, rng.randf_range(0.50, 0.68))
	return surface.commit()


func _kerb_stone(surface: SurfaceTool, stones: Array[Mesh], rng: RandomNumberGenerator, centre: Vector2, across: Vector2, size: float) -> void:
	# Stones have a 0.95 m longest horizontal axis and varied low bedding heights.
	var mesh: Mesh = stones[rng.randi_range(0, stones.size() - 1)]
	var scale := Vector3(rng.randf_range(0.34, 0.46) * size, rng.randf_range(0.30, 0.43) * size, rng.randf_range(0.21, 0.28) * size)
	var basis := Basis.IDENTITY.scaled(scale)
	basis = basis.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
	basis = basis.rotated(Vector3(across.x, 0.0, across.y), rng.randf_range(-0.10, 0.10))
	basis = basis.rotated(Vector3(-across.y, 0.0, across.x), rng.randf_range(-0.09, 0.09))
	var bedded: float = rng.randf_range(-0.055, -0.008)
	surface.append_from(mesh, 0, Transform3D(basis, Vector3(centre.x, bedded, centre.y)))


func _earthen_bank() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector3] = [Vector3(1.20,.08,.88),Vector3(1.29,.055,.97),Vector3(1.39,-.027,1.075),Vector3(1.51,-.066,1.20)]
	for band: int in 3:
		for segment: int in 80:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(1,0)]:
				var angle: float = (segment+corner.x)*TAU/80.0
				var ring: Vector3 = rings[band+corner.y]
				var c: float = cos(angle)
				var s: float = sin(angle)
				var noise: float = (sin(angle*13.0)*.012+sin(angle*23.0)*.006) * (band+corner.y)/3.0
				var p := Vector3(signf(c)*pow(absf(c),.18)*(ring.x+noise),ring.y,signf(s)*pow(absf(s),.18)*(ring.z+noise))
				if band+corner.y == 0:
					p.x = c/maxf(absf(c),absf(s))*ring.x
					p.z = s/maxf(absf(c),absf(s))*ring.z
				surface.set_color(Color(1.0-(band+corner.y)/3.0,0,0,1))
				surface.add_vertex(p)
	surface.generate_normals()
	_ridge.set_shader_parameter("bank",true)
	return surface.commit()
