extends Node
## Derived presentation only. The caller owns selected field, camera and gameplay.

const FOCUS_BIAS: float = 128.0
const OVERVIEW_BIAS: float = 0.0
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
var _dof_strength: float = 1.0
var _band_initialized: bool = false


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
	_dof_strength = clampf(strength, 0.0, 1.0)
	return true


func get_settings() -> Dictionary:
	return {"quality": _quality, "dof_enabled": _dof_enabled, "dof_strength": _dof_strength}


func _apply_quality() -> void:
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
	_set_environment_bias(_environment)
	refresh_decorations()


func _set_bias(node: Node, value: float) -> void:
	if node is GeometryInstance3D:
		node.lod_bias = value
	for child: Node in node.get_children():
		_set_bias(child, value)


func _set_environment_bias(node: Node) -> void:
	# Authored low-poly modules have destructive lowest auto LODs (thin fence posts,
	# stone faces and bridge rails disappear). Classify once by the stable source path.
	if node is Node3D and node.scene_file_path.begins_with("res://art/environment/modules/"):
		_set_bias(node, FOCUS_BIAS)
		return
	if node is GeometryInstance3D:
		node.lod_bias = OVERVIEW_BIAS
	for child: Node in node.get_children():
		_set_environment_bias(child)


func _on_crop_added(node: Node, field: Node3D) -> void:
	_set_bias(node, FOCUS_BIAS if field == _target else OVERVIEW_BIAS)


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
	var framing: bool = not is_instance_valid(_target) and not _decorations.active and _quality == "standard"
	_foreground.set_overview_visible(framing)
	var allowed: bool = _dof_enabled and _quality == "standard" and _dof_strength > 0.0
	var active: bool = is_instance_valid(_target) and allowed
	var frame_blur: bool = framing and allowed
	var approach: float = 1.0 - smoothstep(12.0, 18.0, _camera.global_position.distance_to(_target.global_position)) if active else 0.0
	var target_amount: float = (0.055 if frame_blur else 0.032 * approach) * _dof_strength
	_attributes.dof_blur_amount = move_toward(_attributes.dof_blur_amount, target_amount, delta * 0.12)
	_attributes.dof_blur_near_enabled = (active or frame_blur) and _attributes.dof_blur_amount > 0.0001
	_attributes.dof_blur_far_enabled = (active or frame_blur) and _attributes.dof_blur_near_enabled
	if frame_blur:
		var nearest_field: float = INF
		var farthest_field: float = -INF
		for field: Node3D in _fields:
			var depths: Vector2 = depth_range(_camera, field.global_transform, _target_bounds)
			nearest_field = minf(nearest_field, depths.x)
			farthest_field = maxf(farthest_field, depths.y)
		_attributes.dof_blur_near_distance = maxf(0.1, nearest_field - 1.0)
		_attributes.dof_blur_near_transition = 5.0
		# Every bed stays sharp even at the legal orbit and zoom limits. Only the
		# space beyond the farm/house begins the gradual background defocus.
		_attributes.dof_blur_far_distance = farthest_field + 7.5
		_attributes.dof_blur_far_transition = 28.0
		_band_initialized = false
	if active:
		_attributes.dof_blur_near_transition = 5.0
		_attributes.dof_blur_far_transition = 12.0
		var depths: Vector2 = depth_range(_camera, _target.global_transform, _target_bounds)
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
