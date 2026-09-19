extends Node3D
## Local line preview; publish geometry only after its checked snapshot is saved.
signal checked
const Plan=preload("res://layout/courtyard_plan.gd")
const Routes=preload("res://layout/player_routes.gd")
const Display=preload("res://presentation/player_routes.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
const Cover=preload("res://scenes/environment/ground_cover.gd")
const Fence=preload("res://layout/fence_geometry.gd")
var main: Node3D
var display: Display
var core: Node3D
var expansion: Node3D
var paths: Node3D
var fence: Node3D
var validated: RefCounted
var routes: RefCounted
var message: String=""
var pending: bool=false
var _wanted: Dictionary={}
var _working: Dictionary={}
var _worker: Thread
var _hidden: Array[Node3D]=[]
var _due: int=0
var _accepted: bool=false
var _retiring: bool=false

func configure(scene: Node3D) -> void:
	main=scene
	display=Display.new();add_child(display)
	core=Cover.new();add_child(core)
	core.copy_tiles(main.get_node("Environment/GroundCover/CoreGrass"))
	expansion=Cover.new();add_child(expansion)
	expansion.copy_tiles(main.get_node("Environment/ExpansionGrass"))
	for node: Node3D in [main.get_node("Environment/PlayerRoutes"), main.get_node("Environment/GroundCover/CoreGrass"), main.get_node("Environment/ExpansionGrass")]:
		if node.visible: _hidden.append(node);node.hide()

func update(plan: RefCounted) -> void:
	var snapshot: Dictionary=plan.snapshot()
	if snapshot==_wanted: return
	_wanted=snapshot;validated=null;routes=null
	display.update(plan,main.get_node("Environment"))
	# Lines appear immediately; grass uses the latest known connections while a
	# private navigation build checks the new connections away from the frame.
	plan.paths=main.courtyard_plan.paths.duplicate()
	core.update_tiles(plan,false);expansion.update_expansion(plan)
	var obstacles: Dictionary=main.get_node("Environment").layout_obstacles.duplicate(true)
	obstacles.merge(main.decoration_layout.ground_footprints())
	message=Routes.placement_issue(plan,obstacles)
	pending=message.is_empty();_due=Time.get_ticks_msec()+120

func show_ground(plan: RefCounted) -> void:
	# Existing connections stay visible until the worker has a replacement.
	# Do not construct a redundant copy at the beginning of the first stroke.
	for node: Node in main.get_node("Environment").get_children():
		if node is Node3D and (node.name=="GardenPaths" or node.has_meta("fence_spans")) and node.visible:
			_hidden.append(node);node.hide()
	if is_instance_valid(paths): paths.hide();paths.queue_free()
	if is_instance_valid(fence): fence.hide();fence.queue_free()
	paths=main.get_node("Environment").make_paths(plan);add_child(paths)
	fence=Fence.build(plan.fences,plan.fence_style);add_child(fence)
	core.update_tiles(plan,false);expansion.update_expansion(plan)

static func _build(snapshot: Dictionary, obstacles: Dictionary) -> Dictionary:
	var plan: RefCounted=Plan.from_snapshot(snapshot)
	var circulation:=Circulation.new();circulation.build(plan,obstacles)
	return {"plan":plan,"routes":circulation}

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
				validated=result.plan;routes=result.routes;show_ground(validated)
			else: message=result.routes.issues[-1] if result.routes.issues[-1].begins_with("鸡群") else "这里会挡住通路，请为屋前、田边和桥头留出空间。"
			checked.emit()
	if not pending or _worker!=null or Time.get_ticks_msec()<_due: return
	_working=_wanted.duplicate(true)
	var obstacles: Dictionary=main.get_node("Environment").layout_obstacles.duplicate(true)
	obstacles.merge(main.decoration_layout.ground_footprints())
	_worker=Thread.new()
	var error: Error=_worker.start(_build.bind(_working,obstacles))
	if error!=OK:
		_worker=null;pending=false;message="通路检查未能启动，请重新调整后再试。";push_error("Player route worker: %d"%error);checked.emit()

func accept(plan: RefCounted) -> void:
	_accepted=true
	var environment: Node3D=main.get_node("Environment")
	var old: Node3D=environment.get_node("PlayerRoutes")
	main.focus_detail.replace_structure(old,display)
	environment._contact_sources.erase(old);environment.remove_child(old);old.queue_free()
	display.reparent(environment);display.name="PlayerRoutes";environment._contact_sources.append(display)
	environment.layout_obstacles=Routes.replace_obstacles(environment.layout_obstacles,plan)
	main.farm.plan=plan
	for pair: Array in [[core,environment.get_node("GroundCover"),"CoreGrass"],[expansion,environment,"ExpansionGrass"],[paths,environment,"GardenPaths"]]:
		var previous: Node=pair[1].get_node(pair[2]);previous.get_parent().remove_child(previous);previous.queue_free()
		pair[0].reparent(pair[1]);pair[0].name=pair[2]
	for node: Node in environment.get_children():
		if node.has_meta("fence_spans"):
			environment._contact_sources.erase(node);environment.remove_child(node);node.queue_free()
	fence.reparent(environment);environment._contact_sources.append(fence)
	environment.plan=plan;environment.circulation=routes
	main.courtyard_plan=plan
	_hidden.clear()

func retire() -> void:
	# Cancelling must not wait for an obsolete path search. Keep the private
	# worker owner alive, hidden, until it can join without blocking a frame.
	_retiring=true;pending=false;hide()
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if _worker==null: queue_free()

func _exit_tree() -> void:
	if _worker!=null and _worker.is_started(): _worker.wait_to_finish()
	if not _accepted:
		for node: Node3D in _hidden:
			if is_instance_valid(node): node.show()
