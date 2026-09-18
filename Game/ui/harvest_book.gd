extends CanvasLayer
## Read-only views and draft baskets. The scene commits every exchange to disk.
signal closed
signal share_requested(neighbor: String, round_index: int, basket: Dictionary)
signal gift_requested(neighbor: String, round_index: int, crop: String)
const Crops = preload("res://farm/crop_catalog.gd")
const Neighbors = preload("res://farm/neighbor_catalog.gd")
const Decorations = preload("res://farm/decoration_catalog.gd")
const ThemeFactory = preload("res://ui/farm_theme.gd")
var active: bool = false
var tab: String = "food"
var neighbor: String = "willow"
var _data: Dictionary = {}
var _root: Control
var _content: VBoxContainer
var _tabs: Dictionary = {}
var _draft: Dictionary = {}
var _send: Button
var _total: Label
var _fade: Tween
var _delivery: Tween

func _ready() -> void:
	layer=20
	_root=Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme=ThemeFactory.create()
	_root.theme.set_stylebox("normal","LineEdit",ThemeFactory.paper(ThemeFactory.PAPER.darkened(.025),8))
	_root.theme.set_stylebox("read_only","LineEdit",ThemeFactory.paper(ThemeFactory.PAPER.darkened(.05),8))
	_root.theme.set_color("font_color","LineEdit",ThemeFactory.INK)
	_root.theme.set_color("font_uneditable_color","LineEdit",Color("8b877a"))
	_root.mouse_force_pass_scroll_events=false
	add_child(_root)
	var shade:=ColorRect.new()
	shade.color=Color(.12,.18,.15,.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var paper:=PanelContainer.new()
	paper.name="Paper"
	_root.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paper.offset_left=-440
	paper.offset_right=440
	paper.offset_top=-258
	paper.offset_bottom=258
	var page:=VBoxContainer.new()
	paper.add_child(page)
	var header:=HBoxContainer.new()
	page.add_child(header)
	for entry: Array in [["food","菜篮"],["neighbors","邻里"]]:
		var button:=_button(header,entry[1])
		button.name=entry[0]
		button.toggle_mode=true
		button.pressed.connect(func() -> void: tab=entry[0]; _render())
		_tabs[entry[0]]=button
	var space:=Control.new()
	space.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(space)
	_button(header,"收起").pressed.connect(dismiss)
	var scroll:=ScrollContainer.new()
	scroll.name="Pages"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_content=VBoxContainer.new()
	_content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_root.hide()

func present(data: Dictionary) -> void:
	_data=data.duplicate(true)
	active=true
	_render()
	_root.show()
	_root.modulate.a=0
	if _fade: _fade.kill()
	_fade=create_tween()
	_fade.tween_property(_root,"modulate:a",1.0,.18)
	_tabs[tab].grab_focus()

func dismiss() -> void:
	if not active: return
	active=false
	if _fade: _fade.kill()
	_root.hide()
	closed.emit()

func refresh(data: Dictionary) -> void:
	_data=data.duplicate(true)
	if active: _render()

func _exit_tree() -> void:
	if _fade: _fade.kill()
	if _delivery: _delivery.kill()

func _render() -> void:
	if _delivery: _delivery.kill()
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for id: String in _tabs: _tabs[id].set_pressed_no_signal(id==tab)
	if tab=="food": _food()
	else: _neighbors()

func _food() -> void:
	_label(_content,"存有 %d 篮　·　累计收获 %d 篮"%[Crops.total_harvested(_data.inventory),Crops.total_harvested(_data.harvested)],24)
	var grid:=GridContainer.new()
	grid.columns=4
	grid.add_theme_constant_override("h_separation",14)
	grid.add_theme_constant_override("v_separation",14)
	_content.add_child(grid)
	for id: String in Crops.crop_ids():
		var item:=VBoxContainer.new()
		item.custom_minimum_size.x=188
		grid.add_child(item)
		var line:=HBoxContainer.new()
		item.add_child(line)
		_icon(line,id,56)
		var numbers:=VBoxContainer.new()
		numbers.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		line.add_child(numbers)
		_label(numbers,Crops.definition(id).name,21)
		_label(numbers,"存有 %d 篮"%_data.inventory[id],18)
		var harvested: int=_data.harvested[id]
		var mark: String="待初收" if harvested==0 else ("初收" if harvested<3 else "常种")
		_label(item,"累计 %d 篮 · %s"%[harvested,mark],17)
		_label(item,"可分享 · "+Crops.GROUPS[Crops.definition(id).group],17)
	var earned: int=Crops.total_harvested(_data.harvested)
	var kinds: int=Crops.varieties(_data.harvested)
	for id: String in Decorations.IDS:
		var rule: Dictionary=Decorations.ITEMS[id]
		_label(_content,"%s　%s"%[rule.name,"已解锁" if earned>=rule.total and kinds>=rule.varieties else Decorations.requirement(id)],18)

func _neighbors() -> void:
	var houses:=HBoxContainer.new()
	_content.add_child(houses)
	for id: String in Neighbors.IDS:
		var choose:=_button(houses,Neighbors.HOMES[id].name)
		choose.name=id
		choose.toggle_mode=true
		choose.set_pressed_no_signal(id==neighbor)
		choose.pressed.connect(func() -> void: neighbor=id; _render())
	var visit: Dictionary=_data.neighbors[neighbor]
	var round_index: int=visit.round
	if visit.pending:
		var arrival:=Control.new()
		arrival.custom_minimum_size.y=56
		_content.add_child(arrival)
		var basket:=TextureRect.new()
		basket.texture=preload("res://art/ui/basket.svg")
		basket.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		basket.size=Vector2(50,50)
		basket.mouse_filter=Control.MOUSE_FILTER_IGNORE
		arrival.add_child(basket)
		_delivery=create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_delivery.tween_property(basket,"position:x",30.0,.4)
		_label(_content,"菜篮已送达",24)
		_label(_content,Neighbors.HOMES[neighbor].thanks,22)
		var gifts:=HBoxContainer.new()
		_content.add_child(gifts)
		for crop: String in Neighbors.HOMES[neighbor].gifts:
			var column:=VBoxContainer.new()
			gifts.add_child(column)
			_icon(column,crop,80)
			var take:=_button(column,"带回一篮"+Crops.definition(crop).name)
			take.name="Gift_"+crop
			take.pressed.connect(func() -> void: gift_requested.emit(neighbor,round_index,crop))
		return
	var wish: Dictionary=Neighbors.wish(neighbor,round_index)
	_label(_content,wish.title,26)
	_label(_content,wish.letter,22)
	if not visit.last_gift.is_empty():
		_label(_content,"上次回礼 · "+Crops.definition(visit.last_gift).name+"一篮",17)
	_label(_content,"这次菜篮 · %s %d 篮"%["任意菜" if wish.group=="any" else Crops.GROUPS[wish.group],wish.amount],20)
	_draft={}
	var grid:=GridContainer.new()
	grid.columns=3
	grid.add_theme_constant_override("h_separation",16)
	_content.add_child(grid)
	for crop: String in Crops.crop_ids():
		if not Neighbors.accepts(neighbor,round_index,crop): continue
		var row:=HBoxContainer.new()
		row.custom_minimum_size.x=256
		grid.add_child(row)
		_icon(row,crop,40)
		_label(row,"%s · %d"%[Crops.definition(crop).name,_data.inventory[crop]],18)
		var number:=SpinBox.new()
		number.name="Amount_"+crop
		number.max_value=mini(wish.amount,_data.inventory[crop])
		number.custom_minimum_size.x=80
		number.editable=number.max_value>0
		row.add_child(number)
		number.value_changed.connect(func(value: float) -> void:
			if value>0: _draft[crop]=int(value)
			else: _draft.erase(crop)
			_selection(wish.amount))
	var actions:=HBoxContainer.new()
	_content.add_child(actions)
	_total=_label(actions,"",20)
	_total.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_send=_button(actions,"送出菜篮")
	_send.name="Share"
	_send.pressed.connect(func() -> void: share_requested.emit(neighbor,round_index,_draft.duplicate()))
	_selection(wish.amount)

func _selection(needed: int) -> void:
	var amount: int=0
	for count: int in _draft.values(): amount+=count
	_total.text="已选 %d / %d 篮"%[amount,needed]
	_send.disabled=amount!=needed

func _button(parent: Node, text: String) -> Button:
	var button:=Button.new()
	button.text=text
	button.custom_minimum_size.y=42
	parent.add_child(button)
	return button

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label:=Label.new()
	label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _icon(parent: Node, crop: String, extent: float) -> void:
	var image:=TextureRect.new()
	image.texture=load(Crops.icon_path(crop))
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=Vector2(extent,extent)
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
