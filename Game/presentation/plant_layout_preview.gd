extends Node3D
const Plants=preload("res://layout/plantings.gd")
const Display=preload("res://presentation/player_plants.gd")
const Space=preload("res://scenes/environment/animal_space.gd")
const IslandSpace=preload("res://layout/island_space.gd")
var main: Node3D
var environment: Node3D
var display: Node3D
var message: String=""
var _original: Node3D
var _obstacles: Dictionary={}
var _index:=IslandSpace.new()
var _banks: Array[PackedVector2Array]=[]
var _accepted: bool=false
var _original_shore: Node3D
var _shore: Node3D
var _shown: Array=[]

func configure(scene: Node3D) -> void:
	main=scene;environment=main.get_node("Environment");_original=environment.get_node("PlayerPlants")
	_banks=environment.plan.water_banks()
	_obstacles=environment.layout_obstacles.duplicate(true)
	for key: String in _obstacles.keys():
		if key.begins_with("player_plant_"): _obstacles.erase(key)
	for node: Node3D in environment._shore_sources:
		if node.has_meta("bank_role"): continue
		_obstacles["water_%d"%node.get_instance_id()]=Space.cached_footprint(node,-.55,.55)
	_obstacles["bridge"]=Space.cached_footprint(environment.get_bridge(),environment.plan.ground_height-.08,environment.plan.ground_height+.75)
	_obstacles["boat"]=Space.cached_footprint(environment.get_node("CoveredBoat"),-.55,.65)
	_obstacles.merge(main.decoration_layout.ground_footprints())
	for key: String in _obstacles: _index.add(key,_obstacles[key])
	display=Display.new();add_child(display);display.low_detail=main.focus_detail._quality=="low"
	_original_shore=environment.get_node_or_null("NewShorePlants")
	if is_instance_valid(_original_shore): _original_shore.hide()
	_original.hide()

func entry_issue(entry: Dictionary, plan: RefCounted, check_animals: bool=true) -> String:
	var issue: String=Plants.habitat_issue(entry,plan,_banks)
	if not issue.is_empty(): return issue
	var polygon: PackedVector2Array=Plants.footprint(entry)
	if not _index.collisions(polygon).is_empty(): return "请避开景物、桥头和码头。"
	for route: PackedVector3Array in environment.plan.paths:
		for i: int in range(1,route.size()):
			var a:=Vector2(route[i-1].x,route[i-1].z);var b:=Vector2(route[i].x,route[i].z)
			var side:=Vector2(-(b-a).y,(b-a).x).normalized()*.34
			if IslandSpace.overlaps(polygon,PackedVector2Array([a-side,b-side,b+side,a+side])): return "请为道路留出空间。"
	if check_animals:
		for bird: Dictionary in environment.get_node("CourtyardAnimals").birds:
			for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon,bird.radius+.15):
				if Geometry2D.is_point_in_polygon(bird.position,expanded): return "这里有动物，请等它走开再布置。"
	return ""

func update(plan: RefCounted) -> void:
	display.update(plan.plants);message=""
	environment.fit_player_dressing(plan)
	if is_instance_valid(_original_shore) and (_shown!=plan.plants or not is_instance_valid(_shore)):
		if is_instance_valid(_shore): _shore.free()
		_shore=preload("res://presentation/shore_dressing.gd").plants(plan);add_child(_shore)
	_shown=plan.plants.duplicate(true)
	for entry: Dictionary in plan.plants:
		if entry in environment.plan.plants: continue
		message=entry_issue(entry,plan)
		if not message.is_empty(): break
		for other: Dictionary in plan.plants:
			if other.id==entry.id: continue
			var gap: float=.32 if entry.kind=="trapa" and other.kind=="trapa" else .5
			if Plants.position(entry).distance_to(Plants.position(other))<gap-.001:
				message="这里已有手植植物，请留出一点间距。";return
	if not message.is_empty(): return
	var animals: Node3D=environment.get_node("CourtyardAnimals")
	var added: Array[PackedVector2Array]=[]
	for entry: Dictionary in plan.plants:
		if entry not in environment.plan.plants: added.append(Plants.footprint(entry))
	if not plan.construction.bridge.is_empty():
		var shapes: Array[PackedVector2Array]=[]
		for child: Node in environment.get_children():
			if child is Node3D and child.name!="PlayerPlants": shapes.append_array(animals.water_shapes(child,plan))
		shapes.append_array(Plants.footprints(plan.plants).values())
		message=preload("res://layout/bridge_passage.gd").water_issue(plan,shapes)
		if not message.is_empty(): return
	for kind: String in ["duck","goose"]:
		message=preload("res://layout/flock_layout.gd").added_obstacle_issue(plan,kind,animals.water,added)
		if not message.is_empty(): return

func accept(plan: RefCounted) -> void:
	_accepted=true;environment.remove_child(_original);_original.queue_free()
	display.reparent(environment);display.name="PlayerPlants"
	if is_instance_valid(_original_shore):
		environment.remove_child(_original_shore);_original_shore.queue_free()
		_shore.reparent(environment);_shore.name="NewShorePlants"
	for key: String in environment.layout_obstacles.keys():
		if key.begins_with("player_plant_"): environment.layout_obstacles.erase(key)
	environment.layout_obstacles.merge(Plants.footprints(plan.plants))
	plan.paths=environment.plan.paths.duplicate();plan.garden_fences=environment.plan.garden_fences.duplicate(true);plan.fences=environment.plan.fences.duplicate(true)
	environment.plan=plan;environment.get_node("LivingDetails").plan=plan;main.courtyard_plan=plan;main.farm.plan=plan
	environment.fit_player_dressing(plan,true)

func _exit_tree() -> void:
	if not _accepted:
		if is_instance_valid(_original): _original.show()
		if is_instance_valid(_original_shore): _original_shore.show()
		if is_instance_valid(environment): environment.fit_player_dressing(environment.plan)
