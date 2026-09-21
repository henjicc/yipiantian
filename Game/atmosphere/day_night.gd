extends Node
## Local clock is only presentation. This module has no farm or save dependency.

signal night_weight_changed(weight: float)
signal window_warmth_changed(strength: float)

const WATER_SHADER = preload("res://atmosphere/quiet_water.gdshader")
const WATER_HIGH_SHADER = preload("res://atmosphere/quiet_water_high.gdshader")
const WATER_PIGMENT = preload("res://art/environment/backdrop/river-distance.png")
const HOURS: Array[float] = [0.0, 5.0, 6.5, 9.0, 12.0, 16.5, 18.5, 20.0, 24.0]
const SUN: Array[float] = [0.0, 0.0, 0.88, 1.18, 1.25, 1.28, 0.24, 0.0, 0.0]
# Daylight fill is deliberately far below the key light: an even sky term carries no
# surface orientation, so raising it flattens every form. Night keeps a usable floor.
const AMBIENT: Array[float] = [0.20, 0.20, 0.13, 0.11, 0.115, 0.075, 0.105, 0.20, 0.20]
const NIGHT: Array[float] = [1.0, 1.0, 0.12, 0.0, 0.0, 0.0, 0.50, 1.0, 1.0]
const SUN_COLORS: Array[Color] = [Color("a8c5ed"), Color("a8c5ed"), Color("ffe4c5"), Color("fff5e7"), Color("fff8ed"), Color("fff0d6"), Color("ffca9e"), Color("a8c5ed"), Color("a8c5ed")]
const AMBIENT_COLORS: Array[Color] = [Color("8da8cf"), Color("8da8cf"), Color("c7bda8"), Color("d2cdb8"), Color("d8d2bc"), Color("d9c7a4"), Color("bda694"), Color("8da8cf"), Color("8da8cf")]
const BACKGROUND: Array[Color] = [Color("465c6c"), Color("465c6c"), Color("cbd9d5"), Color("dbe2df"), Color("dbe2df"), Color("e4d9c1"), Color("b3bbc3"), Color("465c6c"), Color("465c6c")]
# Sky ambient is the majority of the fill, so it has to follow the clock as well;
# a fixed cool dome previously held the whole scene cold through the golden hour.
const SKY_TOP: Array[Color] = [Color("26344d"), Color("26344d"), Color("7d9ec0"), Color("86aac6"), Color("88acc3"), Color("687e93"), Color("485970"), Color("26344d"), Color("26344d")]
const SKY_HORIZON: Array[Color] = [Color("3b485e"), Color("3b485e"), Color("c3b6aa"), Color("dcd7bd"), Color("ded8c2"), Color("bfa58b"), Color("877d86"), Color("3b485e"), Color("3b485e")]
const BACKDROP_TINT: Array[Color] = [Color("354d69"), Color("354d69"), Color("a8b2b9"), Color.WHITE, Color.WHITE, Color("b4afa5"), Color("65768c"), Color("354d69"), Color("354d69")]
const GROUND_HORIZON: Array[Color] = [Color("232a2c"), Color("232a2c"), Color("8a7f68"), Color("a09880"), Color("a89c82"), Color("b0997a"), Color("8f7a66"), Color("232a2c"), Color("232a2c")]
const GROUND_BOTTOM: Array[Color] = [Color("12171a"), Color("12171a"), Color("3a352c"), Color("44403a"), Color("4a4238"), Color("52443a"), Color("3a3230"), Color("12171a"), Color("12171a")]
const ELEVATION: Array[float] = [-30.0, -12.0, 8.0, 47.0, 58.0, 34.0, 4.0, -12.0, -30.0]
const AZIMUTH: Array[float] = [-110.0, 40.0, 30.0, 5.0, -25.0, -55.0, -68.0, -80.0, -110.0]
# Interior paper windows retain subtle warmth; outdoor lamps use NIGHT separately.
const WINDOW_WARMTH: Array[float] = [1.0, 1.0, 0.62, 0.30, 0.26, 0.45, 0.9, 1.0, 1.0]
const WATER_COLORS: Array[Color] = [Color("254653"), Color("254653"), Color("79a9ad"), Color("69a3a4"), Color("68a4a3"), Color("83aaa2"), Color("618c9a"), Color("254653"), Color("254653")]

var _moon_fill: DirectionalLight3D
var _sun: DirectionalLight3D
var _world: WorldEnvironment
var _sky_material: ProceduralSkyMaterial
var _water_material: ShaderMaterial
var _backdrop_material: ShaderMaterial
var _backdrop_values: Dictionary = {}
var _lantern_lights: Array[OmniLight3D] = []
var _preview_hour: float = -1.0
var _elapsed: float = 0.0
var _night_weight: float = -1.0
var _window_warmth: float = 0.0
var _ripple_age: float = 10.0
var _high_quality: bool = false


func set_quality(value: String) -> void:
	_high_quality = value == "high"
	if _water_material != null:
		# Keep the same material and shared uniforms: shore, boat and ripple state
		# must survive a quality switch. Both shaders use the same surface code.
		_water_material.shader = WATER_HIGH_SHADER if _high_quality else WATER_SHADER
	if _sun != null:
		_apply_clock()


func get_preview_hour() -> float:
	return _preview_hour


func configure(sun: DirectionalLight3D, world: WorldEnvironment, water: MeshInstance3D = null) -> void:
	_sun = sun
	# Independent weak night fill never inherits or reverses the solar arc.
	_moon_fill = DirectionalLight3D.new()
	_moon_fill.name = "MoonFill"
	_moon_fill.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	_moon_fill.light_color = Color("a8c5ed")
	_moon_fill.light_energy = 0.0
	_moon_fill.shadow_enabled = false
	add_child(_moon_fill)
	_world = world
	_world.environment = world.environment.duplicate() as Environment
	# Linear clipped every bright surface flat at 1.0, which removed the highlight
	# roll-off and left the image with no reachable dark end. AgX keeps hue through
	# the shoulder; its own contrast and white settings restore the lost snap.
	_world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	_world.environment.tonemap_exposure = 1.30
	_world.environment.tonemap_agx_contrast = 1.30
	_world.environment.tonemap_agx_white = 8.0
	_world.environment.adjustment_enabled = true
	_world.environment.adjustment_contrast = 1.04
	# Retain painted chroma without exaggerating the warm daylight on green leaves.
	_world.environment.adjustment_saturation = 1.10
	# Keep the cool shadow toe, but neutralize the old yellow mid/highlight grade.
	# Warmth comes from the timed sun and lanterns, not a tint on every material.
	var grade := Gradient.new()
	grade.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grade.colors = PackedColorArray([Color(0.009, 0.013, 0.020), Color(0.505, 0.505, 0.50), Color(1.0, 0.995, 0.985)])
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
	_world.environment.ssao_intensity = 2.4
	_world.environment.ssao_power = 1.35
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
	_world.environment.fog_mode = Environment.FOG_MODE_DEPTH
	# World-space lake haze handles the inhabited islands and headlands.
	# Depth fog only hides the far clip, rather than washing those shores twice.
	_world.environment.fog_depth_begin = 160.0
	_world.environment.fog_depth_end = 400.0
	_world.environment.fog_depth_curve = 1.5
	_world.environment.fog_density = 0.33
	_world.environment.fog_sky_affect = 0.0
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
		var previous: ShaderMaterial = water.material_override as ShaderMaterial
		_water_material = ShaderMaterial.new()
		_water_material.shader = WATER_SHADER
		if previous != null and previous.shader == WATER_SHADER:
			_water_material.set_shader_parameter("shore_distance", previous.get_shader_parameter("shore_distance"))
			_water_material.set_shader_parameter("shore_contacts_enabled", previous.get_shader_parameter("shore_contacts_enabled"))
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
	_world.environment.sky.sky_material = material
	_world.environment.background_mode = Environment.BG_SKY
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
	var values: Dictionary = {
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
		"backdrop_tint": BACKDROP_TINT[index].lerp(BACKDROP_TINT[index + 1], blend),
	}
	# Open the unlit beds gently while keeping the night distinct from daytime.
	# Using the same smooth clock weight preserves dawn/dusk and midnight continuity.
	var night: float = values.night_weight
	# The solar shadow grows toward sunset, then fades below the horizon.
	values.sun_energy *= smoothstep(0.0, 4.0, float(values.elevation))
	values.moon_energy = 0.31 * night
	values.ambient_energy += 0.035 * night
	values.sun_color = values.sun_color.lerp(Color("f6f7ef"), 0.30 * (1.0 - night))
	values.ambient_color = values.ambient_color.lerp(Color("c6d2d3"), 0.32 * (1.0 - night))
	return values


var _season: String = "daily"

func set_season(id: String) -> void:
	_season = id
	if _sun != null: _apply_clock()

func _apply_clock() -> void:
	var hour: float = _preview_hour
	if hour < 0:
		var local: Dictionary = Time.get_datetime_dict_from_system(false)
		hour = float(local.hour) + float(local.minute) / 60.0 + float(local.second) / 3600.0
	var values: Dictionary = sample_hour(hour)
	# Mood is composed with clock lighting in its sole owner, never overwritten
	# by the next clock tick. Night keeps its readable moonlight and warm windows.
	var daylight: float = 1.0-values.night_weight
	if _season=="after_rain":
		values.sun_energy *= lerpf(1.0,.60,daylight)
		values.ambient_energy *= 1.07
		values.sun_color = values.sun_color.lerp(Color("dbe4da"),daylight*.45)
		values.ambient_color = values.ambient_color.lerp(Color("bacfd0"),daylight*.18)
		values.water_color = values.water_color.lerp(Color("6f9c9c"),daylight*.20)
		values.sky_top = values.sky_top.lerp(values.sky_horizon,.45)
	elif _season=="drying":
		values.sun_energy *= lerpf(1.0,1.10,daylight)
		values.sun_color = values.sun_color.lerp(Color("ffe3ae"),daylight*.25)
		values.backdrop_tint = values.backdrop_tint.lerp(Color("f5e5c8"),daylight*.07)
	_backdrop_values = values
	_moon_fill.light_energy = values.moon_energy
	_sun.light_energy = values.sun_energy
	_sun.light_color = values.sun_color
	_sun.rotation_degrees = Vector3(-values.elevation, values.azimuth, 0.0)
	_world.environment.ambient_light_energy = values.ambient_energy
	_world.environment.ambient_light_color = values.ambient_color
	if _water_material != null:
		_water_material.set_shader_parameter("water_color", values.water_color)
		if _high_quality:
			var fill: Color = values.ambient_color.srgb_to_linear().lerp(values.sky_top.srgb_to_linear() * _sky_material.sky_energy_multiplier, 0.50) * values.ambient_energy
			_water_material.set_shader_parameter("sky_fill", Vector3(fill.r, fill.g, fill.b))
	if _sky_material != null:
		_sky_material.sky_top_color = values.sky_top
		_sky_material.sky_horizon_color = values.sky_horizon
		_sky_material.ground_horizon_color = values.ground_horizon
		_sky_material.ground_bottom_color = values.ground_bottom
	_world.environment.background_color = values.background
	_world.environment.fog_light_color = values.sky_horizon
	if not is_equal_approx(_window_warmth, values.window_warmth):
		_window_warmth = values.window_warmth
		window_warmth_changed.emit(_window_warmth)
	if not is_equal_approx(_night_weight, values.night_weight):
		_night_weight = values.night_weight
		_apply_lanterns()
		night_weight_changed.emit(_night_weight)
	_apply_backdrop()


func _apply_lanterns() -> void:
	for light in _lantern_lights:
		if is_instance_valid(light):
			light.light_energy = maxf(_night_weight, 0.0) * 0.70
			light.visible = _night_weight > 0.0


func _apply_backdrop() -> void:
	if _water_material != null:
		_water_material.set_shader_parameter("sky_top", _backdrop_values.sky_top)
		_water_material.set_shader_parameter("sky_horizon", _backdrop_values.sky_horizon)
		_water_material.set_shader_parameter("reflection_tint", Color.WHITE.lerp(Color("7086a0"), maxf(_night_weight, 0.0)))
	if _backdrop_material != null:
		_backdrop_material.set_shader_parameter("atmosphere_tint", _backdrop_values.backdrop_tint)
		_backdrop_material.set_shader_parameter("sky_top", _backdrop_values.sky_top)
		_backdrop_material.set_shader_parameter("sky_horizon", _backdrop_values.sky_horizon)
		_backdrop_material.set_shader_parameter("ground_horizon", _backdrop_values.ground_horizon)
		_backdrop_material.set_shader_parameter("ground_bottom", _backdrop_values.ground_bottom)
		_backdrop_material.set_shader_parameter("cloud_offset", Time.get_ticks_msec()*0.000002)
		# Shader parameter writes do not emit Resource.changed automatically.
		# Notify the layered landscape once the complete clock palette is ready.
		_backdrop_material.emit_changed()


func _exit_tree() -> void:
	for light in _lantern_lights:
		if is_instance_valid(light):
			light.queue_free()
