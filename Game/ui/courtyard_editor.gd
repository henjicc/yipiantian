extends CanvasLayer
## Draft-only UI. The scene validates geometry and atomically saves confirmed state.
signal check_requested(snapshot: Dictionary, revision: int)
signal apply_requested(snapshot: Dictionary, undo: bool)
signal closed
const Plan = preload("res://layout/courtyard_plan.gd")
const Map = preload("res://ui/courtyard_map.gd")
const Presets = preload("res://layout/courtyard_presets.gd")
const FencePreview = preload("res://ui/fence_preview.gd")
const ThemeFactory = preload("res://ui/farm_theme.gd")
var draft: RefCounted
var revision: int = 0
var active: bool = false
var busy: bool = false
var selected: int = 0
var chart: Map
var _base: Dictionary = {}
var _undo: Dictionary = {}
var _undo_draft: bool = false
var _occupied: Dictionary = {}
var _root: Control
var _selector: OptionButton
var _spacing: OptionButton
var _preset: OptionButton
var _fence: OptionButton
var _fence_preview: FencePreview
var _values: Dictionary = {}
var _message: Label
var _confirm: Button
var _undo_button: Button
var _delete_button: Button
var _debounce: Timer
var _syncing: bool = false
var _next_field: int = 1
var _checked: int = -1
var _blocks: Dictionary = {}

func _ready() -> void:
	layer=30
	_root=Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme=ThemeFactory.create()
	_root.theme.set_stylebox("normal","LineEdit",ThemeFactory.paper(ThemeFactory.PAPER.darkened(.04),8))
	_root.theme.set_stylebox("focus","LineEdit",ThemeFactory.paper(ThemeFactory.PAPER.darkened(.02),8))
	_root.theme.set_color("font_color","LineEdit",ThemeFactory.INK)
	add_child(_root)
	var shade:=ColorRect.new()
	shade.color=Color(0.12,.18,.15,.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var outer:=MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: outer.add_theme_constant_override("margin_"+side,24)
	_root.add_child(outer)
	var paper:=PanelContainer.new()
	paper.add_theme_stylebox_override("panel",ThemeFactory.paper())
	outer.add_child(paper)
	var content:=VBoxContainer.new()
	paper.add_child(content)
	var title:=Label.new()
	title.text="整理小院"
	title.add_theme_font_size_override("font_size",28)
	content.add_child(title)
	var body:=HBoxContainer.new()
	body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_child(body)
	chart=Map.new()
	chart.field_selected.connect(_select)
	chart.field_moved.connect(_move_field)
	chart.drag_finished.connect(func() -> void:
		if active and not busy: _debounce.start())
	body.add_child(chart)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size.x=300
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var controls:=VBoxContainer.new()
	controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(controls)
	_preset=OptionButton.new()
	_preset.name="Arrangement"
	_preset.add_item("选择布局")
	for label: String in Presets.NAMES: _preset.add_item(label)
	_preset.item_selected.connect(_arrange)
	controls.add_child(_preset)
	_fence=OptionButton.new()
	_fence.name="FenceStyle"
	for label: String in ["双横竹栏","交叉竹栏","细竹篱"]: _fence.add_item(label)
	_fence.item_selected.connect(_change_fence)
	controls.add_child(_fence)
	_fence_preview=FencePreview.new()
	controls.add_child(_fence_preview)
	_selector=OptionButton.new()
	_selector.item_selected.connect(_select)
	controls.add_child(_selector)
	var line:=HBoxContainer.new()
	controls.add_child(line)
	_button(line,"添一块田",_add_field)
	_delete_button=_button(line,"移除这块田",_remove_field)
	var rotations:=HBoxContainer.new()
	controls.add_child(rotations)
	_button(rotations,"向左转",func() -> void: _rotate(-15)).name="RotateLeft"
	_button(rotations,"向右转",func() -> void: _rotate(15)).name="RotateRight"
	_spacing=OptionButton.new()
	for label: String in ["株距 · 紧凑","株距 · 舒展","株距 · 宽松"]: _spacing.add_item(label)
	_spacing.item_selected.connect(_change_spacing)
	controls.add_child(_spacing)
	for row: Array in [["columns","每行几株",2,8,1],["rows","共有几行",2,8,1],["west","向西扩岸",0,8,.5],["south","向前扩岸",0,8,.5]]:
		var pair:=HBoxContainer.new()
		controls.add_child(pair)
		var label:=Label.new()
		label.text=row[1]
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		pair.add_child(label)
		var value:=SpinBox.new()
		value.min_value=row[2]
		value.max_value=row[3]
		value.step=row[4]
		value.custom_minimum_size.x=130
		if row[0] not in ["columns","rows"]: value.suffix="米"
		pair.add_child(value)
		_values[row[0]]=value
		value.value_changed.connect(func(number: float) -> void: _change(row[0],number))
	var hint:=Label.new()
	hint.text="拖动左图中的田块调整位置"
	hint.add_theme_font_size_override("font_size",17)
	controls.add_child(hint)
	_message=Label.new()
	_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.y=32
	content.add_child(_message)
	var actions:=HBoxContainer.new()
	actions.alignment=BoxContainer.ALIGNMENT_END
	content.add_child(actions)
	_undo_button=_button(actions,"撤销上次整理",_preview_undo)
	_button(actions,"还原本次修改",_reset_draft)
	_button(actions,"取消",cancel)
	_confirm=_button(actions,"确认整理",_apply)
	_debounce=Timer.new()
	_debounce.one_shot=true
	_debounce.wait_time=.3
	_debounce.timeout.connect(func() -> void:
		if active and not busy: check_requested.emit(draft.snapshot(),revision))
	add_child(_debounce)
	hide()

func present(layout: Dictionary, undo_layout: Dictionary, cells: Dictionary) -> void:
	_base=layout.duplicate(true)
	_undo=undo_layout.duplicate(true)
	_occupied=cells.duplicate(true)
	chart.occupied=_occupied
	_next_field=1
	for candidate: Dictionary in [layout,undo_layout]:
		for field: Dictionary in candidate.get("fields",[]): _next_field=maxi(_next_field,int(field.id.trim_prefix("field_"))+1)
	selected=0
	active=true
	busy=false
	show()
	_reset_draft()

func cancel() -> void:
	if busy: return
	active=false
	revision+=1
	_debounce.stop()
	chart.cancel_drag()
	hide()
	closed.emit()

func _reset_draft() -> void:
	if busy: return
	draft=Plan.from_snapshot(_base)
	_undo_draft=false
	selected=clampi(selected,0,draft.fields.size()-1)
	_changed()

func _preview_undo() -> void:
	if busy or _undo.is_empty(): return
	draft=Plan.from_snapshot(_undo)
	_undo_draft=true
	selected=0
	_changed()

func _select(index: int) -> void:
	if busy: return
	selected=index
	_sync()
	chart.selected=index
	chart.queue_redraw()

func _move_field(index: int, point: Vector2) -> void:
	if busy: return
	_undo_draft=false
	selected=index
	draft.fields[index].position=Vector3(clampf(point.x,-14,6),draft.ground_height+.07,clampf(point.y,-8,13))
	_changed()

func _arrange(index: int) -> void:
	if busy or index==0: return
	_undo_draft=false
	draft=Presets.arrange(draft,Presets.IDS[index-1])
	_preset.select(0)
	_changed()

func _change_fence(index: int) -> void:
	if busy or _syncing: return
	_undo_draft=false
	draft.fence_style=Plan.FENCE_STYLES[index]
	_changed()

func _change(key: String, value: float) -> void:
	if busy or _syncing or not active: return
	_undo_draft=false
	var field: Dictionary=draft.fields[selected]
	match key:
		"x": field.position.x=value
		"z": field.position.z=value
		"yaw": field.yaw=value
		"columns","rows":
			var columns: int=int(_values.columns.value)
			var rows: int=int(_values.rows.value)
			var span: Vector2=Plan.cell_span(field)
			draft.fields[selected]=Plan.resized_field(field,columns,rows,span*Vector2(columns,rows)+Vector2(.2,.29))
		"west","south":
			var construction: Dictionary=draft.construction.duplicate(true)
			var plants: Array=draft.plants.duplicate(true)
			var fields: Array[Dictionary]=draft.fields
			var fence_style: String=draft.fence_style
			var height: float=draft.ground_height
			var width: float=draft.bank_width
			draft=Plan.new()
			draft.expand_shore(_values.west.value,_values.south.value)
			draft.set_terrain(height,width)
			draft.fields=fields
			draft.fence_style=fence_style
			draft.plants=plants
			draft.apply_construction(construction)
	_changed()

func _rotate(amount: float) -> void:
	if busy: return
	_change("yaw",wrapf(draft.fields[selected].yaw+amount,-180,180))

func _change_spacing(index: int) -> void:
	if busy or _syncing: return
	_undo_draft=false
	var field: Dictionary=draft.fields[selected]
	var span: Vector2=[Vector2(.6,.44),Vector2(.8,.64),Vector2(1,.8)][index]
	draft.fields[selected]=Plan.resized_field(field,field.columns,field.rows,span*Vector2(field.columns,field.rows)+Vector2(.2,.29))
	_changed()

func _add_field() -> void:
	if busy or draft.fields.size()>=12: return
	_undo_draft=false
	var field: Dictionary=Plan.new().fields[0].duplicate(true)
	field.id="field_%02d"%_next_field
	field.seed=91744+_next_field*7919
	_next_field+=1
	field.position=Vector3(-3.3,draft.ground_height+.07,6.2)
	draft.fields.append(field)
	selected=draft.fields.size()-1
	_changed()

func _remove_field() -> void:
	if busy or draft.fields.size()<=1: return
	_undo_draft=false
	draft.fields.remove_at(selected)
	selected=mini(selected,draft.fields.size()-1)
	_changed()

func _changed() -> void:
	revision+=1
	_checked=-1
	draft.paths.clear()
	draft.fences.clear()
	_confirm.disabled=true
	_message.text="正在校对位置与通路…"
	_sync()
	chart.present(draft,_blocks,selected,[])
	if chart.is_dragging(): _debounce.stop()
	else: _debounce.start()

func _sync() -> void:
	_syncing=true
	_selector.clear()
	for i: int in draft.fields.size(): _selector.add_item("第 %d 块田"%(i+1))
	_selector.select(selected)
	_fence.select(Plan.FENCE_STYLES.find(draft.fence_style))
	_fence_preview.show_style(draft.fence_style)
	var field: Dictionary=draft.fields[selected]
	var span: Vector2=Plan.cell_span(field)
	_spacing.select(0 if span.x<.7 else (1 if span.x<.9 else 2))
	var values: Dictionary={"columns":field.columns,"rows":field.rows,"west":draft.shore_expansion.x,"south":draft.shore_expansion.y}
	for key: String in values: _values[key].set_value_no_signal(values[key])
	_undo_button.disabled=_undo.is_empty()
	_delete_button.disabled=draft.fields.size()<=1
	_syncing=false

func checked(version: int, checked_plan: RefCounted, blocks: Dictionary, issues: Array[String], message: String) -> void:
	if not active or version!=revision: return
	_checked=version
	_blocks=blocks
	if checked_plan!=null:
		draft.paths=checked_plan.paths
		draft.fences=checked_plan.fences
	chart.present(draft,blocks,selected,issues)
	_message.text=message
	_confirm.disabled=not issues.is_empty() or draft.snapshot()==_base

func _apply() -> void:
	if busy or _checked!=revision or _confirm.disabled: return
	apply_requested.emit(draft.snapshot(),_undo_draft)

func set_busy(value: bool, message: String="") -> void:
	busy=value
	chart.cancel_drag()
	_root.mouse_filter=Control.MOUSE_FILTER_STOP
	_block_controls(_root,value)
	if not message.is_empty(): _message.text=message
	if not value:
		_sync()
		_confirm.disabled=_checked!=revision or not chart.invalid.is_empty() or draft.snapshot()==_base

func _block_controls(node: Node, value: bool) -> void:
	if node is BaseButton: node.disabled=value
	if node is SpinBox: node.editable=not value
	for child: Node in node.get_children(): _block_controls(child,value)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size.y=46
	button.pressed.connect(action)
	parent.add_child(button)
	return button
