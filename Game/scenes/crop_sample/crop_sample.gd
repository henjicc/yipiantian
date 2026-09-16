extends Node3D
## Independent inspection scene; never changes the player's farm.

const Visuals = preload("res://art/crops/crop_visual_catalog.gd")
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var crop_root: Node3D


func _ready() -> void:
	# Compare the authored high/low meshes, without an extra automatic LOD change.
	get_viewport().mesh_lod_threshold = 0.0
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("dbe2df")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e6e9dd")
	environment.ambient_light_energy = 0.40
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("fff8ea")
	sun.light_energy = 0.80
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 36.0
	add_child(camera)
	camera.current = true
	crop_root = Node3D.new()
	add_child(crop_root)
	show_comparison(false)


func set_night(night: bool) -> void:
	sun.light_energy = 0.15 if night else 0.80
	sun.light_color = Color("a9c3dd") if night else Color("fff8ea")
	environment.ambient_light_energy = 0.45 if night else 0.40
	environment.ambient_light_color = Color("a5b8d5") if night else Color("e6e9dd")
	environment.background_color = Color("344853") if night else Color("dbe2df")


func show_comparison(low_detail: bool, yaw: float = 0.0) -> void:
	_clear_crops()
	for row in 2:
		for column in 3:
			var slot := Node3D.new()
			slot.position = Vector3((column - 1) * 0.78, 0, (row - 0.5) * 0.78)
			crop_root.add_child(slot)
			_add_soil(slot, Vector3(0.64, 0.035, 0.62))
			var crop: Node3D = Visuals.instantiate(Visuals.CROP_IDS[row], Visuals.STAGES[column], low_detail)
			if crop != null:
				crop.rotation.y = yaw
				slot.add_child(crop)
			_add_label(slot, ("青菜" if row == 0 else "白萝卜") + " · " + ["幼芽", "幼株", "成熟"][column], Vector3(0, 0.02, 0.34))
	camera.position = Vector3(2.5, 2.7, 3.6)
	camera.look_at(Vector3(0, 0.15, 0))


func show_field_overview(low_detail: bool, mature_only: bool = false) -> void:
	_clear_crops()
	for row in 2:
		for column in 3:
			var field := Node3D.new()
			field.position = Vector3((column - 1) * 3.0, 0, (row - 0.5) * 2.5)
			crop_root.add_child(field)
			_add_soil(field, Vector3(2.6, 0.035, 2.05))
			for a in 3:
				for b in 3:
					var crop: Node3D = Visuals.instantiate(Visuals.CROP_IDS[row], "mature" if mature_only else Visuals.STAGES[column], low_detail)
					if crop != null:
						crop.position = Vector3(-0.8 + a * 0.8, 0, -0.65 + b * 0.65)
						crop.rotation.y = float(a * 3 + b) * 0.23
						field.add_child(crop)
	camera.position = Vector3(7.5, 8.5, 10.0)
	camera.look_at(Vector3.ZERO)


func show_single(crop_id: String, stage: String, low_detail: bool, yaw: float = 0.0) -> void:
	_clear_crops()
	_add_soil(crop_root, Vector3(0.8, 0.035, 0.8))
	var crop: Node3D = Visuals.instantiate(crop_id, stage, low_detail)
	if crop != null:
		crop.rotation.y = yaw
		crop_root.add_child(crop)
	# Same framing and ground anchor for all stages: real growth size stays visible.
	camera.position = Vector3(0.9, 0.72, 1.05)
	camera.look_at(Vector3(0, 0.20, 0))


func _clear_crops() -> void:
	for child: Node in crop_root.get_children():
		crop_root.remove_child(child)
		child.queue_free()


func show_planted_radish() -> void:
	_clear_crops()
	for index in 3:
		var slot := Node3D.new()
		slot.position.x = (index - 1) * 0.48
		crop_root.add_child(slot)
		_add_soil(slot, Vector3(0.46, 0.08, 0.52))
		var stage: String = Visuals.STAGES[index]
		var crop: Node3D = Visuals.instantiate("radish", stage)
		crop.position.y = -Visuals.planting_depth("radish", stage)
		slot.add_child(crop)
		_add_label(slot, ["幼芽 · 入土 3 mm", "幼株 · 入土 20 mm", "成熟 · 入土 60 mm"][index], Vector3(0, 0.015, 0.27))
	camera.position = Vector3(0.78, 0.67, 1.36)
	camera.look_at(Vector3(0.05, 0.16, 0))


func _add_soil(parent: Node3D, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("817561")
	material.roughness = 1.0
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position.y = -size.y * 0.5
	parent.add_child(instance)


func _add_label(parent: Node3D, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei"])
	label.font = font
	label.text = text
	label.position = position
	label.pixel_size = 0.0007
	label.font_size = 42
	label.modulate = Color("f0e9d8")
	label.outline_modulate = Color("3c4941")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
