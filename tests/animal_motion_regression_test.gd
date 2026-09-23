extends SceneTree
const Animals = preload("res://scenes/environment/courtyard_animals.gd")
const Space = preload("res://scenes/environment/animal_space.gd")

class PoseProbe extends RefCounted:
	var phase: float = 0.0
	var advances: int = 0
	var presentations: int = 0
	var elapsed: float = 0.0
	func advance(delta: float, _distance: float, _speed: float, _action: String) -> void:
		advances += 1
		elapsed += delta
	func apply_pose(_action: String, _time: float) -> void:
		presentations += 1

func _initialize() -> void:
	var space := Space.new()
	space.configure(Rect2(-4,-4,8,8),0.0)
	space.block(PackedVector2Array([Vector2(.031,-.02),Vector2(.041,0),Vector2(.031,.02)]))
	assert(space.contains(Vector2.ZERO) and space.contains(Vector2(.144,0)))
	assert(not space.clear_segment(Vector2.ZERO,Vector2(.144,0)), "A narrow polygon tip must block a planned segment")
	assert(space.clear_segment(Vector2(0,.1),Vector2(.144,.1)), "Unobstructed nearby motion remains possible")
	var yard := Space.new()
	yard.configure(Rect2(-1,-1,2,2),0.0,PackedVector2Array([
		Vector2(-1,-1),Vector2(.031,-1),Vector2(.031,.01),Vector2(.041,.01),Vector2(.041,-1),
		Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]))
	assert(yard.contains(Vector2.ZERO) and yard.contains(Vector2(.144,0)))
	assert(not yard.clear_segment(Vector2.ZERO,Vector2(.144,0)), "A narrow gap in walkable ground must block the route")
	var open_space := Space.new()
	open_space.configure(Rect2(-4,-4,8,8),0.0)
	for fps: int in [30,60,120]:
		var animals := Animals.new()
		var bird := Node3D.new()
		bird.name = "LakeDuck1"
		var entry: Dictionary = {"node":bird,"kind":"duck","space":open_space,"pose":PoseProbe.new(),
			"position":Vector2.ZERO,"velocity":Vector2.ZERO,"heading":PI,"speed":.32,"radius":.30,
			"buddy":null,"state":"swim","route":PackedVector2Array([Vector2(0,2)]),"waypoint":0,
			"stuck":0.0,"progress_corner":Vector2.INF,"progress_distance":INF,"phase":0.0,"wake":null}
		animals.birds.append(entry)
		animals._advance(entry,1.0/fps)
		assert(absf(angle_difference(PI,entry.heading)) > 0.001, "Bird must turn from rest at %d Hz" % fps)
		assert(entry.position.length() <= .32/fps + .000001)
		var other := Node3D.new()
		other.name = "LakeDuck2"
		var neighbor: Dictionary = {"node":other,"kind":"duck","position":Vector2(0,.65),"radius":.30}
		animals.birds.append(neighbor)
		animals._recover(entry)
		assert(entry.route.size() >= 2, "A detour keeps the original destination")
		assert(entry.position.distance_to(entry.route[0]) >= .5)
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(neighbor.position, entry.position, entry.route[0])
		assert(closest.distance_to(neighbor.position) >= .64, "The escape leg cannot cut through the blocking bird")
		assert(entry.route[-1].distance_to(Vector2(0,2)) < .2)
		animals.birds.erase(neighbor)
		animals.ready_for_motion = true
		for delta: float in [1.0 / 30.0 + .00001, .10001]:
			entry.pose.advances = 0
			entry.pose.presentations = 0
			entry.pose.elapsed = 0.0
			animals._process(delta)
			assert(entry.pose.advances > 1, "Collision integration retains bounded substeps")
			assert(is_equal_approx(entry.pose.elapsed, delta), "No animation time is lost")
			assert(entry.pose.presentations == 1, "Only the final pose is solved per visible frame")
		other.free()
		bird.free()
		animals.free()
	print("ANIMAL_MOTION_REGRESSION_PASS thin obstacle, 30/60/120 Hz turning and collision-free detour")
	quit()
