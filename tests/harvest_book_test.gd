extends SceneTree
const Store=preload("res://farm/farm_store.gd")
const Settings=preload("res://settings/settings_store.gd")
var scene: Node3D
var folder: String
var failures: Array[String]=[]
var visual: bool=false

func _initialize() -> void: _run.call_deferred()

func expect(condition: bool,message: String) -> void:
	if not condition: failures.append(message); push_error(message)

func click(control: Control) -> void:
	var point: Vector2=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=point
	Input.parse_input_event(motion)
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func shot(label: String) -> void:
	if not visual: return
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))

func _run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	folder=ProjectSettings.globalize_path("res://../.local/verification/harvest-book-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate()
	scene.store=Store.new(folder.path_join("farm"))
	scene.settings_store=Settings.new(folder.path_join("preferences"))
	scene.clock=func() -> float: return 1000
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.atmosphere.set_preview_hour(14)
	scene.farm_state.harvest("field_03","cell_06",1000)
	scene.refresh_farm()
	scene._save_farm()
	await click(scene.hud.get_node("Layout").find_child("OpenBasket",true,false))
	var book: Node=scene.harvest_book
	expect(book.active,"Real HUD basket click opens inventory")
	if not book.active: await finish(); return
	expect(not scene._tools_available(),"Book blocks farm tools")
	await shot("inventory")
	await click(book._tabs.neighbors)
	expect(book.tab=="neighbors","Real tab click shows wishes")
	var quantity: SpinBox=book._root.find_child("Amount_greens",true,false)
	quantity.value=1
	await process_frame
	expect(not book._send.disabled,"Exact basket enables delivery")
	await shot("selected-basket")
	var before: Dictionary=scene.farm_state.snapshot()
	var pending: String=scene.store.directory.path_join(Store.PENDING)
	DirAccess.make_dir_absolute(pending)
	await click(book._send)
	expect(scene._save_failed and not book.active and scene.farm_state.snapshot()==before,"Failed write closes book and does not spend inventory")
	expect(not scene.get_node("Environment/NeighborIslets")._story_groups.has("willow"),"Failed delivery cannot publish a story scene change")
	DirAccess.remove_absolute(pending)
	scene._retry_storage()
	scene._open_basket()
	quantity=book._root.find_child("Amount_greens",true,false)
	quantity.value=1
	await process_frame
	await click(book._send)
	expect(scene.farm_state.snapshot().neighbors.willow.pending,"Delivered basket persists a reply")
	expect(scene.get_node("Environment/NeighborIslets")._story_groups.willow.get_child(0).visible,"Successful durable delivery publishes its story change")
	expect(scene.farm_state.snapshot().inventory.greens==0 and scene.farm_state.snapshot().harvested.greens==1,"UI shares food without reducing progress")
	await shot("reply")
	var reopened: Dictionary=Store.new(scene.store.directory).load_state()
	expect(reopened.farm==scene.farm_state.snapshot(),"Pending gift survives actual disk reload")
	await click(book._root.find_child("Gift_radish",true,false))
	expect(scene.farm_state.snapshot().neighbors.willow.round==1 and scene.farm_state.snapshot().inventory.radish==1,"Gift click moves to next wish and credits selected food")
	before=scene.farm_state.snapshot()
	scene._exchange("willow",0,{},"mustard")
	expect(scene.farm_state.snapshot()==before,"Repeated stale UI reward cannot grant twice")
	var camera_before: Transform3D=scene.camera.transform
	var wheel:=InputEventMouseButton.new()
	wheel.position=Vector2(5,500)
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	Input.parse_input_event(wheel)
	await create_timer(.4).timeout
	expect(scene.camera.transform.is_equal_approx(camera_before),"Book scroll does not zoom world")
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(960,600)
	await process_frame
	await process_frame
	await shot("minimum-window")
	var rect: Rect2=book._root.find_child("Paper",true,false).get_global_rect()
	expect(root.get_visible_rect().encloses(rect),"Book fits minimum supported window")
	var escape:=InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	Input.parse_input_event(escape)
	await process_frame
	expect(not book.active and scene._tools_available(),"Escape restores farming without stale click")
	reopened=Store.new(scene.store.directory).load_state()
	expect(reopened.farm==scene.farm_state.snapshot(),"Claimed reply and inventory reopen together")
	await finish()

func finish() -> void:
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	print("HARVEST_BOOK_TEST failures=",failures.size()," evidence=",folder)
	quit(0 if failures.is_empty() else 1)
