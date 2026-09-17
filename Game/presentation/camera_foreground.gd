extends Node3D
## Camera-space plant fragments frame the view, never farm geometry or input.

const PlantWind = preload("res://presentation/plant_wind.gd")
var _camera: Camera3D
var _fields: Array = []
var _slots: Array[Node3D] = []
var _groups: Array[Dictionary] = []
var _meshes: Array[MeshInstance3D] = []
var _wind := PlantWind.new()
var _amount: float = 0.0
var _wanted: bool = true
var _last_camera: Transform3D
var _last_size := Vector2.ZERO


func configure(camera: Camera3D, fields: Array, environment: Node3D) -> void:
	_camera = camera
	_fields = fields.duplicate()
	for slot: Dictionary in environment.get_decoration_slots():
		_slots.append(environment.get_slot_marker(slot.id))
	_add_edge("tree", Vector2(-1.04, -0.60), 0.90, -0.28)
	_add_edge("tree", Vector2(1.09, -0.88), 0.85, 0.40)
	_add_edge("bamboo", Vector2(-1.11, 1.02), 0.51, PI - 0.35)
	_add_edge("bamboo", Vector2(1.12, 1.00), 0.55, PI + 0.22)
	visible = false
	_update_frame()


func set_overview_visible(value: bool, immediate: bool = false) -> void:
	_wanted = value
	if immediate:
		_amount = 1.0 if value else 0.0
		visible = value


func _add_edge(kind: String, anchor: Vector2, size: float, tilt: float) -> void:
	var packed: PackedScene = load("res://art/environment/%s/%s_low.glb" % [kind, kind])
	var plant: Node3D = packed.instantiate()
	add_child(plant)
	plant.scale = Vector3.ONE * size
	plant.rotation.z = tilt
	_wind.apply(plant, kind)
	var bounds: AABB = _collect_meshes(plant)
	# Only the leafy crown enters the frame; its root/trunk remains outside it.
	var crown := Vector3(bounds.get_center().x, bounds.position.y + bounds.size.y * 0.76, bounds.get_center().z)
	_groups.append({"node": plant, "anchor": anchor, "crown": crown})


func _collect_meshes(node: Node3D) -> AABB:
	var bounds := AABB()
	var found: bool = false
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		pending.append_array(current.get_children())
		if current is MeshInstance3D:
			var mesh: MeshInstance3D = current
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.lod_bias = 0.0
			mesh.set_instance_shader_parameter("frame_enabled", 1.0)
			_meshes.append(mesh)
			var relative: Transform3D = node.global_transform.affine_inverse() * mesh.global_transform
			var box: AABB = relative * mesh.mesh.get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
	return bounds


func _process(delta: float) -> void:
	if _camera == null:
		return
	_amount = move_toward(_amount, 1.0 if _wanted else 0.0, delta * 3.5)
	visible = _amount > 0.001
	for mesh: MeshInstance3D in _meshes:
		mesh.transparency = 1.0 - _amount
	if visible:
		_update_frame()


func _update_frame() -> void:
	var size: Vector2 = _camera.get_viewport().get_visible_rect().size
	if size == _last_size and _camera.global_transform.is_equal_approx(_last_camera):
		return
	_last_camera = _camera.global_transform
	_last_size = size
	var depth: float = 6.0
	var half_height: float = tan(deg_to_rad(_camera.fov * 0.5)) * depth
	var half_width: float = half_height * size.x / size.y
	for group: Dictionary in _groups:
		var plant: Node3D = group.node
		var anchor: Vector2 = group.anchor
		plant.position = Vector3(anchor.x * half_width, anchor.y * half_height, -depth) - plant.basis * group.crown
	# A conservative screen-space keep-clear area includes all field corners and
	# every hanging/ground marker. It updates only when the camera/window changes.
	var rect := Rect2(Vector2(0.32, 0.28), Vector2(0.36, 0.42))
	for field: Node3D in _fields:
		for x: float in [-1.45, 1.45]:
			for z: float in [-1.2, 1.2]:
				var point: Vector3 = field.global_transform * Vector3(x, 0.45, z)
				if not _camera.is_position_behind(point):
					rect = rect.expand(_camera.unproject_position(point) / size)
	for marker: Node3D in _slots:
		if not _camera.is_position_behind(marker.global_position):
			rect = rect.expand(_camera.unproject_position(marker.global_position) / size)
	var safe := Vector4(rect.position.x - 0.025, rect.position.y - 0.035, rect.end.x + 0.025, rect.end.y + 0.035)
	for mesh: MeshInstance3D in _meshes:
		mesh.set_instance_shader_parameter("frame_safe_rect", safe)
