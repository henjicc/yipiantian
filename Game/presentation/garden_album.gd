extends Node
## Owns photo capture and journal viewing; gameplay commits stay in the farm store.
const Farm=preload("res://farm/farm_state.gd")
const Memories=preload("res://farm/garden_memories.gd")
const Files=preload("res://presentation/album_files.gd")
const ThemeFactory=preload("res://ui/farm_theme.gd")
var scene: Node
var files: RefCounted
var active: bool=false
var busy: bool=false
var _pending: Dictionary={}
var _layer: CanvasLayer
var _controls: PanelContainer
var _capture: Button
var _status: Label
var _return: Button
var _preview_hour: float=-1
var _memory_view: bool=false
func configure(owner_scene: Node) -> void:
	scene=owner_scene;files=Files.new(scene.store.directory)
	scene.harvest_book.memory_page.files=files
	scene.harvest_book.photo_requested.connect(begin_photo)
	scene.harvest_book.photo_action_requested.connect(photo_action)
	scene.harvest_book.memory_view_requested.connect(view_memory)
	scene.harvest_book.view_closed.connect(end_memory)
	_layer=CanvasLayer.new();_layer.layer=25;add_child(_layer)
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=ThemeFactory.create();_layer.add_child(root)
	_controls=PanelContainer.new();root.add_child(_controls);_controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_controls.offset_left=-290;_controls.offset_right=290;_controls.offset_top=-90;_controls.offset_bottom=-20
	var row:=HBoxContainer.new();_controls.add_child(row)
	_capture=Button.new();_capture.text="拍照";_capture.name="Shutter";_capture.icon=preload("res://art/ui/camera.svg");_capture.custom_minimum_size.x=130;row.add_child(_capture);_capture.pressed.connect(take_photo)
	_status=Label.new();_status.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_status.add_theme_font_size_override("font_size",18);row.add_child(_status)
	_return=Button.new();_return.text="回到相册";_return.custom_minimum_size.x=150;row.add_child(_return);_return.pressed.connect(end_photo)
	_layer.hide()
	var timer:=Timer.new();timer.wait_time=2.0;timer.timeout.connect(observe);add_child(timer);timer.start()
func observe() -> void:
	if not scene._loaded or scene._save_failed or scene._exiting or busy or scene._layout_active(): return
	var data: Dictionary=scene.farm_state.snapshot()
	var marks: Dictionary=data.memories.marks
	var hour: float=scene.atmosphere.get_preview_hour()
	if hour<0:
		var local: Dictionary=Time.get_time_dict_from_system();hour=local.hour+local.minute/60.0
	var observed: Array[String]=[]
	if hour>=5.5 and hour<8 and not marks.has("dawn"): observed.append("dawn")
	if hour>=17 and hour<20 and not marks.has("dusk"): observed.append("dusk")
	if not marks.has("company"):
		var birds: Array=scene.get_node("Environment/CourtyardAnimals").birds
		for bird: Dictionary in birds:
			if bird.kind!="hen" and bird.state=="swim" and is_instance_valid(bird.buddy) and bird.node.global_position.distance_to(bird.buddy.global_position)<1.8:
				observed.append("company");break
	if observed.is_empty(): return
	var candidate:=Farm.new();candidate.restore_snapshot(data)
	for id: String in observed: candidate.remember(id,scene.clock.call())
	# An observation is not a reward; on failure leave it unrecorded and allow the
	# existing save-error flow to provide a deliberate retry rather than disk spam.
	var saved: Dictionary=scene.store.save(candidate.snapshot(),scene.decoration_state.snapshot())
	if saved.ok:
		scene.farm_state.restore_snapshot(candidate.snapshot())
		if scene.harvest_book.active and scene.harvest_book.tab=="memories" and not scene.harvest_book.viewing and not active:
			scene.harvest_book.refresh(scene.farm_state.snapshot())
	else:
		scene._save_failed=true;end_photo();scene.harvest_book.dismiss();scene.hud.show_storage_issue(saved.kind,true);scene._refresh_hud()
func view_memory(id: String) -> void:
	_preview_hour=scene.atmosphere.get_preview_hour();_memory_view=true
	scene.hud.hide()
	var point: Vector3=scene.camera.overview_point
	var view: Vector3=scene.camera.overview_view
	var subject: Node3D=null
	if id in ["dawn","dusk"]: scene.atmosphere.set_preview_hour(6.5 if id=="dawn" else 18.5)
	elif id.begins_with("neighbor:"):
		scene._view_neighbor(id.split(":")[1]);return
	elif id.begins_with("kitchen:"):
		var recipe: String=id.trim_prefix("kitchen:")
		var framing: Dictionary=scene.kitchen_display.viewpoint(Memories.Kitchen.RECIPES[recipe].station)
		point=framing.point;view=framing.view;subject=framing.subject
	elif id.begins_with("animal:") or id=="company":
		var animal: String=id.trim_prefix("animal:") if id!="company" else "LakeDuck1"
		var bird: Dictionary=scene.get_node("Environment/CourtyardAnimals").interaction.find(animal)
		if not bird.is_empty(): subject=bird.node;point=subject.global_position+Vector3.UP*.3;view=Vector3(28,30,9)
	elif id.begins_with("crop:"):
		point=scene.farm.fields[0].global_position;view=Vector3(27.5,40,13)
		for field: Node in scene.farm.fields:
			var definition: Dictionary=scene.farm_state.get_field(str(field.get_meta("field_id")))
			for cell: Dictionary in definition.cells.values():
				if cell.crop_id==id.trim_prefix("crop:"): point=field.global_position;subject=field;break
	scene.focus_detail.protect_neighbor(subject)
	scene.camera.view_neighbor(point,view)
func end_memory() -> void:
	if not _memory_view: return
	_memory_view=false;scene.atmosphere.set_preview_hour(_preview_hour)
	scene.focus_detail.protect_neighbor(null)
	scene.harvest_book.refresh(scene.farm_state.snapshot())
func begin_photo() -> void:
	if active or scene._exiting or scene._save_failed: return
	active=true;scene._cancel_input();scene.hud.hide();scene.harvest_book._root.hide()
	scene.focus_detail.photo_mode=true
	scene.camera.free_input_enabled=true;scene.camera.set_free_view(true)
	_status.text="";_capture.text="拍照" if _pending.is_empty() else "重试保存"
	_layer.show()
func end_photo() -> void:
	if not active or busy: return
	active=false;_layer.hide();scene.camera.set_free_view(false);scene.camera.free_input_enabled=false
	scene.focus_detail.photo_mode=false
	if scene.harvest_book.viewing: scene.harvest_book.end_view()
	scene.harvest_book.tab="album";scene.harvest_book._root.show();scene.harvest_book.refresh(scene.farm_state.snapshot())
	scene.hud.show();scene._cancel_input()
func _unhandled_input(event: InputEvent) -> void:
	if not active or busy: return
	scene.camera.free_input(event)
	get_viewport().set_input_as_handled()
func cancel_key(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		end_photo();get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and not event.pressed: scene.camera.end_free_drag(event.button_index)
func take_photo() -> void:
	if not active or busy: return
	if scene.farm_state.snapshot().memories.photos.size()>=Memories.MAX_PHOTOS:
		_status.text="相册已满，可移出旧照保留原图";return
	busy=true;_capture.disabled=true;_return.disabled=true;scene.camera.cancel_free_gesture();scene.camera.free_input_enabled=false
	if _pending.is_empty():
		_layer.hide()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if scene._exiting: return
		var image: Image=get_viewport().get_texture().get_image()
		_layer.show()
		var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
		var error: Error=files.save(image,id)
		if error!=OK:
			push_warning("ALBUM stage=image error=%d"%error)
			_status.text="照片未能写入，可重试";_capture.disabled=false;_return.disabled=false;busy=false;scene.camera.free_input_enabled=true;return
		_pending={"id":id,"title":"小院留影","utc":scene.clock.call()}
	var candidate:=Farm.new();candidate.restore_snapshot(scene.farm_state.snapshot())
	var accepted: bool=candidate.photo_action("add",_pending)
	var saved: Dictionary=scene.store.save(candidate.snapshot(),scene.decoration_state.snapshot()) if accepted else {"ok":false}
	if saved.ok:
		scene.farm_state.restore_snapshot(candidate.snapshot());scene.harvest_book.memory_page.selected=_pending.id
		_pending={};_status.text="";_capture.text="拍照"
	else:
		_status.text="相册未能保存，原图已保留";_capture.text="重试保存"
	busy=false;_capture.disabled=false;_return.disabled=false;scene.camera.free_input_enabled=true
	if saved.ok: end_photo()
func photo_action(action: String,photo: Dictionary) -> void:
	if scene._save_failed or scene._exiting: return
	var candidate:=Farm.new();candidate.restore_snapshot(scene.farm_state.snapshot())
	if not candidate.photo_action(action,photo):
		scene.harvest_book.memory_page.issue="名称请用一到四十个字";scene.harvest_book._render();return
	var saved: Dictionary=scene.store.save(candidate.snapshot(),scene.decoration_state.snapshot())
	if not saved.ok: scene.harvest_book.memory_page.issue="相册未能保存，可以重试"
	else:
		scene.farm_state.restore_snapshot(candidate.snapshot());scene.harvest_book.memory_page.issue=""
		if action=="remove": scene.harvest_book.memory_page.selected=""
	scene.harvest_book.refresh(scene.farm_state.snapshot())
