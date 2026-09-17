extends Node
## Derived presentation only. The caller owns selected field, camera and gameplay.

const FOCUS_BIAS: float = 2.0
# Zero forces the coarsest generated LOD even at close range. Preserve Godot's
# screen-space selection everywhere; selected crops get a modest quality margin.
const OVERVIEW_BIAS: float = 1.0
const CameraForeground = preload("res://presentation/camera_foreground.gd")
const PlantWind = preload("res://presentation/plant_wind.gd")
var _decoration_wind := PlantWind.new()
var _foreground: Node3D
var _camera: Camera3D
var _attributes: CameraAttributesPractical
var _target: Node3D
var _fields: Array = []
var _environment: Node3D
var _decorations: Node3D
var _target_bounds := AABB(Vector3(-1.4, -0.1, -1.15), Vector3(2.8, 0.75, 2.3))
var _quality: String = "standard"
var _dof_enabled: bool = true
var _dof_strength: float = 1.5
var _fog_strength: float = 0.55
var _band_initialized: bool = false
var _field_bounds: Dictionary = {}
var _bounds_dirty: bool = true


func configure(camera: Camera3D, fields: Array, environment: Node3D, decorations: Node3D) -> void:
	_camera = camera
	_fields = fields.duplicate()
	_environment = environment
	_decorations = decorations
	_attributes = CameraAttributesPractical.new()
	_attributes.dof_blur_amount = 0.0
	_attributes.dof_blur_near_transition = 2.0
	_attributes.dof_blur_far_transition = 5.0
	_camera.attributes = _attributes
	# Circular, high-sample DOF avoids the coarse polygon pattern on near leaves.
	# Jitter is disabled: the moving foliage already supplies temporal variation.
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH, false)
	_foreground = CameraForeground.new()
	_foreground.name = "CameraForeground"
	_camera.add_child(_foreground)
	_foreground.configure(_camera, _fields, _environment)
	# Run after the camera pose so the clear band follows current projected depth.
	process_priority = 10
	for field: Node3D in _fields:
		field.get_node("Crops").child_entered_tree.connect(_on_crop_added.bind(field))
		field.get_node("Crops").child_exiting_tree.connect(_on_crop_removed)
	_decorations.child_entered_tree.connect(_on_decoration_added)
	_apply_quality()
	refresh_details()


func set_focus(field: Node3D = null) -> void:
	if field == _target:
		return
	_target = field
	_band_initialized = false
	for candidate: Node3D in _fields:
		refresh_field(candidate)
	# Remove blur immediately when switching targets; never blur the new operation.
	# Strength then eases in at the new depth instead of preserving an old focus band.
	if _attributes != null:
		_attributes.dof_blur_amount = 0.0
		_attributes.dof_blur_near_enabled = false
		_attributes.dof_blur_far_enabled = false


func set_quality(value: String) -> bool:
	if value != "standard" and value != "low":
		return false
	_quality = value
	if _camera != null:
		_apply_quality()
	return true


func set_depth_of_field(enabled: bool, strength: float = 1.0) -> bool:
	if not is_finite(strength):
		return false
	_dof_enabled = enabled
	_dof_strength = clampf(strength, 0.0, 3.0)
	return true


func set_fog_strength(strength: float) -> void:
	if is_finite(strength):
		_fog_strength = clampf(strength, 0.0, 1.0)


func get_settings() -> Dictionary:
	return {"quality": _quality, "dof_enabled": _dof_enabled, "dof_strength": _dof_strength, "fog_strength": _fog_strength}


func _apply_quality() -> void:
	_environment.get_node("NeighborIslets").set_low_detail_enabled(_quality == "low")
	# One concrete raster-quality step; shadows and the selected crop stay intact.
	# Drop decorative geometry before an MSAA switch can stall shader compilation.
	if _quality == "low" and _foreground != null:
		_foreground.set_overview_visible(false, true)
	_camera.get_viewport().msaa_3d = Viewport.MSAA_2X if _quality == "low" else Viewport.MSAA_4X
	var world_environment: Environment = _camera.get_world_3d().environment
	if world_environment != null:
		world_environment.ssil_enabled = _quality == "standard"


func refresh_field(field: Node3D) -> void:
	# Changing an instance's bias keeps its imported mesh, material and collision.
	# Scene-child notifications cover stage replacement; no per-frame tree traversal.
	_set_bias(field.get_node("Crops"), FOCUS_BIAS if field == _target else OVERVIEW_BIAS)


func refresh_decorations() -> void:
	_set_bias(_decorations, OVERVIEW_BIAS)
	for child: Node in _decorations.get_children():
		_apply_decoration_wind(child)


func refresh_details() -> void:
	for field: Node3D in _fields:
		refresh_field(field)
	_set_bias(_environment, OVERVIEW_BIAS)
	refresh_decorations()


func _set_bias(node: Node, value: float) -> void:
	if node is GeometryInstance3D:
		node.lod_bias = value
	for child: Node in node.get_children():
		_set_bias(child, value)


func _on_crop_added(node: Node, field: Node3D) -> void:
	_set_bias(node, FOCUS_BIAS if field == _target else OVERVIEW_BIAS)
	_bounds_dirty = true


func _on_crop_removed(_node: Node) -> void:
	_bounds_dirty = true


func protected_depth_range() -> Vector2:
	# Rebuild only after crops change, once their final placement has been applied.
	# Actual foliage bounds plus wind margin protect tall crops as well as soil.
	if _bounds_dirty:
		for field: Node3D in _fields:
			var bounds: AABB = _target_bounds
			for mesh: MeshInstance3D in field.get_node("Crops").find_children("*", "MeshInstance3D", true, false):
				if mesh.mesh != null and mesh.is_visible_in_tree():
					var local: Transform3D = field.global_transform.affine_inverse() * mesh.global_transform
					bounds = bounds.merge(local * mesh.get_aabb())
			_field_bounds[field] = bounds.grow(0.12)
		_bounds_dirty = false
	var result := Vector2(INF, -INF)
	for field: Node3D in _fields:
		var depths: Vector2 = depth_range(_camera, field.global_transform, _field_bounds[field])
		result.x = minf(result.x, depths.x)
		result.y = maxf(result.y, depths.y)
	return result


func _on_decoration_added(node: Node) -> void:
	# Includes new confirmed, recovered and preview instances, without touching state.
	_set_bias(node, OVERVIEW_BIAS)
	_apply_decoration_wind(node)


func _apply_decoration_wind(node: Node) -> void:
	if node is Node3D and node.scene_file_path.begins_with("res://art/decorations/flowerpot/"):
		_decoration_wind.apply(node, "flowerpot")


func _process(delta: float) -> void:
	if _camera == null:
		return
	# Depth haze begins beyond all beds and the house; clock still owns its colour.
	var environment: Environment = _camera.get_world_3d().environment
	var clear_depths: Vector2 = protected_depth_range()
	environment.fog_enabled = _fog_strength > 0.0
	environment.fog_density = _fog_strength * 0.85
	environment.fog_depth_begin = maxf(1.0, clear_depths.y + 10.0)
	environment.fog_depth_end = environment.fog_depth_begin + 70.0
	environment.fog_depth_curve = 1.25
	var inspecting: bool = _camera.get("free_view") == true
	var framing: bool = not inspecting and not is_instance_valid(_target) and not _decorations.active and _quality == "standard"
	_foreground.set_overview_visible(framing, inspecting)
	var allowed: bool = not inspecting and _dof_enabled and _quality == "standard" and _dof_strength > 0.0
	var active: bool = is_instance_valid(_target) and allowed
	var frame_blur: bool = framing and allowed
	var approach: float = 1.0 - smoothstep(12.0, 18.0, _camera.global_position.distance_to(_target.global_position)) if active else 0.0
	var target_amount: float = (0.115 if frame_blur else 0.032 * approach) * _dof_strength
	_attributes.dof_blur_amount = move_toward(_attributes.dof_blur_amount, target_amount, delta * 0.35)
	_attributes.dof_blur_near_enabled = (active or frame_blur) and _attributes.dof_blur_amount > 0.0001
	_attributes.dof_blur_far_enabled = (active or frame_blur) and _attributes.dof_blur_near_enabled
	if frame_blur:
		var depths: Vector2 = protected_depth_range()
		# Keep the boat and mid-water lotus clear; only the much closer frame plants
		# enter the stronger blur band introduced for the low overview angle.
		_attributes.dof_blur_near_distance = maxf(0.1, depths.x - 4.0)
		_attributes.dof_blur_near_transition = 3.5
		# Every bed stays sharp even at the legal orbit and zoom limits. Only the
		# space beyond the farm/house begins the gradual background defocus.
		_attributes.dof_blur_far_distance = depths.y + 7.5
		_attributes.dof_blur_far_transition = 40.0
		_band_initialized = false
	if active:
		_attributes.dof_blur_near_transition = 5.0
		_attributes.dof_blur_far_transition = 12.0
		# Artistic clear plateau: all six beds remain sharp even in a focused view.
		var depths: Vector2 = protected_depth_range()
		var near_edge: float = maxf(0.1, depths.x - 0.6)
		var far_edge: float = depths.y + 0.6
		var weight: float = 1.0 - exp(-delta * 8.0)
		# Expand immediately to enclose the operation; contract smoothly. Ordinary
		# pose tweens are continuous, but a fast pan must never outrun the clear band.
		_attributes.dof_blur_near_distance = minf(near_edge, lerpf(_attributes.dof_blur_near_distance, near_edge, weight)) if _band_initialized else near_edge
		_attributes.dof_blur_far_distance = maxf(far_edge, lerpf(_attributes.dof_blur_far_distance, far_edge, weight)) if _band_initialized else far_edge
		_band_initialized = true


static func depth_range(camera: Camera3D, transform: Transform3D, bounds: AABB) -> Vector2:
	var result := Vector2(INF, -INF)
	var forward: Vector3 = -camera.global_basis.z
	for corner: int in 8:
		var point: Vector3 = transform * bounds.get_endpoint(corner)
		var depth: float = forward.dot(point - camera.global_position)
		result.x = minf(result.x, depth)
		result.y = maxf(result.y, depth)
	return result
