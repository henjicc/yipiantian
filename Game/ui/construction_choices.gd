extends VBoxContainer
signal category_selected(category: String)
signal item_selected(id: String)
const Catalog = preload("res://layout/construction_catalog.gd")
const ItemCard = preload("res://ui/item_card.gd")
var categories: Dictionary = {}
var items: Dictionary = {}
var category: String = "land"
var selected: String = ""

func _ready() -> void:
	add_theme_constant_override("separation",8)
	var navigation := GridContainer.new();navigation.columns=2;add_child(navigation)
	for id: String in Catalog.CATEGORIES:
		var button := Button.new();button.text=Catalog.CATEGORIES[id];button.name=id.capitalize()
		button.toggle_mode=true;button.custom_minimum_size.y=30;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		navigation.add_child(button);categories[id]=button
		button.pressed.connect(func() -> void:
			show_category(id);category_selected.emit(id))
	var grid := GridContainer.new();grid.columns=2;grid.name="Items";add_child(grid)
	for id: String in Catalog.ids():
		var definition: Dictionary=Catalog.item(id)
		var card := ItemCard.new();grid.add_child(card)
		card.configure(definition.name,load(definition.icon),Vector2(120,84),17)
		card.name=id.capitalize();card.toggle_mode=true;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.pressed.connect(func() -> void: item_selected.emit(id))
		items[id]=card
	show_category(category)

func show_category(id: String) -> void:
	category=id
	for key: String in categories: categories[key].set_pressed_no_signal(key==id)
	for key: String in items: items[key].visible=Catalog.item(key).category==id

func select_item(id: String) -> void:
	selected=id
	if not id.is_empty(): show_category(Catalog.item(id).category)
	for key: String in items: items[key].set_pressed_no_signal(key==id)

func present(decorations: Dictionary, busy: bool) -> void:
	for button: Button in categories.values(): button.disabled=busy
	for id: String in items:
		var card: ItemCard=items[id]
		var definition: Dictionary=Catalog.item(id)
		var entry: Dictionary=decorations.get(id,{})
		card.show_state(not entry.get("slot_id","").is_empty(),entry.get("unlocked",true))
		card.disabled=busy or definition.editor.is_empty()
		if definition.editor.is_empty(): card._badge.text="暂不可布置"
