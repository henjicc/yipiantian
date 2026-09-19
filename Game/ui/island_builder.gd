extends CanvasLayer
## In-world draft controller. Only main commits a validated layout to disk.
signal commit_requested(snapshot: Dictionary, undo: bool)
signal closed
signal decoration_undo_requested
const Plan = preload("res://layout/courtyard_plan.gd")
const Construction = preload("res://layout/island_construction.gd")
const Structures = preload("res://layout/garden_structures.gd")
const ThemeFactory = preload("res://ui/farm_theme.gd")
const Assets = preload("res://scenes/environment/courtyard_assets.gd")
const ShorePreview=preload("res://presentation/island_shore_preview.gd")
const IslandSpace=preload("res://layout/island_space.gd")
const FieldPreview=preload("res://presentation/field_layout_preview.gd")
const Catalog=preload("res://layout/construction_catalog.gd")
const Choices=preload("res://ui/construction_choices.gd")
var choices: Choices
var _decoration_actions: HBoxContainer
var _decoration_rotate: Button
var _decoration_remove: Button
var _decoration_snap: CheckButton
var field_preview: FieldPreview
var selected_field: int=0
var _new_field: bool=false
var _field_gesture: String=""
var _field_actions: HBoxContainer
var _next_field_id: int=1
var main: Node3D
var active: bool = false
var busy: bool = false
var tool: String = "land"
var draft: Dictionary = {}
var candidate: RefCounted
var previous: Dictionary = {}
var _preview: Node3D
var _hidden: Array[Node3D] = []
var _panel: PanelContainer
var _status: Label
var _confirm: Button
var _undo: Button
var _values: Dictionary = {}
var _rows: Dictionary = {}
var _tools: Dictionary = {}
var _start:=Vector2.INF
var _drag_snapshot: Dictionary = {}
var _bridge_end: int = -1
var _pan:=Vector2.INF
var _last_cell:=Vector2.INF
var _shore: Node3D
var _brush_last:=Vector2.INF
var _pending_land:=Vector2.INF
var _brush_message: String=""
var close_after_commit: bool=false

func _ready() -> void:
	layer=15
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=ThemeFactory.create();add_child(root)
	_panel=PanelContainer.new();root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal=Control.GROW_DIRECTION_BEGIN
	_panel.offset_left=-294;_panel.offset_right=-18;_panel.offset_top=104
	_panel.add_theme_stylebox_override("panel",ThemeFactory.paper())
	var content:=VBoxContainer.new();content.add_theme_constant_override("separation",8);_panel.add_child(content)
	var title:=Label.new();title.text="布置小岛";title.add_theme_font_size_override("font_size",23);content.add_child(title)
	choices=Choices.new();content.add_child(choices);_tools=choices.items
	choices.item_selected.connect(choose)
	choices.category_selected.connect(func(_category: String) -> void: choose(""))
	for entry: Array in [["columns","田块列数",2,8,1],["rows","田块行数",2,8,1],["length","架长",2,6,.1],["width","架宽",.8,2,.1],["height","架高",1.6,3,.1],["bridge_width","桥宽",.8,1.8,.1],["count","鸭子数量",0,12,1]]:
		var row:=HBoxContainer.new();content.add_child(row);_rows[entry[0]]=row
		var label:=Label.new();label.text=entry[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		var spin:=SpinBox.new();spin.name=entry[0];spin.min_value=entry[2];spin.max_value=entry[3];spin.step=entry[4];spin.custom_minimum_size.x=106
		if entry[0] not in ["count","columns","rows"]: spin.suffix="米"
		row.add_child(spin);_values[entry[0]]=spin
		spin.value_changed.connect(_parameter_changed)
	_field_actions=HBoxContainer.new();content.add_child(_field_actions)
	_button(_field_actions,"添田",func() -> void: _field_action("new")).name="AddField"
	_button(_field_actions,"旋转",func() -> void: _field_action("rotate")).name="RotateField"
	_button(_field_actions,"移除",func() -> void: _field_action("remove")).name="RemoveField"
	_decoration_actions=HBoxContainer.new();content.add_child(_decoration_actions)
	_decoration_rotate=_button(_decoration_actions,"旋转",func() -> void: main.decoration_layout.rotate_preview())
	_decoration_remove=_button(_decoration_actions,"收起摆件",func() -> void: main.decoration_layout.remove_selected())
	_decoration_snap=CheckButton.new();_decoration_snap.text="吸附格子";content.add_child(_decoration_snap)
	_decoration_snap.button_pressed=true
	_decoration_snap.toggled.connect(func(enabled: bool) -> void:
		main.decoration_layout.snap_to_grid=enabled
		if main.decoration_layout.preview_position.is_finite(): main.decoration_layout.preview_on_ground(main.decoration_layout.preview_position))
	_status=Label.new();_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_status.custom_minimum_size=Vector2(248,48);content.add_child(_status)
	_confirm=_button(content,"确认调整",_commit);_confirm.name="Confirm"
	var actions:=HBoxContainer.new();content.add_child(actions)
	_button(actions,"取消调整",cancel_draft).name="Cancel"
	_undo=_button(actions,"撤销上次",_undo_last);_undo.name="Undo"
	_button(content,"完成",finish).name="Finish"
	get_window().focus_exited.connect(_focus_lost)
	hide()

func _button(parent: Node, label: String, action: Callable) -> Button:
	var button:=Button.new();button.text=label;button.custom_minimum_size.y=36;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(button);button.pressed.connect(action)
	return button

func begin(scene: Node3D, selected: String = "land") -> void:
	main=scene;active=true;busy=false;close_after_commit=false;previous=main.previous_layout.duplicate(true)
	if not main.decoration_layout.preview_changed.is_connected(_decoration_changed):
		main.decoration_layout.preview_changed.connect(_decoration_changed)
	for field: Dictionary in main.farm_state.snapshot().layout.fields:
		_next_field_id=maxi(_next_field_id,int(field.id.trim_prefix("field_"))+1)
	show();choose(selected)

func choose(id: String) -> void:
	if busy: return
	if not id.is_empty() and (Catalog.item(id).is_empty() or Catalog.item(id).editor.is_empty()): return
	# End the previous controller before activating another; no invisible draft survives.
	tool=""
	if main.decoration_layout.active: main.decoration_layout.finish_mode()
	_clear_preview()
	_new_field=false;_field_gesture=""
	tool=id;draft=main.farm_state.snapshot().layout;_start=Vector2.INF;_drag_snapshot={};_last_cell=Vector2.INF
	_pending_land=Vector2.INF;_brush_last=Vector2.INF;_brush_message=""
	choices.select_item(id);choices.present(main.decoration_state.snapshot(),busy)
	for key: String in _rows: _rows[key].visible=(id=="trellis" and key in ["length","width","height"]) or (id=="bridge" and key=="bridge_width") or (id=="ducks" and key=="count") or (id=="fields" and key in ["columns","rows"])
	_field_actions.visible=id=="fields"
	_decoration_actions.visible=_is_decoration()
	_decoration_snap.visible=_is_decoration() and Catalog.Decorations.ITEMS[tool].type=="ground"
	selected_field=mini(selected_field,draft.fields.size()-1)
	_sync_field_controls()
	var size: Vector3=Construction.trellis_size(main.courtyard_plan)
	_values.length.set_value_no_signal(size.x);_values.width.set_value_no_signal(size.y);_values.height.set_value_no_signal(size.z)
	_values.count.set_value_no_signal(draft.construction.ducks.count)
	_values.bridge_width.set_value_no_signal(1.2 if draft.construction.bridge.is_empty() else draft.construction.bridge[4])
	if _is_decoration():
		main.decoration_layout.begin_mode();main.decoration_layout.hud.hide()
		main.decoration_layout.select_item(id)
		_decoration_changed();return
	_refresh()

func _is_decoration() -> bool:
	return Catalog.Decorations.ITEMS.has(tool)

func _decoration_changed() -> void:
	if not active or not _is_decoration(): return
	var layout: Node=main.decoration_layout
	_status.text=layout._message
	_confirm.disabled=busy or not layout.has_preview() or main.camera.is_transitioning()
	_decoration_rotate.disabled=busy or not layout.has_preview() or (not layout.preview_slot.is_empty() and Catalog.Decorations.allowed_turns(layout.preview_slot).size()<2)
	_decoration_remove.disabled=busy or layout.selected_item.is_empty() or not preload("res://farm/decoration_state.gd").is_placed(main.decoration_state.snapshot().get(tool,{}))
	_undo.disabled=busy or not _has_undo()
	choices.present(main.decoration_state.snapshot(),busy)

func _has_undo() -> bool:
	return not previous.is_empty() or not main.previous_decorations.is_empty()

func _parameter_changed(_value: float) -> void:
	if not active or busy: return
	if tool=="fields":
		var plan: RefCounted=Plan.from_snapshot(draft)
		if plan==null: return
		var field: Dictionary=plan.fields[selected_field]
		var columns: int=int(_values.columns.value);var rows: int=int(_values.rows.value)
		plan.fields[selected_field]=Plan.resized_field(field,columns,rows,Plan.cell_span(field)*Vector2(columns,rows)+Vector2(.2,.29))
		draft=plan.snapshot()
	elif tool=="trellis": draft.construction.trellis=[_values.length.value,_values.width.value,_values.height.value]
	elif tool=="bridge":
		var points: Array[Vector3]=Construction.bridge_points(main.courtyard_plan) if draft.construction.bridge.is_empty() else Construction.bridge_points(candidate if candidate!=null else main.courtyard_plan)
		draft.construction.bridge=[points[0].x,points[0].z,points[1].x,points[1].z,_values.bridge_width.value]
	elif tool=="ducks": draft.construction.ducks.count=int(_values.count.value)
	_refresh()

func cancel_draft() -> void:
	if not busy: choose(tool)

func _undo_last() -> void:
	if busy: return
	if not main.previous_decorations.is_empty():
		decoration_undo_requested.emit();return
	if previous.is_empty(): return
	commit_requested.emit(previous.duplicate(true),true)

func _commit() -> void:
	if _is_decoration():
		main.decoration_layout.confirm_preview();return
	if busy or candidate==null or not issue().is_empty() or draft==main.farm_state.snapshot().layout: return
	commit_requested.emit(draft.duplicate(true),false)

func set_busy(value: bool, message: String = "") -> void:
	busy=value
	if not value: close_after_commit=false
	_confirm.disabled=value or candidate==null or draft==main.farm_state.snapshot().layout
	_undo.disabled=value or not _has_undo()
	choices.present(main.decoration_state.snapshot(),value)
	for spin: SpinBox in _values.values(): spin.editable=not value
	if _is_decoration(): _decoration_changed()
	if not message.is_empty(): _status.text=message

func finish() -> void:
	if busy: return
	if _is_decoration():
		var layout: Node=main.decoration_layout
		if layout.has_preview():
			layout.confirm_preview()
			if layout.has_preview(): return
		tool="";layout.finish_mode()
	_flush_land()
	if draft!=main.farm_state.snapshot().layout:
		if candidate==null or not issue().is_empty(): return
		close_after_commit=true
		_commit()
		return
	_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()

func accept_land(plan: RefCounted) -> void:
	# The live mesh is already the final result; transfer it only after disk save.
	if not is_instance_valid(_shore):
		_shore=ShorePreview.new();main.add_child(_shore);_shore.configure(main.get_node("Environment"))
		_shore.update(plan)
	_shore.accept(plan);_shore.free();_shore=null
	var close_now: bool=close_after_commit
	set_busy(false)
	previous=main.previous_layout.duplicate(true)
	choose(tool)
	if close_now: finish()

func accept_fields(plan: RefCounted) -> void:
	field_preview.accept(plan);field_preview.free();field_preview=null
	var close_now: bool=close_after_commit
	set_busy(false);previous=main.previous_layout.duplicate(true)
	draft=plan.snapshot();candidate=plan
	if close_now:
		_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()
	else: choose("fields")

func _focus_lost() -> void:
	if active and not busy:
		if _is_decoration():
			main.decoration_layout.cancel_preview();main.decoration_layout.select_item(tool);return
		if not _drag_snapshot.is_empty(): draft=_drag_snapshot;_drag_snapshot={}
		_start=Vector2.INF;_pan=Vector2.INF;_pending_land=Vector2.INF;_last_cell=Vector2.INF;_refresh()

func _process(_delta: float) -> void:
	if active and not busy and _pending_land.is_finite(): _flush_land()

func _flush_land() -> void:
	if not _pending_land.is_finite(): return
	var point: Vector2=_pending_land;_pending_land=Vector2.INF
	var before: int=draft.construction.land.size()
	var outline: PackedVector2Array=candidate.rim if candidate!=null else main.courtyard_plan.rim
	var from: Vector2=point if not _brush_last.is_finite() else _brush_last
	var steps: int=mini(100,maxi(1,ceili(from.distance_to(point)/.25)))
	var east: PackedVector2Array=Construction.bridge_support(main.courtyard_plan,1)
	var flock: Dictionary=draft.construction.ducks
	for i: int in steps+1:
		var sample: Vector2=from.lerp(point,float(i)/steps)
		var cell: Vector2=Vector2(IslandSpace.cell_at(sample))*Construction.CELL
		var area: PackedVector2Array=Construction.rectangle([cell.x-.5,cell.y-.5,1.5,1.5])
		if not Geometry2D.intersect_polygons(area,east).is_empty(): continue
		if flock.count>0 and not flock.area.is_empty() and not Geometry2D.intersect_polygons(area,Construction.rectangle(flock.area)).is_empty(): continue
		outline=Construction.paint(draft.construction.land,outline,sample)
	_brush_last=point;_last_cell=point
	_brush_message="从现有岸边开始涂抹；对岸和鸭群水域会保留。" if draft==main.farm_state.snapshot().layout and draft.construction.land.size()==before else ""
	if draft.construction.land.size()>=Construction.MAX_PATCHES: _brush_message="本岛添地范围已达到本轮上限。可取消当前调整。"
	if draft.construction.land.size()!=before: _refresh()
	elif is_instance_valid(_preview):
		for child: Node in _preview.get_children(): child.free()
		_draw_brush(Color("88b779"))
		if not _brush_message.is_empty(): _status.text=_brush_message

func observe(event: InputEvent) -> void:
	if not active or busy: return
	if _is_decoration(): main.decoration_layout.observe_input(event)
	if (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):
		if _is_decoration() and main.decoration_layout.has_preview(): cancel_draft()
		elif draft!=main.farm_state.snapshot().layout or _start!=Vector2.INF: cancel_draft()
		else: finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_MIDDLE: _pan=Vector2.INF
		if not _is_decoration() and _start!=Vector2.INF and event.button_index==MOUSE_BUTTON_LEFT and (event.canceled or _panel.get_global_rect().has_point(event.position)):
			_focus_lost()

func handle(event: InputEvent) -> void:
	if not active or busy: return
	if _is_decoration() and not (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]) and _pan==Vector2.INF:
		main.decoration_layout.handle_input(event);get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			main.camera.zoom(-.8 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8)
		elif event.button_index==MOUSE_BUTTON_MIDDLE:
			_pan=event.position if event.pressed else Vector2.INF
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: _press(event.position)
			else:
				if _start!=Vector2.INF: _drag(event.position)
				if tool=="land": _flush_land()
				_start=Vector2.INF;_drag_snapshot={}
	elif event is InputEventMouseMotion:
		if _pan!=Vector2.INF:
			main.camera.drag(event.relative,event.shift_pressed);_pan=event.position
		elif _start!=Vector2.INF: _drag(event.position)
	get_viewport().set_input_as_handled()

func world_point(screen: Vector2) -> Vector2:
	var from: Vector3=main.camera.project_ray_origin(screen);var direction: Vector3=main.camera.project_ray_normal(screen)
	if direction.y>=-.001: return Vector2.INF
	var distance: float=(main.courtyard_plan.ground_height-from.y)/direction.y
	if distance<0 or distance>200: return Vector2.INF
	var point: Vector3=from+direction*distance
	return Vector2(point.x,point.z)

func _press(screen: Vector2) -> void:
	if tool.is_empty(): return
	if main.camera.is_transitioning(): return
	var point: Vector2=world_point(screen)
	if not point.is_finite(): return
	_bridge_end=-1
	if tool=="fields":
		_press_field(point,screen)
		return
	if tool=="bridge":
		var points: Array[Vector3]=Construction.bridge_points(candidate if candidate!=null else main.courtyard_plan)
		var nearest: float=60
		for i: int in points.size():
			var distance: float=main.camera.unproject_position(points[i]).distance_to(screen)
			if distance<nearest: nearest=distance;_bridge_end=i
		if _bridge_end<0: return
	elif tool=="trellis":
		var p: Vector3=main.courtyard_plan.anchors.trellis
		if absf(point.x-p.x)>2 or absf(point.y-p.z)>4: return
	_start=point;_drag_snapshot=draft.duplicate(true);_last_cell=Vector2.INF
	if tool=="land":
		_brush_last=point;_pending_land=point;_flush_land()

func _drag(screen: Vector2) -> void:
	var point: Vector2=world_point(screen)
	if not point.is_finite(): return
	if tool=="fields":
		_drag_field(point)
		return
	if tool=="land":
		_pending_land=point
		return
	point=IslandSpace.snap(point) if tool in ["land","ducks"] else point.snapped(Vector2.ONE*.1)
	if point==_last_cell: return
	_last_cell=point;draft=_drag_snapshot.duplicate(true)
	match tool:
		"ducks":
			var start: Vector2=IslandSpace.snap(_start)
			var low: Vector2=start.min(point);var size: Vector2=(start-point).abs()
			var rect: Array=[low.x,low.y,maxf(.5,size.x),maxf(.5,size.y)]
			draft.construction.ducks.area=rect
		"trellis":
			var size: Vector3=Construction.trellis_size(main.courtyard_plan)
			draft.construction.trellis=[clampf(size.x+(point.y-_start.y)*2,2,6),_values.width.value,_values.height.value]
			_values.length.set_value_no_signal(draft.construction.trellis[0])
		"bridge":
			var ends: Array[Vector3]=Construction.bridge_points(main.courtyard_plan)
			if not draft.construction.bridge.is_empty():
				ends=[Vector3(draft.construction.bridge[0],0,draft.construction.bridge[1]),Vector3(draft.construction.bridge[2],0,draft.construction.bridge[3])]
			point=Construction.snap_bridge_end(main.courtyard_plan,point,_bridge_end,_values.bridge_width.value)
			ends[_bridge_end]=Vector3(point.x,0,point.y)
			draft.construction.bridge=[ends[0].x,ends[0].z,ends[1].x,ends[1].z,_values.bridge_width.value]
	_refresh()

func issue() -> String:
	if candidate==null:
		if tool=="fields": return "田块位置或大小超出范围。最多 12 块田、384 个田格，每块田最多 8 行 × 8 列；可取消后重新调整。"
		if tool=="ducks": return "水域至少 2 × 2 米，每只鸭子需约 3 平方米。请扩大水域或减少数量。"
		if tool=="bridge": return "桥长需在 2 至 9 米之间，请调整桥头。"
		if tool=="trellis": return "请把菜架尺寸调回允许范围。"
		return "从现有岸边涂抹，让新土地保持连通。"
	if tool=="fields" and is_instance_valid(field_preview):
		if not field_preview.message.is_empty(): return field_preview.message
		if field_preview.pending: return "正在校对田边通路…"
	var bridge: String=Construction.bridge_issue(candidate)
	if not bridge.is_empty(): return bridge
	var water_issue: String=Construction.water_area_issue(candidate)
	if not water_issue.is_empty(): return water_issue
	if not candidate.construction.trellis.is_empty():
		var size: Vector3=Construction.trellis_size(candidate)
		var at: Vector3=candidate.anchors.trellis
		var footprint: PackedVector2Array=Construction.rectangle([at.x-size.y*.5-.1,at.z-size.x*.5-.044,size.y+.2,size.x+.088])
		if not IslandSpace.supported(footprint,candidate.plateau()): return "菜架的立柱需要全部落在平地上。"
		var obstacles: Dictionary=main.get_node("Environment").layout_obstacles.duplicate()
		obstacles.merge(main.decoration_layout.ground_footprints())
		for key: String in obstacles:
			# This generated flower clump follows the candidate bed on commit.
			if key=="EntranceTrellis" or key.begins_with("Flowers0_") or key.begins_with("stone") or key.begins_with("@Node"): continue
			if IslandSpace.overlaps(footprint,obstacles[key]): return "菜架碰到了树木或旁边物件，请缩小长宽。"
	var area: Array=candidate.construction.ducks.area
	if not area.is_empty() and int(candidate.construction.ducks.count)>0:
		var rect:=Rect2(area[0],area[1],area[2],area[3])
		var clear: int=0
		for y: int in 7:
			for x: int in 7:
				var p: Vector2=rect.position+Vector2((x+.5)/7.0,(y+.5)/7.0)*rect.size
				if main.get_node("Environment/CourtyardAnimals").water.contains(p): clear+=1
		if clear<35: return "这里的水面太拥挤，请避开岛岸、桥头和密集荷花"
	return ""

func _refresh() -> void:
	if _is_decoration(): _decoration_changed();return
	candidate=Plan.from_snapshot(draft)
	if tool.is_empty():
		_status.text="";_confirm.disabled=true;_undo.disabled=not _has_undo();return
	if tool=="fields" and candidate!=null:
		if not is_instance_valid(field_preview):
			field_preview=FieldPreview.new();main.add_child(field_preview);field_preview.configure(main)
			field_preview.checked.connect(_field_checked)
		field_preview.update(candidate)
	var message: String=issue()
	_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
	_undo.disabled=busy or not _has_undo()
	_status.text=message if not message.is_empty() else {"fields":"点击田块后拖动移动；圆点调大小，田外圆点转向。点添田后在空地拖出新田。","land":"按住左键沿岸涂抹，土地与水边植物实时变化。完成保存，Esc 取消。","trellis":"拖动菜架调整长度，也可调节长宽高。","bridge":"拖动任一桥头，让两端落在岸上。","ducks":"在水面拖出活动区域，再选择数量。"}[tool]
	if tool=="land" and not _brush_message.is_empty(): _status.text=_brush_message
	_render_preview(message.is_empty())

func _clear_preview(keep_shore: bool=false, keep_fields: bool=false) -> void:
	if not keep_fields and is_instance_valid(field_preview):
		field_preview.retire();field_preview=null
	if not keep_shore and is_instance_valid(_shore):
		_shore.restore();_shore.free();_shore=null
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if is_instance_valid(_preview): _preview.free()

func _hide_node(node: Node3D) -> void:
	if node!=null and node.visible: node.hide();_hidden.append(node)

func _render_preview(valid: bool) -> void:
	_clear_preview(tool=="land" and candidate!=null and draft!=main.farm_state.snapshot().layout,tool=="fields")
	_preview=Node3D.new();_preview.name="ConstructionPreview";main.add_child(_preview)
	var tint:=Color("88b779") if valid else Color("d77d62")
	var plan: RefCounted=candidate if candidate!=null else main.courtyard_plan
	if candidate!=null and draft!=main.farm_state.snapshot().layout:
		if tool=="land":
			if not is_instance_valid(_shore):
				_shore=ShorePreview.new();main.add_child(_shore);_shore.configure(main.get_node("Environment"))
			_shore.update(plan)
		elif tool=="trellis":
			_hide_node(main.get_node("Environment/EntranceTrellis"));_preview.add_child(Structures.trellis(plan))
		elif tool=="bridge" and not plan.construction.bridge.is_empty():
			for child: Node in main.get_node("Environment").get_children():
				if child is Node3D and (child.name=="AdaptiveBridge" or child.scene_file_path.ends_with("stone_bridge.glb")): _hide_node(child)
			_preview.add_child(Structures.bridge(plan))
	if tool=="fields" and candidate!=null:
		for index: int in candidate.fields.size():
			_outline(candidate.field_polygon(index),candidate.ground_height+.16,tint if index==selected_field else Color("b8b293"),false)
		var field: Dictionary=candidate.fields[selected_field]
		var pose: Transform3D=candidate.field_transform(selected_field)
		_handle(pose*Vector3(field.size.x*.5,.12,field.size.y*.5),tint)
		_handle(pose*Vector3(0,.12,-field.size.y*.5-.55),tint)
	elif tool=="land" and _last_cell.is_finite():
		_draw_brush(tint)
	elif tool=="ducks" and not draft.construction.ducks.area.is_empty():
		var rect: Array=draft.construction.ducks.area
		if Construction.numbers(rect,4) and rect[2]<=12 and rect[3]<=12:
			_outline(Construction.rectangle(rect),-.21,tint,false)
			if valid and draft!=main.farm_state.snapshot().layout:
				for bird: Dictionary in main.get_node("Environment/CourtyardAnimals").birds:
					if bird.kind=="duck":
						_hide_node(bird.node)
						if bird.wake!=null: _hide_node(bird.wake)
				for i: int in int(draft.construction.ducks.count):
					var p:=Vector3(rect[0]+rect[2]*(.2+.6*fmod(i*.618,1)), -.45,rect[1]+rect[3]*(.2+.6*fmod(i*.382,1)))
					Assets.place(_preview,"duck",p,i*39,.8)
	elif tool=="bridge":
		for point: Vector3 in Construction.bridge_points(plan): _handle(point+Vector3.UP*.12,tint)
	elif tool=="trellis":
		_handle(plan.anchors.trellis+Vector3(0,.08,Construction.trellis_size(plan).x*.5),tint)

func _draw_brush(tint: Color) -> void:
	var circle:=PackedVector2Array()
	for i: int in 32: circle.append(_last_cell+Vector2.from_angle(i*TAU/32)*.8)
	_outline(circle,main.courtyard_plan.ground_height+.06,tint,false)

func _handle(at: Vector3, tint: Color) -> void:
	var node:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.12;sphere.height=.24;node.mesh=sphere;node.position=at
	var material:=StandardMaterial3D.new();material.albedo_color=tint;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_preview.add_child(node)

func _outline(points: PackedVector2Array, height: float, tint: Color, grid: bool) -> void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_LINES)
	for i: int in points.size():
		for p: Vector2 in [points[i],points[(i+1)%points.size()]]: surface.add_vertex(Vector3(p.x,height,p.y))
	if grid:
		var p: Vector2=points[0];var end: Vector2=points[2]
		for x: int in range(1,roundi((end.x-p.x)/Construction.CELL)):
			surface.add_vertex(Vector3(p.x+x*Construction.CELL,height,p.y));surface.add_vertex(Vector3(p.x+x*Construction.CELL,height,end.y))
		for y: int in range(1,roundi((end.y-p.y)/Construction.CELL)):
			surface.add_vertex(Vector3(p.x,height,p.y+y*Construction.CELL));surface.add_vertex(Vector3(end.x,height,p.y+y*Construction.CELL))
	var node:=MeshInstance3D.new();node.mesh=surface.commit()
	var material:=StandardMaterial3D.new();material.albedo_color=tint;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_preview.add_child(node)

func _sync_field_controls() -> void:
	if draft.is_empty(): return
	_values.columns.set_value_no_signal(draft.fields[selected_field].columns)
	_values.rows.set_value_no_signal(draft.fields[selected_field].rows)

func _field_action(action: String) -> void:
	if busy: return
	if action=="new":
		_new_field=true;_status.text="在空地按住左键，拖出一块新田。";return
	var plan: RefCounted=Plan.from_snapshot(draft)
	if plan==null: return
	if action=="rotate": plan.fields[selected_field].yaw=wrapf(plan.fields[selected_field].yaw+15,-180,180)
	elif action=="remove" and plan.fields.size()>1:
		plan.fields.remove_at(selected_field);selected_field=mini(selected_field,plan.fields.size()-1)
	draft=plan.snapshot();_sync_field_controls();_refresh()

func _field_checked() -> void:
	if active and tool=="fields":
		var message: String=issue()
		_status.text=message if not message.is_empty() else "拖动田块移动，圆点调整大小和方向。完成后保存。"
		_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
		_render_preview(message.is_empty())

func _press_field(point: Vector2, screen: Vector2) -> void:
	var plan: RefCounted=Plan.from_snapshot(draft)
	if plan==null: return
	_drag_snapshot=draft.duplicate(true);_start=point;_last_cell=Vector2.INF
	_field_gesture="move"
	if _new_field:
		if plan.fields.size()>=12: _start=Vector2.INF;_status.text="最多布置 12 块田。";return
		var field: Dictionary=Plan.new().fields[0].duplicate(true)
		var next_id: int=_next_field_id
		_next_field_id+=1
		field.id="field_%02d"%next_id;field.seed=91744+next_id*7919
		field.position=Vector3(point.x,plan.ground_height+.07,point.y)
		plan.fields.append(field);selected_field=plan.fields.size()-1
		draft=plan.snapshot();_field_gesture="new";_new_field=false
		_drag_field(point);return
	var field: Dictionary=plan.fields[selected_field]
	var pose: Transform3D=plan.field_transform(selected_field)
	var handles: Array[Vector3]=[pose*Vector3(field.size.x*.5,.12,field.size.y*.5),pose*Vector3(0,.12,-field.size.y*.5-.55)]
	for i: int in handles.size():
		if main.camera.unproject_position(handles[i]).distance_to(screen)<18:
			_field_gesture="resize" if i==0 else "rotate";return
	var found: bool=false
	for i: int in plan.fields.size():
		if Geometry2D.is_point_in_polygon(point,plan.field_polygon(i)):
			selected_field=i;found=true;break
	if not found: _start=Vector2.INF;_drag_snapshot={};return
	_sync_field_controls();_refresh()

func _drag_field(point: Vector2) -> void:
	point=point.snapped(Vector2.ONE*.05)
	if point==_last_cell: return
	_last_cell=point
	var plan: RefCounted=Plan.from_snapshot(draft if _field_gesture=="new" else _drag_snapshot)
	if plan==null: return
	var field: Dictionary=plan.fields[selected_field]
	var span: Vector2=Plan.cell_span(field)
	if _field_gesture=="move":
		var delta: Vector2=IslandSpace.snap(point-_start)
		field.position+=Vector3(delta.x,0,delta.y)
	elif _field_gesture in ["new","resize"]:
		var size: Vector2=(point-_start).abs() if _field_gesture=="new" else Vector2.ZERO
		if _field_gesture=="resize":
			var local: Vector3=plan.field_transform(selected_field).affine_inverse()*Vector3(point.x,0,point.y)
			size=Vector2(local.x,local.z).max(Vector2.ZERO)*2
		var columns: int=clampi(roundi((size.x-.2)/span.x),2,8)
		var rows: int=clampi(roundi((size.y-.29)/span.y),2,8)
		field=Plan.resized_field(field,columns,rows,span*Vector2(columns,rows)+Vector2(.2,.29))
		if _field_gesture=="new":
			var center: Vector2=_start+field.size*.5*Vector2(1 if point.x>=_start.x else -1,1 if point.y>=_start.y else -1)
			field.position=Vector3(center.x,plan.ground_height+.07,center.y)
		plan.fields[selected_field]=field
	elif _field_gesture=="rotate":
		var center:=Vector2(field.position.x,field.position.z)
		field.yaw=wrapf(field.yaw+snappedf(rad_to_deg((_start-center).angle()-(point-center).angle()),15),-180,180)
	draft=plan.snapshot();_sync_field_controls();_refresh()
