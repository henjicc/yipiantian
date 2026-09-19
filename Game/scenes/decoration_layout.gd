extends Node3D
## Owns arrangement interaction and previews, never harvest counts or disk writes.

signal confirmed
signal change_requested(candidate: Dictionary)
signal mode_changed(active: bool)
signal preview_changed
signal illumination_changed

const Catalog = preload("res://farm/decoration_catalog.gd")
const ConstructionCatalog = preload("res://layout/construction_catalog.gd")
const State = preload("res://farm/decoration_state.gd")
const DecorHUD = preload("res://scenes/decoration_hud.gd")
const Geometry = preload("res://presentation/decoration_geometry.gd")
var active: bool = false
var state: State
var camera: FarmCamera
var environment: Node3D
var hud: DecorHUD
var selected_item: String = ""
var preview_slot: String = ""
var preview_turn: int = 0
var preview_position := Vector2.INF
var snap_to_grid: bool = true
var _grab_offset := Vector2.ZERO
var _outline: MeshInstance3D
var _instances: Dictionary = {}
var _attachment_previews: Dictionary = {}
var _rings: Dictionary = {}
var _preview: Node3D
var _press_position := Vector2.INF
var _message: String = "布置"
var _environment_meshes: Array[MeshInstance3D] = []
var _triangle_meshes: Dictionary = {}
var _night_weight: float=0
var _kitchen: Dictionary={}
const Space=preload("res://scenes/environment/animal_space.gd")
const IslandSpace=preload("res://layout/island_space.gd")
const SITE_SCENERY=preload("res://layout/courtyard_plan.gd").DECORATION_SCENERY


func configure(courtyard: Node3D, farm_camera: FarmCamera, decoration_state: State) -> void:
	environment = courtyard
	camera = farm_camera
	state = decoration_state
	for id: String in environment.prepared_decorations:
		var instance: Node3D=environment.prepared_decorations[id]
		instance.reparent(self);_instances[id]=instance
	environment.prepared_decorations.clear()
	var prepared: Node=environment.get_node_or_null("PlacedDecorations")
	if prepared!=null: prepared.free()
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
	preview_position = Vector2.INF
	_cancel_press()
	_clear_preview()
	for instance: Node3D in _instances.values():
		instance.show()
	_restore_site_scenery()
	_update_grass()
	illumination_changed.emit()
	_message = "布置"
	_refresh()


func select_item(item_id: String) -> void:
	if not active:
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
	var result: Dictionary = state.can_place(selected_item, slot_id, turn,false)
	if not result.ok:
		_message = {"occupied": "这个位置已有装饰", "wrong_type": "这个位置不适合这件装饰"}.get(result.reason, "无法放在这里")
		_refresh()
		return
	if not _slot_visible(slot_id):
		_message = "这个位置被景物挡住了"
		_refresh()
		return
	preview_slot = slot_id
	preview_position = Vector2.INF
	preview_turn = turn
	for instance: Node3D in _instances.values(): instance.show()
	var created: bool=not has_preview()
	if created: _preview = _instantiate(selected_item, _preview_entry())
	else: Geometry.pose(_preview,_preview_entry(),environment.plan)
	if _instances.has(selected_item):
		_instances[selected_item].hide()
	_restore_site_scenery(slot_id)
	_message = Catalog.ITEMS[selected_item].name + " · 待确认"
	if created: illumination_changed.emit()
	_update_preview_feedback()

func has_preview() -> bool:
	return is_instance_valid(_preview)

func preview_on_ground(point: Vector2) -> void:
	if not active or selected_item.is_empty() or Catalog.ITEMS[selected_item].type!="ground" or camera.is_transitioning() or not point.is_finite(): return
	preview_position=IslandSpace.snap(point) if snap_to_grid else point
	preview_slot=""
	if not has_preview():
		_preview=_instantiate(selected_item,_preview_entry())
		illumination_changed.emit()
	else: Geometry.pose(_preview,_preview_entry(),environment.plan)
	if _instances.has(selected_item): _instances[selected_item].hide()
	_restore_site_scenery()
	_update_preview_feedback()

func _preview_entry() -> Dictionary:
	return {"slot_id":preview_slot,"position":[preview_position.x,preview_position.y] if preview_position.is_finite() else [],"quarter_turn":preview_turn}

func _update_preview_feedback() -> void:
	var issue: String=placement_issue(_preview,selected_item,preview_slot)
	_message=Catalog.ITEMS[selected_item].name+" · 待确认" if issue.is_empty() else issue
	if is_instance_valid(_outline): _outline.free()
	if Catalog.ITEMS[selected_item].type=="ground":
		var polygon: PackedVector2Array=Space.cached_footprint(_preview,environment.plan.ground_height-.08,environment.plan.ground_height+1.17)
		var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for i: int in polygon.size():
			for p: Vector2 in [polygon[i],polygon[(i+1)%polygon.size()]]: mesh.surface_add_vertex(Vector3(p.x,_preview.global_position.y+.02,p.y))
		mesh.surface_end()
		_outline=MeshInstance3D.new();_outline.mesh=mesh
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=Color("b4c589") if issue.is_empty() else Color("dc876b")
		_outline.material_override=material;add_child(_outline)
	_update_grass()
	_refresh()


func rotate_preview() -> void:
	if not active or not has_preview():
		return
	if preview_position.is_finite():
		preview_turn=(preview_turn+1)%4
		preview_on_ground(preview_position);return
	var turns: Array[int] = Catalog.allowed_turns(preview_slot)
	preview_turn = turns[(turns.find(preview_turn) + 1) % turns.size()]
	preview_at(preview_slot)


func confirm_preview() -> void:
	if not active or not has_preview() or camera.is_transitioning():
		return
	var candidate:=State.new()
	candidate.restore_snapshot(state.snapshot())
	var result: Dictionary = candidate.place_at(selected_item,preview_position,preview_turn) if preview_position.is_finite() else candidate.place(selected_item, preview_slot, preview_turn,false)
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
	# Adopt the displayed mesh only after the save succeeds; keep other objects alive.
	if has_preview() and replacement.snapshot()[selected_item] != state.snapshot()[selected_item] and State.is_placed(replacement.snapshot()[selected_item]):
		if _instances.has(selected_item): _instances[selected_item].free()
		_instances[selected_item]=_preview;_preview=null
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
	environment.decoration_data=state.snapshot()
	for item_id: String in Catalog.IDS:
		var item: Dictionary = state.snapshot()[item_id]
		if State.is_placed(item):
			if not _instances.has(item_id): _instances[item_id]=_instantiate(item_id,item)
			else: Geometry.pose(_instances[item_id],item,environment.plan)
		elif _instances.has(item_id):
			_instances[item_id].free();_instances.erase(item_id)
	_restore_site_scenery()
	_update_grass()
	update_life(_kitchen)
	var animals: Node=environment.get_node("CourtyardAnimals")
	animals.set_decorations(_instances)
	_refresh()


func lantern_anchors() -> Array[Node3D]:
	var anchors: Array[Node3D] = []
	for id: String in _instances:
		if ConstructionCatalog.has_capability(id,"light") and _instances[id].visible: anchors.append(_instances[id])
	if has_preview() and ConstructionCatalog.has_capability(selected_item,"light"): anchors.append(_preview)
	for id: String in _attachment_previews:
		if ConstructionCatalog.has_capability(id,"light"): anchors.append(_attachment_previews[id])
	return anchors

func preview_attachment(slot: String, plan: RefCounted) -> void:
	for id: String in _instances:
		var entry: Dictionary=state.snapshot()[id]
		if entry.slot_id!=slot: continue
		var created: bool=not _attachment_previews.has(id)
		if created:
			var node: Node3D=Geometry.build(environment,id);add_child(node);_attachment_previews[id]=node
		Geometry.pose(_attachment_previews[id],entry,plan)
		_instances[id].hide()
		if created: illumination_changed.emit()

func clear_attachment_preview() -> void:
	if _attachment_previews.is_empty(): return
	for id: String in _attachment_previews:
		_attachment_previews[id].free()
		if _instances.has(id): _instances[id].show()
	_attachment_previews.clear();illumination_changed.emit()

func accept_attachment_plan(plan: RefCounted) -> void:
	for id: String in _instances:
		var entry: Dictionary=state.snapshot()[id]
		if not entry.slot_id.is_empty(): Geometry.pose(_instances[id],entry,plan)
	for slot: String in _rings:
		_rings[slot].global_position=plan.slots[slot]+Vector3.UP*(.035 if slot.begins_with("ground") else -.22)
	clear_attachment_preview()

func show_save_issue() -> void:
	_message="未能保存，可重试或取消调整。"
	_refresh()

func restoration_issue(candidate: Dictionary) -> String:
	var issue: String=_restoration_issue(candidate)
	if not issue.is_empty(): return issue
	for id: String in candidate:
		var entry: Dictionary=candidate[id]
		if not State.is_placed(entry) or entry==state.snapshot()[id]: continue
		var node: Node3D=_instantiate(id,entry)
		issue=placement_issue(node,id,entry.slot_id)
		remove_child(node);node.queue_free()
		if not issue.is_empty(): return issue
	return ""


func handle_input(event: InputEvent) -> void:
	if selected_item.is_empty(): return
	if event is InputEventMouseMotion and _press_position != Vector2.INF:
		_preview_pointer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click or event.canceled or camera.is_transitioning():
			_cancel_press()
		elif event.pressed:
			_press_position = event.position
			_grab_offset=Vector2.ZERO
			var prop: Node3D=_preview if has_preview() else _instances.get(selected_item)
			if prop!=null:
				var surface: Node=environment_surface_at(event.position)
				if surface!=null and (surface==prop or prop.is_ancestor_of(surface)):
					_grab_offset=Vector2(prop.global_position.x,prop.global_position.z)-_ground_point(event.position)
					if not has_preview(): preview_turn=state.snapshot()[selected_item].quarter_turn
			_preview_pointer(event.position)
		else:
			if _press_position!=Vector2.INF: _preview_pointer(event.position)
			_cancel_press()

func _ground_point(screen: Vector2) -> Vector2:
	var origin: Vector3=camera.project_ray_origin(screen)
	var direction: Vector3=camera.project_ray_normal(screen)
	var point: Vector3=environment.plan.ground_ray(origin,direction)
	return Vector2(point.x,point.z)

func _preview_pointer(screen: Vector2) -> void:
	var slot: String=_slot_at(screen)
	if not slot.is_empty():
		if slot!=preview_slot: preview_at(slot)
	elif Catalog.ITEMS[selected_item].type=="ground":
		preview_on_ground(_ground_point(screen)+_grab_offset)
	else:
		_clear_preview();preview_slot=""
		for instance: Node3D in _instances.values(): instance.show()
		illumination_changed.emit();_message="灯笼需要挂在挂点上";_refresh()


func observe_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			if _press_position!=Vector2.INF:
				var id: String=selected_item;cancel_preview();select_item(id)


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

func refresh_path_geometry() -> void:
	_environment_meshes.assign(_environment_meshes.filter(func(mesh: Variant) -> bool: return is_instance_valid(mesh)))
	_collect_environment_meshes(environment.get_node("GardenPaths"))


func _slot_visible(slot_id: String) -> bool:
	var target: Vector3 = _rings[slot_id].global_position
	var replaced: Node=environment.get_node_or_null("LivingDetails/"+SITE_SCENERY.get(slot_id,"")) if SITE_SCENERY.has(slot_id) else null
	return world_point_visible(target,replaced)

func world_point_visible(target: Vector3,excluded: Node=null) -> bool:
	if camera.is_position_behind(target):
		return false
	# Stop just before the marker to avoid treating its own hook/support as a wall.
	var endpoint: Vector3 = target.move_toward(camera.global_position, 0.06)
	for instance: MeshInstance3D in _environment_meshes:
		if not is_instance_valid(instance): continue
		if not instance.is_visible_in_tree():
			continue
		# The selectable site replaces this object; it must not occlude its own marker.
		if excluded!=null and (instance==excluded or excluded.is_ancestor_of(instance)): continue
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


func environment_surface_at(screen_point: Vector2, extra: Node3D=null) -> MeshInstance3D:
	# Reuse the existing visibility mesh cache. A scene entrance must be the
	# actual frontmost surface, not an invisible screen rectangle behind a tree.
	var origin: Vector3=camera.project_ray_origin(screen_point)
	var endpoint: Vector3=origin+camera.project_ray_normal(screen_point)*camera.far
	var nearest: MeshInstance3D=null
	var nearest_distance: float=INF
	var surfaces: Array[Node]=environment.find_children("*","MeshInstance3D",true,false)
	if is_instance_valid(extra): surfaces.append_array(extra.find_children("*","MeshInstance3D",true,false))
	for item: Node3D in _instances.values():
		surfaces.append_array(item.find_children("*","MeshInstance3D",true,false))
	if has_preview(): surfaces.append_array(_preview.find_children("*","MeshInstance3D",true,false))
	var panorama: Node=environment.get_node_or_null("DistantRiverPanorama")
	for instance: MeshInstance3D in surfaces:
		if not instance.is_visible_in_tree() or instance.mesh==null: continue
		if instance==environment.get_water_surface() or (panorama!=null and panorama.is_ancestor_of(instance)): continue
		var inverse: Transform3D=instance.global_transform.affine_inverse()
		var start: Vector3=inverse*origin
		var end: Vector3=inverse*endpoint
		if instance.mesh.get_aabb().intersects_segment(start,end)==null: continue
		var mesh_id: int=instance.mesh.get_instance_id()
		if not _triangle_meshes.has(mesh_id): _triangle_meshes[mesh_id]=instance.mesh.generate_triangle_mesh()
		var triangles: TriangleMesh=_triangle_meshes[mesh_id]
		if triangles==null: continue
		var hit: Dictionary=triangles.intersect_segment(start,end)
		if hit.is_empty(): continue
		var distance: float=origin.distance_squared_to(instance.to_global(hit.position))
		if distance<nearest_distance:
			nearest=instance;nearest_distance=distance
	return nearest


func _instantiate(item_id: String, entry: Dictionary) -> Node3D:
	var instance: Node3D=Geometry.build(environment,item_id)
	add_child(instance)
	Geometry.pose(instance,entry,environment.plan)
	_apply_life(instance,item_id)
	return instance

func update_life(kitchen: Dictionary) -> void:
	_kitchen=kitchen
	for id: String in _instances: _apply_life(_instances[id],id)
	if has_preview(): _apply_life(_preview,selected_item)

func _apply_life(instance: Node3D, id: String) -> void:
	if id=="drying_rack":
		instance.get_node("Harvest").visible=not _kitchen.is_empty() and not _kitchen.jobs.garden_rack.is_empty()
	if id=="tea_table": instance.get_node("Tea").visible=_night_weight>.25

func set_night_weight(weight: float) -> void:
	_night_weight=weight
	update_life(_kitchen)

func placement_issue(prop: Node3D, item: String, slot: String) -> String:
	if Catalog.ITEMS[item].type!="ground": return ""
	var rise: float=environment.plan.ground_height-.13
	var polygon: PackedVector2Array=Space.cached_footprint(prop,.05+rise,1.3+rise)
	if polygon.size()<3: return "摆件没有可用的落地轮廓"
	if environment.plan.supporting_island(polygon)<0: return "这里超出了平地"
	var approach: String=preload("res://layout/bridge_passage.gd").approach_issue(environment.plan,{"candidate_decoration":polygon})
	if not approach.is_empty(): return approach
	var occupied:=IslandSpace.new()
	for key: String in environment.layout_obstacles:
		if key==SITE_SCENERY.get(slot,""): continue
		var occupied_site: bool=false
		for other: String in state.snapshot():
			if other!=item and SITE_SCENERY.get(state.snapshot()[other].slot_id,"")==key: occupied_site=true;break
		if occupied_site: continue
		occupied.add(key,environment.layout_obstacles[key])
	if not occupied.collisions(polygon).is_empty(): return "这里会碰到院中景物"
	for index: int in environment.plan.fields.size():
		if IslandSpace.overlaps(polygon,environment.plan.field_polygon(index,.12)): return "这里需要留给田地"
	for other: String in _instances:
		if other==item: continue
		var obstacle: PackedVector2Array=Space.cached_footprint(_instances[other],.05+rise,1.3+rise)
		if IslandSpace.overlaps(polygon,obstacle): return "这里会碰到其他摆件"
	if slot.is_empty():
		for route: PackedVector3Array in environment.plan.paths:
			for i: int in range(route.size()-1):
				var a:=Vector2(route[i].x,route[i].z);var b:=Vector2(route[i+1].x,route[i+1].z)
				var offset: Vector2=(b-a).normalized().orthogonal()*.3
				if IslandSpace.overlaps(polygon,PackedVector2Array([a-offset,a+offset,b+offset,b-offset])): return "这里需要留出通路"
	for span: Dictionary in environment.plan.fences:
		var a:=Vector2(span.a.x,span.a.z);var b:=Vector2(span.b.x,span.b.z)
		var offset: Vector2=(b-a).normalized().orthogonal()*.07
		if IslandSpace.overlaps(polygon,PackedVector2Array([a-offset,a+offset,b+offset,b-offset])): return "这里会碰到围栏"
	var flock_issue: String=preload("res://layout/flock_layout.gd").added_obstacle_issue(environment.plan,"hen",environment.get_node("CourtyardAnimals").yard,[polygon])
	return flock_issue if not flock_issue.is_empty() else _animal_issue(polygon)

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
		for id: String in candidate:
			var entry: Dictionary=candidate[id]
			if not State.is_placed(entry) or Catalog.ITEMS[id].type!="ground": continue
			var prop: Node3D=_instantiate(id,entry)
			var other: PackedVector2Array=Space.cached_footprint(prop,.05+rise,1.3+rise)
			prop.free()
			if IslandSpace.overlaps(polygon,other): return "原位置的景物会碰到摆件，请先移开摆件"
	return ""

func _restore_site_scenery(preview: String="") -> void:
	for slot: String in SITE_SCENERY:
		var occupied: bool=slot==preview
		var items: Dictionary=state.snapshot()
		for id: String in items:
			if has_preview() and id==selected_item: continue
			if items[id].slot_id==slot: occupied=true
		environment.get_node("LivingDetails/"+SITE_SCENERY[slot]).visible=not occupied

func _clear_preview() -> void:
	if is_instance_valid(_outline): _outline.free()
	if is_instance_valid(_preview):
		remove_child(_preview)
		_preview.queue_free()
	_preview = null


func cancel_pointer_gesture() -> void:
	_cancel_press()

func ground_footprints() -> Dictionary:
	return Geometry.footprints(_instances,environment.plan.ground_height)

func _update_grass() -> void:
	var instances: Dictionary=_instances.duplicate()
	if has_preview(): instances[selected_item]=_preview
	var footprints: Dictionary=Geometry.footprints(instances,environment.plan.ground_height)
	for path: String in ["GroundCover/CoreGrass","ExpansionGrass"]:
		var cover: Node=environment.get_node_or_null(path)
		if cover!=null:
			cover.update_objects(environment.plan,footprints.values(),path=="ExpansionGrass")


func _cancel_press() -> void:
	_press_position = Vector2.INF


func _refresh() -> void:
	if hud == null:
		return
	for slot_id: String in _rings:
		_rings[slot_id].visible = active and not selected_item.is_empty() and state.can_place(selected_item, slot_id, 0,false).ok and _slot_visible(slot_id)
	hud.present(state.snapshot(), selected_item, preview_slot, has_preview(), _message, camera.is_transitioning())
	preview_changed.emit()
