extends CanvasLayer
## In-world draft controller. Only main commits a validated layout to disk.
signal commit_requested(snapshot: Dictionary, undo: bool)
signal closed
signal decoration_undo_requested
const Plan = preload("res://layout/courtyard_plan.gd")
const Construction = preload("res://layout/island_construction.gd")
const ThemeFactory = preload("res://ui/farm_theme.gd")
const ShorePreview=preload("res://presentation/island_shore_preview.gd")
const IslandSpace=preload("res://layout/island_space.gd")
const LandSupport=preload("res://layout/land_support.gd")
var _land_actions: HBoxContainer
var _land_buttons: Dictionary={}
var _land_erase: bool=false
var _land_support: Dictionary={}
const FieldPreview=preload("res://presentation/field_layout_preview.gd")
const TrellisPreview=preload("res://presentation/trellis_layout_preview.gd")
const BuildingPreview=preload("res://presentation/building_layout_preview.gd")
const FlockPreview=preload("res://presentation/flock_layout_preview.gd")
var flock_preview: FlockPreview
const Flocks=preload("res://layout/flock_layout.gd")
var _flock_actions: HBoxContainer
var _flock_gesture: String=""
var _flock_corner: int=0
var _flock_redraw: bool=false
const BridgePreview=preload("res://presentation/bridge_layout_preview.gd")
var bridge_preview: BridgePreview
const Routes=preload("res://layout/player_routes.gd")
const RoutePreview=preload("res://presentation/route_layout_preview.gd")
var route_preview: RoutePreview
var _route_actions: HBoxContainer
var _route_buttons: Dictionary={}
var _route_mode: String="draw"
var _route_index: int=-1
var _route_message: String=""
const Plants=preload("res://layout/plantings.gd")
const PlantPreview=preload("res://presentation/plant_layout_preview.gd")
var plant_preview: PlantPreview
var _plant_actions: HBoxContainer
var _plant_mode: String="point"
var _plant_buttons: Dictionary={}
var _plant_last:=Vector2.INF
var _plant_message: String=""
var _plant_selected: Array[int]=[]
var _plant_rotate: Button
const Buildings=preload("res://layout/building_layout.gd")
var building_preview: BuildingPreview
var _building_actions: HBoxContainer
var _building_snap: CheckButton
var _building_gesture: String=""
const Catalog=preload("res://layout/construction_catalog.gd")
const Choices=preload("res://ui/construction_choices.gd")
var choices: Choices
var _decoration_actions: HBoxContainer
var _decoration_rotate: Button
var _decoration_remove: Button
var _decoration_snap: CheckButton
var field_preview: FieldPreview
var trellis_preview: TrellisPreview
var _trellis_actions: HBoxContainer
var _trellis_snap: CheckButton
var _trellis_gesture: String=""
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
var _bridge_snap: CheckButton
var _bridge_style: OptionButton
var _bridge_style_row: HBoxContainer
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
	for entry: Array in [["columns","田块列数",2,8,1],["rows","田块行数",2,8,1],["length","架长",2,6,.1],["width","架宽",.8,2,.1],["height","架高",1.6,3,.1],["bridge_width","桥宽",.8,1.8,.1],["count","鸭子数量",0,12,1],["radius","笔刷半径",.3,3,.1],["density","疏密（1–3）",1,3,1]]:
		var row:=HBoxContainer.new();content.add_child(row);_rows[entry[0]]=row
		var label:=Label.new();label.text=entry[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
		var spin:=SpinBox.new();spin.name=entry[0];spin.min_value=entry[2];spin.max_value=entry[3];spin.step=entry[4];spin.custom_minimum_size.x=106
		if entry[0] not in ["count","columns","rows","density"]: spin.suffix="米"
		row.add_child(spin);_values[entry[0]]=spin
		spin.value_changed.connect(_parameter_changed)
	_values.radius.set_value_no_signal(1.5);_values.density.set_value_no_signal(2)
	_land_actions=HBoxContainer.new();content.add_child(_land_actions)
	for mode: String in ["add","erase"]:
		var button: Button=_button(_land_actions,"添地" if mode=="add" else "缩地",_select_land_mode.bind(mode=="erase"))
		button.name="Land"+mode.capitalize();button.toggle_mode=true;button.button_pressed=mode=="add";_land_buttons[mode]=button
	_plant_actions=HBoxContainer.new();content.add_child(_plant_actions)
	for mode: String in ["point","brush","move","erase"]:
		var button: Button=_button(_plant_actions,{"point":"点放","brush":"涂刷","move":"移动","erase":"擦除"}[mode],_select_plant_mode.bind(mode))
		button.add_theme_font_size_override("font_size",17)
		button.toggle_mode=true;button.button_pressed=mode==_plant_mode;button.name="Plant"+mode.capitalize();_plant_buttons[mode]=button
	_plant_rotate=_button(content,"旋转选中的植物",_rotate_plants);_plant_rotate.name="RotatePlants"
	_route_actions=HBoxContainer.new();content.add_child(_route_actions)
	for mode: String in ["draw","gate","erase"]:
		var button: Button=_button(_route_actions,{"draw":"绘制","gate":"出入口","erase":"移除"}[mode],_select_route_mode.bind(mode))
		button.toggle_mode=true;button.button_pressed=mode==_route_mode;button.name="Route"+mode.capitalize();_route_buttons[mode]=button
	_flock_actions=HBoxContainer.new();content.add_child(_flock_actions)
	_button(_flock_actions,"重新圈定",func() -> void: _focus_lost();_flock_redraw=true).name="DrawFlock"
	_button(_flock_actions,"自由活动",_reset_flock_area).name="ResetFlock"
	_field_actions=HBoxContainer.new();content.add_child(_field_actions)
	_button(_field_actions,"添田",func() -> void: _field_action("new")).name="AddField"
	_button(_field_actions,"旋转",func() -> void: _field_action("rotate")).name="RotateField"
	_button(_field_actions,"移除",func() -> void: _field_action("remove")).name="RemoveField"
	_trellis_actions=HBoxContainer.new();content.add_child(_trellis_actions)
	_button(_trellis_actions,"旋转",_rotate_trellis).name="RotateTrellis"
	_trellis_snap=CheckButton.new();_trellis_snap.text="吸附格子";_trellis_snap.button_pressed=true;_trellis_actions.add_child(_trellis_snap)
	_bridge_style_row=HBoxContainer.new();content.add_child(_bridge_style_row)
	var bridge_label:=Label.new();bridge_label.text="桥型";bridge_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_bridge_style_row.add_child(bridge_label)
	_bridge_style=OptionButton.new();_bridge_style.custom_minimum_size.x=106;_bridge_style_row.add_child(_bridge_style)
	for label: String in Construction.BRIDGE_STYLES: _bridge_style.add_item(label)
	_bridge_style.item_selected.connect(func(_index: int) -> void: _parameter_changed(0))
	_bridge_snap=CheckButton.new();_bridge_snap.text="吸附格子";_bridge_snap.button_pressed=true;content.add_child(_bridge_snap)
	_building_actions=HBoxContainer.new();content.add_child(_building_actions)
	_button(_building_actions,"旋转",_rotate_building).name="RotateBuilding"
	_building_snap=CheckButton.new();_building_snap.text="吸附格子";_building_snap.button_pressed=true;_building_actions.add_child(_building_snap)
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
	if id in Routes.KINDS and tool in Routes.KINDS and id!=tool:
		_focus_lost();tool=id;choices.select_item(id);_route_buttons.gate.visible=id=="fence"
		if id=="road" and _route_mode=="gate": _select_route_mode("draw")
		_refresh();return
	if id in Plants.KINDS and tool in Plants.KINDS and id!=tool:
		_focus_lost();tool=id;_plant_selected.clear();_plant_message="";choices.select_item(id);_refresh();return
	# End the previous controller before activating another; no invisible draft survives.
	tool=""
	if main.decoration_layout.active: main.decoration_layout.finish_mode()
	_clear_preview()
	_new_field=false;_field_gesture=""
	tool=id;draft=main.farm_state.snapshot().layout;_start=Vector2.INF;_drag_snapshot={};_last_cell=Vector2.INF
	_pending_land=Vector2.INF;_brush_last=Vector2.INF;_brush_message="";_plant_message="";_plant_last=Vector2.INF;_plant_selected.clear()
	choices.select_item(id);choices.present(main.decoration_state.snapshot(),busy)
	_land_actions.visible=id=="land"
	if id=="land": _land_support=LandSupport.capture(main)
	for key: String in _rows: _rows[key].visible=(id=="trellis" and key in ["length","width","height"]) or (id=="bridge" and key=="bridge_width") or (id in Flocks.TOOLS and key=="count") or (id=="fields" and key in ["columns","rows"]) or (id in Plants.KINDS and key in ["radius","density"])
	_route_actions.visible=id in Routes.KINDS;_route_buttons.gate.visible=id=="fence"
	_route_index=-1;_route_message=""
	if id=="road" and _route_mode=="gate": _select_route_mode("draw")
	_flock_actions.visible=id in Flocks.TOOLS
	_flock_redraw=false
	_plant_actions.visible=id in Plants.KINDS
	_plant_rotate.visible=id in Plants.KINDS and _plant_mode=="move"
	_field_actions.visible=id=="fields"
	_trellis_actions.visible=id=="trellis"
	_bridge_snap.visible=id=="bridge";_bridge_style_row.visible=id=="bridge"
	_bridge_style.select(Construction.bridge_style(main.courtyard_plan))
	_building_actions.visible=Buildings.BASE.has(id)
	_decoration_actions.visible=_is_decoration()
	_decoration_snap.visible=_is_decoration() and Catalog.Decorations.ITEMS[tool].type=="ground"
	selected_field=mini(selected_field,draft.fields.size()-1)
	_sync_field_controls()
	var size: Vector3=Construction.trellis_size(main.courtyard_plan)
	_values.length.set_value_no_signal(size.x);_values.width.set_value_no_signal(size.y);_values.height.set_value_no_signal(size.z)
	if id in Flocks.TOOLS:
		var kind: String=Flocks.TOOLS[id]
		_rows.count.get_child(0).text=Flocks.SPECIES[kind].name+"数量"
		_values.count.set_block_signals(true);_values.count.max_value=Flocks.SPECIES[kind].limit
		_values.count.set_value_no_signal(draft.construction.flocks[kind].count);_values.count.set_block_signals(false)
	_values.bridge_width.set_value_no_signal(1.2 if draft.construction.bridge.is_empty() else draft.construction.bridge[4])
	if _is_decoration():
		main.decoration_layout.begin_mode();main.decoration_layout.hud.hide()
		main.decoration_layout.select_item(id)
		_decoration_changed();return
	_refresh()

func _select_land_mode(erase: bool) -> void:
	_focus_lost();_land_erase=erase;_brush_message=""
	_land_buttons["add"].button_pressed=not erase;_land_buttons["erase"].button_pressed=erase
	_refresh()

func _select_route_mode(mode: String) -> void:
	_focus_lost();_route_mode=mode;_route_message=""
	for key: String in _route_buttons: _route_buttons[key].button_pressed=key==mode

func _press_route(point: Vector2) -> void:
	_route_index=-1;_route_message=""
	if _route_mode=="draw": return
	var nearest: int=-1;var distance: float=.65;var projected:=Vector2.ZERO
	for i: int in draft.routes.size():
		var entry: Dictionary=draft.routes[i]
		if entry.kind!=tool: continue
		var at: Vector2=Routes.nearest_on_line(entry,point)
		if at.distance_to(point)<distance: distance=at.distance_to(point);nearest=i;projected=at
	if nearest<0: return
	if _route_mode=="erase": draft.routes.remove_at(nearest)
	elif tool=="fence":
		var openings: Array=draft.routes[nearest].openings
		var found: int=-1
		for i: int in openings.size():
			if Routes.point(openings[i]).distance_to(projected)<Routes.GATE_HALF: found=i;break
		if found>=0: openings.remove_at(found)
		elif openings.size()<32: openings.append([float("%.4f"%projected.x),float("%.4f"%projected.y)])
	_refresh()

func _draw_route(point: Vector2) -> void:
	point=IslandSpace.snap(point)
	if point==_last_cell: return
	_last_cell=point
	var before: Array=draft.routes.duplicate(true)
	if _route_index<0:
		var start: Vector2=IslandSpace.snap(_start)
		if start==point: return
		var id: int=1
		for entry: Dictionary in draft.routes: id=maxi(id,int(entry.id)+1)
		draft.routes.append({"id":id,"kind":tool,"points":[[start.x,start.y],[point.x,point.y]],"openings":[]})
		_route_index=draft.routes.size()-1
	else:
		var points: Array=draft.routes[_route_index].points
		var end: Vector2=Routes.point(points[-1]);var previous_point: Vector2=Routes.point(points[-2])
		if end==point: return
		if absf((end-previous_point).cross(point-end))<.001 and (end-previous_point).dot(point-end)>0:
			points[-1]=[point.x,point.y]
		else: points.append([point.x,point.y])
	if not Routes.valid(draft.routes):
		draft.routes=before
		if _route_index>=draft.routes.size(): _route_index=-1
		_route_message="最多 64 笔、256 个转折点和 256 米线路；请先移除部分内容。"
	_refresh()

func _reset_flock_area() -> void:
	if busy or tool not in Flocks.TOOLS: return
	_focus_lost();draft.construction.flocks[Flocks.TOOLS[tool]].area=[];_flock_redraw=false;_refresh()

func _press_flock(point: Vector2, screen: Vector2) -> void:
	_flock_gesture="draw"
	var area: Array=draft.construction.flocks[Flocks.TOOLS[tool]].area
	if _flock_redraw or area.is_empty(): return
	var corners: PackedVector2Array=Construction.rectangle(area)
	var level: float=main.courtyard_plan.ground_height+.08 if tool=="hen" else -.21
	for i: int in corners.size():
		if main.camera.unproject_position(Vector3(corners[i].x,level,corners[i].y)).distance_to(screen)<18:
			_flock_gesture="resize";_flock_corner=i;return
	if Geometry2D.is_point_in_polygon(point,corners): _flock_gesture="move"

func _drag_flock(point: Vector2) -> void:
	var kind: String=Flocks.TOOLS[tool]
	var area: Array=_drag_snapshot.construction.flocks[kind].area
	if _flock_gesture=="move":
		var delta: Vector2=(point-_start).snapped(Vector2.ONE*.5)
		draft.construction.flocks[kind].area=[area[0]+delta.x,area[1]+delta.y,area[2],area[3]]
		return
	var start: Vector2=IslandSpace.snap(_start)
	if _flock_gesture=="resize": start=Construction.rectangle(area)[(_flock_corner+2)%4]
	var low: Vector2=start.min(point);var size: Vector2=(start-point).abs()
	draft.construction.flocks[kind].area=[low.x,low.y,maxf(.5,size.x),maxf(.5,size.y)]
	_flock_redraw=false

func _is_decoration() -> bool:
	return Catalog.Decorations.ITEMS.has(tool)

func _select_plant_mode(mode: String) -> void:
	if busy: return
	_focus_lost();_plant_mode=mode;_plant_message="";_plant_selected.clear()
	_plant_rotate.visible=mode=="move"
	for id: String in _plant_buttons: _plant_buttons[id].button_pressed=id==mode
	_refresh()

func _ensure_plant_preview() -> void:
	if is_instance_valid(plant_preview): return
	plant_preview=PlantPreview.new();main.add_child(plant_preview);plant_preview.configure(main)

func _paint_plants(point: Vector2) -> void:
	_ensure_plant_preview()
	var plan: RefCounted=Plan.from_snapshot(draft)
	if plan==null: return
	var from: Vector2=_plant_last if _plant_last.is_finite() else point
	var steps: int=mini(100,maxi(1,ceili(from.distance_to(point)/.3)))
	var samples:=PackedVector2Array([point])
	if _plant_mode!="point":
		samples.clear()
		for i: int in steps+1: samples.append(from.lerp(point,float(i)/steps))
	_plant_message=""
	var next_id: int=1
	for entry: Dictionary in draft.plants: next_id=maxi(next_id,int(entry.id)+1)
	for sample: Vector2 in samples:
		if _plant_mode=="erase":
			for i: int in range(draft.plants.size()-1,-1,-1):
				var entry: Dictionary=draft.plants[i]
				if entry.kind==tool and Plants.position(entry).distance_to(sample)<=_values.radius.value: draft.plants.remove_at(i)
			continue
		var points: PackedVector2Array=Plants.brush_points(sample,_values.radius.value,int(_values.density.value),tool) if _plant_mode=="brush" else PackedVector2Array([sample])
		for at: Vector2 in points:
			if draft.plants.size()>=Plants.MAX_CLUMPS: _plant_message="已达到 %d 簇，可擦除部分植物再布置。"%Plants.MAX_CLUMPS;break
			var near: bool=false
			for entry: Dictionary in draft.plants:
				if Plants.position(entry).distance_to(at)<(.32 if tool=="trapa" and entry.kind=="trapa" else .5): near=true;break
			if near: continue
			var entry: Dictionary=Plants.make_entry(next_id,tool,at)
			var message: String=plant_preview.entry_issue(entry,plan)
			if not message.is_empty(): _plant_message=message;continue
			draft.plants.append(entry);next_id+=1
	_plant_last=point;_refresh()

func _move_plants(point: Vector2) -> void:
	draft=_drag_snapshot.duplicate(true)
	var delta: Vector2=(point-_start).snapped(Vector2.ONE*.05)
	for entry: Dictionary in draft.plants:
		if entry.id not in _plant_selected: continue
		entry.pose[0]+=delta.x;entry.pose[1]+=delta.y
	draft.plants=Plants.canonical(draft.plants)
	_plant_last=point;_refresh()

func _rotate_plants() -> void:
	if busy or _plant_selected.is_empty(): return
	var center:=Vector2.ZERO;var count: int=0
	for entry: Dictionary in draft.plants:
		if entry.id in _plant_selected: center+=Plants.position(entry);count+=1
	if count==0: return
	center/=count
	for entry: Dictionary in draft.plants:
		if entry.id not in _plant_selected: continue
		var at: Vector2=center+(Plants.position(entry)-center).rotated(-PI/12)
		entry.pose=[at.x,at.y,fposmod(entry.pose[2]+15,360),entry.pose[3]]
	draft.plants=Plants.canonical(draft.plants);_refresh()

func _decoration_changed() -> void:
	if not active or not _is_decoration(): return
	var layout: Node=main.decoration_layout
	_status.text=layout._message
	if not main.decoration_state.snapshot()[tool].unlocked:
		var farm: Dictionary=main.farm_state.snapshot()
		_status.text=Catalog.Decorations.progress(tool,farm.harvested,farm.kitchen)
		if tool=="drying_rack": _status.text+="\n菜篮 → 厨房"
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
	elif tool=="trellis":
		var plan: RefCounted=Plan.from_snapshot(draft)
		var parameters: Array=Construction.trellis_parameters(plan if plan!=null else main.courtyard_plan)
		parameters[0]=_values.length.value;parameters[1]=_values.width.value;parameters[2]=_values.height.value
		draft.construction.trellis=parameters
	elif tool=="bridge":
		var parameters: Array=Construction.bridge_parameters(main.courtyard_plan) if draft.construction.bridge.is_empty() else draft.construction.bridge.duplicate()
		parameters[4]=_values.bridge_width.value;parameters[5]=_bridge_style.selected
		draft.construction.bridge=parameters
	elif tool in Flocks.TOOLS: draft.construction.flocks[Flocks.TOOLS[tool]].count=int(_values.count.value)
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
	if busy or candidate==null or (not issue().is_empty() and not _layout_check_pending()) or draft==main.farm_state.snapshot().layout: return
	commit_requested.emit(draft.duplicate(true),false)

func _layout_check_pending() -> bool:
	if tool in Routes.KINDS: return is_instance_valid(route_preview) and route_preview.pending and route_preview.message.is_empty()
	if tool=="bridge": return is_instance_valid(bridge_preview) and bridge_preview.pending and bridge_preview.message.is_empty()
	if tool in Flocks.TOOLS: return is_instance_valid(flock_preview) and flock_preview.pending and flock_preview.message.is_empty()
	if Buildings.BASE.has(tool): return is_instance_valid(building_preview) and building_preview.pending and building_preview.message.is_empty()
	return tool=="trellis" and is_instance_valid(trellis_preview) and trellis_preview.pending and trellis_preview.message.is_empty()

func set_busy(value: bool, message: String = "") -> void:
	busy=value
	if not value: close_after_commit=false
	_confirm.disabled=value or candidate==null or draft==main.farm_state.snapshot().layout
	_undo.disabled=value or not _has_undo()
	choices.present(main.decoration_state.snapshot(),value)
	for spin: SpinBox in _values.values(): spin.editable=not value
	_bridge_style.disabled=value;_bridge_snap.disabled=value
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
		if candidate==null or (not issue().is_empty() and not _layout_check_pending()): return
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

func accept_trellis(plan: RefCounted) -> void:
	trellis_preview.accept(plan);trellis_preview.free();trellis_preview=null
	var close_now: bool=close_after_commit
	set_busy(false);previous=main.previous_layout.duplicate(true)
	draft=plan.snapshot();candidate=plan
	if close_now:
		_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()
	else: choose(tool)

func accept_building(plan: RefCounted) -> void:
	building_preview.accept(plan);building_preview.free();building_preview=null
	var close_now: bool=close_after_commit
	set_busy(false);previous=main.previous_layout.duplicate(true)
	draft=plan.snapshot();candidate=plan
	if close_now:
		_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()
	else: choose(tool)

func accept_flock(plan: RefCounted) -> void:
	flock_preview.accept(plan);flock_preview.free();flock_preview=null
	var close_now: bool=close_after_commit
	set_busy(false);previous=main.previous_layout.duplicate(true)
	draft=plan.snapshot();candidate=plan
	if close_now:
		_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()
	else: choose(tool)

func accept_routes(plan: RefCounted) -> void:
	route_preview.accept(plan);route_preview.free();route_preview=null
	var close_now: bool=close_after_commit
	set_busy(false);previous=main.previous_layout.duplicate(true)
	draft=plan.snapshot();candidate=plan
	if close_now:
		_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()
	else: choose(tool)

func accept_bridge(plan: RefCounted) -> void:
	bridge_preview.accept(plan);bridge_preview.free();bridge_preview=null
	var close_now: bool=close_after_commit
	set_busy(false);previous=main.previous_layout.duplicate(true)
	draft=plan.snapshot();candidate=plan
	if close_now:
		_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()
	else: choose(tool)

func accept_plants(plan: RefCounted) -> void:
	plant_preview.accept(plan);plant_preview.free();plant_preview=null
	var close_now: bool=close_after_commit
	set_busy(false);previous=main.previous_layout.duplicate(true)
	draft=plan.snapshot();candidate=plan
	if close_now:
		_clear_preview();active=false;_start=Vector2.INF;hide();closed.emit()
	else: choose(tool)

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
	if draft.construction.land.is_empty(): outline=preload("res://layout/bank_geometry.gd").contour(outline)
	var from: Vector2=point if not _brush_last.is_finite() else _brush_last
	var steps: int=mini(100,maxi(1,ceili(from.distance_to(point)/.25)))
	var east: PackedVector2Array=Construction.bridge_support(main.courtyard_plan,1)
	_brush_message=""
	var visited: Dictionary={}
	for i: int in steps+1:
		var sample: Vector2=from.lerp(point,float(i)/steps)
		var cell: Vector2=Construction.brush_cell(sample)
		if visited.has(cell): continue
		visited[cell]=true
		var area: PackedVector2Array=Construction.rectangle([cell.x-.5,cell.y-.5,1.5,1.5])
		if not Geometry2D.intersect_polygons(area,east).is_empty(): continue
		var protected: bool=false
		for kind: String in ([] if _land_erase else ["duck","goose"]):
			var flock: Dictionary=draft.construction.flocks[kind]
			if flock.count>0 and not flock.area.is_empty() and IslandSpace.overlaps(area,Construction.rectangle(flock.area)): protected=true;break
		if protected: continue
		var count: int=draft.construction.land.size()
		var next: PackedVector2Array=Construction.paint(draft.construction.land,outline,sample,_land_erase)
		if _land_erase and draft.construction.land.size()>count:
			var reason: String=LandSupport.issue(LandSupport.plateau(next,main.courtyard_plan),_land_support)
			if reason.is_empty() and not main.decoration_layout._animal_issue(area).is_empty(): reason="小鸡在这里，请等它走开再缩地。"
			if not reason.is_empty():
				draft.construction.land.pop_back();_brush_message=reason;continue
		outline=next
	_brush_last=point;_last_cell=point
	if _brush_message.is_empty() and draft.construction.land.size()==before:
		_brush_message="请沿岸缩地，保留完整相连的岛屿。" if _land_erase else ("从现有岸边开始涂抹；对岸和水禽活动区域会保留。" if draft==main.farm_state.snapshot().layout else "")
	if draft.construction.land.size()>=Construction.MAX_PATCHES: _brush_message="本岛地形笔迹已达到上限。可取消当前调整。"
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
		elif tool in Plants.KINDS:
			_plant_last=world_point(event.position);_render_preview(true)
	get_viewport().set_input_as_handled()

func world_point(screen: Vector2) -> Vector2:
	var from: Vector3=main.camera.project_ray_origin(screen);var direction: Vector3=main.camera.project_ray_normal(screen)
	if direction.y>=-.001: return Vector2.INF
	var level: float=-.25 if tool in Plants.KINDS or tool in ["ducks","goose"] else main.courtyard_plan.ground_height
	var distance: float=(level-from.y)/direction.y
	if distance<0 or distance>200: return Vector2.INF
	var point: Vector3=from+direction*distance
	return Vector2(point.x,point.z)

func _press(screen: Vector2) -> void:
	if tool.is_empty(): return
	if main.camera.is_transitioning(): return
	var point: Vector2=world_point(screen)
	if not point.is_finite(): return
	_bridge_end=-1
	if tool in Flocks.TOOLS: _press_flock(point,screen)
	if tool=="fields":
		_press_field(point,screen)
		return
	if tool=="bridge":
		var points: Array[Vector3]=Construction.bridge_points(candidate if candidate!=null else main.courtyard_plan)
		var nearest: float=18
		for i: int in points.size():
			var distance: float=main.camera.unproject_position(points[i]+Vector3.UP*.12).distance_to(screen)
			if distance<nearest: nearest=distance;_bridge_end=i
		if _bridge_end<0:
			var structure: Node3D=bridge_preview.structure if is_instance_valid(bridge_preview) else main.get_node("Environment").get_bridge()
			var hit: MeshInstance3D=main.decoration_layout.environment_surface_at(screen,structure)
			if hit==null or not structure.is_ancestor_of(hit): return
	elif tool=="trellis":
		var plan: RefCounted=Plan.from_snapshot(draft)
		if plan==null: return
		var pose: Transform3D=Construction.trellis_pose(plan)
		var size: Vector3=Construction.trellis_size(plan)
		_trellis_gesture="move"
		if main.camera.unproject_position(pose*Vector3(0,.08,size.x*.5)).distance_to(screen)<18: _trellis_gesture="resize"
		elif main.camera.unproject_position(pose*Vector3(size.y*.5+.65,.08,0)).distance_to(screen)<18: _trellis_gesture="rotate"
		elif not Geometry2D.is_point_in_polygon(point,Construction.trellis_footprint(plan)):
			var structure: Node3D=trellis_preview.structure if is_instance_valid(trellis_preview) else main.get_node("Environment/EntranceTrellis")
			var hit: MeshInstance3D=main.decoration_layout.environment_surface_at(screen,structure)
			if hit==null or not structure.is_ancestor_of(hit): return
	elif Buildings.BASE.has(tool):
		var plan: RefCounted=Plan.from_snapshot(draft)
		if plan==null: return
		_building_gesture="move"
		if main.camera.unproject_position(_building_handle(plan)).distance_to(screen)<18: _building_gesture="rotate"
		else:
			var hit: MeshInstance3D=main.decoration_layout.environment_surface_at(screen)
			var selected: bool=false
			if hit!=null:
				for member: Node3D in main.get_node("Environment").building_contact_sources(tool):
					if member==hit or member.is_ancestor_of(hit): selected=true;break
			if not selected: return
	_start=point;_drag_snapshot=draft.duplicate(true);_last_cell=Vector2.INF
	if tool in Routes.KINDS:
		_press_route(point)
	elif tool=="land":
		_brush_last=point;_pending_land=point;_flush_land()
	elif tool in Plants.KINDS:
		_plant_last=point
		if _plant_mode=="move":
			_plant_selected.clear()
			for entry: Dictionary in draft.plants:
				if entry.kind==tool and Plants.position(entry).distance_to(point)<=_values.radius.value: _plant_selected.append(entry.id)
			_refresh()
		else: _paint_plants(point)

func _drag(screen: Vector2) -> void:
	var point: Vector2=world_point(screen)
	if not point.is_finite(): return
	if tool in Routes.KINDS:
		if _route_mode=="draw": _draw_route(point)
		return
	if tool in Plants.KINDS:
		if _plant_mode=="move": _move_plants(point)
		elif _plant_mode!="point": _paint_plants(point)
		return
	if tool=="fields":
		_drag_field(point)
		return
	if tool=="land":
		_pending_land=point
		return
	point=IslandSpace.snap(point) if tool in Flocks.TOOLS else point
	if point==_last_cell: return
	_last_cell=point;draft=_drag_snapshot.duplicate(true)
	match tool:
		"house","kitchen":
			var plan: RefCounted=Plan.from_snapshot(_drag_snapshot)
			var parameters: Array=Buildings.parameters(plan,tool)
			var original: Array=parameters.duplicate()
			if _building_gesture=="move":
				var delta: Vector2=(point-_start).snapped(Vector2.ONE*(.5 if _building_snap.button_pressed else .05))
				parameters[0]+=delta.x;parameters[1]+=delta.y
			else:
				var center:=Vector2(parameters[0],parameters[1])
				parameters[2]=wrapf(parameters[2]+snappedf(rad_to_deg((_start-center).angle()-(point-center).angle()),15),-180,180)
			if parameters!=original: draft.construction.buildings[tool]=parameters
		"ducks","goose","hen":
			_drag_flock(point)
		"trellis":
			var plan: RefCounted=Plan.from_snapshot(_drag_snapshot)
			var parameters: Array=Construction.trellis_parameters(plan)
			var delta: Vector2=point-_start
			if _trellis_gesture=="move":
				delta=delta.snapped(Vector2.ONE*(.5 if _trellis_snap.button_pressed else .05))
				parameters[3]+=delta.x;parameters[4]+=delta.y
			elif _trellis_gesture=="resize":
				var local: Vector3=Construction.trellis_pose(plan).basis.inverse()*Vector3(delta.x,0,delta.y)
				parameters[0]=clampf(snappedf(parameters[0]+local.z*2,.1),2,6)
			else:
				var center:=Vector2(parameters[3],parameters[4])
				parameters[5]=wrapf(parameters[5]+snappedf(rad_to_deg((_start-center).angle()-(point-center).angle()),15),-180,180)
			draft.construction.trellis=parameters
			_values.length.set_value_no_signal(draft.construction.trellis[0])
		"bridge":
			# A click is not an edit. Keep the authored bridge until a real drag,
			# and derive each movement from the press snapshot to avoid drift.
			var delta: Vector2=point-_start
			if delta.length()<.015: _refresh();return
			var ends: Array[Vector3]=Construction.bridge_points(main.courtyard_plan)
			if not draft.construction.bridge.is_empty():
				ends=[Vector3(draft.construction.bridge[0],0,draft.construction.bridge[1]),Vector3(draft.construction.bridge[2],0,draft.construction.bridge[3])]
			if _bridge_end<0:
				delta=delta.snapped(Vector2.ONE*(.5 if _bridge_snap.button_pressed else .05))
				if delta==Vector2.ZERO: _refresh();return
				# Snap the translation, never each end separately: moving a whole
				# bridge must preserve its span, heading and width at either shore.
				for i: int in ends.size(): ends[i]+=Vector3(delta.x,0,delta.y)
			else:
				point=Construction.snap_bridge_end(main.courtyard_plan,point,_bridge_end,_values.bridge_width.value)
				ends[_bridge_end]=Vector3(point.x,0,point.y)
			draft.construction.bridge=[ends[0].x,ends[0].z,ends[1].x,ends[1].z,_values.bridge_width.value,_bridge_style.selected]
	_refresh()

func issue() -> String:
	if candidate==null:
		if tool in Routes.KINDS: return "线路超出可布置范围或数量上限，请缩短后再试。"
		if tool in Plants.KINDS: return "植物位置超出布置范围，请移回小岛附近。"
		if Buildings.BASE.has(tool): return "建筑位置超出可布置范围，请移回岛内。"
		if tool=="fields": return "田块位置或大小超出范围。最多 12 块田、384 个田格，每块田最多 8 行 × 8 列；可取消后重新调整。"
		if tool in Flocks.TOOLS: return "区域边长需在 2–12 米；每只需约 %s 平方米。请扩大范围或减少数量。"%Flocks.SPECIES[Flocks.TOOLS[tool]].area
		if tool=="bridge": return "桥长需在 2 至 9 米之间，请调整桥头。"
		if tool=="trellis": return "请把菜架尺寸调回允许范围。"
		return "从现有岸边涂抹，让新土地保持连通。"
	var plants_issue: String=Plants.terrain_issue(candidate)
	if not plants_issue.is_empty(): return plants_issue
	if tool in Routes.KINDS and is_instance_valid(route_preview):
		if not route_preview.message.is_empty(): return route_preview.message
		if route_preview.pending: return "正在校对道路和围栏通路…"
	if tool in Plants.KINDS and is_instance_valid(plant_preview): return plant_preview.message
	if tool in Flocks.TOOLS and is_instance_valid(flock_preview):
		if not flock_preview.message.is_empty(): return flock_preview.message
		if flock_preview.pending: return "正在校对活动区域…"
		return ""
	if tool=="bridge" and is_instance_valid(bridge_preview):
		if not bridge_preview.message.is_empty(): return bridge_preview.message
		if bridge_preview.pending: return "正在校对桥头通路…"
	if tool=="fields" and is_instance_valid(field_preview):
		if not field_preview.message.is_empty(): return field_preview.message
		if field_preview.pending: return "正在校对田边通路…"
	if Buildings.BASE.has(tool) and is_instance_valid(building_preview):
		if not building_preview.message.is_empty(): return building_preview.message
		if building_preview.pending: return "正在校对屋前通路…"
	var bridge: String=Construction.bridge_issue(candidate)
	if not bridge.is_empty(): return bridge
	if tool=="land":
		var passage: String=preload("res://layout/bridge_passage.gd").plan_water_issue(candidate,main.get_node("Environment").layout_obstacles)
		var support_issue: String=LandSupport.issue(candidate.plateau(),_land_support) if _land_erase else ""
		if not support_issue.is_empty(): return support_issue
		if not passage.is_empty(): return passage
	var flock_issue: String=Construction.Flocks.terrain_issue(candidate)
	if not flock_issue.is_empty(): return flock_issue
	if tool=="trellis" and is_instance_valid(trellis_preview):
		if not trellis_preview.message.is_empty(): return trellis_preview.message
		if trellis_preview.pending: return "正在校对架旁通路…"

	return ""

func _refresh() -> void:
	if _is_decoration(): _decoration_changed();return
	candidate=Plan.from_snapshot(draft)
	if (tool in ["trellis","bridge"] or Buildings.BASE.has(tool)) and candidate!=null: draft=candidate.snapshot()
	if tool.is_empty():
		_status.text="";_confirm.disabled=true;_undo.disabled=not _has_undo();return
	if tool in Routes.KINDS and candidate!=null and (draft!=main.farm_state.snapshot().layout or is_instance_valid(route_preview)):
		if not is_instance_valid(route_preview):
			route_preview=RoutePreview.new();main.add_child(route_preview);route_preview.configure(main)
			route_preview.checked.connect(_routes_checked)
		route_preview.update(candidate)
	if tool in Plants.KINDS and candidate!=null:
		_ensure_plant_preview();plant_preview.update(candidate)
	if tool in Flocks.TOOLS and candidate!=null and draft!=main.farm_state.snapshot().layout:
		if not is_instance_valid(flock_preview):
			flock_preview=FlockPreview.new();main.add_child(flock_preview);flock_preview.configure(main,Flocks.TOOLS[tool])
			flock_preview.checked.connect(_flock_checked)
		flock_preview.update(candidate)
	if tool=="bridge" and candidate!=null and draft!=main.farm_state.snapshot().layout:
		if not is_instance_valid(bridge_preview):
			bridge_preview=BridgePreview.new();main.add_child(bridge_preview);bridge_preview.configure(main)
			bridge_preview.checked.connect(_bridge_checked)
		bridge_preview.update(candidate)
	if tool=="fields" and candidate!=null:
		if not is_instance_valid(field_preview):
			field_preview=FieldPreview.new();main.add_child(field_preview);field_preview.configure(main)
			field_preview.checked.connect(_field_checked)
		field_preview.update(candidate)
	if tool=="trellis" and candidate!=null and draft!=main.farm_state.snapshot().layout:
		if not is_instance_valid(trellis_preview):
			trellis_preview=TrellisPreview.new();main.add_child(trellis_preview);trellis_preview.configure(main)
			trellis_preview.checked.connect(_trellis_checked)
		trellis_preview.update(candidate)
	if Buildings.BASE.has(tool) and candidate!=null and draft!=main.farm_state.snapshot().layout:
		if not is_instance_valid(building_preview):
			building_preview=BuildingPreview.new();main.add_child(building_preview);building_preview.configure(main,tool)
			building_preview.checked.connect(_building_checked)
		building_preview.update(candidate)
	var message: String=issue()
	_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
	_undo.disabled=busy or not _has_undo()
	_status.text=message if not message.is_empty() else {"fields":"点击田块后拖动移动；圆点调大小，田外圆点转向。点添田后在空地拖出新田。","land":"按住左键沿岸涂抹，土地与水边植物实时变化。完成保存，Esc 取消。","trellis":"拖动菜架移动；圆点调长度和方向。"}.get(tool,"")
	if tool in Routes.KINDS and message.is_empty():
		_status.text=_route_message
	if tool=="land" and not _brush_message.is_empty(): _status.text=_brush_message
	if tool in Plants.KINDS and message.is_empty():
		_status.text=_plant_message if not _plant_message.is_empty() else "点放或按住左键涂刷；擦除仅作用于当前植物。已布置 %d / %d 簇。"%[draft.plants.size(),Plants.MAX_CLUMPS]
		if _plant_mode=="move": _status.text="按住拖动范围内的同种植物。调小半径可单独移动；选中后可旋转。"
	_plant_rotate.disabled=_plant_selected.is_empty() or busy
	_render_preview(message.is_empty())

func _clear_preview(keep_shore: bool=false, keep_fields: bool=false, keep_trellis: bool=false, keep_building: bool=false, keep_flock: bool=false, keep_bridge: bool=false, keep_plants: bool=false, keep_routes: bool=false) -> void:
	if not keep_routes and is_instance_valid(route_preview):
		route_preview.retire();route_preview=null
	if not keep_plants and is_instance_valid(plant_preview):
		plant_preview.free();plant_preview=null
	if not keep_bridge and is_instance_valid(bridge_preview):
		bridge_preview.retire();bridge_preview=null
	if not keep_flock and is_instance_valid(flock_preview):
		flock_preview.retire();flock_preview=null
	if not keep_building and is_instance_valid(building_preview):
		building_preview.retire();building_preview=null
	if not keep_trellis and is_instance_valid(trellis_preview):
		trellis_preview.retire();trellis_preview=null
	if not keep_fields and is_instance_valid(field_preview):
		field_preview.retire();field_preview=null
	if not keep_shore and is_instance_valid(_shore):
		_shore.restore();_shore.free();_shore=null
	if is_instance_valid(_preview): _preview.free()

func _render_preview(valid: bool) -> void:
	var changed: bool=candidate!=null and draft!=main.farm_state.snapshot().layout
	_clear_preview(tool=="land" and changed,tool=="fields",tool=="trellis" and changed,Buildings.BASE.has(tool) and changed,tool in Flocks.TOOLS and changed,tool=="bridge" and changed,tool in Plants.KINDS,tool in Routes.KINDS)
	_preview=Node3D.new();_preview.name="ConstructionPreview";main.add_child(_preview)
	var tint:=Color("88b779") if valid else Color("d77d62")
	var plan: RefCounted=candidate if candidate!=null else main.courtyard_plan
	if candidate!=null and draft!=main.farm_state.snapshot().layout:
		if tool=="land":
			if not is_instance_valid(_shore):
				_shore=ShorePreview.new();main.add_child(_shore);_shore.configure(main.get_node("Environment"))
			_shore.update(plan)
	if tool in Routes.KINDS:
		for polygon: PackedVector2Array in plan.route_footprints().values(): _outline(polygon,plan.ground_height+.06,tint,false)
	elif tool in Plants.KINDS and _plant_last.is_finite():
		var circle:=PackedVector2Array()
		var radius: float=.35 if _plant_mode=="point" else _values.radius.value
		for i: int in 32: circle.append(_plant_last+Vector2.from_angle(i*TAU/32)*radius)
		_outline(circle,-.205,tint,false)
		for entry: Dictionary in draft.plants:
			if entry.id in _plant_selected: _outline(Plants.footprint(entry),-.20,tint,false)
	elif tool=="fields" and candidate!=null:
		for index: int in candidate.fields.size():
			_outline(candidate.field_polygon(index),candidate.ground_height+.16,tint if index==selected_field else Color("b8b293"),false)
		var field: Dictionary=candidate.fields[selected_field]
		var pose: Transform3D=candidate.field_transform(selected_field)
		_handle(pose*Vector3(field.size.x*.5,.12,field.size.y*.5),tint)
		_handle(pose*Vector3(0,.12,-field.size.y*.5-.55),tint)
	elif tool=="land" and _last_cell.is_finite():
		_draw_brush(tint)
	elif tool in Flocks.TOOLS and not draft.construction.flocks[Flocks.TOOLS[tool]].area.is_empty():
		var rect: Array=draft.construction.flocks[Flocks.TOOLS[tool]].area
		if Construction.numbers(rect,4) and rect[2]<=12 and rect[3]<=12:
			var level: float=plan.ground_height+.08 if tool=="hen" else -.21
			var corners: PackedVector2Array=Construction.rectangle(rect)
			_outline(corners,level,tint,false)
			for at: Vector2 in corners: _handle(Vector3(at.x,level,at.y),tint)
	elif tool=="bridge":
		for point: Vector3 in Construction.bridge_points(plan): _handle(point+Vector3.UP*.12,tint)
	elif Buildings.BASE.has(tool):
		var parts: Dictionary={}
		for key: String in Buildings.STRUCTURES[tool]+Buildings.PROPS[tool]:
			if main.get_node("Environment").layout_obstacles.has(key): parts[key]=main.get_node("Environment").layout_obstacles[key]
		var polygon: PackedVector2Array=building_preview.footprint if is_instance_valid(building_preview) else BuildingPreview._outline(parts)
		_outline(polygon,plan.ground_height+.06,tint,false)
		_handle(_building_handle(plan),tint)
	elif tool=="trellis":
		var pose: Transform3D=Construction.trellis_pose(plan)
		var size: Vector3=Construction.trellis_size(plan)
		_outline(Construction.trellis_footprint(plan),plan.ground_height+.06,tint,false)
		_handle(pose*Vector3(0,.08,size.x*.5),tint)
		_handle(pose*Vector3(size.y*.5+.65,.08,0),tint)

func _building_handle(plan: RefCounted) -> Vector3:
	return Buildings.pose(plan,tool)*Vector3(0,.08,4.3 if tool=="house" else 3.3)

func _flock_checked() -> void:
	if not active or tool not in Flocks.TOOLS: return
	var message: String=issue()
	_status.text=message
	_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
	_render_preview(message.is_empty())

func _routes_checked() -> void:
	if not active or tool not in Routes.KINDS: return
	var message: String=issue()
	_status.text=message if not message.is_empty() else _route_message
	_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
	_render_preview(message.is_empty())

func _bridge_checked() -> void:
	if not active or tool!="bridge": return
	var message: String=issue()
	_status.text=message
	_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
	_render_preview(message.is_empty())

func _rotate_building() -> void:
	if busy: return
	var plan: RefCounted=Plan.from_snapshot(draft)
	if plan==null: return
	var parameters: Array=Buildings.parameters(plan,tool)
	parameters[2]=wrapf(parameters[2]+15,-180,180)
	draft.construction.buildings[tool]=parameters;_refresh()

func _building_checked() -> void:
	if not active or not Buildings.BASE.has(tool): return
	var message: String=issue()
	_status.text=message
	_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
	_render_preview(message.is_empty())

func _rotate_trellis() -> void:
	if busy: return
	var plan: RefCounted=Plan.from_snapshot(draft)
	if plan==null: return
	var parameters: Array=Construction.trellis_parameters(plan)
	parameters[5]=wrapf(parameters[5]+15,-180,180)
	draft.construction.trellis=parameters;_refresh()

func _trellis_checked() -> void:
	if not active or tool!="trellis": return
	var message: String=issue()
	_status.text=message if not message.is_empty() else "拖动菜架移动，圆点调整长度和方向。"
	_confirm.disabled=busy or not message.is_empty() or draft==main.farm_state.snapshot().layout
	_render_preview(message.is_empty())

func _draw_brush(tint: Color) -> void:
	if _land_erase:
		tint=Color("d77d62") if not _brush_message.is_empty() else Color("d5b979")
		_outline(PackedVector2Array([_last_cell+Vector2(-.28,0),_last_cell+Vector2(.28,0)]),main.courtyard_plan.ground_height+.06,tint,false)
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
