extends Node
## Derived presentation only. The caller owns selected field, camera and gameplay.

signal quality_changed(value: String)

const FOCUS_BIAS: float = 2.0
# Zero forces the coarsest generated LOD even at close range. Preserve Godot's
# screen-space selection everywhere; selected crops get a modest quality margin.
const OVERVIEW_BIAS: float = 1.0
const CameraForeground = preload("res://presentation/camera_foreground.gd")
const PlantWind = preload("res://presentation/plant_wind.gd")
const IndirectLighting = preload("res://presentation/indirect_lighting.gd")
var _indirect_lighting: Node
var _decoration_wind := PlantWind.new()
var photo_mode: bool = false
var _foreground: Node3D
var _camera: Camera3D
var _attributes: CameraAttributesPractical
var _target: Node3D
var _fields: Array = []
var _environment: Node3D
var _decorations: Node3D
var _quality: String = "standard"
var _dof_enabled: bool = true
var _dof_strength: float = 1.7
var _fog_strength: float = 0.28
var _field_bounds: Dictionary = {}
var _bounds_dirty: bool = true
var _neighbor: Node3D
var _neighbor_clear: float = 0.0
var _neighbor_center: Vector2 = Vector2.ZERO
var _construction_clear: float=0.0

func replace_structure(previous: Node, replacement: Node) -> void:
	_indirect_lighting.replace_structure(previous,replacement)

func protect_neighbor(island: Node3D) -> void:
	_neighbor=island
	if is_instance_valid(island): _neighbor_center=Vector2(island.global_position.x,island.global_position.z)


func configure(camera: Camera3D, fields: Array, environment: Node3D, decorations: Node3D) -> void:
	_camera = camera
	_fields = fields.duplicate()
	_environment = environment
	_decorations = decorations
	RenderingServer.global_shader_parameter_set("courtyard_haze_region", environment.plan.haze_region)
	RenderingServer.global_shader_parameter_set("courtyard_haze_visit",Vector4.ZERO)
	_attributes = CameraAttributesPractical.new()
	_attributes.dof_blur_amount = 0.0
	_attributes.dof_blur_near_transition = 2.0
	_attributes.dof_blur_far_transition = 5.0
	_camera.attributes = _attributes
	# Keep circular bokeh; sampling cost is selected with the quality preset.
	# Jitter is disabled: the moving foliage already supplies temporal variation.
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)
	_foreground = CameraForeground.new()
	_foreground.name = "CameraForeground"
	_camera.add_child(_foreground)
	_foreground.configure(_camera)
	_indirect_lighting = IndirectLighting.new()
	add_child(_indirect_lighting)
	_indirect_lighting.configure(_environment.get_parent(), _environment, _camera.get_world_3d().environment)
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
	for candidate: Node3D in _fields:
		refresh_field(candidate)
	# Focus changes detail priority, never the appearance or continuity of DOF.

func replace_fields(fields: Array) -> void:
	_target=null
	for field: Node3D in _fields:
		var crops: Node=field.get_node("Crops")
		crops.child_entered_tree.disconnect(_on_crop_added.bind(field))
		crops.child_exiting_tree.disconnect(_on_crop_removed)
	_fields=fields.duplicate()
	_field_bounds.clear();_bounds_dirty=true
	for field: Node3D in _fields:
		field.get_node("Crops").child_entered_tree.connect(_on_crop_added.bind(field))
		field.get_node("Crops").child_exiting_tree.connect(_on_crop_removed)
		refresh_field(field)


func set_quality(value: String) -> bool:
	if value not in ["standard", "low", "high"]:
		return false
	if value == _quality:
		return true
	_quality = value
	if _camera != null:
		_apply_quality()
	quality_changed.emit(value)
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


func refresh_antialiasing() -> void:
	var viewport: Viewport = _camera.get_viewport()
	# FSR2 already reconstructs antialiased edges; avoid stacking MSAA's cost.
	viewport.msaa_3d = Viewport.MSAA_DISABLED if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 else (Viewport.MSAA_4X if _quality == "high" else Viewport.MSAA_2X)


func _apply_quality() -> void:
	_environment.get_node("PlayerPlants").set_low_detail(_quality=="low")
	_environment.get_node("NeighborIslets").set_low_detail_enabled(_quality == "low")
	_environment.get_node("LivingDetails").set_lamp_shadows(_quality != "low")
	# Preserve the foreground composition. High remains an explicit costlier choice.
	var high: bool = _quality == "high"
	var low: bool = _quality == "low"
	refresh_antialiasing()
	_camera.get_viewport().positional_shadow_atlas_size = 4096 if high else (1024 if low else 2048)
	# Keep distant leaf shadows stable; standard spends the atlas on two cascades.
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, false)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM if high else RenderingServer.ENV_SSAO_QUALITY_LOW, not high, 0.5, 2, 50.0, 300.0)
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_HIGH if high else RenderingServer.DOF_BLUR_QUALITY_MEDIUM, false)
	var world_environment: Environment = _camera.get_world_3d().environment
	if world_environment != null:
		world_environment.ssil_enabled = high
	_indirect_lighting.set_enabled(_quality == "high")


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
			var size: Vector2 = field.get_meta("field_size")+Vector2(.2,.25)
			var bounds := AABB(Vector3(-size.x*.5,-.1,-size.y*.5),Vector3(size.x,.75,size.y))
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
	if is_instance_valid(_neighbor):
		var depths: Vector2=depth_range(_camera,_neighbor.global_transform,AABB(Vector3(-5,-.2,-5),Vector3(10,6.2,10)))
		result.x=minf(result.x,depths.x)
		result.y=maxf(result.y,depths.y)
	if _construction_clear>0:
		var bounds: Rect2=_camera.construction_bounds.grow(.5)
		var depth: Vector2=depth_range(_camera,Transform3D.IDENTITY,AABB(Vector3(bounds.position.x,-.3,bounds.position.y),Vector3(bounds.size.x,6.5,bounds.size.y)))
		result=result.lerp(Vector2(minf(result.x,depth.x),maxf(result.y,depth.y)),_construction_clear)
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
	# Artistic haze belongs to the world, not the camera's moving depth range.
	var environment: Environment = _camera.get_world_3d().environment
	environment.fog_enabled = true
	environment.fog_density = 0.0
	RenderingServer.global_shader_parameter_set("courtyard_haze_strength", _fog_strength)
	var visiting: bool=is_instance_valid(_neighbor) and _camera.get("neighbor_view")==true
	_neighbor_clear=move_toward(_neighbor_clear,1.0 if visiting else 0.0,delta/0.7)
	RenderingServer.global_shader_parameter_set("courtyard_haze_visit",Vector4(_neighbor_center.x,_neighbor_center.y,0,_neighbor_clear))
	# Global buffer colors are consumed directly by spatial shaders in linear space.
	RenderingServer.global_shader_parameter_set("courtyard_haze_color", environment.fog_light_color.srgb_to_linear())
	var inspecting: bool = _camera.get("free_view") == true and not photo_mode
	var constructing: bool=_camera.get("construction_framing")==true
	_construction_clear=move_toward(_construction_clear,1.0 if constructing else 0.0,delta/.7)
	var framing: bool = not inspecting and not constructing and not is_instance_valid(_neighbor) and not is_instance_valid(_target) and not _decorations.active
	_foreground.set_overview_visible(framing)
	var allowed: bool = not inspecting and _dof_enabled and _quality != "low" and _dof_strength > 0.0
	var effect_active: bool = allowed and not _decorations.active
	var target_amount: float = 0.115 * _dof_strength if effect_active else 0.0
	_attributes.dof_blur_amount = move_toward(_attributes.dof_blur_amount, target_amount, delta * 0.35)
	_attributes.dof_blur_near_enabled = effect_active and _attributes.dof_blur_amount > 0.0001
	_attributes.dof_blur_far_enabled = _attributes.dof_blur_near_enabled
	# One farm-relative clear band in overview, zoom, focus and camera tweens.
	# No target reset or separate low-strength close-up profile.
	var depths: Vector2 = protected_depth_range()
	_attributes.dof_blur_near_distance = maxf(0.1, depths.x - 4.0)
	_attributes.dof_blur_near_transition = 3.5
	_attributes.dof_blur_far_distance = depths.y + 7.5
	_attributes.dof_blur_far_transition = 40.0


static func depth_range(camera: Camera3D, transform: Transform3D, bounds: AABB) -> Vector2:
	var result := Vector2(INF, -INF)
	var forward: Vector3 = -camera.global_basis.z
	for corner: int in 8:
		var point: Vector3 = transform * bounds.get_endpoint(corner)
		var depth: float = forward.dot(point - camera.global_position)
		result.x = minf(result.x, depth)
		result.y = maxf(result.y, depth)
	return result
