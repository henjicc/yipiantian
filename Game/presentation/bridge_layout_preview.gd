extends Node3D
## Local bridge assembly; the private route result is adopted only after saving.
signal checked
const Plan=preload("res://layout/courtyard_plan.gd")
const Construction=preload("res://layout/island_construction.gd")
const Structures=preload("res://layout/garden_structures.gd")
const Space=preload("res://scenes/environment/animal_space.gd")
const IslandSpace=preload("res://layout/island_space.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
const Cover=preload("res://scenes/environment/ground_cover.gd")
const Contacts=preload("res://presentation/contact_shading.gd")
const Fence=preload("res://layout/fence_geometry.gd")
var main: Node3D
var environment: Node3D
var structure: Node3D
var contacts: Node3D
var core: Node3D
var expansion: Node3D
var paths: Node3D
var fence: Node3D
var pending: bool=false
var message: String=""
var validated: RefCounted
var routes: RefCounted
var footprint: PackedVector2Array
var _source: Node3D
var _source_footprint: PackedVector2Array
var _water_footprint: PackedVector2Array
var _hidden: Array[Node3D]=[]
var _dressing: Array[Dictionary]=[]
var _authored_contacts: Array[String]=["YardJarCluster"]
var _obstacles: Dictionary={}
var _wanted: Dictionary={}
var _working: Dictionary={}
var _worker: Thread
var _due: int=0
var _retiring: bool=false
var _restored: bool=false
var _accepted: bool=false

func configure(scene: Node3D) -> void:
	main=scene;environment=main.get_node("Environment");_source=environment.get_bridge()
	for child: Node in environment.get_children():
		if child.has_meta("bridge_dressing_stone"):
			_dressing.append({"node":child,"visible":child.visible,"footprint":Space.cached_footprint(child,environment.plan.ground_height+.10,environment.plan.ground_height+.62)})
		elif String(child.name).begins_with("BankReeds"): _authored_contacts.append(String(child.name))
	if environment.has_meta("authored_bridge_footprint"):
		_source_footprint=environment.get_meta("authored_bridge_footprint")
	elif environment.plan.construction.bridge.is_empty():
		_source_footprint=Space.cached_footprint(_source,environment.plan.ground_height-.08,environment.plan.ground_height+.75)
	else:
		var authored: Node3D=load("res://art/environment/modules/stone_bridge.glb").instantiate()
		authored.position=environment.plan.anchors.bridge;authored.rotation.y=deg_to_rad(environment.plan.angles.bridge)
		authored.hide();add_child(authored)
		_source_footprint=Space.footprint(authored,environment.plan.ground_height-.08,environment.plan.ground_height+.75,false)
		authored.free()
	environment.set_meta("authored_bridge_footprint",_source_footprint)
	core=Cover.new();add_child(core);core.copy_tiles(environment.get_node("GroundCover/CoreGrass"))
	expansion=Cover.new();add_child(expansion);expansion.copy_tiles(environment.get_node("ExpansionGrass"))
	for node: Node3D in [_source,environment.get_node("BridgeContacts"),environment.get_node("GroundCover/CoreGrass"),environment.get_node("ExpansionGrass")]: _hide(node)

func _hide(node: Node3D) -> void:
	if node.visible: _hidden.append(node);node.hide()

func update(plan: RefCounted) -> void:
	if plan.snapshot()==_wanted: return
	_wanted=plan.snapshot();validated=null;routes=null
	for node: Node in [structure,contacts]:
		if is_instance_valid(node): node.free()
	if plan.construction.bridge.is_empty():
		structure=load("res://art/environment/modules/stone_bridge.glb").instantiate()
		structure.position=plan.anchors.bridge;structure.rotation.y=deg_to_rad(plan.angles.bridge)
		environment._apply_pigment(structure,"stone_bridge")
	else: structure=Structures.bridge(plan)
	add_child(structure)
	footprint=Space.cached_footprint(structure,plan.ground_height-.08,plan.ground_height+.75)
	_water_footprint=Space.cached_footprint(structure,-.55,.55) if plan.construction.bridge.is_empty() else PackedVector2Array()
	contacts=Contacts.new();add_child(contacts)
	var end: Vector3=Construction.bridge_points(plan)[1]
	contacts.configure_bounds(plan.land_bounds().expand(Vector2(end.x,end.z)).grow(.6))
	contacts.collect(structure,[plan.ground_height+.002])
	_obstacles=environment.layout_obstacles.duplicate(true);_obstacles.erase(String(_source.name))
	for entry: Dictionary in _dressing:
		entry.node.visible=not IslandSpace.overlaps(footprint,entry.footprint) and not entry.node.get_meta("player_dressing_hidden",false)
		_obstacles.erase(String(entry.node.name))
		if entry.node.visible: _obstacles[String(entry.node.name)]=entry.footprint
	_obstacles.merge(main.decoration_layout.ground_footprints())
	message=_placement_issue(plan)
	_obstacles[String(structure.name)]=footprint
	var before: PackedVector2Array=core._exclusions[Cover.BRIDGE_EXCLUSION]
	core._exclusions[Cover.BRIDGE_EXCLUSION]=footprint;expansion._exclusions[Cover.BRIDGE_EXCLUSION]=footprint
	plan.paths=environment.plan.paths.duplicate()
	var changed: Dictionary=Cover.grass_cells([before,footprint])
	core.update_tiles(plan,false,changed);expansion.update_tiles(plan,true,changed)
	pending=message.is_empty();_due=Time.get_ticks_msec()+120;checked.emit()

func _placement_issue(plan: RefCounted) -> String:
	var issue: String=Construction.bridge_issue(plan)
	if not issue.is_empty(): return issue
	for key: String in _obstacles:
		for overlap: PackedVector2Array in Geometry2D.intersect_polygons(footprint,_obstacles[key]):
			# The authored stone bridge meets bank reeds and the nearby jar cluster.
			# Retain only that envelope; player props are never exempted.
			if key in _authored_contacts and IslandSpace.supported(overlap,_source_footprint): continue
			return "桥梁碰到了景物或摆件，请调整桥头或宽度。"
	for i: int in plan.fields.size():
		if IslandSpace.overlaps(footprint,plan.field_polygon(i,.12)): return "请为田地留出空间。"
	return animal_issue()

func animal_issue() -> String:
	var issue: String=main.decoration_layout._animal_issue(footprint)
	if not issue.is_empty(): return issue
	for bird: Dictionary in environment.get_node("CourtyardAnimals").birds:
		if bird.kind=="hen": continue
		if not _water_footprint.is_empty():
			for polygon: PackedVector2Array in Geometry2D.offset_polygon(_water_footprint,bird.radius):
				if Geometry2D.is_point_in_polygon(bird.position,polygon): return "水边有动物，请等它游开再调整。"
		for point: Vector2 in structure.get_meta("bridge_supports",PackedVector2Array()):
			if point.distance_to(bird.position)<bird.radius+.10: return "桥柱旁有动物，请等它游开再调整。"
	var additions: Array[PackedVector2Array]=[]
	if not _water_footprint.is_empty(): additions.append(_water_footprint)
	for point: Vector2 in structure.get_meta("bridge_supports",PackedVector2Array()): additions.append(IslandSpace.rectangle(point-Vector2.ONE*.055,Vector2.ONE*.11))
	for kind: String in ["duck","goose"]:
		issue=preload("res://layout/flock_layout.gd").added_obstacle_issue(Plan.from_snapshot(_wanted),kind,environment.get_node("CourtyardAnimals").water,additions)
		if not issue.is_empty(): return issue

	return ""

static func _build(snapshot: Dictionary, obstacles: Dictionary, levels: Dictionary, origin: Vector2, extent: Vector2) -> Dictionary:
	var plan: RefCounted=Plan.from_snapshot(snapshot)
	var circulation:=Circulation.new();circulation.build(plan,obstacles)
	return {"plan":plan,"routes":circulation,"contacts":Contacts.paint_levels(levels,origin,extent)}

func _process(_delta: float) -> void:
	if _retiring:
		if _worker!=null:
			if _worker.is_alive(): return
			_worker.wait_to_finish();_worker=null
		queue_free();return
	if _worker!=null:
		if _worker.is_alive(): return
		var result: Dictionary=_worker.wait_to_finish();_worker=null
		if _working==_wanted and pending:
			pending=false
			if result.routes.issues.is_empty():
				validated=result.plan;routes=result.routes;contacts.apply_pixels(result.contacts);_show_ground(validated)
			else: message=result.routes.issues[-1] if result.routes.issues[-1].begins_with("鸡群") else "这里会挡住通路，请为屋前、田边和桥头留出空间。"
			checked.emit()
	if not pending or _worker!=null or Time.get_ticks_msec()<_due: return
	_working=_wanted.duplicate(true);_worker=Thread.new()
	var error: Error=_worker.start(_build.bind(_working,_obstacles.duplicate(true),contacts._levels.duplicate(true),contacts._origin,contacts._extent))
	if error!=OK:
		_worker=null;pending=false;message="通路检查未能启动，请重新调整后再试。"
		push_error("Bridge route worker: %d"%error);checked.emit()

func _show_ground(plan: RefCounted) -> void:
	_hide(environment.get_node("GardenPaths"))
	for node: Node in environment.get_children():
		if node is Node3D and node.has_meta("fence_spans"): _hide(node)
	for node: Node in [paths,fence]:
		if is_instance_valid(node): node.free()
	paths=environment.make_paths(plan);add_child(paths)
	fence=Fence.build(plan.fences,plan.fence_style);add_child(fence)
	core.update_tiles(plan,false);expansion.update_expansion(plan)

func accept(plan: RefCounted) -> void:
	_accepted=true
	main.focus_detail.replace_structure(_source,structure)
	environment._contact_sources.erase(_source);environment._shore_sources.erase(_source)
	environment.remove_child(_source);_source.queue_free();structure.reparent(environment)
	environment._contact_sources.append(structure);environment._shore_sources.append(structure)
	for entry: Dictionary in _dressing:
		entry.node.set_meta("bridge_dressing_hidden",IslandSpace.overlaps(footprint,entry.footprint))
		environment._shore_sources.erase(entry.node)
		if entry.node.visible: environment._shore_sources.append(entry.node)
	for pair: Array in [[contacts,environment,"BridgeContacts"],[core,environment.get_node("GroundCover"),"CoreGrass"],[expansion,environment,"ExpansionGrass"],[paths,environment,"GardenPaths"]]:
		var old: Node=pair[1].get_node(pair[2]);old.get_parent().remove_child(old);old.queue_free()
		pair[0].reparent(pair[1]);pair[0].name=pair[2]
	for node: Node in environment.get_children():
		if node.has_meta("fence_spans"):
			environment._contact_sources.erase(node);environment.remove_child(node);node.queue_free()
	fence.reparent(environment);environment._contact_sources.append(fence)
	environment.layout_obstacles=_obstacles.duplicate(true)
	for key: String in environment.layout_obstacles.keys():
		if key.begins_with("decoration_"): environment.layout_obstacles.erase(key)
	environment.plan=plan;environment.circulation=routes;environment.get_node("LivingDetails").plan=plan
	main.courtyard_plan=plan;main.farm.plan=plan
	main.decoration_layout._collect_environment_meshes(structure)
	_hidden.clear()

func retire() -> void:
	_retiring=true;pending=false;hide();_restore()
	if _worker==null: queue_free()

func _restore() -> void:
	if _accepted or _restored: return
	_restored=true
	for entry: Dictionary in _dressing:
		if is_instance_valid(entry.node): entry.node.visible=entry.visible
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()

func _exit_tree() -> void:
	if _worker!=null and _worker.is_started(): _worker.wait_to_finish()
	_restore()
