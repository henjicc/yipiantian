extends Node3D
## Draft geometry is disposable. FarmState and the existing farm remain authoritative.
signal checked
const Plan=preload("res://layout/courtyard_plan.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
const Cover=preload("res://scenes/environment/ground_cover.gd")
const Fence=preload("res://layout/fence_geometry.gd")
var main: Node3D
var farm: FarmLayout
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
var _shown_paths: Array=[]
var _shown_fences: Array=[]
var _shown_fence_style: String=""
var _grass_context: Dictionary={}
var _grass_fields: Array[PackedVector2Array]=[]
var _grass_paths: Array[PackedVector3Array]=[]

func configure(scene: Node3D) -> void:
	main=scene
	farm=FarmLayout.new();farm.plan.fields.clear();add_child(farm);farm.preview_from(main.farm)
	for body: StaticBody3D in farm.fields: body.collision_layer=0
	core=Cover.new();add_child(core)
	core.preview_tiles(main.get_node("Environment/GroundCover/CoreGrass"))
	expansion=Cover.new();add_child(expansion)
	expansion.preview_tiles(main.get_node("Environment/ExpansionGrass"))
	# Opening the tool has not changed any land, paths or fence contacts.
	# Keep the existing ground dressing until a validated edit changes it.
	validated=main.courtyard_plan;routes=main.get_node("Environment").circulation
	_wanted=validated.snapshot()
	_shown_paths=validated.paths.duplicate(true)
	_shown_fences=validated.fences.duplicate(true);_shown_fence_style=validated.fence_style
	_grass_context=_wanted.duplicate();_grass_context.erase("fields")
	for i: int in validated.fields.size(): _grass_fields.append(validated.field_polygon(i,.07))
	_grass_paths=validated.paths.duplicate()

func update(plan: RefCounted) -> void:
	var snapshot: Dictionary=plan.snapshot()
	if snapshot==_wanted: return
	_wanted=snapshot;validated=null;routes=null
	farm.sync_plan(plan,main.farm_state)
	for body: StaticBody3D in farm.fields: body.collision_layer=0
	# Soil/crops move immediately; grass uses the latest known routes while a
	# private navigation build checks the new connections away from the frame.
	plan.paths=main.courtyard_plan.paths.duplicate()
	_update_grass(plan)
	var obstacles: Dictionary=main.get_node("Environment").layout_obstacles.duplicate(true)
	obstacles.merge(main.decoration_layout.ground_footprints())
	message=""
	if not Circulation.field_placement_issues(plan,obstacles).is_empty(): message="田块需要落在空地上，并与岸边、景物和其他田块留出间距。"
	var state: RefCounted=main.farm_state.copy()
	if not state.apply_layout(snapshot,main.clock.call()).ok: message="缩小或移除的田格里还有作物，请先收获，或保留这些田格。"
	pending=message.is_empty();_due=Time.get_ticks_msec()+120
	checked.emit()

func show_ground(plan: RefCounted) -> void:
	var environment: Node3D=main.get_node("Environment")
	if plan.paths!=_shown_paths:
		var source: Node3D=paths if is_instance_valid(paths) else environment.get_node("GardenPaths")
		var replacement: Node3D=environment.make_paths(plan,source)
		if is_instance_valid(paths): paths.hide();paths.queue_free()
		var original: Node3D=environment.get_node("GardenPaths")
		if original.visible: _hidden.append(original);original.hide()
		paths=replacement;add_child(paths)
		_shown_paths=plan.paths.duplicate(true)
	if plan.fences!=_shown_fences or plan.fence_style!=_shown_fence_style:
		if is_instance_valid(fence): fence.hide();fence.queue_free()
		for node: Node in environment.get_children():
			if node is Node3D and node.has_meta("fence_spans") and node.visible: _hidden.append(node);node.hide()
		fence=Fence.build(plan.fences,plan.fence_style);add_child(fence)
		_shown_fences=plan.fences.duplicate(true);_shown_fence_style=plan.fence_style
	_update_grass(plan)

func _update_grass(plan: RefCounted) -> void:
	var context: Dictionary=plan.snapshot();context.erase("fields")
	var fields: Array[PackedVector2Array]=[]
	for i: int in plan.fields.size(): fields.append(plan.field_polygon(i,.07))
	var changes: Array[PackedVector2Array]=[]
	for polygon: PackedVector2Array in _grass_fields+fields:
		if polygon not in _grass_fields or polygon not in fields: changes.append(polygon)
	for route: PackedVector3Array in _grass_paths+plan.paths:
		if route in _grass_paths and route in plan.paths: continue
		for i: int in range(1,route.size()):
			var a:=Vector2(route[i-1].x,route[i-1].z);var b:=Vector2(route[i].x,route[i].z)
			# GroundCover clears .23m around path centres, including endpoints.
			var bounds:=Rect2(a,Vector2.ZERO).expand(b).grow(.24)
			changes.append(Cover.IslandSpace.rectangle(bounds.position,bounds.size))
	var full: bool=context!=_grass_context
	_grass_context=context;_grass_fields=fields;_grass_paths=plan.paths.duplicate()
	if not full and changes.is_empty(): return
	# Other layout changes still use the complete ground pass. During normal
	# field editing only old/new soil feet and changed path segments need it.
	var cells: Dictionary={} if full else Cover.grass_cells(changes)
	if not full and cells.is_empty(): return
	core.update_tiles(plan,false,cells);expansion.update_tiles(plan,true,cells)

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
		_worker=null;pending=false;message="通路检查未能启动，请重新调整后再试。";push_error("Field route worker: %d"%error);checked.emit()

func accept(plan: RefCounted) -> void:
	_accepted=true
	var environment: Node3D=main.get_node("Environment")
	var old_farm: FarmLayout=main.farm
	farm.accept_preview()
	main.focus_detail.replace_fields(farm.fields+[main.trellis_crops.body])
	main.remove_child(old_farm);old_farm.queue_free()
	for body: StaticBody3D in farm.fields: body.collision_layer=1
	farm.reparent(main);farm.name="Farm";farm.plan=plan;main.farm=farm
	core.accept_tiles();expansion.accept_tiles()
	if is_instance_valid(paths):
		var old: Node=environment.get_node("GardenPaths");environment.remove_child(old);old.queue_free()
		paths.reparent(environment);paths.name="GardenPaths"
	if is_instance_valid(fence):
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
	farm.restore_preview()
	core.restore_tiles();expansion.restore_tiles()
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if _worker==null: queue_free()

func _exit_tree() -> void:
	if _worker!=null and _worker.is_started(): _worker.wait_to_finish()
	if not _accepted:
		farm.restore_preview()
		core.restore_tiles();expansion.restore_tiles()
		for node: Node3D in _hidden:
			if is_instance_valid(node): node.show()
