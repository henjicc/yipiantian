extends Node3D
const Gait = preload("res://scenes/environment/bird_gait.gd")
## Goal selection, safe routes, local yielding and distance-driven skeletal movement.
const Assets = preload("res://scenes/environment/courtyard_assets.gd")
const Passage=preload("res://layout/bridge_passage.gd")
const Space = preload("res://scenes/environment/animal_space.gd")
const Pose = preload("res://scenes/environment/bird_pose.gd")
const Interaction=preload("res://scenes/environment/bird_interaction.gd")
var interaction:=Interaction.new()
const PROFILES := {
	"duck": {"speed": .32, "radius": .30, "draft": .20, "turn": 1.8, "pause": Vector2(2.5, 7.0), "range": 6.0},
	"goose": {"speed": .27, "radius": .38, "draft": .29, "turn": 1.5, "pause": Vector2(3.0, 8.0), "range": 6.5},
	"hen": {"speed": .23, "radius": .20, "draft": 0.0, "turn": 2.8, "pause": Vector2(2.0, 5.0), "range": 4.0},
}
var water := Space.new()
var yard := Space.new()
const Flocks=preload("res://layout/flock_layout.gd")
var flock_spaces: Dictionary={}
var birds: Array[Dictionary] = []
var _swimmers: Array[Dictionary] = []
var _hens: Array[Node3D] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var ready_for_motion: bool = false
var water_ready: bool = false
var preview_kind: String=""
var yard_ready: bool=false
var _decorations: Dictionary={}
var decoration_rest := PackedVector2Array()
var _navigation_worker: Thread

func _exit_tree() -> void:
	if _navigation_worker!=null and _navigation_worker.is_started(): _navigation_worker.wait_to_finish()

static func _bake_spaces(water_space: RefCounted,yard_space: RefCounted,update_water: bool) -> void:
	if update_water: water_space.bake()
	yard_space.bake()

func set_decorations(instances: Dictionary) -> void:
	_decorations=instances.duplicate()
	if ready_for_motion or get_parent()._terrain_refreshing:
		get_parent().refresh_terrain(false)

func _ready() -> void:
	interaction.owner=self
	_rng.randomize()
	_build.call_deferred()

func _build() -> void:
	rebuild_spaces()
	for kind: String in Flocks.KINDS:
		var flock: Dictionary=get_parent().plan.construction.flocks[kind]
		var placed:=PackedVector2Array()
		for entry: Dictionary in birds:
			if (entry.kind=="hen")== (kind=="hen"): placed.append(entry.position)
		for i: int in int(flock.count):
			var point: Vector2=Flocks.separated_point(flock_spaces[kind],Flocks.start(kind,i,flock.area),placed,Flocks.SPECIES[kind].spacing)
			if not point.is_finite():
				push_error("No valid flock spawn: "+Flocks.id(kind,i));continue
			placed.append(point);_spawn(kind,Flocks.id(kind,i),point,Flocks.size(kind,i))
	ready_for_motion = true

static func water_shapes(node: Node3D, plan: RefCounted) -> Array[PackedVector2Array]:
	if node.get_meta("bridge_dressing_hidden",false) or node.get_meta("player_dressing_hidden",false): return []
	if node.has_meta("bridge_water_shapes"): return node.get_meta("bridge_water_shapes")
	if node.name=="PlayerPlants":
		var planted: Array[PackedVector2Array]=[];planted.assign(preload("res://layout/plantings.gd").footprints(plan.plants).values());return planted
	if node.name=="NeighborIslets":
		var islands: Array[PackedVector2Array]=[]
		for island: Node3D in node.waterline_sources(): islands.append(Space.cached_footprint(island,-.55,.55))
		return islands
	if node.has_meta("bank_role"): return [Space.cached_footprint(node,-.35,.16)]
	if node.scene_file_path.contains("stone_") or node.name=="CoveredBoat" or String(node.name).begins_with("Lotus"): return [Space.cached_footprint(node,-.55,.55)]
	return []

func rebuild_spaces(update_water: bool=true, progressive: bool=false) -> void:
	if update_water: water_ready=false;water = Space.new()
	yard_ready=false;yard = Space.new()
	var environment: Node3D = get_parent()
	var rise: float=environment.plan.ground_height-.13
	yard.floor_level=environment.plan.ground_height
	if update_water: water.configure(environment.plan.animal_areas.water, .46)
	var walkable: PackedVector2Array=Passage.outline(environment.plan,.21)
	yard.configure(Passage.bounds(environment.plan),.21,walkable)
	if walkable.is_empty():
		push_error("Bridge and banks have no connected walkable surface")
		yard.block(preload("res://layout/island_space.gd").rectangle(yard.bounds.position,yard.bounds.size))
	var slice: int=Time.get_ticks_usec()
	for child: Node in environment.get_children():
		if progressive and Time.get_ticks_usec()-slice>2000:
			await get_tree().process_frame
			slice=Time.get_ticks_usec()
		if not is_instance_valid(child): continue
		if not child is Node3D or child == self: continue
		if update_water:
			for polygon: PackedVector2Array in water_shapes(child,environment.plan): water.block(polygon)
		if child.has_meta("bridge_water_shapes"):
			if child.has_meta("bridge_seamed_deck"):
				yard.add_floor(child,false,Vector2(-INF,INF))
				yard.floor_seams.append(child.get_meta("bridge_seamed_deck"))
			else: yard.add_floor(child.get_node("Deck"),false,Vector2(-INF,INF))
			continue
		if child.name=="PlayerRoutes":
			yard.add_floor(child.get_node("Roads"),false)
			for key: String in environment.plan.route_footprints():
				if key.begins_with("player_fence_"): yard.block(environment.plan.route_footprints()[key])
			continue
		if child.name=="PlayerPlants": continue
		if child.get_meta("bridge_dressing_hidden",false) or child.get_meta("player_dressing_hidden",false): continue
		var path: String = child.scene_file_path
		var bank_role: String = child.get_meta("bank_role", "")

		if child.has_meta("garden_paths"):
			yard.add_floor(child,false)
			continue
		if child.has_meta("fence_spans"):
			for span: Dictionary in child.get_meta("fence_spans"):
				var a := Vector2(span.a.x,span.a.z)
				var b := Vector2(span.b.x,span.b.z)
				var side := Vector2(-(b-a).y,(b-a).x).normalized()*.064
				yard.block(PackedVector2Array([a-side,b-side,b+side,a+side]))
			continue
		if not bank_role.is_empty():
			var height: float=environment.plan.ground_height+child.position.y
			yard.add_floor(child,false,Vector2(height-.04,height+.11))
		elif path.contains("stone_"): yard.add_floor(child,false)
		if child.name in ["WaterSurface", "GroundCover", "ExpansionGrass", "NewShorePlants", "DistantLandscape", "NeighborIslets", "ContactShading", "DecorationSlots", "OsmanthusLeaves"]: continue
		if not bank_role.is_empty() or String(child.name).begins_with("BankGrass"): continue
		if child.name == "LivingDetails":
			for prop: Node in child.get_children():
				var replaced: bool=false
				for entry: Dictionary in environment.decoration_data.values():
					if environment.plan.DECORATION_SCENERY.get(entry.slot_id,"")==String(prop.name): replaced=true;break
				if prop is Node3D and not replaced: yard.block(Space.cached_footprint(prop, .19+rise, .70+rise))
		else: yard.block(Space.cached_footprint(child, .23+rise, .70+rise))
	var farm: Node3D = environment.get_parent().get_node_or_null("Farm")
	if farm != null:
		for field: Node3D in farm.fields:
			var polygon := PackedVector2Array()
			var half: Vector2 = field.get_meta("field_size")*.5+Vector2(.02,.035)
			for corner: Vector2 in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
				var p: Vector3 = field.to_global(Vector3(corner.x, 0, corner.y))
				polygon.append(Vector2(p.x, p.z))
			yard.block(polygon)
	for prop: Node3D in _decorations.values():
		if is_instance_valid(prop): yard.block(Space.cached_footprint(prop,.05+rise,1.3+rise))
	if progressive:
		# Birds remain paused; these private grids have one owner until joined.
		_navigation_worker=Thread.new()
		if _navigation_worker.start(_bake_spaces.bind(water,yard,update_water))==OK:
			while _navigation_worker.is_alive(): await get_tree().process_frame
			_navigation_worker.wait_to_finish()
		else:
			push_error("Terrain navigation worker could not start")
			_bake_spaces(water,yard,update_water)
		_navigation_worker=null
	else:
		if update_water: water.bake()
		yard.bake()
	decoration_rest.clear()
	for id: String in ["bench","flowerpot","tea_table","pot"]:
		if not _decorations.has(id): continue
		var prop: Node3D=_decorations[id]
		for direction: int in 8:
			var offset: Vector2=Vector2.from_angle(direction*TAU/8)*.85
			var world: Vector3=prop.to_global(Vector3(offset.x,0,offset.y))
			var point:=Vector2(world.x,world.z)
			var snapped: Vector2=yard.nearest(point)
			if snapped.distance_to(point)<.22 and not decoration_rest.has(snapped): decoration_rest.append(snapped)
	if update_water:
		for p: Vector2 in environment.plan.animal_rest.water: water.resting.append(water.nearest(p))
	for p: Vector2 in environment.plan.animal_rest.yard: yard.resting.append(yard.nearest(p))
	for kind: String in Flocks.KINDS:
		if not update_water and kind!="hen": continue
		var source: RefCounted=yard if kind=="hen" else water
		var area: Array=environment.plan.construction.flocks[kind].area.duplicate()
		flock_spaces[kind]=source
		if area.is_empty(): continue
		var captured: Dictionary=Space.capture(source)
		if progressive:
			_navigation_worker=Thread.new()
			if _navigation_worker.start(Space.build_region.bind(area,captured))==OK:
				while _navigation_worker.is_alive(): await get_tree().process_frame
				flock_spaces[kind]=_navigation_worker.wait_to_finish()
			else:
				push_error("Flock navigation worker could not start")
				flock_spaces[kind]=Space.build_region(area,captured)
			_navigation_worker=null
		else: flock_spaces[kind]=Space.build_region(area,captured)
	if update_water: water_ready=true
	yard_ready=true
	for entry: Dictionary in birds:
		if not update_water and entry.kind!="hen": continue
		interaction.cancel(entry.node.name)
		entry.space = flock_spaces[entry.kind]
		entry.pose.ground = entry.space.ground_height
		entry.route = PackedVector2Array()
		entry.state = "observe"
		entry.timer = 0.0
		entry.velocity=Vector2.ZERO
		entry.interest=Vector2.INF
		if not entry.space.contains(entry.position):
			var occupied:=PackedVector2Array()
			for other: Dictionary in birds:
				if other!=entry and (other.kind=="hen")== (entry.kind=="hen"): occupied.append(other.position)
			var point: Vector2=Flocks.separated_point(entry.space,entry.position,occupied,Flocks.SPECIES[entry.kind].spacing)
			if point.is_finite():
				entry.position=point;entry.node.position.x=point.x;entry.node.position.z=point.y
			else: push_error("Flock region has no separated relocation: "+String(entry.node.name))


func apply_flock(kind: String, space: RefCounted, profiles: Dictionary, models: Dictionary) -> void:
	interaction.profiles=profiles
	var changed_area: bool=flock_spaces[kind]!=space
	flock_spaces[kind]=space
	for entry: Dictionary in birds.duplicate():
		if entry.kind!=kind or models.has(String(entry.node.name)): continue
		interaction.cancel(entry.node.name)
		for other: Dictionary in birds:
			if other.buddy==entry.node: other.buddy=null
		birds.erase(entry);_swimmers.erase(entry);_hens.erase(entry.node)
		entry.node.queue_free()
		if is_instance_valid(entry.wake): entry.wake.queue_free()
	for id: String in models:
		var model: Node3D=models[id]
		var point:=Vector2(model.position.x,model.position.z)
		var entry: Dictionary=interaction.find(id)
		if entry.is_empty():
			_spawn(kind,id,point,model.scale.x,model)
			continue
		if not changed_area: continue
		interaction.cancel(id)
		entry.space=space;entry.pose.ground=space.ground_height
		entry.position=point;entry.node.position.x=point.x;entry.node.position.z=point.y
		entry.route=PackedVector2Array();entry.waypoint=0;entry.state="observe"
		entry.timer=0.0;entry.velocity=Vector2.ZERO;entry.interest=Vector2.INF;entry.buddy=null
		entry.wake_strength=0.0
		if is_instance_valid(entry.wake): entry.wake.hide()

func _spawn(kind: String, label: String, start: Vector2, size: float, model: Node3D=null) -> void:
	var space: RefCounted = flock_spaces[kind]
	var p: Vector2 = space.nearest(start)
	var bird: Node3D = model
	if bird==null: bird=Assets.place(self,kind,Vector3.ZERO,0,size)
	else: bird.reparent(self)
	bird.position=Vector3(p.x,space.ground_height(p) if kind=="hen" else -.25-PROFILES[kind].draft,p.y)
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
		"wake": null if kind == "hen" else _wake(.32 if kind == "duck" else .43), "recoveries": 0,"interest":Vector2.INF}
	birds.append(entry)
	if kind == "hen": _hens.append(bird)
	else: _swimmers.append(entry)

func _choose(entry: Dictionary) -> void:
	if interaction.retry(entry): return
	interaction.cancel(entry.node.name)
	var space: RefCounted = entry.space
	var start: Vector2 = entry.position
	for attempt: int in 16:
		entry.buddy = null
		entry.interest=Vector2.INF
		var target: Vector2
		var pick: float = _rng.randf()
		var familiar: int=interaction.profiles[String(entry.node.name)].visits
		if pick < .22+minf(familiar,5)*.025:
			target=interaction.rest_target(entry)
			entry.interest=target
		elif entry.kind=="hen" and pick<.50 and not decoration_rest.is_empty():
			target=decoration_rest[_rng.randi_range(0,decoration_rest.size()-1)]
			entry.interest=target
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
	if interaction.arrive(entry): return
	var choices: Array = ["rest", "observe", "peck", "preen"] if entry.kind == "hen" else ["rest", "probe", "preen", "observe"]
	entry.state = choices[_rng.randi_range(0, choices.size() - 1)]
	var pause: Vector2 = PROFILES[entry.kind].pause
	entry.timer = _rng.randf_range(pause.x, pause.y)
	if entry.position.distance_to(entry.interest)<.28:
		entry.state="rest"
		entry.timer=_rng.randf_range(7,13)
	entry.interest=Vector2.INF
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
		for entry: Dictionary in birds:
			if entry.kind==preview_kind: continue
			_advance(entry, step)
		remaining -= step

func _advance(entry: Dictionary, delta: float) -> void:
	interaction.advance(entry,delta)
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
			var pace: float = Gait.hen_pace(entry.pose.phase) if entry.kind == "hen" else Gait.pace(entry.kind, _time + entry.phase)
			desired = offset.normalized() * entry.speed * arrival * pace
			route_velocity = desired
	else:
		entry.timer -= delta
		if entry.timer <= 0: _choose(entry)
	for other: Dictionary in birds:
		if other == entry or (other.kind=="hen") != (entry.kind=="hen"): continue
		var away: Vector2 = p - other.position
		var safe: float = entry.radius + other.radius + .12
		if away.length() < safe + .5 and away.length() > .001:
			var urgency: float = 1.0 - smoothstep(safe, safe + .5, away.length())
			# Narrow passages may not fit the preferred social distance. Relax
			# that buffer at an edge, while the hard body collision below remains.
			var retreat: Vector2=p+away.normalized()*(safe+.5-away.length())
			if entry.kind=="hen" and not entry.space.clear_segment(p,retreat):
				urgency=1.0-smoothstep(entry.radius+other.radius,safe,away.length())
			desired += away.normalized() * urgency * entry.speed
			if moving and urgency > .1: desired += Vector2(-away.y, away.x).normalized() * .09
	var velocity: Vector2 = (entry.velocity as Vector2).move_toward(desired.limit_length(entry.speed), delta * (2.3 if entry.kind=="hen" else .65))
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
		if other == entry or (other.kind=="hen") != (entry.kind=="hen"): continue
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
