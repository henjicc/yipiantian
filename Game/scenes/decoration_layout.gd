extends Node3D
## Owns arrangement interaction and previews, never harvest counts or disk writes.

signal confirmed
signal change_requested(candidate: Dictionary)
signal mode_changed(active: bool)

const Catalog = preload("res://farm/decoration_catalog.gd")
const State = preload("res://farm/decoration_state.gd")
const DecorHUD = preload("res://scenes/decoration_hud.gd")
var active: bool = false
var state: State
var camera: FarmCamera
var environment: Node3D
var hud: DecorHUD
var selected_item: String = ""
var preview_slot: String = ""
var preview_turn: int = 0
var _instances: Dictionary = {}
var _rings: Dictionary = {}
var _preview: Node3D
var _press_slot: String = ""
var _press_position := Vector2.INF
var _message: String = "布置"
var _environment_meshes: Array[MeshInstance3D] = []
var _triangle_meshes: Dictionary = {}
var _night_weight: float=0
var _kitchen: Dictionary={}
const LivingDecoration=preload("res://presentation/living_decoration.gd")
const Space=preload("res://scenes/environment/animal_space.gd")
const SITE_SCENERY=preload("res://layout/courtyard_plan.gd").DECORATION_SCENERY


func configure(courtyard: Node3D, farm_camera: FarmCamera, decoration_state: State) -> void:
	environment = courtyard
	camera = farm_camera
	state = decoration_state
	_collect_environment_meshes(environment)
	hud = DecorHUD.new()
	hud.name = "DecorationHUD"
	add_child(hud)
	hud.item_requested.connect(select_item)
	hud.rotate_requested.connect(rotate_preview)
	hud.confirm_requested.connect(confirm_preview)
	hud.cancel_requested.connect(cancel_preview)
	hud.finish_requested.connect(finish_mode)
	hud.remove_requested.connect(remove_selected)
	camera.motion_finished.connect(_refresh)
	for slot: Dictionary in environment.get_decoration_slots():
		var ring := MeshInstance3D.new()
		ring.name = slot.id
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.36
		mesh.outer_radius = 0.42
		mesh.rings = 24
		mesh.ring_segments = 8
		ring.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("b4c589")
		ring.material_override = material
		add_child(ring)
		ring.global_transform = environment.get_slot_marker(slot.id).global_transform
		ring.position.y += 0.035 if slot.type == "ground" else -0.22
		ring.hide()
		_rings[slot.id] = ring
	refresh_confirmed()


func bind_state(decoration_state: State) -> void:
	state = decoration_state
	finish_mode()
	refresh_confirmed()


func begin_mode() -> void:
	active = true
	hud.show()
	_message = "布置"
	mode_changed.emit(true)
	_refresh()


func finish_mode() -> void:
	cancel_preview()
	active = false
	if hud != null:
		hud.hide()
	_refresh()
	mode_changed.emit(false)


func cancel_preview() -> void:
	selected_item = ""
	preview_slot = ""
	preview_turn = 0
	_cancel_press()
	_clear_preview()
	for instance: Node3D in _instances.values():
		instance.show()
	_restore_site_scenery()
	_message = "布置"
	_refresh()


func select_item(item_id: String) -> void:
	if not active or camera.is_transitioning():
		return
	cancel_preview()
	if not state.snapshot()[item_id].unlocked:
		_message = Catalog.requirement(item_id)
		_refresh()
		return
	selected_item = item_id
	_message = Catalog.ITEMS[item_id].name
	_refresh()


func preview_at(slot_id: String) -> void:
	if not active or selected_item.is_empty() or camera.is_transitioning():
		return
	var turn: int = preview_turn if Catalog.allowed_turns(slot_id).has(preview_turn) else 0
	var result: Dictionary = state.can_place(selected_item, slot_id, turn,true)
	if not result.ok:
		_message = {"occupied": "这个位置已有装饰", "wrong_type": "这个位置不适合这件装饰"}.get(result.reason, "无法放在这里")
		_refresh()
		return
	if not _slot_visible(slot_id):
		_message = "这个位置被景物挡住了"
		_refresh()
		return
	preview_slot = slot_id
	preview_turn = turn
	_clear_preview()
	for instance: Node3D in _instances.values(): instance.show()
	_restore_site_scenery(slot_id)
	_preview = _instantiate(selected_item, slot_id, turn)
	if _instances.has(selected_item):
		_instances[selected_item].hide()
	_message = Catalog.ITEMS[selected_item].name + " · 待确认"
	for other: String in Catalog.IDS:
		if other!=selected_item and state.snapshot()[other].slot_id==slot_id:
			_instances[other].hide()
			_message+=" · 将收起"+Catalog.ITEMS[other].name
	_refresh()


func rotate_preview() -> void:
	if not active or preview_slot.is_empty():
		return
	var turns: Array[int] = Catalog.allowed_turns(preview_slot)
	preview_turn = turns[(turns.find(preview_turn) + 1) % turns.size()]
	preview_at(preview_slot)


func confirm_preview() -> void:
	if not active or preview_slot.is_empty() or camera.is_transitioning():
		return
	var candidate:=State.new()
	candidate.restore_snapshot(state.snapshot())
	var result: Dictionary = candidate.place(selected_item, preview_slot, preview_turn,true)
	if not result.ok:
		return
	var issue: String=placement_issue(_preview,selected_item,preview_slot)
	if issue.is_empty(): issue=_restoration_issue(candidate.snapshot())
	if not issue.is_empty():
		_message=issue
		_refresh()
		return
	change_requested.emit(candidate.snapshot())

func accept_state(replacement: State) -> void:
	state=replacement
	cancel_preview()
	refresh_confirmed()
	confirmed.emit()
	_refresh()

func remove_selected() -> void:
	if not active or selected_item.is_empty() or camera.is_transitioning(): return
	var candidate:=State.new()
	candidate.restore_snapshot(state.snapshot())
	if not candidate.remove(selected_item).ok: return
	var issue: String=_restoration_issue(candidate.snapshot())
	if not issue.is_empty():
		_message=issue
		_refresh()
		return
	change_requested.emit(candidate.snapshot())


func refresh_confirmed() -> void:
	for instance: Node3D in _instances.values():
		remove_child(instance)
		instance.queue_free()
	_instances.clear()
	for item_id: String in Catalog.IDS:
		var item: Dictionary = state.snapshot()[item_id]
		if not item.slot_id.is_empty():
			_instances[item_id] = _instantiate(item_id, item.slot_id, item.quarter_turn)
	_restore_site_scenery()
	update_life(_kitchen)
	var animals: Node=environment.get_node("CourtyardAnimals")
	animals.set_decorations(_instances)
	_refresh()


func lantern_anchors() -> Array[Node3D]:
	var anchors: Array[Node3D] = []
	if _instances.has("lantern"):
		anchors.append(_instances.lantern)
	return anchors


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _press_position != Vector2.INF and event.position.distance_to(_press_position) > 7:
		_cancel_press()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click or event.canceled or camera.is_transitioning():
			_cancel_press()
		elif event.pressed:
			_press_position = event.position
			_press_slot = _slot_at(event.position)
		else:
			if not _press_slot.is_empty() and _slot_at(event.position) == _press_slot:
				preview_at(_press_slot)
			_cancel_press()


func observe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_cancel_press()
	elif event is InputEventMouseMotion and _press_position != Vector2.INF and event.position.distance_to(_press_position) > 7:
		_cancel_press()


func _slot_at(point: Vector2) -> String:
	var nearest: String = ""
	var distance: float = 32.0
	for slot_id: String in _rings:
		var ring: Node3D = _rings[slot_id]
		if not ring.visible or camera.is_position_behind(ring.global_position):
			continue
		var projected: Vector2 = camera.unproject_position(ring.global_position)
		if point.distance_to(projected) < distance:
			distance = point.distance_to(projected)
			nearest = slot_id
	return nearest


func _collect_environment_meshes(node: Node) -> void:
	if node == environment.get_water_surface() or node.name == "DistantRiverPanorama":
		return
	if node is MeshInstance3D and node.mesh != null:
		_environment_meshes.append(node)
		var mesh_id: int = node.mesh.get_instance_id()
		if not _triangle_meshes.has(mesh_id):
			_triangle_meshes[mesh_id] = node.mesh.generate_triangle_mesh()
	for child: Node in node.get_children():
		_collect_environment_meshes(child)


func _slot_visible(slot_id: String) -> bool:
	var target: Vector3 = _rings[slot_id].global_position
	if camera.is_position_behind(target):
		return false
	# Stop just before the marker to avoid treating its own hook/support as a wall.
	var endpoint: Vector3 = target.move_toward(camera.global_position, 0.06)
	var replaced: Node=environment.get_node_or_null("LivingDetails/"+SITE_SCENERY.get(slot_id,"")) if SITE_SCENERY.has(slot_id) else null
	for instance: MeshInstance3D in _environment_meshes:
		if not instance.is_visible_in_tree():
			continue
		# The selectable site replaces this object; it must not occlude its own marker.
		if replaced!=null and (instance==replaced or replaced.is_ancestor_of(instance)): continue
		var inverse: Transform3D = instance.global_transform.affine_inverse()
		var start: Vector3 = inverse * camera.global_position
		var end: Vector3 = inverse * endpoint
		if instance.mesh.get_aabb().intersects_segment(start, end) == null:
			continue
		var mesh_id: int = instance.mesh.get_instance_id()
		var triangles: TriangleMesh = _triangle_meshes[mesh_id]
		if triangles != null and not triangles.intersect_segment(start, end).is_empty():
			return false
	return true


func _instantiate(item_id: String, slot_id: String, turn: int) -> Node3D:
	var instance: Node3D
	if item_id in ["bench","drying_rack","tea_table"]:
		instance=LivingDecoration.build(environment.get_node("LivingDetails"),item_id)
	else: instance=environment.get_decoration_scene(item_id).instantiate()
	add_child(instance)
	instance.global_transform = environment.get_slot_marker(slot_id).global_transform
	instance.rotate_object_local(Vector3.UP, turn * PI / 2.0)
	return instance

func update_life(kitchen: Dictionary) -> void:
	_kitchen=kitchen
	if _instances.has("drying_rack"):
		var showing: bool=not kitchen.is_empty() and (not kitchen.jobs.rack.is_empty() or kitchen.stock.root_dry>0)
		_instances.drying_rack.get_node("Harvest").visible=showing
	if _instances.has("tea_table"):
		_instances.tea_table.get_node("Tea").visible=_night_weight>.25

func set_night_weight(weight: float) -> void:
	_night_weight=weight
	update_life(_kitchen)

func placement_issue(prop: Node3D, item: String, slot: String) -> String:
	if Catalog.ITEMS[item].type!="ground": return ""
	var rise: float=environment.plan.ground_height-.13
	var polygon: PackedVector2Array=Space.footprint(prop,.05+rise,1.3+rise,false)
	if polygon.size()<3: return "摆件没有可用的落地轮廓"
	if not Geometry2D.clip_polygons(polygon,environment.plan.plateau()).is_empty(): return "这里超出了平地"
	for key: String in environment.layout_obstacles:
		if key==SITE_SCENERY.get(slot,""): continue
		if not Geometry2D.intersect_polygons(polygon,environment.layout_obstacles[key]).is_empty(): return "这里会碰到院中景物"
	for index: int in environment.plan.fields.size():
		if not Geometry2D.intersect_polygons(polygon,environment.plan.field_polygon(index,.12)).is_empty(): return "这里需要留给田地"
	for other: String in _instances:
		if other==item or state.snapshot()[other].slot_id==slot: continue
		var obstacle: PackedVector2Array=Space.footprint(_instances[other],.05+rise,1.3+rise,false)
		if obstacle.size()>=3 and not Geometry2D.intersect_polygons(polygon,obstacle).is_empty(): return "这里会碰到其他摆件"
	return _animal_issue(polygon)

func _animal_issue(polygon: PackedVector2Array) -> String:
	var animals: Node=environment.get_node("CourtyardAnimals")
	for bird: Dictionary in animals.birds:
		if bird.kind!="hen": continue
		for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon,.23):
			if Geometry2D.is_point_in_polygon(bird.position,expanded): return "小鸡在这里，等它走开再放"
	return ""

func _restoration_issue(candidate: Dictionary) -> String:
	# Moving or removing furniture restores the site's original objects. Check
	# their larger footprint too, so a chicken is never covered or teleported.
	var rise: float=environment.plan.ground_height-.13
	for slot: String in SITE_SCENERY:
		var before: bool=false
		var after: bool=false
		for entry: Dictionary in state.snapshot().values():
			if entry.slot_id==slot: before=true
		for entry: Dictionary in candidate.values():
			if entry.slot_id==slot: after=true
		if not before or after: continue
		var source: Node3D=environment.get_node("LivingDetails/"+SITE_SCENERY[slot])
		var polygon: PackedVector2Array=Space.footprint(source,.05+rise,1.3+rise,false)
		var issue: String=_animal_issue(polygon)
		if not issue.is_empty(): return "小鸡正在摆件旁，等它走开再整理"
	return ""

func _restore_site_scenery(preview: String="") -> void:
	for slot: String in SITE_SCENERY:
		var occupied: bool=slot==preview
		for item: Dictionary in state.snapshot().values():
			if item.slot_id==slot: occupied=true
		environment.get_node("LivingDetails/"+SITE_SCENERY[slot]).visible=not occupied

func _clear_preview() -> void:
	if is_instance_valid(_preview):
		remove_child(_preview)
		_preview.queue_free()
	_preview = null


func cancel_pointer_gesture() -> void:
	_cancel_press()

func ground_footprints() -> Dictionary:
	var result: Dictionary = {}
	var rise: float=environment.plan.ground_height-.13
	for key: String in _instances:
		var polygon: PackedVector2Array = preload("res://scenes/environment/animal_space.gd").footprint(_instances[key],.05+rise,.75+rise)
		if polygon.size()>=3: result["decoration_"+key]=polygon
	return result


func _cancel_press() -> void:
	_press_slot = ""
	_press_position = Vector2.INF


func _refresh() -> void:
	if hud == null:
		return
	for slot_id: String in _rings:
		_rings[slot_id].visible = active and not selected_item.is_empty() and state.can_place(selected_item, slot_id, 0,true).ok and _slot_visible(slot_id)
	hud.present(state.snapshot(), selected_item, preview_slot, not preview_slot.is_empty(), _message, camera.is_transitioning())
