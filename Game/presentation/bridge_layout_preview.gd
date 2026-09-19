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
const Animals=preload("res://scenes/environment/courtyard_animals.gd")
const Passage=preload("res://layout/bridge_passage.gd")
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
var _hidden: Array[Node3D]=[]
var _dressing: Array[Dictionary]=[]
var _obstacles: Dictionary={}
var _base_water: Dictionary={}
var _water_obstacles: Dictionary={}
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
		if child is Node3D and child!=_source: _base_water[String(child.name)]=Animals.water_shapes(child,environment.plan)
		if child.has_meta("bridge_dressing_stone") or String(child.name).begins_with("BankReeds"):
			var ground: PackedVector2Array=environment.layout_obstacles.get(String(child.name),PackedVector2Array())
			if ground.is_empty(): ground=Space.cached_footprint(child,environment.plan.ground_height+.10,environment.plan.ground_height+.62)
			var water: PackedVector2Array=Space.cached_footprint(child,-.55,.55) if child.has_meta("bridge_dressing_stone") else PackedVector2Array()
			_dressing.append({"node":child,"visible":child.visible,"footprint":ground,"water":water})

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
		structure=Structures.authored_bridge(plan)
		environment._apply_pigment(structure,"stone_bridge")
	else: structure=Structures.bridge(plan)
	add_child(structure)
	footprint=Space.cached_footprint(structure,plan.ground_height-.08,plan.ground_height+.75)
	contacts=Contacts.new();add_child(contacts)
	var end: Vector3=Construction.bridge_points(plan)[1]
	contacts.configure_bounds(plan.land_bounds().expand(Vector2(end.x,end.z)).grow(.6))
	contacts.collect(structure,[plan.ground_height+.002])
	_obstacles=environment.layout_obstacles.duplicate(true);_obstacles.erase(String(_source.name))
	_water_obstacles=_base_water.duplicate(true)
	for entry: Dictionary in _dressing:
		entry.node.visible=not _hide_dressing(entry,plan) and not entry.node.get_meta("player_dressing_hidden",false)
		_obstacles.erase(String(entry.node.name))
		_water_obstacles.erase(String(entry.node.name))
		if entry.node.visible:
			_obstacles[String(entry.node.name)]=entry.footprint
			if entry.node.has_meta("bridge_dressing_stone"): _water_obstacles[String(entry.node.name)]=[entry.water]
	_obstacles.merge(main.decoration_layout.ground_footprints())
	_water_obstacles[String(structure.name)]=Animals.water_shapes(structure,plan)
	message=_placement_issue(plan)
	_obstacles[String(structure.name)]=footprint
	var before: PackedVector2Array=core._exclusions[Cover.BRIDGE_EXCLUSION]
	core._exclusions[Cover.BRIDGE_EXCLUSION]=footprint;expansion._exclusions[Cover.BRIDGE_EXCLUSION]=footprint
	plan.paths=environment.plan.paths.duplicate()
	var changed: Dictionary=Cover.grass_cells([before,footprint])
	core.update_tiles(plan,false,changed);expansion.update_tiles(plan,true,changed)
	pending=message.is_empty();_due=Time.get_ticks_msec()+120;checked.emit()

func _hide_dressing(entry: Dictionary, plan: RefCounted) -> bool:
	return Passage.dressing_overlap(plan,footprint,entry.footprint) or entry.node.get_meta("authored_bridge_path",false)

func _placement_issue(plan: RefCounted) -> String:
	var issue: String=Construction.bridge_issue(plan)
	if not issue.is_empty(): return issue
	for key: String in _obstacles:
		if key.begins_with("player_road_"): continue
		if IslandSpace.overlaps(footprint,_obstacles[key]): return "桥梁碰到了景物或摆件，请调整桥头或宽度。"
	for i: int in plan.fields.size():
		if IslandSpace.overlaps(footprint,plan.field_polygon(i,.12)): return "请为田地留出空间。"
	return animal_issue()

func animal_issue() -> String:
	var issue: String=main.decoration_layout._animal_issue(footprint)
	if not issue.is_empty(): return issue
	for bird: Dictionary in environment.get_node("CourtyardAnimals").birds:
		if bird.kind=="hen": continue
		for shape: PackedVector2Array in structure.get_meta("bridge_water_shapes",[]):
			for polygon: PackedVector2Array in Geometry2D.offset_polygon(shape,bird.radius):
				if Geometry2D.is_point_in_polygon(bird.position,polygon): return "桥下有动物，请等它游开再调整。"
	var additions: Array[PackedVector2Array]=[]
	additions.append_array(structure.get_meta("bridge_water_shapes",[]))
	var plan: RefCounted=Plan.from_snapshot(_wanted)
	var source: RefCounted=null
	for kind: String in ["duck","goose"]:
		var flock: Dictionary=plan.construction.flocks[kind]
		if flock.count==0 or flock.area.is_empty(): continue
		if source==null:
			# The region validator needs raw obstacles and clearance; it builds
			# its own grid. Free-ranging birds need only the checks above.
			source=Space.new();source.radius=Passage.WATER_RADIUS
			for key: String in _water_obstacles:
				if key==String(structure.name): continue
				for polygon: PackedVector2Array in _water_obstacles[key]: source.block(polygon)
		issue=preload("res://layout/flock_layout.gd").added_obstacle_issue(plan,kind,source,additions)
		if not issue.is_empty(): return issue

	return ""

static func _build(snapshot: Dictionary, obstacles: Dictionary, water_obstacles: Dictionary, levels: Dictionary, origin: Vector2, extent: Vector2) -> Dictionary:
	var plan: RefCounted=Plan.from_snapshot(snapshot)
	var circulation:=Circulation.new();circulation.build(plan,obstacles)
	var water_issue: String=""
	var polygons: Array[PackedVector2Array]=[]
	for shapes: Array in water_obstacles.values(): polygons.append_array(shapes)
	water_issue=Passage.water_issue(plan,polygons)
	return {"plan":plan,"routes":circulation,"water_issue":water_issue,"contacts":Contacts.paint_levels(levels,origin,extent)}

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
			if result.routes.issues.is_empty() and result.water_issue.is_empty():
				validated=result.plan;routes=result.routes;contacts.apply_pixels(result.contacts);_show_ground(validated)
			elif not result.water_issue.is_empty(): message=result.water_issue
			else:
				var last: String=result.routes.issues[-1]
				message=last if last.begins_with("鸡群") or last.begins_with("桥") or last.begins_with("对岸") else "这里会挡住通路，请为屋前、田边和桥头留出空间。"
			checked.emit()
	if not pending or _worker!=null or Time.get_ticks_msec()<_due: return
	_working=_wanted.duplicate(true);_worker=Thread.new()
	var error: Error=_worker.start(_build.bind(_working,_obstacles.duplicate(true),_water_obstacles.duplicate(true),contacts._levels.duplicate(true),contacts._origin,contacts._extent))
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
		entry.node.set_meta("bridge_dressing_hidden",_hide_dressing(entry,plan))
		environment._shore_sources.erase(entry.node)
		if entry.node.visible and entry.node.has_meta("bridge_dressing_stone"): environment._shore_sources.append(entry.node)
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
