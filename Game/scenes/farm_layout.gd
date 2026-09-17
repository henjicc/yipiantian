class_name FarmLayout
extends Node3D

const CropVisuals = preload("res://art/crops/crop_visual_catalog.gd")
const FarmState = preload("res://farm/farm_state.gd")
const PlantWind = preload("res://presentation/plant_wind.gd")
const SoilShader = preload("res://scenes/environment/soil.gdshader")
const FIELD_SIZE := Vector3(2.6, 0.16, 2.05)
const CELL_SPAN := Vector2(0.60, 0.44)
const CELL_ORIGIN := Vector2(-1.20, -0.88)
var fields: Array[StaticBody3D] = []
var _frames: Array[Node3D] = []
var _crop_roots: Dictionary = {}
var _visual_keys: Dictionary = {}
var _soil_meshes: Dictionary = {}
var _cell_crops: Dictionary = {}
var _cell_frame: Node3D
var _wet_soil: ShaderMaterial
var _soil: ShaderMaterial
var _ridge: ShaderMaterial
var _plant_wind := PlantWind.new()


func _ready() -> void:
	_soil = _soil_material("80684d", 0.0)
	_wet_soil = _soil_material("62533e", 1.0)
	_ridge = _soil_material("766046", 0.0)
	_make_fields()


func select_field(index: int) -> void:
	for i in _frames.size():
		_frames[i].visible = i == index


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
	_cell_frame.visible = index >= 0 and not cell_id.is_empty()
	if _cell_frame.visible:
		_cell_frame.position = fields[index].position + cell_center(cell_id)


func show_field(field: Dictionary) -> void:
	for cell_id: String in FarmState.CELL_IDS:
		var cell: Dictionary = field.cells[cell_id]
		var identity: String = field.id + "/" + cell_id
		var key: String = "%s/%s/%s" % [cell.crop_id, cell.stage, cell.watered]
		if _visual_keys.get(identity) == key:
			continue
		_visual_keys[identity] = key
		_soil_meshes[field.id][cell_id].material_override = _wet_soil if cell.watered else _soil
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
		crop.rotation.y = float(FarmState.CELL_IDS.find(cell_id)) * 0.23
		_crop_roots[field.id].add_child(crop)
		_cell_crops[field.id][cell_id] = crop
		_plant_wind.apply(crop, cell.crop_id)


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
	var soil_patch: ArrayMesh = _soil_patch()
	var earthen_bank: ArrayMesh = _earthen_bank()
	var selected := _material("4d806c")
	selected.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cell_frame = Node3D.new()
	_cell_frame.name = "SelectedCell"
	add_child(_cell_frame)
	for side: int in [-1, 1]:
		_box(_cell_frame, Vector3(side * .291, .014, 0), Vector3(.014, .012, .426), selected)
		_box(_cell_frame, Vector3(0, .014, side * .213), Vector3(.596, .012, .014), selected)
	_cell_frame.hide()
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
			# A shallow shared bed under sixteen soil pads makes narrow natural furrows,
			# without raised UI dividers or a separate collision body per plant.
			_mesh(body, earthen_bank, Vector3.ZERO, _ridge)
			_soil_meshes[field_id(index)] = {}
			_cell_crops[field_id(index)] = {}
			for cell_id: String in FarmState.CELL_IDS:
				var center: Vector3 = cell_center(cell_id)
				_soil_meshes[field_id(index)][cell_id] = _mesh(body, soil_patch, center, _soil)
			var crops := Node3D.new()
			crops.name = "Crops"
			body.add_child(crops)
			_crop_roots[field_id(index)] = crops
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = FIELD_SIZE
			collision.shape = shape
			body.add_child(collision)
			var frame := Node3D.new()
			body.add_child(frame)
			_frames.append(frame)
			for side in [-1, 1]:
				_box(frame, Vector3(side * 1.39, 0.16, 0), Vector3(0.045, 0.04, 2.3), selected)
				_box(frame, Vector3(0, 0.16, side * 1.13), Vector3(2.8, 0.04, 0.045), selected)
			frame.visible = false


func _soil_patch() -> ArrayMesh:
	# Contiguous soft furrows retain exact grid coordinates without sixteen raised tiles.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in 8:
		for col: int in 10:
			for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var uv := Vector2((col+offset.x)/10.0,(row+offset.y)/8.0)
				var edge: float = minf(minf(uv.x,1.0-uv.x),minf(uv.y,1.0-uv.y))
				var height: float = -.016*(1.0-smoothstep(0.0,.11,edge))
				surface.set_uv(uv)
				surface.add_vertex(Vector3((uv.x-.5)*CELL_SPAN.x,height,(uv.y-.5)*CELL_SPAN.y))
	surface.generate_normals()
	return surface.commit()


func _earthen_bank() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Vector3] = [Vector3(1.20,.064,.88),Vector3(1.29,.045,.97),Vector3(1.39,-.027,1.075),Vector3(1.51,-.066,1.20)]
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
