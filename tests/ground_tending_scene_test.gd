extends SceneTree
const Store=preload("res://farm/farm_store.gd")
var scene: Node
var folder: String
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func click_point(point: Vector2) -> void:
	var move:=InputEventMouseMotion.new();move.position=point;root.push_input(move,true);await physics_frame;await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
		await physics_frame;await process_frame
func click(control: Control) -> void:
	await click_point(control.get_global_rect().get_center())
func ground_click(cell: String) -> void:
	var point: Vector3=scene.farm.fields[5].to_global(scene.farm.cell_position(5,cell))
	await click_point(scene.camera.unproject_position(point))
	await create_timer(.3).timeout
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../.local/verification/tending-scene-%d"%Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.store=Store.new(folder.path_join("farm"));scene.settings_store=load("res://settings/settings_store.gd").new(folder.path_join("settings"));scene.clock=func() -> float: return 1000
	root.add_child(scene);await process_frame
	var animals: Node=scene.get_node("Environment/CourtyardAnimals")
	while not animals.ready_for_motion: await process_frame
	scene.atmosphere.set_preview_hour(14);await create_timer(.4).timeout
	scene._focus_field(5);await create_timer(1.2).timeout
	await click(scene.hud.find_child("Tools",true,false));await create_timer(.3).timeout
	await click(scene.hud._buttons.weed)
	check(scene.selected_tool=="weed","Real tool card selects weeding")
	await shot("weedy")
	await ground_click("cell_13")
	check(scene.farm_state.get_cell("field_06","cell_13").ground=="rough","Actual click cuts grass")
	check(scene.farm._untended["field_06/cell_13"].mesh.get_meta("ground")=="rough","Tall grass becomes short roots")
	await shot("rough")
	await click(scene.hud._buttons.till)
	check(scene.selected_tool=="till","Real tool card selects hoe")
	# Simulate a write failure; geometry and authority must both remain unchanged.
	var pending: String=scene.store.directory.path_join(Store.PENDING);DirAccess.make_dir_absolute(pending)
	await ground_click("cell_13")
	check(scene._save_failed and scene.farm_state.get_cell("field_06","cell_13").ground=="rough","Save failure does not reclaim visually or in memory")
	DirAccess.remove_absolute(pending);scene._retry_storage();await create_timer(.2).timeout
	scene._open_palette("tools");await create_timer(.3).timeout;await click(scene.hud._buttons.till)
	await ground_click("cell_13")
	check(scene.farm_state.get_cell("field_06","cell_13").ground=="ready","Explicit retry reclaims once")
	check(not is_instance_valid(scene.farm._untended["field_06/cell_13"].mesh),"Hoe removes the remaining roots")
	await shot("ready")
	scene._select_crop("greens");await ground_click("cell_13")
	check(scene.farm_state.get_cell("field_06","cell_13").crop_id=="greens","Reclaimed cell plants through real pointer input")
	await shot("planted")
	var loaded: Dictionary=Store.new(scene.store.directory).load_state()
	check(loaded.ok and loaded.farm.fields.field_06.cells.cell_13.crop_id=="greens","Planted reclaimed cell persisted")
	scene._cancel_tool();scene._open_palette("tools");root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,600);await create_timer(.5).timeout
	await shot("minimum")
	check(scene.hud._tool_row.get_global_rect().end.x<=root.get_visible_rect().end.x,"Tool row fits minimum viewport")
	scene._cancel_tool();check(scene.selected_tool.is_empty() and scene.selected_palette.is_empty(),"Cancel restores ordinary pointer and closes palette")
	scene.farm_audio.shutdown();await create_timer(.15).timeout
	print("GROUND_TENDING_SCENE failures=",failures," evidence=",folder);scene.queue_free();await process_frame;quit(0 if failures==0 else 1)
