extends Node3D
## Owns the live trellis assembly and a private route check. Saving stays in main.
signal checked
const Plan=preload("res://layout/courtyard_plan.gd")
const Construction=preload("res://layout/island_construction.gd")
const Structures=preload("res://layout/garden_structures.gd")
const Cover=preload("res://scenes/environment/ground_cover.gd")
const Space=preload("res://scenes/environment/animal_space.gd")
const IslandSpace=preload("res://layout/island_space.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
const Fence=preload("res://layout/fence_geometry.gd")
const Contacts=preload("res://presentation/contact_shading.gd")
var main: Node3D
var environment: Node3D
var structure: Node3D
var bed: Node3D
var support: Node3D
var contacts: Node3D
var core: Node3D
var expansion: Node3D
var paths: Node3D
var fence: Node3D
var pending: bool=false
var message: String=""
var validated: RefCounted
var routes: RefCounted
var _wanted: Dictionary={}
var _working: Dictionary={}
var _obstacles: Dictionary={}
var _dimensions:=Vector3.ZERO
var _contact_pose:=Transform3D.IDENTITY
var _followers: Array[Dictionary]=[]
var _hidden: Array[Node3D]=[]
var _worker: Thread
var _due: int=0
var _retiring: bool=false
var _accepted: bool=false
var _restored: bool=false
var _original_geometry: bool=false
var _last_footprint: PackedVector2Array

func configure(scene: Node3D) -> void:
	main=scene;environment=main.get_node("Environment")
	core=Cover.new();add_child(core);core.copy_tiles(environment.get_node("GroundCover/CoreGrass"))
	_last_footprint=core._exclusions[2]
	expansion=Cover.new();add_child(expansion);expansion.copy_tiles(environment.get_node("ExpansionGrass"))
	paths=environment.get_node("GardenPaths").duplicate(0);add_child(paths)
	fence=Fence.build(environment.plan.fences,environment.plan.fence_style);add_child(fence)
	for node: Node3D in [environment.get_node("Flowers0_0"),environment.get_node("Flowers0_1"),environment.get_node("BankGrass0"),environment.get_node("GroundCover/TrellisRoots")]:
		var copy: Node3D=node.duplicate(0);add_child(copy);copy.global_transform=node.global_transform
		var polygon: PackedVector2Array=Space.cached_footprint(node,environment.plan.ground_height+.10,environment.plan.ground_height+.62) if String(node.name).begins_with("Flowers0_") else PackedVector2Array()
		_followers.append({"source":node,"copy":copy,"pose":node.global_transform,"footprint":polygon})
		_hide(node)
	for path: String in ["EntranceTrellis","TrellisSupport","TrellisContacts","GroundCover/ClimbingBed","GroundCover/CoreGrass","ExpansionGrass","GardenPaths"]: _hide(environment.get_node(path))
	for node: Node in environment.get_children():
		if node is Node3D and node.has_meta("fence_spans"): _hide(node)

func _hide(node: Node3D) -> void:
	if node.visible: _hidden.append(node);node.hide()

func update(plan: RefCounted) -> void:
	if plan.snapshot()==_wanted: return
	_wanted=plan.snapshot();validated=null;routes=null
	var dimensions: Vector3=Construction.trellis_size(plan)
	var original: bool=plan.construction.trellis.is_empty()
	if not is_instance_valid(structure) or dimensions!=_dimensions or original!=_original_geometry:
		for node: Node in [structure,bed,support,contacts]:
			if is_instance_valid(node): node.free()
		if original:
			structure=load("res://art/environment/modules/climbing_trellis.glb").instantiate()
			structure.position=plan.anchors.trellis;structure.rotation.y=deg_to_rad(plan.angles.trellis)
			environment._apply_pigment(structure,"climbing_trellis")
		else: structure=Structures.trellis(plan)
		add_child(structure);structure.name="EntranceTrellis"
		var cover:=Cover.new();add_child(cover);cover._build_trellis_bed(plan)
		bed=cover.get_node("ClimbingBed");bed.reparent(self);cover.free()
		support=Structures.trellis_support(plan);add_child(support)
		contacts=Contacts.new();add_child(contacts);contacts.configure_bounds(plan.land_bounds().grow(.6))
		contacts.collect(structure,[plan.ground_height+.002]);contacts.bake()
		_contact_pose=Construction.trellis_pose(plan);_dimensions=dimensions;_original_geometry=original
	var pose: Transform3D=Construction.trellis_pose(plan)
	structure.transform=pose*Transform3D(Basis(Vector3.UP,PI/2),Vector3.ZERO) if original else pose
	bed.position=plan.anchors.trellis;bed.rotation.y=deg_to_rad(Construction.trellis_yaw(plan))
	support.transform=pose
	contacts.transform=pose*_contact_pose.affine_inverse()
	var delta: Vector3=plan.flower_centres[0]-environment.plan.flower_centres[0]
	for pair: Dictionary in _followers:
		pair.copy.global_transform=pair.pose;pair.copy.global_position+=delta
	main.decoration_layout.preview_attachment("hanging_03",plan)
	_obstacles=environment.layout_obstacles.duplicate(true)
	_obstacles.erase("EntranceTrellis")
	for key: String in _obstacles.keys():
		if key.begins_with("Flowers0_"): _obstacles.erase(key)
	_obstacles.merge(main.decoration_layout.ground_footprints())
	message=_placement_issue(plan)
	_obstacles.EntranceTrellis=_footprint(plan)
	for pair: Dictionary in _followers:
		if not String(pair.source.name).begins_with("Flowers0_"): continue
		var polygon: PackedVector2Array=_flower_footprint(pair)
		if polygon.size()>=3: _obstacles[String(pair.source.name)]=polygon
	core._exclusions[2]=_footprint(plan)
	expansion._exclusions[2]=core._exclusions[2]
	plan.paths=environment.plan.paths.duplicate()
	var changed: Dictionary=Cover.grass_cells([_last_footprint,core._exclusions[2]])
	core.update_tiles(plan,false,changed);expansion.update_tiles(plan,true,changed)
	_last_footprint=core._exclusions[2]
	pending=message.is_empty();_due=Time.get_ticks_msec()+120
	checked.emit()

func _placement_issue(plan: RefCounted) -> String:
	var footprint: PackedVector2Array=_footprint(plan)
	if not IslandSpace.supported(footprint,plan.plateau()): return "菜架需要完整落在平地上。"
	for key: String in _obstacles:
		if IslandSpace.overlaps(footprint,_obstacles[key]): return "菜架碰到了景物或摆件，请调整位置或大小。"
	for i: int in plan.fields.size():
		if IslandSpace.overlaps(footprint,plan.field_polygon(i,.12)): return "这里需要留给田地。"
	for pair: Dictionary in _followers:
		if not String(pair.source.name).begins_with("Flowers0_"): continue
		var polygon: PackedVector2Array=_flower_footprint(pair)
		# Leaves may overhang the bank; the planted root must remain supported.
		var root_at:=Vector2(pair.copy.global_position.x,pair.copy.global_position.z)
		if not IslandSpace.supported(IslandSpace.rectangle(root_at-Vector2.ONE*.10,Vector2.ONE*.20),plan.plateau()): return "架旁花草需要留在陆地上。"
		for other: PackedVector2Array in main.decoration_layout.ground_footprints().values():
			if IslandSpace.overlaps(polygon,other): return "架旁花草会碰到摆件，请留出一些空间。"
		for i: int in plan.fields.size():
			if IslandSpace.overlaps(polygon,plan.field_polygon(i,.12)): return "架旁花草需要避开田地。"
	return animal_issue(plan)

func animal_issue(plan: RefCounted) -> String:
	var issue: String=main.decoration_layout._animal_issue(_footprint(plan))
	if not issue.is_empty(): return issue
	for pair: Dictionary in _followers:
		if String(pair.source.name).begins_with("Flowers0_"):
			issue=main.decoration_layout._animal_issue(_flower_footprint(pair))
			if not issue.is_empty(): return issue
	return ""

func _footprint(plan: RefCounted) -> PackedVector2Array:
	if plan.construction.trellis.is_empty(): return Space.cached_footprint(structure,plan.ground_height-.08,plan.ground_height+.62)
	return Construction.trellis_footprint(plan)

func _flower_footprint(pair: Dictionary) -> PackedVector2Array:
	var delta: Vector3=pair.copy.global_position-pair.pose.origin
	return Transform2D(0,Vector2(delta.x,delta.z))*pair.footprint

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
				validated=result.plan;routes=result.routes;_show_ground(validated)
			else: message=result.routes.issues[-1] if result.routes.issues[-1].begins_with("鸡群") else "这里会挡住通路，请为屋前、田边和桥头留出空间。"
			checked.emit()
	if not pending or _worker!=null or Time.get_ticks_msec()<_due: return
	_working=_wanted.duplicate(true);_worker=Thread.new()
	var error: Error=_worker.start(_build.bind(_working,_obstacles.duplicate(true)))
	if error!=OK:
		_worker=null;pending=false;message="通路检查未能启动，请重新调整后再试。";push_error("Trellis route worker: %d"%error);checked.emit()

func _show_ground(plan: RefCounted) -> void:
	for node: Node in [paths,fence]:
		if is_instance_valid(node): node.free()
	paths=environment.make_paths(plan);add_child(paths)
	fence=Fence.build(plan.fences,plan.fence_style);add_child(fence)
	core.update_tiles(plan,false);expansion.update_expansion(plan)

func accept(plan: RefCounted) -> void:
	_accepted=true
	for pair: Array in [[structure,environment,"EntranceTrellis"],[support,environment,"TrellisSupport"],[contacts,environment,"TrellisContacts"],[bed,environment.get_node("GroundCover"),"ClimbingBed"],[core,environment.get_node("GroundCover"),"CoreGrass"],[expansion,environment,"ExpansionGrass"],[paths,environment,"GardenPaths"]]:
		var old: Node=pair[1].get_node(pair[2]);environment._contact_sources.erase(old)
		if pair[2]=="EntranceTrellis": main.focus_detail.replace_structure(old,structure)
		old.get_parent().remove_child(old);old.queue_free()
		pair[0].reparent(pair[1]);pair[0].name=pair[2]
	for pair: Dictionary in _followers:
		pair.source.global_transform=pair.copy.global_transform;pair.source.show();_hidden.erase(pair.source)
	for node: Node in environment.get_children():
		if node.has_meta("fence_spans"):
			environment._contact_sources.erase(node);environment.remove_child(node);node.queue_free()
	fence.reparent(environment);environment._contact_sources.append(fence)
	environment._contact_sources.append(structure)
	environment.layout_obstacles=_obstacles.duplicate(true)
	# Decorations remain separately owned; layout obstacles must not retain stale prop poses.
	for key: String in environment.layout_obstacles.keys():
		if key.begins_with("decoration_"): environment.layout_obstacles.erase(key)
	environment.plan=plan;environment.circulation=routes;main.courtyard_plan=plan;main.farm.plan=plan
	environment.get_slot_marker("hanging_03").position=plan.slots.hanging_03
	main.decoration_layout.accept_attachment_plan(plan)
	main.decoration_layout._collect_environment_meshes(structure)
	main.decoration_layout._collect_environment_meshes(support)
	_hidden.clear()

func retire() -> void:
	_retiring=true;pending=false;hide();_restore()
	if _worker==null: queue_free()

func _restore() -> void:
	if _accepted or _restored: return
	_restored=true
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if is_instance_valid(main) and is_instance_valid(main.decoration_layout): main.decoration_layout.clear_attachment_preview()

func _exit_tree() -> void:
	if _worker!=null and _worker.is_started(): _worker.wait_to_finish()
	_restore()
