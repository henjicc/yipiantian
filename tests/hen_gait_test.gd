extends SceneTree
## Measure actual skinned beak movement, not just the target curve.
const Pose = preload("res://scenes/environment/bird_pose.gd")
const Gait = preload("res://scenes/environment/bird_gait.gd")
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for size: float in [.88, 1.0]:
		var bird: Node3D = load("res://art/environment/courtyard_life/hen_high.glb").instantiate()
		root.add_child(bird)
		bird.scale = Vector3.ONE * size
		var pose := Pose.new()
		pose.configure(bird,"hen")
		pose.ground = func(_p: Vector2) -> float: return 0.0
		for speed: float in [.10,.23]:
			pose.motion = 1.0
			pose.action = "walk"
			pose.phase = 0.0
			var hold_speed: float = 0.0
			var thrust_speed: float = 0.0
			var holds: int = 0
			var thrusts: int = 0
			var previous: Vector3 = pose.beak_world_position()
			for frame: int in 240:
				bird.position.z += speed / 60.0
				pose.update(1.0/60.0,speed/60.0,speed,"walk",frame/60.0)
				var beak: Vector3 = pose.beak_world_position()
				var step: float = fposmod(pose.phase*2.0,1.0)
				if frame > 10:
					if step > .35 and step < .90:
						hold_speed += absf(beak.z-previous.z)*60.0
						holds += 1
					elif step > .07 and step < .22:
						thrust_speed += (beak.z-previous.z)*60.0
						thrusts += 1
				previous = beak
				if not beak.is_finite(): failures.append("Nonfinite skinned beak")
			var hold_ratio: float = hold_speed/maxi(holds,1)/speed
			var thrust_ratio: float = thrust_speed/maxi(thrusts,1)/speed
			print("HEN_GAIT size=",size," speed=",speed," hold/body=",hold_ratio," thrust/body=",thrust_ratio)
			if hold_ratio > .40: failures.append("Head does not hold against body translation")
			if thrust_ratio < 2.0: failures.append("Missing quick forward thrust")
			var stopped_phase: float = pose.phase
			for frame: int in 60: pose.update(1.0/60.0,0.0,0.0,"rest",frame/60.0)
			if pose.phase != stopped_phase: failures.append("Step phase advances while stopped")
		bird.queue_free()
		await process_frame
	print("HEN_GAIT_PASS" if failures.is_empty() else "HEN_GAIT_FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
