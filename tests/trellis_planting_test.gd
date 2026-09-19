extends "res://../tests/trellis_layout_test.gd"
const Slots=preload("res://layout/trellis_slots.gd")
const Planting=preload("res://presentation/trellis_crops.gd")

func point_root(id: String) -> Vector2:
	return scene.camera.unproject_position(scene.trellis_crops.body.to_global(Slots.slots(scene.courtyard_plan)[id]+Vector3.UP*.045))

func tap(point: Vector2) -> void:
	var hover:=InputEventMouseMotion.new();hover.position=point;hover.window_id=root.get_window_id()
	root.push_input(hover,true);await frames()
	await mouse(point,true);await mouse(point,false)

func petal(id: String) -> void:
	var button: Control=scene.field_menu.cards.get_node(id)
	await tap(button.global_position+button.center)

func root_action(id: String,action: String) -> void:
	await tap(point_root(id))
	expect(scene.field_menu.active,"Root click opens action menu: "+id)
	if not scene.field_menu.active: return
	await petal(action)
	if action=="sow":
		expect(scene.field_menu.cards.has_node("luffa") and not scene.field_menu.cards.has_node("greens"),"Frame offers only climbing seed")
		await petal("luffa")

func crop_views() -> void:
	var previous_view: Vector3=scene.camera.view
	var previous_point: Vector3=scene.camera.focus_point
	scene.camera.focus_point=scene.courtyard_plan.anchors.trellis+Vector3.UP*1.2
	for angle: float in [105,285]:
		scene.camera.view=Vector3(angle,18,9);scene.camera._apply_pose();await frames(8)
		await shot("mature-side-%d"%angle)
	scene.camera.view=previous_view;scene.camera.focus_point=previous_point;scene.camera._apply_pose();await frames()

func fruit_point(id: String) -> Vector2:
	var mesh: MeshInstance3D=scene.trellis_crops.crops.get_node(id+"/Fruit")
	var points: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i: int in range(0,points.size()-2,30):
		var point: Vector2=scene.camera.unproject_position(mesh.to_global((points[i]+points[i+1]+points[i+2])/3.0))
		if scene._farm_hit(point).get("cell","")==id: return point
	return Vector2.INF

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/trellis-planting-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var plan:=Plan.new()
	plan.apply_construction({"land":[[-4,5,5,5],[0,5,4,5],[-4,9,5,4],[0,9,4,4]],"trellis":[],"bridge":[],"buildings":{"house":[],"kitchen":[]},"flocks":preload("res://layout/flock_layout.gd").initial()})
	if Plan.from_snapshot(plan.snapshot())==null:
		expect(false,"Expanded test land must satisfy current layout rules");quit(1);return
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=plan
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	if OS.get_cmdline_user_args().has("--night-only"):
		scene.farm_state.sow("trellis","right_0","luffa",now)
		now+=3000;scene.settle_farm()
		scene._focus_field(Planting.INDEX);await create_timer(1).timeout
		scene.atmosphere.set_preview_hour(22);await frames();await shot("night-root-locations")
		await root_action("right_0","water")
		expect(scene.farm_state.get_cell("trellis","right_0").watered,"Focused night root accepts watering")
		root.size=Vector2i(960,640);await frames();await shot("night-small")
		await finish();return
	await tap(point_root("left_0"));await create_timer(1).timeout
	expect(scene.selected_field==Planting.INDEX and scene.camera.focused,"Click actual root patch focuses trellis")
	await shot("01-focus")
	if scene.selected_field!=Planting.INDEX: await finish();return
	await root_action("left_2","sow")
	expect(scene.farm_state.get_cell("trellis","left_2").stage=="sprout","Real menu sows a climber")
	await root_action("left_2","water")
	expect(scene.farm_state.get_cell("trellis","left_2").watered,"Real menu waters climber")
	await root_action("right_0","sow")
	await shot("02-sprouts")
	if scene.farm_state.get_cell("trellis","left_2").crop_id.is_empty(): await finish();return
	now+=1700;scene.settle_farm();await frames()
	expect(scene.farm_state.get_cell("trellis","left_2").stage=="young","Clock advances visible climbing stage")
	await shot("03-young")
	var state: Dictionary=scene.farm_state.snapshot()
	scene._begin_construction("trellis");await create_timer(1).timeout
	var builder: Node=scene.island_builder
	builder._values.length.value=2.4
	expect(builder.issue().contains("作物") and builder._confirm.disabled,"Occupied endpoint prevents short frame")
	expect(scene.trellis_crops.crops.has_node("left_2"),"Rejected short preview still displays occupied outer vine")
	expect(scene.farm_state.snapshot()==state,"Rejected preview preserves authoritative growth")
	builder.cancel_draft();await frames()
	expect(scene.trellis_crops.body.transform.is_equal_approx(Construction.trellis_pose(scene.courtyard_plan)),"Cancel restores root display pose")
	builder._values.height.value=2.4
	var original: Vector3=builder.candidate.anchors.trellis
	await drag(original,Vector3(-.8,.13,9.0))
	await click(builder._trellis_actions.get_node("RotateTrellis"))
	builder._values.length.value=6
	if not await ready_draft(): await shot("failure-moving");await finish();return
	expect(scene.trellis_crops.body.transform.is_equal_approx(Construction.trellis_pose(builder.candidate)),"Vines follow live frame pose")
	expect(scene.trellis_crops._patches.size()==14,"Live expansion displays fourteen planting positions")
	expect(scene.farm_state.snapshot()==state,"Moving and rotating only changes preview")
	await shot("04-live-move")
	var scene_id: int=scene.get_instance_id()
	var directory: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocked"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocked/child")
	await click(builder._confirm)
	expect(scene.farm_state.snapshot()==state and builder._status.text.contains("未能保存"),"Failed planted-frame save retains growth and retryable draft")
	scene.store.directory=directory
	if not await apply(): await finish();return
	expect(scene.get_instance_id()==scene_id,"Planted trellis saves without scene replacement")
	expect(scene.farm_state.get_cell("trellis","left_2").watered,"Moving frame keeps care state")
	builder.finish();await create_timer(1).timeout
	now+=1900;scene.settle_farm();await frames()
	scene._focus_field(Planting.INDEX);await create_timer(1).timeout
	expect(scene.farm_state.get_cell("trellis","left_2").stage=="mature","Mature watered crop after movement")
	await shot("05-mature")
	await crop_views()
	var fruit: Vector2=fruit_point("left_2")
	expect(fruit!=Vector2.INF,"Visible fruit triangles select their own root")
	if fruit==Vector2.INF: await finish();return
	await tap(fruit)
	expect(scene.field_menu.active,"Click actual fruit opens crop menu")
	if not scene.field_menu.active: await finish();return
	await petal("harvest")
	expect(scene.farm_state.snapshot().inventory.luffa==1 and not scene.trellis_crops.crops.has_node("left_2"),"Actual harvest removes vine and adds one basket")
	scene._begin_construction("trellis");await create_timer(1).timeout
	builder._values.length.value=2.4
	if not await ready_draft(): await finish();return
	if not await apply(): await finish();return
	expect(scene.farm_state.get_cell("trellis","right_0").crop_id=="luffa","Shrinking after harvest retains central plant")
	await click(builder._undo)
	var started: int=Time.get_ticks_msec()
	while builder.busy:
		await process_frame
		if Time.get_ticks_msec()-started>20000: expect(false,"Planted undo finishes");break
	expect(Construction.trellis_size(scene.courtyard_plan).x==6 and scene.farm_state.snapshot().inventory.luffa==1,"Undo restores length without rolling back later harvest")
	expect(scene.farm_state.get_cell("trellis","right_0").growth_seconds==3600,"Undo preserves elapsed crop growth")
	var saved: Dictionary=scene.farm_state.snapshot()
	var path: String=scene.store.directory
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.farm_state.snapshot()==saved,"Actual reopen preserves vines, frame, inventory and growth")
	scene._focus_field(Planting.INDEX);await create_timer(1).timeout
	scene.atmosphere.set_preview_hour(22);await frames();await shot("06-reopened-night")
	root.size=Vector2i(960,640);await frames();await root_action("right_0","water")
	expect(scene.farm_state.get_cell("trellis","right_0").watered,"Reopened vine still accepts actual input at small window")
	await shot("07-small")
	await finish()
