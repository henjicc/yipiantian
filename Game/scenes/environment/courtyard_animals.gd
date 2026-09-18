extends Node3D
## Goal selection, safe routes, local yielding and distance-driven skeletal movement.
const Assets = preload("res://scenes/environment/courtyard_assets.gd")
const Space = preload("res://scenes/environment/animal_space.gd")
const Pose = preload("res://scenes/environment/bird_pose.gd")
const PROFILES := {
	"duck": {"speed": .32, "radius": .30, "draft": .20, "turn": 1.8, "pause": Vector2(2.5, 7.0), "range": 6.0},
	"goose": {"speed": .27, "radius": .38, "draft": .29, "turn": 1.5, "pause": Vector2(3.0, 8.0), "range": 6.5},
	"hen": {"speed": .23, "radius": .20, "draft": 0.0, "turn": 2.8, "pause": Vector2(2.0, 5.0), "range": 4.0},
}
var water := Space.new()
var yard := Space.new()
var birds: Array[Dictionary] = []
var _swimmers: Array[Dictionary] = []
var _hens: Array[Node3D] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var ready_for_motion: bool = false

func _ready() -> void:
	_rng.randomize()
	_build.call_deferred()

func _build() -> void:
	rebuild_spaces()
	for i: int in 3: _spawn("duck", "LakeDuck%d" % (i + 1), Vector2(-10.7 + i * .8, 1.7 + i * .6), .88 if i == 2 else 1.0)
	for i: int in 2: _spawn("goose", "LakeGoose%d" % (i + 1), Vector2(1.5 + i * 1.4, 9.3), 1.0)
	for i: int in 2: _spawn("hen", "YardHen%d" % (i + 1), Vector2(-.7 + i * .8, 4.62), .88 + i * .12)
	ready_for_motion = true

func rebuild_spaces() -> void:
	water = Space.new()
	yard = Space.new()
	var environment: Node3D = get_parent()
	var rise: float=environment.plan.ground_height-.13
	yard.floor_level=environment.plan.ground_height
	water.configure(environment.plan.animal_areas.water, .46)
	var safe_plateaus: Array[PackedVector2Array] = Geometry2D.offset_polygon(environment.plan.plateau(), -.21)
	yard.configure(environment.plan.animal_areas.yard, .21, safe_plateaus[0])
	for child: Node in environment.get_children():
		if not child is Node3D or child == self: continue
		var path: String = child.scene_file_path
		var bank_role: String = child.get_meta("bank_role", "")
		if child.has_meta("fence_spans"):
			for span: Dictionary in child.get_meta("fence_spans"):
				var a := Vector2(span.a.x,span.a.z)
				var b := Vector2(span.b.x,span.b.z)
				var side := Vector2(-(b-a).y,(b-a).x).normalized()*.064
				yard.block(PackedVector2Array([a-side,b-side,b+side,a+side]))
			continue
		if child.name == "NeighborIslets":
			for island: Node3D in child.waterline_sources(): water.block(Space.footprint(island, -.55, .55, false))
		if not bank_role.is_empty():
			water.block(Space.footprint(child, -.35, .16))
		elif path.contains("stone_") or child.name == "CoveredBoat" or String(child.name).begins_with("Lotus"):
			water.block(Space.footprint(child, -.55, .55))
		if bank_role == "main" or path.contains("stone_"): yard.add_floor(child)
		if child.name in ["WaterSurface", "GroundCover", "DistantLandscape", "NeighborIslets", "ContactShading", "DecorationSlots", "OsmanthusLeaves"]: continue
		if not bank_role.is_empty() or String(child.name).begins_with("BankGrass"): continue
		if child.name == "LivingDetails":
			for prop: Node in child.get_children():
				if prop is Node3D: yard.block(Space.footprint(prop, .19+rise, .70+rise))
		else: yard.block(Space.footprint(child, .23+rise, .70+rise))
	var farm: Node3D = environment.get_parent().get_node_or_null("Farm")
	if farm != null:
		for field: Node3D in farm.fields:
			var polygon := PackedVector2Array()
			var half: Vector2 = field.get_meta("field_size")*.5+Vector2(.02,.035)
			for corner: Vector2 in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
				var p: Vector3 = field.to_global(Vector3(corner.x, 0, corner.y))
				polygon.append(Vector2(p.x, p.z))
			yard.block(polygon)
	water.bake()
	yard.bake()
	for p: Vector2 in environment.plan.animal_rest.water: water.resting.append(water.nearest(p))
	for p: Vector2 in environment.plan.animal_rest.yard: yard.resting.append(yard.nearest(p))
	for entry: Dictionary in birds:
		entry.space = yard if entry.kind == "hen" else water
		entry.pose.ground = entry.space.ground_height
		entry.route = PackedVector2Array()
		entry.state = "observe"
		entry.timer = 0.0

func _spawn(kind: String, label: String, start: Vector2, size: float) -> void:
	var space: RefCounted = yard if kind == "hen" else water
	var p: Vector2 = space.nearest(start)
	var bird: Node3D = Assets.place(self, kind, Vector3(p.x, space.ground_height(p) if kind == "hen" else -.25 - (.20 if kind == "duck" else .29), p.y), 0, size)
	bird.name = label
	bird.set_meta("species", kind)
	var pose := Pose.new()
	pose.configure(bird, kind)
	pose.ground = space.ground_height
	var entry: Dictionary = {"node": bird, "kind": kind, "space": space, "pose": pose, "position": p,
		"velocity": Vector2.ZERO, "heading": 0.0, "speed": PROFILES[kind].speed,
		"radius": PROFILES[kind].radius, "buddy": null, "follow_time": 0.0, "repath": 0.0,
		"state": "observe", "timer": _rng.randf_range(.5, 3.0), "route": PackedVector2Array(),
		"waypoint": 0, "stuck": 0.0, "phase": _rng.randf_range(0, TAU), "wake_strength": 0.0,
		"wake": null if kind == "hen" else _wake(.32 if kind == "duck" else .43), "recoveries": 0}
	birds.append(entry)
	if kind == "hen": _hens.append(bird)
	else: _swimmers.append(entry)

func _choose(entry: Dictionary) -> void:
	var space: RefCounted = entry.space
	var start: Vector2 = entry.position
	for attempt: int in 16:
		entry.buddy = null
		var target: Vector2
		var pick: float = _rng.randf()
		if pick < .16:
			target = space.resting[_rng.randi_range(0, space.resting.size() - 1)]
		elif pick < .40 and entry.kind != "hen":
			var companion: Dictionary = _swimmers[_rng.randi_range(0, _swimmers.size() - 1)]
			if companion == entry: continue
			entry.buddy = companion.node
			target = companion.position + Vector2.from_angle(_rng.randf_range(0, TAU)) * _rng.randf_range(1.0, 1.8)
		else:
			target = start + Vector2.from_angle(_rng.randf_range(0, TAU)) * _rng.randf_range(1.1, PROFILES[entry.kind].range)
		target = space.nearest(target)
		if start.distance_to(target) < .7: continue
		var route: PackedVector2Array = space.path(start, target)
		if route.is_empty(): continue
		entry.route = route
		entry.waypoint = 0
		entry.state = "walk" if entry.kind == "hen" else "swim"
		entry.timer = 0.0
		entry.stuck = 0.0
		entry.follow_time = _rng.randf_range(10.0, 20.0)
		entry.repath = 2.0
		return
	_idle(entry)

func _idle(entry: Dictionary) -> void:
	var choices: Array = ["rest", "observe", "peck", "preen"] if entry.kind == "hen" else ["rest", "probe", "preen", "observe"]
	entry.state = choices[_rng.randi_range(0, choices.size() - 1)]
	var pause: Vector2 = PROFILES[entry.kind].pause
	entry.timer = _rng.randf_range(pause.x, pause.y)
	entry.route = PackedVector2Array()
	entry.stuck = 0.0
	entry.buddy = null

func _wake(radius: float) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in 2:
		var r: float = radius + ring*.15
		for i: int in 30:
			var a: float = lerpf(-1.35,1.35,i/30.0)
			var b: float = lerpf(-1.35,1.35,(i+1)/30.0)
			for p: Vector2 in [Vector2(a,r),Vector2(b,r+.007),Vector2(b,r),Vector2(a,r),Vector2(a,r+.007),Vector2(b,r+.007)]:
				surface.set_uv(Vector2(float(ring)/2.0,(p.x+1.35)/2.7))
				surface.add_vertex(Vector3(sin(p.x)*p.y,0,-cos(p.x)*p.y*.6))
	surface.generate_normals()
	var wake := MeshInstance3D.new()
	wake.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/environment/bird_wake.gdshader")
	wake.material_override = material
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wake)
	return wake

func _process(delta: float) -> void:
	if not ready_for_motion: return
	var remaining: float = minf(delta, .15)
	while remaining > 0.0:
		var step: float = minf(remaining, 1.0 / 30.0)
		_time += step
		for entry: Dictionary in birds: _advance(entry, step)
		remaining -= step

func _advance(entry: Dictionary, delta: float) -> void:
	var p: Vector2 = entry.position
	var desired := Vector2.ZERO
	var route_velocity := Vector2.ZERO
	var moving: bool = entry.state in ["walk", "swim"]
	if moving and entry.buddy != null:
		entry.follow_time -= delta
		entry.repath -= delta
		if entry.follow_time <= 0.0: entry.buddy = null
		elif entry.repath <= 0.0:
			entry.repath = 2.0
			var companion: Node3D = entry.buddy
			var companion_heading: float = companion.rotation.y - (PI if companion.get_meta("species") == "goose" else 0.0)
			var behind: Vector3 = companion.position - Vector3(sin(companion_heading), 0, cos(companion_heading)) * 1.2
			var route: PackedVector2Array = entry.space.path(p, Vector2(behind.x, behind.z))
			if not route.is_empty():
				entry.route = route
				entry.waypoint = 0
	if moving:
		var route: PackedVector2Array = entry.route
		while entry.waypoint < route.size():
			var can_turn: bool = entry.waypoint + 1 >= route.size() or entry.space.clear_segment(p, route[entry.waypoint + 1])
			var close: bool = p.distance_to(route[entry.waypoint]) < .025 and can_turn
			var shortcut: bool = entry.waypoint + 1 < route.size() and p.distance_to(route[entry.waypoint]) < .16 and can_turn
			if not close and not shortcut: break
			entry.waypoint += 1
		if entry.waypoint >= route.size(): _idle(entry)
		else:
			var offset: Vector2 = route[entry.waypoint] - p
			var arrival: float = clampf(offset.length() / .32, .16, 1.0) if entry.waypoint == route.size() - 1 else 1.0
			desired = offset.normalized() * entry.speed * arrival
			route_velocity = desired
	else:
		entry.timer -= delta
		if entry.timer <= 0: _choose(entry)
	for other: Dictionary in birds:
		if other == entry or other.space != entry.space: continue
		var away: Vector2 = p - other.position
		var safe: float = entry.radius + other.radius + .12
		if away.length() < safe + .5 and away.length() > .001:
			var urgency: float = 1.0 - smoothstep(safe, safe + .5, away.length())
			desired += away.normalized() * urgency * entry.speed
			if moving and urgency > .1: desired += Vector2(-away.y, away.x).normalized() * .09
	var velocity: Vector2 = (entry.velocity as Vector2).move_toward(desired.limit_length(entry.speed), delta * .65)
	if velocity.length() > .015:
		var target_heading: float = atan2(velocity.x, velocity.y)
		entry.heading = rotate_toward(entry.heading, target_heading, delta * PROFILES[entry.kind].turn)
		velocity *= maxf(0.0, cos(angle_difference(entry.heading, target_heading)))
	var next: Vector2 = p + velocity * delta
	if moving and entry.waypoint < entry.route.size() and absf(velocity.cross(route_velocity))>.0001:
		# Separation and turn inertia may push a safe route around the wrong side
		# of a polygon tip. Keep sight of the next corner instead of waiting until
		# the following frame is pinned against it.
		var corner: Vector2 = entry.route[entry.waypoint]
		if entry.space.clear_segment(p,corner) and not entry.space.clear_segment(next,corner):
			velocity = route_velocity
			next = p+velocity*delta
	var safe_step: bool = entry.space.clear_segment(p, next)
	if not safe_step and not route_velocity.is_zero_approx():
		# Inertia/separation must not pin a bird against the inside of a turn.
		velocity = route_velocity
		next = p + velocity * delta
		safe_step = entry.space.clear_segment(p, next)
	for other: Dictionary in birds:
		if other == entry or other.space != entry.space: continue
		if next.distance_to(other.position) < entry.radius + other.radius and next.distance_to(other.position) < p.distance_to(other.position): safe_step = false
	if not safe_step:
		velocity = Vector2.ZERO
		next = p
	entry.velocity = velocity
	entry.position = next
	var distance: float = next.distance_to(p)
	if moving:
		entry.stuck = entry.stuck + delta if distance < .001 * delta else 0.0
		if entry.stuck > 2.5:
			entry.recoveries += 1
			_choose(entry)
	var bird: Node3D = entry.node
	bird.position.x=next.x
	bird.position.z=next.y
	bird.rotation.y = entry.heading + (PI if entry.kind == "goose" else 0.0)
	var height: float = entry.pose.support_height() if entry.kind == "hen" else -.25 - PROFILES[entry.kind].draft * bird.scale.x
	if entry.kind != "hen": height += sin(_time * 1.3 + entry.phase) * .007
	bird.position.y=move_toward(bird.position.y,height,delta*(.8 if entry.kind=="hen" else .3))
	entry.pose.update(delta, distance, velocity.length(), entry.state, _time + entry.phase)
	if entry.wake != null:
		entry.wake_strength = move_toward(entry.wake_strength, clampf(velocity.length() / entry.speed, 0, 1), delta * 1.4)
		entry.wake.position = Vector3(next.x, -.235, next.y)
		entry.wake.rotation.y = entry.heading
		entry.wake.material_override.set_shader_parameter("strength", entry.wake_strength)
