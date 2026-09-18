extends SceneTree
const Store=preload("res://farm/farm_store.gd")
var scene: Node
var folder: String
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func click(control: Control) -> void:
	var point: Vector2=control.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new();move.position=point;root.push_input(move,true);await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
		await physics_frame;await process_frame
func shot(name: String) -> void:
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../.local/verification/garden-album-%d"%Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.store=Store.new(folder.path_join("farm"));scene.settings_store=load("res://settings/settings_store.gd").new(folder.path_join("settings"));scene.clock=func() -> float: return 1000
	root.add_child(scene)
	await process_frame
	var animals: Node=scene.get_node("Environment/CourtyardAnimals")
	while not animals.ready_for_motion: await process_frame
	animals.set_process(false)
	var fixture: Dictionary=scene.farm_state.snapshot();fixture.harvested.greens=1;fixture.inventory.greens=2;fixture.neighbors.willow.pending=true;scene.farm_state.restore_snapshot(fixture);scene._save_farm()
	scene.atmosphere.set_preview_hour(14);scene.refresh_farm();await create_timer(.4).timeout
	await click(scene.hud.find_child("OpenBasket",true,false));await create_timer(.3).timeout
	var book: Node=scene.harvest_book
	if not book.active: scene.farm_audio.shutdown();quit(1);return
	await click(book._tabs.memories);await process_frame
	check(book.tab=="memories","Actual book tab")
	await click(book._content.find_child("Memory_dawn",true,false));await process_frame
	await shot("memories")
	var original: Vector3=scene.camera.focus_point
	await click(book._content.find_child("ViewMemory",true,false));await create_timer(1.2).timeout
	scene.garden_album.observe()
	check(book.viewing and scene.atmosphere.get_preview_hour()==6.5 and scene.farm_state.snapshot().memories.marks.has("dawn"),"Morning scene can be visited and remembered")
	await shot("dawn")
	await click(book._return_button);await create_timer(1).timeout
	check(scene.atmosphere.get_preview_hour()==14 and scene.camera.focus_point.is_equal_approx(original),"Review restores time and camera")
	await click(book._content.find_child("TakePhoto",true,false));await process_frame
	check(scene.garden_album.active and scene.camera.free_view,"Photo mode takes input")
	var before: Dictionary=scene.farm_state.snapshot()
	var event:=InputEventMouseButton.new();event.position=Vector2(500,350);event.button_index=MOUSE_BUTTON_WHEEL_UP;event.pressed=true;root.push_input(event,true);await process_frame;event.pressed=false;root.push_input(event,true);await create_timer(.5).timeout
	check(scene.farm_state.snapshot()==before,"Photo wheel doesn't sow or charge anything")
	# Make the album directory a file: image failure must not publish a phantom photo.
	var files: RefCounted=scene.garden_album.files
	var blocker:=FileAccess.open(files.directory,FileAccess.WRITE);blocker.store_string("fixture");blocker.close()
	await click(scene.garden_album._capture)
	while scene.garden_album.busy: await process_frame
	check(scene.farm_state.snapshot().memories.photos.is_empty(),"Image failure adds no album record")
	DirAccess.remove_absolute(files.directory)
	# Then fail the metadata write after the PNG succeeds. Retry must reuse it.
	var pending: String=scene.store.directory.path_join(Store.PENDING);DirAccess.make_dir_absolute(pending)
	await click(scene.garden_album._capture)
	while scene.garden_album.busy: await process_frame
	check(scene.farm_state.snapshot().memories.photos.is_empty() and not scene.garden_album._pending.is_empty(),"Metadata failure preserves unpublished original for retry")
	var id: String=scene.garden_album._pending.get("id","")
	check(files.texture(id)!=null,"Original is readable after failed metadata")
	DirAccess.remove_absolute(pending)
	await click(scene.garden_album._capture)
	while scene.garden_album.busy: await process_frame
	await create_timer(1).timeout
	check(not scene.garden_album.active and book.tab=="album" and scene.farm_state.snapshot().memories.photos.size()==1,"Retry publishes exactly one photo and returns to album")
	check(scene.farm_state.snapshot().memories.photos[0].id==id,"Retry doesn't capture a second image")
	await shot("photo-detail")
	var title: LineEdit=book._content.find_child("PhotoTitle",true,false);title.text="九月，湖边的一刻"
	await click(book._content.find_child("RenamePhoto",true,false));await process_frame
	check(scene.farm_state.snapshot().memories.photos[0].title=="九月，湖边的一刻","Rename persisted")
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,600);await shot("minimum-album")
	check(root.get_visible_rect().encloses(book._paper.get_global_rect()),"Book fits minimum viewport")
	var saved: Dictionary=scene.store.load_state();scene._load_game(saved)
	check(saved.farm.memories.photos.size()==1 and files.texture(id,true)!=null,"Reload retains photo and thumbnail")
	await click(book._content.find_child("RemovePhoto",true,false));await process_frame
	check(scene.farm_state.snapshot().memories.photos.is_empty() and files.texture(id)!=null,"Removing from album retains original")
	book.dismiss();await create_timer(1).timeout
	check(scene._tools_available(),"Closing album restores farming")
	scene.farm_audio.shutdown();scene.queue_free();await process_frame;await process_frame
	print("GARDEN_ALBUM_SCENE failures=",failures," evidence=",folder);quit(0 if failures==0 else 1)
