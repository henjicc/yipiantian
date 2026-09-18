extends RefCounted
const Memories=preload("res://farm/garden_memories.gd")
const ItemCard=preload("res://ui/item_card.gd")
var files: RefCounted
var selected: String=""
var page: int=0
var issue: String=""
func render(book: Node,data: Dictionary,album: bool) -> void:
	var content: VBoxContainer=book._content
	var toolbar:=HBoxContainer.new();content.add_child(toolbar)
	var camera: Button=book._button(toolbar,"拍照");camera.name="TakePhoto";camera.icon=preload("res://art/ui/camera.svg");camera.pressed.connect(func() -> void: book.photo_requested.emit())
	if album:
		var folder: Button=book._button(toolbar,"打开原图文件夹");folder.pressed.connect(func() -> void:
			if files.open_folder()!=OK: issue="原图文件夹暂时无法打开";book._render())
	if not issue.is_empty(): book._label(content,issue,20)
	if album: _album(book,data.memories.photos);return
	var entries: Array[Dictionary]=Memories.entries(data)
	var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);content.add_child(grid)
	for entry: Dictionary in entries:
		var card:=ItemCard.new();grid.add_child(card);card.name="Memory_"+entry.id.replace(":","_")
		card.configure(entry.title,load(entry.icon),Vector2(190,112),18);card.toggle_mode=true;card.set_pressed_no_signal(entry.id==selected)
		card.get_node("Caption").text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		if entry.id in ["dawn","dusk"] and entry.recorded: card.get_node("State").text="见过"
		card.pressed.connect(func() -> void: selected=entry.id;book._render())
	for entry: Dictionary in entries:
		if entry.id!=selected: continue
		book._label(content,entry.title,25);book._label(content,entry.text,21)
		var view: Button=book._button(content,"看看此刻" if entry.id not in ["dawn","dusk"] else "看这一刻的光景")
		view.name="ViewMemory";view.pressed.connect(func() -> void: book.begin_memory_view(entry.id))
	content.move_child(grid,-1)
func _album(book: Node,photos: Array) -> void:
	var content: VBoxContainer=book._content
	if photos.is_empty(): book._label(content,"相册还是空的",22);return
	var chosen: Dictionary={}
	for photo: Dictionary in photos:
		if photo.id==selected: chosen=photo;break
	if not chosen.is_empty():
		var picture:=TextureRect.new();picture.texture=files.texture(chosen.id);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.custom_minimum_size=Vector2(760,290);content.add_child(picture)
		if picture.texture==null: book._label(content,"照片暂时无法读取，原图记录仍保留",20)
		var row:=HBoxContainer.new();content.add_child(row)
		var title:=LineEdit.new();title.name="PhotoTitle";title.max_length=40;title.text=chosen.title;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title)
		var rename: Button=book._button(row,"改名");rename.name="RenamePhoto";rename.pressed.connect(func() -> void: book.photo_action_requested.emit("rename",{"id":chosen.id,"title":title.text.strip_edges()}))
		var remove: Button=book._button(row,"移出相册，保留原图");remove.name="RemovePhoto";remove.pressed.connect(func() -> void: book.photo_action_requested.emit("remove",{"id":chosen.id}))
		book._button(row,"返回缩略图").pressed.connect(func() -> void: selected="";book._render())
		return
	page=clampi(page,0,(photos.size()-1)/8)
	var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);content.add_child(grid)
	for i: int in range(page*8,mini(page*8+8,photos.size())):
		var photo: Dictionary=photos[photos.size()-1-i]
		var card:=ItemCard.new();grid.add_child(card);card.name="Photo_"+photo.id
		card.configure(photo.title,files.texture(photo.id,true),Vector2(190,150),16)
		card.get_node("Caption").text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		card.pressed.connect(func() -> void: selected=photo.id;book._render())
	var pages:=HBoxContainer.new();content.add_child(pages)
	var previous: Button=book._button(pages,"上一页");previous.disabled=page==0;previous.pressed.connect(func() -> void: page-=1;book._render())
	book._label(pages,"%d / %d"%[page+1,ceili(photos.size()/8.0)],18)
	var next: Button=book._button(pages,"下一页");next.disabled=(page+1)*8>=photos.size();next.pressed.connect(func() -> void: page+=1;book._render())
