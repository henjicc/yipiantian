extends RefCounted
## Kitchen page uses the same modal book; only drafts and display controls live here.
const Kitchen=preload("res://farm/kitchen.gd")
const Crops=preload("res://farm/crop_catalog.gd")
const Neighbors=preload("res://farm/neighbor_catalog.gd")
const ItemCard=preload("res://ui/item_card.gd")
var recipe: String="leaf_stir"
var crop: String="greens"
var recipient: String="willow"
var _timers: Array[Dictionary]=[]

func render(book: Node, data: Dictionary, journal: bool, now: float) -> void:
	_timers.clear()
	var page: VBoxContainer=book._content
	var state: Dictionary=data.kitchen
	if journal:
		_journal(book,page,state)
		return
	var stations:=HBoxContainer.new()
	page.add_child(stations)
	for station: String in Kitchen.STATIONS:
		var column:=VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		stations.add_child(column)
		var job: Dictionary=state.jobs[station]
		book._label(column,Kitchen.STATION_NAMES[station],23)
		if job.is_empty():
			book._label(column,"空闲",19)
		else:
			var text: Label=book._label(column,Kitchen.RECIPES[job.recipe].name,19)
			var collect: Button=book._button(column,"收起成品")
			collect.name="Collect_"+station
			collect.pressed.connect(func() -> void: book.kitchen_requested.emit("collect",{"station":station},int(state.revision)))
			_timers.append({"label":text,"button":collect,"job":job})
	var choices:=GridContainer.new()
	choices.columns=3
	page.add_child(choices)
	for id: String in Kitchen.RECIPES:
		var button:=ItemCard.new()
		choices.add_child(button)
		button.configure(Kitchen.RECIPES[id].name,load("res://art/ui/kitchen/%s.png"%Kitchen.RECIPES[id].asset),Vector2(140,100),18)
		button.name="Recipe_"+id
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.toggle_mode=true
		button.set_pressed_no_signal(recipe==id)
		button.pressed.connect(func() -> void: recipe=id; book._render())
	var rule: Dictionary=Kitchen.RECIPES[recipe]
	var preview:=HBoxContainer.new()
	page.add_child(preview)
	_icon(preview,rule.asset,120)
	var details:=VBoxContainer.new()
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	preview.add_child(details)
	book._label(details,rule.name,26)
	book._label(details,rule.method,21)
	book._label(details,"一篮食材 · 一份成品 · 约%d秒"%rule.seconds,19)
	var eligible: Array[String]=[]
	for id: String in Crops.crop_ids():
		if Kitchen.accepts(recipe,id): eligible.append(id)
	if crop not in eligible:
		crop=eligible[0]
		for id: String in eligible:
			if data.inventory[id]>0: crop=id; break
	var ingredients:=OptionButton.new()
	ingredients.name="KitchenIngredient"
	ingredients.custom_minimum_size.y=40
	details.add_child(ingredients)
	for id: String in eligible: ingredients.add_item("%s · 存有%d篮"%[Crops.definition(id).name,data.inventory[id]])
	ingredients.select(eligible.find(crop))
	var start: Button=book._button(details,"开始制作")
	start.name="StartCooking"
	start.disabled=data.inventory[crop]<1 or not state.jobs[rule.station].is_empty()
	ingredients.item_selected.connect(func(index: int) -> void:
		crop=eligible[index]
		start.disabled=data.inventory[crop]<1 or not state.jobs[rule.station].is_empty())
	var selected_recipe: String=recipe
	start.pressed.connect(func() -> void: book.kitchen_requested.emit("start",{"recipe":selected_recipe,"crop":crop},int(state.revision)))
	var views:=HBoxContainer.new()
	page.add_child(views)
	for station: String in ["stove","rack","jar","table"]:
		var see: Button=book._button(views,{"stove":"看看厨房","rack":"看看晒架","jar":"看看陶罐","table":"看看餐桌"}[station])
		see.name="ViewKitchen_"+station
		see.pressed.connect(func() -> void: book.begin_kitchen_view(station))
	_stock(book,page,state)
	tick(now)

func tick(now: float) -> void:
	for entry: Dictionary in _timers:
		if not is_instance_valid(entry.label): continue
		var done: bool=Kitchen.ready(entry.job,now)
		entry.label.text=Kitchen.RECIPES[entry.job.recipe].name+ (" · 可收起" if done else " · 制作中 %d秒"%ceili(maxf(0,entry.job.finish_utc-now)))
		entry.button.disabled=not done

func _stock(book: Node, page: VBoxContainer, state: Dictionary) -> void:
	book._label(page,"做好的食物",24)
	var to:=OptionButton.new()
	to.name="MealRecipient"
	to.custom_minimum_size.y=42
	page.add_child(to)
	for id: String in Neighbors.IDS: to.add_item("送给 "+Neighbors.HOMES[id].name)
	to.select(Neighbors.IDS.find(recipient))
	to.item_selected.connect(func(index: int) -> void: recipient=Neighbors.IDS[index])
	var any: bool=false
	for id: String in Kitchen.RECIPES:
		if state.stock[id]==0: continue
		any=true
		var row:=HBoxContainer.new()
		page.add_child(row)
		_icon(row,Kitchen.RECIPES[id].asset,54)
		var label: Label=book._label(row,"%s · %d份"%[Kitchen.RECIPES[id].name,state.stock[id]],21)
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var display: Button=book._button(row,"桌上这道" if state.display==id else "摆上桌")
		display.name="Display_"+id
		display.disabled=state.display==id
		display.pressed.connect(func() -> void: book.kitchen_requested.emit("display",{"recipe":id},int(state.revision)))
		var share: Button=book._button(row,"分享一份")
		share.name="ShareMeal_"+id
		share.pressed.connect(func() -> void: book.kitchen_requested.emit("share",{"recipe":id,"neighbor":recipient},int(state.revision)))
	if not any: book._label(page,"暂未收起成品",20)

func _journal(book: Node, page: VBoxContainer, state: Dictionary) -> void:
	var any: bool=false
	for id: String in Kitchen.RECIPES:
		var record: Dictionary=state.records[id]
		if record.made==0: continue
		any=true
		var row:=HBoxContainer.new()
		page.add_child(row)
		_icon(row,Kitchen.RECIPES[id].asset,110)
		var words:=VBoxContainer.new()
		words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(words)
		book._label(words,Kitchen.RECIPES[id].name,26)
		book._label(words,Kitchen.RECIPES[id].entry,21)
		book._label(words,"上回用的是%s · 做过%d份 · 分享%d份"%[Crops.definition(record.last_crop).name,record.made,record.shared],18)
		if record.last_to!="": book._label(words,Kitchen.share_reply(id,record.last_to),20)
	if not any: book._label(page,"食记还空着",24)

func _icon(parent: Node, asset: String, extent: float) -> void:
	var image:=TextureRect.new()
	image.texture=load("res://art/ui/kitchen/%s.png"%asset)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=Vector2(extent,extent)
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
