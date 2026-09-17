extends GPUParticles3D
## A short visual cue after a successful empty -> planted state change.

func _ready() -> void:
	name = "PlantingSoilBurst"
	emitting = false
	one_shot = true
	amount = 12
	lifetime = .42
	explosiveness = 1.0
	local_coords = true
	visibility_aabb = AABB(Vector3(-.4,-.2,-.4),Vector3(.8,.7,.8))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 65.0
	motion.initial_velocity_min = .35
	motion.initial_velocity_max = .65
	motion.gravity = Vector3(0,-3.0,0)
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	motion.emission_ring_axis = Vector3.UP
	motion.emission_ring_inner_radius = .04
	motion.emission_ring_radius = .105
	motion.emission_ring_height = .01
	motion.scale_min = .65
	motion.scale_max = 1.25
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0,1))
	scale_curve.add_point(Vector2(.65,1))
	scale_curve.add_point(Vector2(1,0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	motion.scale_curve = scale_texture
	process_material = motion
	var crumb := SphereMesh.new()
	crumb.radius = .009
	crumb.height = .013
	crumb.radial_segments = 7
	crumb.rings = 3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("61503d")
	material.roughness = 1.0
	crumb.material = material
	draw_pass_1 = crumb
	finished.connect(queue_free)
	emitting = true
