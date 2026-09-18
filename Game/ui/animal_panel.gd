extends CanvasLayer
signal closed
signal action_requested(id: String,action: String,value: Variant,revision: int)
const Companions=preload("res://farm/animal_companions.gd")
const Crops=preload("res://farm/crop_catalog.gd")
const FarmTheme=preload("res://ui/farm_theme.gd")
const ItemCard=preload("res://ui/item_card.gd")
var active: bool=false
var animal_id: String=""
var _revision: int=0
var _name: LineEdit
var _save: Button
var _picture: TextureRect
var _foods: Dictionary={}
var _crop: String="greens"
var _rest: OptionButton
var _feed: Button
var _call: Button
var _status: Label
var _root: Control
var _inventory: Dictionary={}
var _busy: bool=false
var _last_activity: String=""
func _ready() -> void:
	layer=20
	_root=Control.new();_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(_root)
	_root.theme=FarmTheme.create()
	_root.theme.set_stylebox("normal","LineEdit",FarmTheme.paper(FarmTheme.PAPER.darkened(.025),8))
	_root.theme.set_stylebox("focus","LineEdit",FarmTheme.paper(FarmTheme.PAPER.darkened(.05),8))
	_root.theme.set_color("font_color","LineEdit",FarmTheme.INK)
	var panel:=PanelContainer.new();_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left=-360;panel.offset_right=-18;panel.offset_top=-245;panel.offset_bottom=245
	var box:=VBoxContainer.new();panel.add_child(box);box.add_theme_constant_override("separation",10)
	var top:=HBoxContainer.new();box.add_child(top)
	_picture=TextureRect.new();_picture.custom_minimum_size=Vector2(90,100);_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;top.add_child(_picture)
	var words:=VBoxContainer.new();top.add_child(words);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_name=LineEdit.new();_name.name="AnimalName";_name.max_length=12;_name.custom_minimum_size.y=40;words.add_child(_name)
	_save=_button(words,"改名");_save.name="Rename"
	_save.pressed.connect(func() -> void: _send("name",_name.text.strip_edges()))
	_name.text_submitted.connect(func(value: String) -> void: _send("name",value.strip_edges()))
	_name.text_changed.connect(func(value: String) -> void: _save.disabled=not Companions.valid_name(value.strip_edges()))
	_label(box,"喜欢歇在")
	_rest=OptionButton.new();_rest.name="RestPreference";_rest.custom_minimum_size.y=38;box.add_child(_rest)
	_rest.item_selected.connect(func(index: int) -> void: _send("preference",index-1))
	var foods:=HBoxContainer.new();foods.name="LeafFood";foods.alignment=BoxContainer.ALIGNMENT_CENTER;foods.add_theme_constant_override("separation",8);box.add_child(foods)
	for id: String in Companions.FOOD:
		var card:=ItemCard.new();foods.add_child(card);card.name=id;card.toggle_mode=true
		card.configure(Crops.definition(id).name,load(Crops.icon_path(id)),Vector2(68,82),14)
		card.pressed.connect(func() -> void: _crop=id;_update_food())
		_foods[id]=card
	var actions:=HBoxContainer.new();actions.alignment=BoxContainer.ALIGNMENT_CENTER;actions.add_theme_constant_override("separation",10);box.add_child(actions)
	_call=ItemCard.new();actions.add_child(_call);_call.name="Call";_call.configure("招呼一下",null,Vector2(142,94),18)
	_call.pressed.connect(func() -> void: _send("call",null))
	_feed=ItemCard.new();actions.add_child(_feed);_feed.name="Feed";_feed.configure("撒一篮菜叶",load(Crops.icon_path("greens")),Vector2(142,94),18)
	_feed.pressed.connect(func() -> void: _send("feed",_crop))
	_status=_label(box,"");_status.custom_minimum_size.y=25
	_button(box,"收起").pressed.connect(dismiss)
	_root.hide()
func present(id: String,data: Dictionary,inventory: Dictionary) -> void:
	animal_id=id;active=true;_root.show()
	_picture.texture=load("res://art/ui/animals/%s.png"%Companions.kind(id))
	_call.get_node("Icon").texture=_picture.texture
	_rest.clear()
	for label: String in Companions.preferences(id): _rest.add_item(label)
	refresh(data,inventory)
func refresh(data: Dictionary,inventory: Dictionary) -> void:
	_revision=data.revision;_name.text=data.name;_save.disabled=false;_rest.select(data.preference+1);_status.text=""
	_inventory=inventory.duplicate()
	if inventory[_crop]==0:
		for id: String in Companions.FOOD:
			if inventory[id]>0: _crop=id;break
	_update_food();set_activity("")
func _update_food() -> void:
	for id: String in _foods:
		_foods[id].get_node("Caption").text="%s·%d"%[Crops.definition(id).name,_inventory.get(id,0)]
		_foods[id].disabled=_inventory.get(id,0)<1
		_foods[id].set_pressed_no_signal(id==_crop)
	_feed.get_node("Icon").texture=load(Crops.icon_path(_crop))
	set_activity(_last_activity)
func set_activity(status: String) -> void:
	if status!=_last_activity: _status.text=status
	_last_activity=status;_busy=not status.is_empty()
	_call.disabled=_busy
	_feed.disabled=_busy or _inventory.get(_crop,0)<1
func show_issue(text: String) -> void:
	_status.text=text
func dismiss() -> void:
	if not active: return
	active=false;_root.hide();closed.emit()
func _send(action: String,value: Variant) -> void:
	action_requested.emit(animal_id,action,value,_revision)
func _button(parent: Node,text: String) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=38;parent.add_child(button);return button
func _label(parent: Node,text: String) -> Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",19);parent.add_child(label);return label
