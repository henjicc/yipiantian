extends Node
## Local clock is only presentation. This module has no farm or save dependency.

signal night_weight_changed(weight: float)

const WATER_SHADER = preload("res://atmosphere/quiet_water.gdshader")
const WATER_PIGMENT = preload("res://art/environment/backdrop/river-distance.png")
const HOURS: Array[float] = [0.0, 5.0, 6.5, 9.0, 16.0, 18.0, 20.0, 24.0]
const SUN: Array[float] = [0.15, 0.15, 0.52, 0.80, 0.80, 0.43, 0.15, 0.15]
const AMBIENT: Array[float] = [0.45, 0.45, 0.44, 0.40, 0.40, 0.43, 0.45, 0.45]
const NIGHT: Array[float] = [1.0, 1.0, 0.12, 0.0, 0.0, 0.28, 1.0, 1.0]
const SUN_COLORS: Array[Color] = [Color("a9c3dd"), Color("a9c3dd"), Color("ffecd2"), Color("fff8ea"), Color("fff8ea"), Color("ffcfab"), Color("a9c3dd"), Color("a9c3dd")]
const AMBIENT_COLORS: Array[Color] = [Color("a5b8d5"), Color("a5b8d5"), Color("dbe3dc"), Color("e6e9dd"), Color("e6e9dd"), Color("d8cccf"), Color("a5b8d5"), Color("a5b8d5")]
const BACKGROUND: Array[Color] = [Color("465c6c"), Color("465c6c"), Color("cbd9d5"), Color("dbe2df"), Color("dbe2df"), Color("cbd0cd"), Color("465c6c"), Color("465c6c")]

var _sun: DirectionalLight3D
var _world: WorldEnvironment
var _water_material: ShaderMaterial
var _backdrop_material: ShaderMaterial
var _lantern_lights: Array[OmniLight3D] = []
var _preview_hour: float = -1.0
var _elapsed: float = 0.0
var _night_weight: float = -1.0
var _ripple_age: float = 10.0


func configure(sun: DirectionalLight3D, world: WorldEnvironment, water: MeshInstance3D = null) -> void:
	_sun = sun
	_world = world
	_world.environment = world.environment.duplicate() as Environment
	_world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_world.environment.fog_enabled = true
	_world.environment.fog_density = 0.0012
	if water != null:
		_water_material = ShaderMaterial.new()
		_water_material.shader = WATER_SHADER
		_water_material.set_shader_parameter("painted_water", WATER_PIGMENT)
		# The courtyard's initial material_override takes precedence over surfaces.
		water.material_override = _water_material
	_apply_clock()


func set_lantern_anchors(anchors: Array[Node3D]) -> void:
	for light in _lantern_lights:
		if is_instance_valid(light):
			light.free()
	_lantern_lights.clear()
	for anchor in anchors:
		var light := OmniLight3D.new()
		light.name = "FarmLanternLight"
		light.position.y = -0.22
		light.light_color = Color("ffd296")
		light.omni_range = 2.8
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		anchor.add_child(light)
		_lantern_lights.append(light)
	_apply_lanterns()


func set_backdrop_material(material: ShaderMaterial) -> void:
	_backdrop_material = material
	_apply_backdrop()


func set_preview_hour(hour: float = -1.0) -> bool:
	if not is_finite(hour) or (hour < 0.0 and hour != -1.0):
		return false
	_preview_hour = -1.0 if hour == -1.0 else fposmod(hour, 24.0)
	if _sun != null:
		_apply_clock()
	return true


func get_night_weight() -> float:
	return maxf(_night_weight, 0.0)


func ripple_at(world_position: Vector3) -> void:
	if _water_material != null:
		_water_material.set_shader_parameter("ripple_center", Vector2(world_position.x, world_position.z))
		_ripple_age = 0.0


func _process(delta: float) -> void:
	if _water_material != null and _ripple_age < 5.0:
		_ripple_age += delta
		_water_material.set_shader_parameter("ripple_age", _ripple_age)
	_elapsed += delta
	if _elapsed >= 0.25 and _sun != null:
		_elapsed = 0.0
		_apply_clock()


static func sample_hour(hour: float) -> Dictionary:
	var wrapped: float = fposmod(hour, 24.0)
	var index: int = 0
	while index < HOURS.size() - 2 and wrapped >= HOURS[index + 1]:
		index += 1
	var blend: float = smoothstep(HOURS[index], HOURS[index + 1], wrapped)
	return {
		"sun_energy": lerpf(SUN[index], SUN[index + 1], blend),
		"ambient_energy": lerpf(AMBIENT[index], AMBIENT[index + 1], blend),
		"night_weight": lerpf(NIGHT[index], NIGHT[index + 1], blend),
		"sun_color": SUN_COLORS[index].lerp(SUN_COLORS[index + 1], blend),
		"ambient_color": AMBIENT_COLORS[index].lerp(AMBIENT_COLORS[index + 1], blend),
		"background": BACKGROUND[index].lerp(BACKGROUND[index + 1], blend),
	}


func _apply_clock() -> void:
	var hour: float = _preview_hour
	if hour < 0:
		var local: Dictionary = Time.get_datetime_dict_from_system(false)
		hour = float(local.hour) + float(local.minute) / 60.0 + float(local.second) / 3600.0
	var values: Dictionary = sample_hour(hour)
	_sun.light_energy = values.sun_energy
	_sun.light_color = values.sun_color
	_world.environment.ambient_light_energy = values.ambient_energy
	_world.environment.ambient_light_color = values.ambient_color
	_world.environment.background_color = values.background
	_world.environment.fog_light_color = values.background
	if not is_equal_approx(_night_weight, values.night_weight):
		_night_weight = values.night_weight
		_apply_lanterns()
		_apply_backdrop()
		night_weight_changed.emit(_night_weight)


func _apply_lanterns() -> void:
	for light in _lantern_lights:
		if is_instance_valid(light):
			light.light_energy = maxf(_night_weight, 0.0) * 0.70


func _apply_backdrop() -> void:
	if _backdrop_material != null:
		_backdrop_material.set_shader_parameter("atmosphere_tint", Color.WHITE.lerp(Color("7086a0"), maxf(_night_weight, 0.0)))


func _exit_tree() -> void:
	for light in _lantern_lights:
		if is_instance_valid(light):
			light.queue_free()
