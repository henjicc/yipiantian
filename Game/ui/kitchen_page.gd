extends RefCounted
## Kitchen page uses the same modal book; only drafts and display controls live here.
const Kitchen=preload("res://farm/kitchen.gd")
const Crops=preload("res://farm/crop_catalog.gd")
const Neighbors=preload("res://farm/neighbor_catalog.gd")
const ItemCard=preload("res://ui/item_card.gd")
var recipe: String="leaf_stir"
var crop: String="greens"
var recipient: String="willow"
var selected_station: String=""
var _timers: Array[Dictionary]=[]

func render(book: Node, data: Dictionary, journal: bool, now: float) -> void:
	_timers.clear()
	var page: VBoxContainer=book._content
	var state: Dictionary=data.kitchen
	if journal:
		_journal(book,page,state)
		_construction(book,page,data)
		tick(now)
		return
	_construction(book,page,data)
	var stations:=HBoxContainer.new()
	page.add_child(stations)
	for station: String in Kitchen.STATIONS:
		if station=="garden_rack" and not Kitchen.extra_rack_placed(book.decorations): continue
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
	var available: Array[String]=[rule.station]
	if rule.station=="rack" and Kitchen.extra_rack_placed(book.decorations): available.append("garden_rack")
	if selected_station not in available: selected_station=available[0]
	if available.size()>1:
		var station_choice:=OptionButton.new();station_choice.name="CookingStation"
		station_choice.custom_minimum_size.y=40;details.add_child(station_choice)
		for id: String in available: station_choice.add_item(Kitchen.STATION_NAMES[id]+(" · 制作中" if not state.jobs[id].is_empty() else " · 空闲"))
		station_choice.select(available.find(selected_station))
		station_choice.item_selected.connect(func(index: int) -> void: selected_station=available[index];book._render())
	var eligible: Array[String]=[]
	for id: String in Crops.crop_ids():
		if Kitchen.accepts(recipe,id): eligible.append(id)
	if crop not in eligible or data.inventory[crop]<=0:
		crop=eligible[0]
		for id: String in eligible:
			if data.inventory[id]>0: crop=id; break
	var ingredients:=GridContainer.new()
	ingredients.name="KitchenIngredients"
	ingredients.columns=4
	details.add_child(ingredients)
	var ingredient_cards: Dictionary={}
	for id: String in eligible:
		var card:=ItemCard.new()
		card.name="Ingredient_"+id
		card.configure(Crops.definition(id).name,load(Crops.icon_path(id)),Vector2(106,106),18)
		card.toggle_mode=true
		card.set_pressed_no_signal(id==crop)
		card.disabled=data.inventory[id]<=0
		card._badge.text="%d篮"%data.inventory[id]
		ingredients.add_child(card)
		ingredient_cards[id]=card
	var start: Button=book._button(details,"开始制作")
	start.name="StartCooking"
	start.disabled=data.inventory[crop]<1 or not state.jobs[selected_station].is_empty()
	for id: String in ingredient_cards:
		ingredient_cards[id].pressed.connect(func() -> void:
			crop=id
			for key: String in ingredient_cards: ingredient_cards[key].set_pressed_no_signal(key==id)
			start.disabled=data.inventory[crop]<1 or not state.jobs[selected_station].is_empty())
	var selected_recipe: String=recipe
	start.pressed.connect(func() -> void: book.kitchen_requested.emit("start",{"recipe":selected_recipe,"crop":crop,"station":selected_station},int(state.revision)))
	var views:=HBoxContainer.new()
	page.add_child(views)
	for station: String in ["stove","rack","jar","table"]:
		var see: Button=book._button(views,{"stove":"看看厨房","rack":"看看晒架","jar":"看看陶罐","table":"看看餐桌"}[station])
		see.name="ViewKitchen_"+station
		see.pressed.connect(func() -> void: book.begin_kitchen_view(station))
	if Kitchen.extra_rack_placed(book.decorations):
		var see: Button=book._button(views,"看看小晒架");see.name="ViewKitchen_garden_rack"
		see.pressed.connect(func() -> void: book.begin_kitchen_view("garden_rack"))
	_stock(book,page,state)
	tick(now)

func _construction(book: Node,page: VBoxContainer,data: Dictionary) -> void:
	var item: Dictionary=book.decorations.get("drying_rack",{})
	if not item.get("unlocked",false):
		var state: Dictionary=data.kitchen
		var progress: String="小晒架 · "+book.Decorations.progress("drying_rack",data.harvested,state)
		var status: Label=book._label(page,progress,19)
		status.name="RackProgress"
		for id: String in Kitchen.RECIPES:
			if state.stock[id]==0: continue
			var share: Button=book._button(page,"分享%s给%s"%[Kitchen.RECIPES[id].name,Neighbors.HOMES[recipient].name])
			share.name="FirstMealShare"
			share.pressed.connect(func() -> void: book.kitchen_requested.emit("share",{"recipe":id,"neighbor":recipient},int(state.revision)))
			return
		var pending: String=""
		for station: String in Kitchen.STATIONS:
			if state.jobs[station].is_empty(): continue
			if pending.is_empty() or state.jobs[station].finish_utc<state.jobs[pending].finish_utc: pending=station
		if not pending.is_empty():
			var collect: Button=book._button(page,"收起"+Kitchen.RECIPES[state.jobs[pending].recipe].name)
			collect.name="FirstMealCollect"
			collect.pressed.connect(func() -> void: book.kitchen_requested.emit("collect",{"station":pending},int(state.revision)))
			_timers.append({"label":status,"button":collect,"job":state.jobs[pending],"prefix":progress+" · "})
			return
		var available_recipe: String=""
		var available_crop: String=""
		for id: String in Kitchen.RECIPES:
			if not available_recipe.is_empty() and Kitchen.RECIPES[id].seconds>=Kitchen.RECIPES[available_recipe].seconds: continue
			for ingredient: String in Crops.crop_ids():
				if Kitchen.accepts(id,ingredient) and data.inventory[ingredient]>0:
					available_recipe=id;available_crop=ingredient;break
		if not available_recipe.is_empty():
			var prepare: Button=book._button(page,"%s1篮 → %s · %d秒"%[Crops.definition(available_crop).name,Kitchen.RECIPES[available_recipe].name,Kitchen.RECIPES[available_recipe].seconds])
			prepare.name="FirstMealCook"
			prepare.pressed.connect(func() -> void: book.kitchen_requested.emit("start",{"recipe":available_recipe,"crop":available_crop},int(state.revision)))
			return
		for neighbor: String in Neighbors.IDS:
			if not data.neighbors[neighbor].pending: continue
			var gift: Button=book._button(page,"领取"+Neighbors.HOMES[neighbor].name+"的回礼")
			gift.name="FirstMealGift"
			gift.pressed.connect(func() -> void: book.tab="neighbors";book.neighbor=neighbor;book._history_open=false;book._render())
			return
		var harvest: Button=book._button(page,"回到田里收获食材");harvest.name="FirstMealHarvest"
		harvest.pressed.connect(book.dismiss)
	elif not Kitchen.extra_rack_placed(book.decorations):
		var place: Button=book._button(page,"摆放小晒架 · 多一处晾晒位置");place.name="BuildDryingRack"
		place.pressed.connect(func() -> void: book.construction_requested.emit("drying_rack"))

func tick(now: float) -> void:
	for entry: Dictionary in _timers:
		if not is_instance_valid(entry.label): continue
		var done: bool=Kitchen.ready(entry.job,now)
		entry.label.text=entry.get("prefix","")+Kitchen.RECIPES[entry.job.recipe].name+ (" · 可收起" if done else " · 制作中 %d秒"%ceili(maxf(0,entry.job.finish_utc-now)))
		entry.button.disabled=not done

func _stock(book: Node, page: VBoxContainer, state: Dictionary) -> void:
	book._label(page,"做好的食物",24)
	var to:=OptionButton.new()
	to.name="MealRecipient"
	to.custom_minimum_size.y=42
	page.add_child(to)
	for id: String in Neighbors.IDS: to.add_item("送给 "+Neighbors.HOMES[id].name)
	to.select(Neighbors.IDS.find(recipient))
	to.item_selected.connect(func(index: int) -> void: recipient=Neighbors.IDS[index];book._render())
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
