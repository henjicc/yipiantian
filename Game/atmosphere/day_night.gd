extends Node
## Local clock is only presentation. This module has no farm or save dependency.

signal night_weight_changed(weight: float)
signal window_warmth_changed(strength: float)

const WATER_SHADER = preload("res://atmosphere/quiet_water.gdshader")
const WATER_PIGMENT = preload("res://art/environment/backdrop/river-distance.png")
const HOURS: Array[float] = [0.0, 5.0, 6.5, 9.0, 12.0, 16.5, 18.5, 20.0, 24.0]
const SUN: Array[float] = [0.24, 0.24, 0.88, 1.18, 1.25, 1.28, 0.66, 0.24, 0.24]
# Daylight fill is deliberately far below the key light: an even sky term carries no
# surface orientation, so raising it flattens every form. Night keeps a usable floor.
const AMBIENT: Array[float] = [0.26, 0.26, 0.15, 0.11, 0.115, 0.10, 0.15, 0.26, 0.26]
const NIGHT: Array[float] = [1.0, 1.0, 0.12, 0.0, 0.0, 0.0, 0.50, 1.0, 1.0]
const SUN_COLORS: Array[Color] = [Color("a8c5ed"), Color("a8c5ed"), Color("ffe4c5"), Color("fff5e7"), Color("fff8ed"), Color("fff0d6"), Color("ffca9e"), Color("a8c5ed"), Color("a8c5ed")]
const AMBIENT_COLORS: Array[Color] = [Color("8da8cf"), Color("8da8cf"), Color("c7bda8"), Color("d2cdb8"), Color("d8d2bc"), Color("d9c7a4"), Color("bda694"), Color("8da8cf"), Color("8da8cf")]
const BACKGROUND: Array[Color] = [Color("465c6c"), Color("465c6c"), Color("cbd9d5"), Color("dbe2df"), Color("dbe2df"), Color("e4d9c1"), Color("b3bbc3"), Color("465c6c"), Color("465c6c")]
# Sky ambient is the majority of the fill, so it has to follow the clock as well;
# a fixed cool dome previously held the whole scene cold through the golden hour.
const SKY_TOP: Array[Color] = [Color("2b3a52"), Color("2b3a52"), Color("7d9ec0"), Color("86aac6"), Color("88acc3"), Color("8fa6b4"), Color("6b7f9c"), Color("2b3a52"), Color("2b3a52")]
const SKY_HORIZON: Array[Color] = [Color("4a5568"), Color("4a5568"), Color("e8c9a8"), Color("dcd7bd"), Color("ded8c2"), Color("f0d3a6"), Color("e8b287"), Color("4a5568"), Color("4a5568")]
const GROUND_HORIZON: Array[Color] = [Color("232a2c"), Color("232a2c"), Color("8a7f68"), Color("a09880"), Color("a89c82"), Color("b0997a"), Color("8f7a66"), Color("232a2c"), Color("232a2c")]
const GROUND_BOTTOM: Array[Color] = [Color("12171a"), Color("12171a"), Color("3a352c"), Color("44403a"), Color("4a4238"), Color("52443a"), Color("3a3230"), Color("12171a"), Color("12171a")]
const ELEVATION: Array[float] = [48.0, 48.0, 25.0, 47.0, 58.0, 34.0, 16.0, 48.0, 48.0]
const AZIMUTH: Array[float] = [-35.0, -35.0, 30.0, 5.0, -25.0, -55.0, -68.0, -35.0, -35.0]
# Interior and lantern warmth never drops to nothing: the courtyard reads as lived in
# at midday too, and the warm accents are the only high-chroma notes in the frame.
const WINDOW_WARMTH: Array[float] = [1.0, 1.0, 0.62, 0.30, 0.26, 0.45, 0.9, 1.0, 1.0]
const WATER_COLORS: Array[Color] = [Color("263845"), Color("263845"), Color("8c9e9c"), Color("93a89e"), Color("96aa9f"), Color("a8a795"), Color("6e7b80"), Color("263845"), Color("263845")]

var _sun: DirectionalLight3D
var _world: WorldEnvironment
var _sky_material: ProceduralSkyMaterial
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
	# Linear clipped every bright surface flat at 1.0, which removed the highlight
	# roll-off and left the image with no reachable dark end. AgX keeps hue through
	# the shoulder; its own contrast and white settings restore the lost snap.
	_world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_world.environment.tonemap_exposure = 1.30
	_world.environment.tonemap_agx_contrast = 1.45
	_world.environment.tonemap_agx_white = 8.0
	_world.environment.adjustment_enabled = true
	_world.environment.adjustment_contrast = 1.04
	# AgX desaturates towards the shoulder; the washes need that chroma back.
	_world.environment.adjustment_saturation = 1.18
	# Per-channel remap pulling shadows off blue and paper towards warm ivory. The
	# reference keeps its darks warm; an untinted engine curve leaves them cyan.
	var grade := Gradient.new()
	grade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grade.colors = PackedColorArray([Color(0.022, 0.014, 0.012), Color(0.53, 0.505, 0.462), Color(1.0, 0.984, 0.946)])
	var grade_texture := GradientTexture1D.new()
	grade_texture.gradient = grade
	grade_texture.width = 256
	_world.environment.adjustment_color_correction = grade_texture
	# A brighter sky above and darker ground below keep the undersides of leaves
	# and eaves distinct; the clock supplies the four colours every update.
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_energy_multiplier = 0.85
	_sky_material.ground_energy_multiplier = 0.48
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_world.environment.sky = sky
	_world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_world.environment.ambient_light_sky_contribution = 0.50
	_world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_world.environment.ssao_enabled = true
	# A 0.42 m radius averages occlusion over far more than a 3 cm railing post or a
	# kerb stone, so those contacts produced almost no darkening and every prop met
	# the ground on a hard line. The radius has to match the contact being drawn.
	_world.environment.ssao_radius = 0.18
	_world.environment.ssao_intensity = 3.4
	_world.environment.ssao_power = 1.6
	_world.environment.ssao_horizon = 0.035
	_world.environment.ssao_sharpness = 0.92
	# Restrained artistic contact darkening in sunlit areas, not a replacement for
	# cast shadows. In 4.7.2 Forward+, the AO-channel mix also gates this influence.
	_world.environment.ssao_light_affect = 0.75
	_world.environment.ssao_ao_channel_affect = 1.0
	_world.environment.ssao_detail = 1.0
	_world.environment.ssil_enabled = true
	_world.environment.ssil_radius = 1.8
	_world.environment.ssil_intensity = 0.22
	_world.environment.glow_enabled = true
	_world.environment.glow_intensity = 0.55
	_world.environment.glow_strength = 0.65
	_world.environment.glow_bloom = 0.0
	_world.environment.glow_hdr_threshold = 1.35
	_world.environment.fog_enabled = true
	_world.environment.fog_density = 0.0012
	# PCSS produces stippled self-shadowing on the curved thin leaves in 4.7.2.
	# Filtered PCF keeps real shadows, with a restrained constant soft edge.
	_sun.light_angular_distance = 0.0
	# A constant wide blur removed every contact edge and made props read as pasted
	# on. This is the narrowest filter that still hides the thin-leaf stipple.
	_sun.shadow_blur = 1.1
	_sun.shadow_bias = 0.06
	_sun.shadow_normal_bias = 0.35
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_max_distance = 48.0
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
		"sky_top": SKY_TOP[index].lerp(SKY_TOP[index + 1], blend),
		"sky_horizon": SKY_HORIZON[index].lerp(SKY_HORIZON[index + 1], blend),
		"ground_horizon": GROUND_HORIZON[index].lerp(GROUND_HORIZON[index + 1], blend),
		"ground_bottom": GROUND_BOTTOM[index].lerp(GROUND_BOTTOM[index + 1], blend),
		"water_color": WATER_COLORS[index].lerp(WATER_COLORS[index + 1], blend),
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
	if _water_material != null:
		_water_material.set_shader_parameter("water_color", values.water_color)
	if _sky_material != null:
		_sky_material.sky_top_color = values.sky_top
		_sky_material.sky_horizon_color = values.sky_horizon
		_sky_material.ground_horizon_color = values.ground_horizon
		_sky_material.ground_bottom_color = values.ground_bottom
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
			# A small daylight floor keeps the lanterns as warm accents at noon.
			light.light_energy = maxf(_night_weight, 0.26) * 0.70


func _apply_backdrop() -> void:
	if _water_material != null:
		_water_material.set_shader_parameter("reflection_tint", Color.WHITE.lerp(Color("7086a0"), maxf(_night_weight, 0.0)))
	if _backdrop_material != null:
		_backdrop_material.set_shader_parameter("atmosphere_tint", Color.WHITE.lerp(Color("7086a0"), maxf(_night_weight, 0.0)))


func _exit_tree() -> void:
	for light in _lantern_lights:
		if is_instance_valid(light):
			light.queue_free()
