extends SceneTree
const Atmosphere = preload("res://atmosphere/day_night.gd")

func _initialize() -> void:
	var previous: Dictionary = Atmosphere.sample_hour(12.0)
	for step: int in range(1,511):
		var sample: Dictionary = Atmosphere.sample_hour(12.0+step/60.0)
		assert(sample.elevation <= previous.elevation+0.00001, "Afternoon sun cannot rise again")
		assert(sample.azimuth <= previous.azimuth+0.00001, "Solar direction cannot reverse at dusk")
		if sample.elevation <= 0.0: assert(sample.sun_energy == 0.0)
		previous = sample
	assert(Atmosphere.sample_hour(0) == Atmosphere.sample_hour(24))
	for hour: float in Atmosphere.HOURS:
		var before: Dictionary = Atmosphere.sample_hour(hour-.001)
		var after: Dictionary = Atmosphere.sample_hour(hour+.001)
		for key: String in ["sun_energy","moon_energy","elevation","azimuth"]:
			assert(absf(before[key]-after[key]) < .001, "Light keys remain continuous")
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	var atmosphere := Atmosphere.new()
	root.add_child(sun)
	root.add_child(world)
	root.add_child(atmosphere)
	atmosphere.configure(sun,world)
	for hour: float in [12,16.5,18.5,20.5,0,6.5,12]:
		assert(atmosphere.set_preview_hour(hour))
		assert(sun.shadow_enabled)
		assert(not atmosphere._moon_fill.shadow_enabled, "Night fill cannot introduce a second moving cast shadow")
		if hour == 12: assert(atmosphere._moon_fill.light_energy == 0.0)
		if hour == 20.5: assert(sun.light_energy == 0.0 and atmosphere._moon_fill.light_energy > 0)
	atmosphere.free()
	world.free()
	sun.free()
	print("SOLAR_MOTION_PASS 510 afternoon samples and real day/night light nodes")
	quit()
