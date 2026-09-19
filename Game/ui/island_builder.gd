extends CanvasLayer
## In-world draft controller. Only main commits a validated layout to disk.
signal commit_requested(snapshot: Dictionary, undo: bool)
signal closed
const Plan = preload("res://layout/courtyard_plan.gd")
const Construction = preload("res://layout/island_construction.gd")
const Structures = preload("res://layout/garden_structures.gd")
const Bank = preload("res://layout/bank_geometry.gd")
const ThemeFactory = preload("res://ui/farm_theme.gd")
const Assets = preload("res://scenes/environment/courtyard_assets.gd")
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

func _ready() -> void:
	layer=15
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=ThemeFactory.create();add_child(root)
	_panel=PanelContainer.new();root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal=Control.GROW_DIRECTION_BEGIN
	_panel.offset_left=-270;_panel.offset_right=-18;_panel.offset_top=104
	_panel.add_theme_stylebox_override("panel",ThemeFactory.paper())
	var content:=VBoxContainer.new();content.add_theme_constant_override("separation",8);_panel.add_child(content)
	var title:=Label.new();title.text="布置小岛";title.add_theme_font_size_override("font_size",23);content.add_child(title)
	var choices:=GridContainer.new();choices.columns=2;content.add_child(choices)
	for entry: Array in [["land","添地"],["trellis","菜架"],["bridge","桥梁"],["ducks","鸭群"]]:
		var id: String=entry[0]
		var button: Button=_button(choices,entry[1],func() -> void: choose(id))
		button.name=id.capitalize();button.toggle_mode=true;_tools[id]=button
	for entry: Array in [["length","架长",2,6,.1],["width","架宽",.8,2,.1],["height","架高",1.6,3,.1],["bridge_width","桥宽",.8,1.8,.1],["count","鸭子数量",0,12,1]]:
		var row:=HBoxContainer.new();content.add_child(row);_rows[entry[0]]=row
		var label:=Label.new();label.text=entry[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		var spin:=SpinBox.new();spin.name=entry[0];spin.min_value=entry[2];spin.max_value=entry[3];spin.step=entry[4];spin.custom_minimum_size.x=106
		if entry[0]!="count": spin.suffix="米"
		row.add_child(spin);_values[entry[0]]=spin
		spin.value_changed.connect(_parameter_changed)
	_status=Label.new();_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_status.custom_minimum_size=Vector2(224,72);content.add_child(_status)
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
	main=scene;active=true;busy=false;previous=main.previous_layout.duplicate(true)
	show();choose(selected)

func choose(id: String) -> void:
	if busy: return
	tool=id;draft=main.farm_state.snapshot().layout;_start=Vector2.INF;_drag_snapshot={};_last_cell=Vector2.INF
	for key: String in _tools: _tools[key].set_pressed_no_signal(key==id)
	for key: String in _rows: _rows[key].visible=(id=="trellis" and key in ["length","width","height"]) or (id=="bridge" and key=="bridge_width") or (id=="ducks" and key=="count")
	var size: Vector3=Construction.trellis_size(main.courtyard_plan)
	_values.length.set_value_no_signal(size.x);_values.width.set_value_no_signal(size.y);_values.height.set_value_no_signal(size.z)
	_values.count.set_value_no_signal(draft.construction.ducks.count)
	_values.bridge_width.set_value_no_signal(1.2 if draft.construction.bridge.is_empty() else draft.construction.bridge[4])
	_refresh()

func _parameter_changed(_value: float) -> void:
	if not active or busy: return
	if tool=="trellis": draft.construction.trellis=[_values.length.value,_values.width.value,_values.height.value]
	elif tool=="bridge":
		var points: Array[Vector3]=Construction.bridge_points(main.courtyard_plan) if draft.construction.bridge.is_empty() else Construction.bridge_points(candidate if candidate!=null else main.courtyard_plan)
		draft.construction.bridge=[points[0].x,points[0].z,points[1].x,points[1].z,_values.bridge_width.value]
	elif tool=="ducks": draft.construction.ducks.count=int(_values.count.value)
	_refresh()

func cancel_draft() -> void:
	if not busy: choose(tool)

func _undo_last() -> void:
	if busy or previous.is_empty(): return
	commit_requested.emit(previous.duplicate(true),true)

func _commit() -> void:
	if busy or candidate==null or not issue().is_empty() or draft==main.farm_state.snapshot().layout: return
	commit_requested.emit(draft.duplicate(true),false)

func set_busy(value: bool, message: String = "") -> void:
	busy=value
	_confirm.disabled=value or candidate==null or draft==main.farm_state.snapshot().layout
	_undo.disabled=value or previous.is_empty()
	for button: Button in _tools.values(): button.disabled=value
	for spin: SpinBox in _values.values(): spin.editable=not value
	if not message.is_empty(): _status.text=message

func finish() -> void:
	if busy: return
	_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()

func _focus_lost() -> void:
	if active and not busy:
		if not _drag_snapshot.is_empty(): draft=_drag_snapshot;_drag_snapshot={}
		_start=Vector2.INF;_pan=Vector2.INF;_refresh()

func observe(event: InputEvent) -> void:
	if not active or busy: return
	if (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):
		if draft!=main.farm_state.snapshot().layout or _start!=Vector2.INF: cancel_draft()
		else: finish()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_MIDDLE: _pan=Vector2.INF
		if event.button_index==MOUSE_BUTTON_LEFT and (event.canceled or _panel.get_global_rect().has_point(event.position)):
			_focus_lost()

func handle(event: InputEvent) -> void:
	if not active or busy: return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			main.camera.zoom(-.8 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8)
		elif event.button_index==MOUSE_BUTTON_MIDDLE:
			_pan=event.position if event.pressed else Vector2.INF
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: _press(event.position)
			else:
				if _start!=Vector2.INF: _drag(event.position)
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
	var point: Vector2=world_point(screen)
	if not point.is_finite(): return
	_bridge_end=-1
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

func _drag(screen: Vector2) -> void:
	var point: Vector2=world_point(screen)
	if not point.is_finite(): return
	point=point.snapped(Vector2.ONE*Construction.CELL) if tool in ["land","ducks"] else point.snapped(Vector2.ONE*.1)
	if point==_last_cell: return
	_last_cell=point;draft=_drag_snapshot.duplicate(true)
	match tool:
		"land","ducks":
			var start: Vector2=_start.snapped(Vector2.ONE*Construction.CELL)
			var low: Vector2=start.min(point);var size: Vector2=(start-point).abs()
			var rect: Array=[low.x,low.y,maxf(.5,size.x),maxf(.5,size.y)]
			if tool=="land": draft.construction.land.append(rect)
			else: draft.construction.ducks.area=rect
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
		if tool=="ducks": return "水域至少 2 × 2 米，每只鸭子需约 3 平方米。请扩大水域或减少数量。"
		if tool=="bridge": return "桥长需在 2 至 9 米之间，请调整桥头。"
		if tool=="trellis": return "请把菜架尺寸调回允许范围。"
		return "添地需与岸边重叠，单次不超过 5 × 5 米，最多添加 16 块。"
	var bridge: String=Construction.bridge_issue(candidate)
	if not bridge.is_empty(): return bridge
	if not candidate.construction.trellis.is_empty():
		var size: Vector3=Construction.trellis_size(candidate)
		var at: Vector3=candidate.anchors.trellis
		var footprint: PackedVector2Array=Construction.rectangle([at.x-size.y*.5-.1,at.z-size.x*.5-.044,size.y+.2,size.x+.088])
		if not Geometry2D.clip_polygons(footprint,candidate.plateau()).is_empty(): return "菜架的立柱需要全部落在平地上。"
		var obstacles: Dictionary=main.get_node("Environment").layout_obstacles.duplicate()
		obstacles.merge(main.decoration_layout.ground_footprints())
		for key: String in obstacles:
			# This generated flower clump follows the candidate bed on commit.
			if key=="EntranceTrellis" or key.begins_with("Flowers0_") or key.begins_with("stone") or key.begins_with("@Node"): continue
			if not Geometry2D.intersect_polygons(footprint,obstacles[key]).is_empty(): return "菜架碰到了树木或旁边物件，请缩小长宽。"
	var area: Array=candidate.construction.ducks.area
	if not area.is_empty() and int(candidate.construction.ducks.count)>0:
		var rect:=Rect2(area[0],area[1],area[2],area[3])
		var clear: int=0
		for y: int in 7:
			for x: int in 7:
				var p: Vector2=rect.position+Vector2((x+.5)/7.0,(y+.5)/7.0)*rect.size
				if Geometry2D.is_point_in_polygon(p,candidate.rim): return "鸭群活动区域需要留在水面上"
				if main.get_node("Environment/CourtyardAnimals").water.contains(p): clear+=1
		if clear<35: return "这里的水面太拥挤，请避开岛岸、桥头和密集荷花"
	return ""

func _refresh() -> void:
	candidate=Plan.from_snapshot(draft)
	var message: String=issue()
	_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
	_undo.disabled=busy or previous.is_empty()
	_status.text=message if not message.is_empty() else {"land":"沿岸拖出添地范围，确认后生效。","trellis":"拖动菜架调整长度，也可调节长宽高。","bridge":"拖动任一桥头，让两端落在岸上。","ducks":"在水面拖出活动区域，再选择数量。"}[tool]
	_render_preview(message.is_empty())

func _clear_preview() -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if is_instance_valid(_preview): _preview.free()

func _hide_node(node: Node3D) -> void:
	if node!=null and node.visible: node.hide();_hidden.append(node)

func _render_preview(valid: bool) -> void:
	_clear_preview()
	_preview=Node3D.new();_preview.name="ConstructionPreview";main.add_child(_preview)
	var tint:=Color("88b779") if valid else Color("d77d62")
	var plan: RefCounted=candidate if candidate!=null else main.courtyard_plan
	if candidate!=null and draft!=main.farm_state.snapshot().layout:
		if tool=="land":
			var old: Node3D=main.get_node("Environment/MainBank")
			_hide_node(old)
			var mesh:=MeshInstance3D.new();mesh.mesh=Bank.build(plan.rim,plan.ground_height,plan.bank_width)
			mesh.material_override=old.get_child(0).get_active_material(0);mesh.set_layer_mask_value(2,true);_preview.add_child(mesh)
			var environment: Node3D=main.get_node("Environment")
			for node: Node in environment.get_children():
				if node is Node3D and (node.has_meta("shore_stone") or node.name=="NewShorePlants"): _hide_node(node)
			for entry: Dictionary in preload("res://presentation/shore_dressing.gd").stones(plan):
				var rock: Node3D=(load("res://art/environment/modules/"+entry.asset+".glb") as PackedScene).instantiate()
				_preview.add_child(rock);rock.position=entry.at;rock.rotation.y=deg_to_rad(entry.yaw);rock.scale=entry.size
				environment._apply_pigment(rock,entry.asset);environment._tint_stone(rock,entry.color)
			_preview.add_child(preload("res://presentation/shore_dressing.gd").plants(plan))
		elif tool=="trellis":
			_hide_node(main.get_node("Environment/EntranceTrellis"));_preview.add_child(Structures.trellis(plan))
		elif tool=="bridge" and not plan.construction.bridge.is_empty():
			for child: Node in main.get_node("Environment").get_children():
				if child is Node3D and (child.name=="AdaptiveBridge" or child.scene_file_path.ends_with("stone_bridge.glb")): _hide_node(child)
			_preview.add_child(Structures.bridge(plan))
	if tool=="land" and not draft.construction.land.is_empty():
		var rect: Array=draft.construction.land[-1]
		if Construction.numbers(rect,4) and rect[2]<=5 and rect[3]<=5:
			_outline(Construction.rectangle(rect),main.courtyard_plan.ground_height+.08,tint,true)
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
