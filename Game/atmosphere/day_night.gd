extends Node
## Local clock is only presentation. This module has no farm or save dependency.

signal night_weight_changed(weight: float)
signal window_warmth_changed(strength: float)

const WATER_SHADER = preload("res://atmosphere/quiet_water.gdshader")
const WATER_PIGMENT = preload("res://art/environment/backdrop/river-distance.png")
const HOURS: Array[float] = [0.0, 5.0, 6.5, 9.0, 12.0, 16.5, 18.5, 20.0, 24.0]
const SUN: Array[float] = [0.24, 0.24, 0.88, 1.18, 1.25, 1.28, 0.66, 0.24, 0.24]
const AMBIENT: Array[float] = [0.32, 0.32, 0.28, 0.27, 0.28, 0.25, 0.29, 0.32, 0.32]
const NIGHT: Array[float] = [1.0, 1.0, 0.12, 0.0, 0.0, 0.0, 0.50, 1.0, 1.0]
const SUN_COLORS: Array[Color] = [Color("a8c5ed"), Color("a8c5ed"), Color("ffdab0"), Color("fff1d7"), Color("fff6e3"), Color("ffe4bc"), Color("ffb782"), Color("a8c5ed"), Color("a8c5ed")]
const AMBIENT_COLORS: Array[Color] = [Color("8da8cf"), Color("8da8cf"), Color("aebdcc"), Color("c1d2d7"), Color("c8d9df"), Color("b6c9d3"), Color("a7afc9"), Color("8da8cf"), Color("8da8cf")]
const BACKGROUND: Array[Color] = [Color("465c6c"), Color("465c6c"), Color("cbd9d5"), Color("dbe2df"), Color("dbe2df"), Color("e4d9c1"), Color("b3bbc3"), Color("465c6c"), Color("465c6c")]
const ELEVATION: Array[float] = [48.0, 48.0, 25.0, 47.0, 58.0, 34.0, 16.0, 48.0, 48.0]
const AZIMUTH: Array[float] = [-35.0, -35.0, 30.0, 5.0, -25.0, -55.0, -68.0, -35.0, -35.0]
const WINDOW_WARMTH: Array[float] = [1.0, 1.0, 0.6, 0.15, 0.12, 0.35, 0.9, 1.0, 1.0]

var _sun: DirectionalLight3D
var _world: WorldEnvironment
var _water_material: ShaderMaterial
var _backdrop_material: ShaderMaterial
var _lantern_lights: Array[OmniLight3D] = []
var _preview_hour: float = -1.0
var _elapsed: float = 0.0
var _night_weight: float = -1.0
var _window_warmth: float = 0.0
var _ripple_age: float = 10.0


func configure(sun: DirectionalLight3D, world: WorldEnvironment, water: MeshInstance3D = null) -> void:
	_sun = sun
	_world = world
	_world.environment = world.environment.duplicate() as Environment
	_world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_world.environment.tonemap_exposure = 1.0
	_world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_world.environment.ssao_enabled = true
	_world.environment.ssao_radius = 0.85
	_world.environment.ssao_intensity = 1.5
	_world.environment.ssao_power = 1.4
	_world.environment.ssao_light_affect = 0.22
	_world.environment.ssao_detail = 0.7
	_world.environment.glow_enabled = true
	_world.environment.glow_intensity = 0.55
	_world.environment.glow_strength = 0.65
	_world.environment.glow_bloom = 0.0
	_world.environment.glow_hdr_threshold = 1.35
	_world.environment.fog_enabled = true
	_world.environment.fog_density = 0.0012
	_sun.light_angular_distance = 1.8
	_sun.shadow_bias = 0.035
	_sun.shadow_normal_bias = 0.65
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


func get_window_warmth() -> float:
	return _window_warmth


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
		"elevation": lerpf(ELEVATION[index], ELEVATION[index + 1], blend),
		"azimuth": lerpf(AZIMUTH[index], AZIMUTH[index + 1], blend),
		"window_warmth": lerpf(WINDOW_WARMTH[index], WINDOW_WARMTH[index + 1], blend),
	}


func _apply_clock() -> void:
	var hour: float = _preview_hour
	if hour < 0:
		var local: Dictionary = Time.get_datetime_dict_from_system(false)
		hour = float(local.hour) + float(local.minute) / 60.0 + float(local.second) / 3600.0
	var values: Dictionary = sample_hour(hour)
	_sun.light_energy = values.sun_energy
	_sun.light_color = values.sun_color
	_sun.rotation_degrees = Vector3(-values.elevation, values.azimuth, 0.0)
	_world.environment.ambient_light_energy = values.ambient_energy
	_world.environment.ambient_light_color = values.ambient_color
	_world.environment.background_color = values.background
	_world.environment.fog_light_color = values.background
	if not is_equal_approx(_window_warmth, values.window_warmth):
		_window_warmth = values.window_warmth
		window_warmth_changed.emit(_window_warmth)
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
	if _water_material != null:
		_water_material.set_shader_parameter("reflection_tint", Color.WHITE.lerp(Color("7086a0"), maxf(_night_weight, 0.0)))
	if _backdrop_material != null:
		_backdrop_material.set_shader_parameter("atmosphere_tint", Color.WHITE.lerp(Color("7086a0"), maxf(_night_weight, 0.0)))


func _exit_tree() -> void:
	for light in _lantern_lights:
		if is_instance_valid(light):
			light.queue_free()
