extends Node3D
## A reversible rigid assembly keeps tools, food and lighting on their real supports.
signal checked
const Plan=preload("res://layout/courtyard_plan.gd")
const Buildings=preload("res://layout/building_layout.gd")
const Space=preload("res://layout/island_space.gd")
const Cover=preload("res://scenes/environment/ground_cover.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
const Fence=preload("res://layout/fence_geometry.gd")
var main: Node3D
var environment: Node3D
var building_id: String
var pending: bool=false
var message: String=""
var validated: RefCounted
var routes: RefCounted
var footprint: PackedVector2Array
var core: Node3D
var expansion: Node3D
var paths: Node3D
var fence: Node3D
var _members: Array[Dictionary]=[]
var _geometry: Array[Dictionary]=[]
var _hidden: Array[Node3D]=[]
var _parts: Dictionary={}
var _authored_parts: Dictionary={}
var _authored_neighbors: Array[String]=[]
var _base_pose: Transform3D
var _last_footprint: PackedVector2Array
var _obstacles: Dictionary={}
var _wanted: Dictionary={}
var _working: Dictionary={}
var _worker: Thread
var _due: int=0
var _retiring: bool=false
var _restored: bool=false
var _accepted: bool=false

func configure(scene: Node3D, id: String) -> void:
	main=scene;building_id=id;environment=main.get_node("Environment")
	_base_pose=Buildings.pose(environment.plan,id)
	var members: Array[Node3D]=environment.building_contact_sources(id)
	for path: String in [id.capitalize()+"Supports",id.capitalize()+"Contacts","GroundCover/"+id.capitalize()+"Foundation"]: members.append(environment.get_node(path))
	if id=="house": members.append(environment.get_node("DoorTools"))
	for node: Node3D in members:
		_members.append({"node":node,"pose":node.global_transform})
		for mesh: GeometryInstance3D in node.find_children("*","GeometryInstance3D",true,false):
			_geometry.append({"node":mesh,"gi":mesh.gi_mode});mesh.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
	for key: String in Buildings.STRUCTURES[id]+Buildings.PROPS[id]:
		if environment.layout_obstacles.has(key): _parts[key]=environment.layout_obstacles[key]
	var original: Transform3D=Buildings.delta(environment.plan,id).affine_inverse()
	_authored_parts=_transform_parts(_parts,original,environment.plan.ground_height)
	for tree: Dictionary in environment.plan.trees: _authored_neighbors.append(tree.id)
	for other: String in Buildings.BASE:
		if other!=id and Buildings.delta(environment.plan,other).is_equal_approx(Transform3D.IDENTITY):
			_authored_neighbors.append_array(Buildings.STRUCTURES[other]+Buildings.PROPS[other])
	_last_footprint=_outline(_parts)
	core=Cover.new();add_child(core);core.copy_tiles(environment.get_node("GroundCover/CoreGrass"))
	expansion=Cover.new();add_child(expansion);expansion.copy_tiles(environment.get_node("ExpansionGrass"))
	for path: String in ["GroundCover/CoreGrass","ExpansionGrass"]: _hide(environment.get_node(path))

func _hide(node: Node3D) -> void:
	if node.visible: _hidden.append(node);node.hide()

static func _outline(parts: Dictionary) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for polygon: PackedVector2Array in parts.values(): points.append_array(polygon)
	return Geometry2D.convex_hull(points)

func update(plan: RefCounted) -> void:
	if plan.snapshot()==_wanted: return
	_wanted=plan.snapshot();validated=null;routes=null
	var transform: Transform3D=Buildings.pose(plan,building_id)*_base_pose.affine_inverse()
	for member: Dictionary in _members: member.node.global_transform=transform*member.pose
	main.kitchen_display.sync_supports()
	for slot: String in Buildings.SLOTS[building_id]: main.decoration_layout.preview_attachment(slot,plan)
	var changed_parts: Dictionary=_transform_parts(_parts,transform,plan.ground_height)
	footprint=_outline(changed_parts)
	_obstacles=environment.layout_obstacles.duplicate(true)
	for key: String in _parts: _obstacles.erase(key)
	_obstacles.merge(main.decoration_layout.ground_footprints())
	message=_placement_issue(plan,changed_parts)
	_obstacles.merge(changed_parts)
	# Keep the core meadow's fixed architectural exclusions in the same pose.
	for key: String in Cover.BUILDING_EXCLUSIONS:
		if changed_parts.has(key):
			core._exclusions[Cover.BUILDING_EXCLUSIONS[key]]=changed_parts[key]
			expansion._exclusions[Cover.BUILDING_EXCLUSIONS[key]]=changed_parts[key]
	plan.paths=environment.plan.paths.duplicate()
	var changed: Dictionary=Cover.grass_cells([_last_footprint,footprint])
	core.update_tiles(plan,false,changed);expansion.update_tiles(plan,true,changed);_last_footprint=footprint
	pending=message.is_empty();_due=Time.get_ticks_msec()+120;checked.emit()

static func _transform_parts(parts: Dictionary, pose: Transform3D, height: float) -> Dictionary:
	var result: Dictionary={}
	for key: String in parts:
		var polygon:=PackedVector2Array()
		for point: Vector2 in parts[key]:
			var moved: Vector3=pose*Vector3(point.x,height,point.y)
			polygon.append(Vector2(moved.x,moved.z))
		result[key]=polygon
	return result

func _placement_issue(plan: RefCounted, parts: Dictionary) -> String:
	var island: int=-1
	for key: String in parts:
		var polygon: PackedVector2Array=parts[key]
		var support: int=plan.supporting_island(polygon)
		if support<0 or (island>=0 and support!=island): return "建筑及附属物需要完整落在同一座岛的陆地上。"
		island=support
		for other: String in _obstacles:
			var overlaps: Array[PackedVector2Array]=Geometry2D.intersect_polygons(polygon,_obstacles[other])
			for overlap: PackedVector2Array in overlaps:
				# Tree roots and the original side rack touch the authored houses.
				# Preserve only that contact envelope while the neighbour is still
				# in its authored pose; relocated buildings and player props block.
				if other in _authored_neighbors and Space.supported(overlap,_authored_parts[key]): continue
				return "这里碰到了其他建筑、景物或摆件，请留出空间。"
		for i: int in plan.fields.size():
			if Space.overlaps(polygon,plan.field_polygon(i,.12)): return "这里需要留给田地。"
	return animal_issue()

func animal_issue() -> String:
	return main.decoration_layout._animal_issue(footprint)

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
			else: message=result.routes.issues[-1] if result.routes.issues[-1].begins_with("鸡群") else "这里会挡住入口或通路，请为屋前、田边和桥头留出空间。"
			checked.emit()
	if not pending or _worker!=null or Time.get_ticks_msec()<_due: return
	_working=_wanted.duplicate(true);_worker=Thread.new()
	var error: Error=_worker.start(_build.bind(_working,_obstacles.duplicate(true)))
	if error!=OK:
		_worker=null;pending=false;message="通路检查未能启动，请重新调整后再试。";push_error("Building route worker: %d"%error);checked.emit()

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
	for pair: Array in [[core,environment.get_node("GroundCover"),"CoreGrass"],[expansion,environment,"ExpansionGrass"],[paths,environment,"GardenPaths"]]:
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
	for slot: String in Buildings.SLOTS[building_id]: environment.get_slot_marker(slot).position=plan.slots[slot]
	main.decoration_layout.accept_attachment_plan(plan)
	_restore_gi();_hidden.clear()

func _restore_gi() -> void:
	for entry: Dictionary in _geometry:
		if is_instance_valid(entry.node): entry.node.gi_mode=entry.gi

func retire() -> void:
	_retiring=true;pending=false;hide();_restore()
	if _worker==null: queue_free()

func _restore() -> void:
	if _accepted or _restored: return
	_restored=true
	for member: Dictionary in _members:
		if is_instance_valid(member.node): member.node.global_transform=member.pose
	_restore_gi()
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if is_instance_valid(main):
		if is_instance_valid(main.decoration_layout): main.decoration_layout.clear_attachment_preview()
		if is_instance_valid(main.kitchen_display): main.kitchen_display.sync_supports()

func _exit_tree() -> void:
	if _worker!=null and _worker.is_started(): _worker.wait_to_finish()
	_restore()
