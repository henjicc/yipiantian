extends Node3D
## Owns arrangement interaction and previews, never harvest counts or disk writes.

signal confirmed
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
	var result: Dictionary = state.can_place(selected_item, slot_id, turn)
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
	_preview = _instantiate(selected_item, slot_id, turn)
	if _instances.has(selected_item):
		_instances[selected_item].hide()
	_message = Catalog.ITEMS[selected_item].name + " · 待确认"
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
	var result: Dictionary = state.place(selected_item, preview_slot, preview_turn)
	if not result.ok:
		return
	cancel_preview()
	refresh_confirmed()
	_message = "已布置"
	confirmed.emit()
	_refresh()


func refresh_confirmed() -> void:
	for instance: Node3D in _instances.values():
		remove_child(instance)
		instance.queue_free()
	_instances.clear()
	for item_id: String in Catalog.IDS:
		var item: Dictionary = state.snapshot()[item_id]
		if not item.slot_id.is_empty():
			_instances[item_id] = _instantiate(item_id, item.slot_id, item.quarter_turn)
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
	for instance: MeshInstance3D in _environment_meshes:
		if not instance.is_visible_in_tree():
			continue
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
	var packed: PackedScene = environment.get_decoration_scene(item_id)
	var instance := packed.instantiate() as Node3D
	add_child(instance)
	instance.global_transform = environment.get_slot_marker(slot_id).global_transform
	instance.rotate_object_local(Vector3.UP, turn * PI / 2.0)
	return instance


func _clear_preview() -> void:
	if is_instance_valid(_preview):
		remove_child(_preview)
		_preview.queue_free()
	_preview = null


func cancel_pointer_gesture() -> void:
	_cancel_press()


func _cancel_press() -> void:
	_press_slot = ""
	_press_position = Vector2.INF


func _refresh() -> void:
	if hud == null:
		return
	for slot_id: String in _rings:
		_rings[slot_id].visible = active and not selected_item.is_empty() and state.can_place(selected_item, slot_id, 0).ok and _slot_visible(slot_id)
	hud.present(state.snapshot(), selected_item, preview_slot, not preview_slot.is_empty(), _message, camera.is_transitioning())
