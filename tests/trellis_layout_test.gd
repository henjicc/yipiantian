extends "res://../tests/island_construction_test.gd"
var now: float=2000000.0

func grass_inside(nodes: Array, polygon: PackedVector2Array) -> bool:
	for node: Node in nodes:
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			for surface: int in mesh.mesh.get_surface_count():
				for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var world: Vector3=mesh.global_transform*vertex
					if Geometry2D.is_point_in_polygon(Vector2(world.x,world.z),polygon): return true
	return false

func ready_draft() -> bool:
	var started: int=Time.get_ticks_msec()
	while is_instance_valid(scene.island_builder.trellis_preview) and scene.island_builder.trellis_preview.pending:
		await process_frame
		if Time.get_ticks_msec()-started>20000: expect(false,"Trellis route validation finishes");return false
	var message: String=scene.island_builder.issue()
	if not message.is_empty():
		var footprint: PackedVector2Array=Construction.trellis_footprint(scene.island_builder.candidate)
		for key: String in scene.island_builder.trellis_preview._obstacles:
			if preload("res://layout/island_space.gd").overlaps(footprint,scene.island_builder.trellis_preview._obstacles[key]): print("TRELLIS_OVERLAP ",key)
	expect(message.is_empty(),"Trellis draft accepted: "+message)
	return message.is_empty()

func motion(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	event.window_id=root.get_window_id()
	var started: int=Time.get_ticks_usec();root.push_input(event,true)
	print("TRELLIS_POINTER_US ",Time.get_ticks_usec()-started);await frames()

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/trellis-layout-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	var plan:=Plan.new()
	plan.apply_construction({"east_land":[],"land":[[-3,5,5,5]],"trellis":[],"bridge":[],"buildings":{"house":[],"kitchen":[]},"flocks":preload("res://layout/flock_layout.gd").initial()})
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience";scene.courtyard_plan=plan
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	var decor: Dictionary=scene.decoration_state.snapshot()
	decor.lantern={"unlocked":true,"slot_id":"hanging_03","quarter_turn":1,"position":[]}
	expect(scene.decoration_state.restore_snapshot(decor),"Fixture has a trellis lantern")
	scene.decoration_layout.refresh_confirmed()
	var original: Dictionary=scene.farm_state.snapshot()
	var house_id: int=scene.get_node("Environment/MainHouse").get_instance_id()
	var scene_id: int=scene.get_instance_id()
	var lamp: Node3D=scene.decoration_layout._instances.lantern
	var lamp_pose: Transform3D=lamp.global_transform
	var flower: Node3D=scene.get_node("Environment/Flowers0_0")
	var flower_pose: Transform3D=flower.global_transform
	await click(scene.hud.get_node("Layout/FarmControls/BuildIsland"));await create_timer(1).timeout
	await choose_tool("trellis")
	var builder: Node=scene.island_builder
	if OS.get_cmdline_user_args().has("--finish-only"):
		await finish_while_checking(builder)
		await finish();return
	builder._values.width.value=.8;builder._values.height.value=2.4
	var endpoint: Vector3=Construction.trellis_pose(builder.candidate)*Vector3(0,.08,Construction.trellis_size(builder.candidate).x*.5)
	await drag(endpoint,endpoint+Vector3(0,0,.1))
	expect(builder.draft.construction.trellis[0]>4.65,"Actual endpoint drag lengthens trellis")
	if not await ready_draft(): await shot("failure-original");await finish();return
	await shot("01-resize")
	builder._values.length.value=6
	expect(builder._confirm.disabled,"Overlapping the existing tree rejects enlargement")
	builder._values.length.value=2.4
	var at: Vector3=builder.candidate.anchors.trellis
	var target:=Vector3(-.8,.13,8.05)
	await mouse(scene.camera.unproject_position(at),true)
	await motion(scene.camera.unproject_position(target))
	expect(builder.candidate.anchors.trellis.distance_to(at)>2,"Dragging inside footprint moves whole trellis")
	var preview: Node3D=builder.trellis_preview
	var size: Vector3=Construction.trellis_size(builder.candidate)
	var inner: PackedVector2Array=preload("res://layout/island_space.gd").footprint(Vector2(size.y-.24,size.x-.24),Construction.trellis_pose(builder.candidate))
	expect(not grass_inside([preview.core,preview.expansion],inner),"Live grass geometry clears the moved bed before release")
	expect(preview.structure.position.is_equal_approx(builder.candidate.anchors.trellis),"Trellis appears at pointer before release")
	expect(preview.bed.position.is_equal_approx(preview.structure.position),"Soil follows live trellis position")
	expect(not lamp.visible and scene.decoration_layout._attachment_previews.lantern.position.is_equal_approx(builder.candidate.slots.hanging_03),"Attached lamp follows live hook")
	expect(not flower.visible and preview._followers[0].copy.global_position.distance_to(flower_pose.origin)>2,"Flowers follow before release")
	expect(scene.farm_state.snapshot()==original,"Held preview leaves authoritative farm untouched")
	await mouse(scene.camera.unproject_position(target),false)
	await click(builder._trellis_actions.get_node("RotateTrellis"))
	expect(builder.draft.construction.trellis[5]==15,"Rotate button changes structure direction")
	if not await ready_draft(): await shot("failure-move");await finish();return
	await click(builder._trellis_snap)
	var current: Vector3=builder.candidate.anchors.trellis
	await drag(current,current+Vector3(.15,0,0))
	expect(absf(builder.candidate.anchors.trellis.x-current.x-.15)<.001,"Free movement keeps offsets smaller than a grid cell")
	if not await ready_draft(): await finish();return
	var pose: Transform3D=Construction.trellis_pose(builder.candidate)
	var handle: Vector3=pose*Vector3(.4+.65,.08,0)
	await drag(handle,pose*(Basis(Vector3.UP,deg_to_rad(15))*Vector3(.4+.65,.08,0)))
	expect(builder.draft.construction.trellis[5]==30,"World rotation handle turns the trellis")
	if not await ready_draft(): await finish();return
	await shot("02-moved-live")
	current=builder.candidate.anchors.trellis
	await drag(current,scene.courtyard_plan.fields[0].position)
	expect(builder._confirm.disabled and not builder.issue().is_empty(),"Existing farmland rejects a moved trellis")
	builder.cancel_draft();await frames(10)
	expect(lamp.visible and lamp.global_transform.is_equal_approx(lamp_pose),"Cancel restores original attached lantern")
	expect(flower.visible and flower.global_transform.is_equal_approx(flower_pose),"Cancel restores flower position")
	expect(scene.get_node("Environment/EntranceTrellis").visible,"Cancel restores original trellis")
	# A canceled route worker must not later clear the next draft's attachment.
	builder._values.length.value=2.4;builder._values.width.value=.8
	await drag(at,target)
	await click(builder._trellis_actions.get_node("RotateTrellis"))
	if not await ready_draft(): await shot("failure-second");await finish();return
	expect(not lamp.visible and scene.decoration_layout._attachment_previews.has("lantern"),"Retired worker cannot restore a later preview")
	var wanted: Dictionary=builder.draft.duplicate(true)
	var instance: int=builder.trellis_preview.structure.get_instance_id()
	var path: String=scene.store.directory
	var blocker:=FileAccess.open(folder.path_join("blocked"),FileAccess.WRITE);blocker.store_string("file");blocker.close()
	scene.store.directory=folder.path_join("blocked/child")
	await click(builder._confirm)
	expect(scene.farm_state.snapshot()==original and is_instance_valid(builder.trellis_preview) and builder._status.text.contains("未能保存"),"Failed save preserves original state and retryable preview")
	scene.store.directory=path
	var started: int=Time.get_ticks_msec()
	await click(builder._panel.find_child("Finish",true,false))
	print("TRELLIS_FINISH_INPUT_MS ",Time.get_ticks_msec()-started)
	expect(not builder.active and scene.farm_state.snapshot().layout==wanted,"Finish saves and exits construction")
	expect(scene.get_instance_id()==scene_id and scene.get_node("Environment/MainHouse").get_instance_id()==house_id,"Save retains scene and unrelated house")
	expect(scene.get_node("Environment/EntranceTrellis").get_instance_id()==instance,"Save adopts displayed structure")
	expect(lamp.visible and lamp.position.is_equal_approx(scene.courtyard_plan.slots.hanging_03),"Confirmed lantern adopts new hook")
	expect(flower.visible and flower.global_position.distance_to(flower_pose.origin)>2,"Confirmed flowers retain displayed position")
	await shot("03-completed")
	scene.atmosphere.set_preview_hour(22);await frames();await shot("04-night")
	scene._begin_construction("trellis");await create_timer(1).timeout
	now+=300
	await click(builder._undo)
	started=Time.get_ticks_msec()
	while builder.busy:
		await process_frame
		if Time.get_ticks_msec()-started>20000: expect(false,"Undo finishes");break
	expect(scene.farm_state.snapshot().layout==original.layout,"Undo restores original structure and layout: "+builder._status.text)
	expect(lamp.global_transform.is_equal_approx(lamp_pose),"Undo restores original hook and lamp orientation")
	# Place once more and reconstruct from the actual save.
	builder._values.length.value=2.4;builder._values.width.value=.8
	await drag(at,target);await click(builder._trellis_actions.get_node("RotateTrellis"))
	if not await ready_draft(): await finish();return
	if not await apply(): await finish();return
	var final_plan: Dictionary=scene.courtyard_plan.snapshot()
	var final_lamp: Transform3D=lamp.global_transform
	var final_flower: Transform3D=flower.global_transform
	var animals: Node=scene.get_node("Environment/CourtyardAnimals")
	started=Time.get_ticks_msec()
	while scene.get_node("Environment")._terrain_refreshing:
		await process_frame
		if Time.get_ticks_msec()-started>20000: expect(false,"Trellis animal routes finish updating");break
	var endpoints: Dictionary=scene.get_node("Environment").circulation.endpoints
	expect(not animals.yard.path(endpoints.house,endpoints.trellis).is_empty(),"New trellis remains reachable from the house")
	root.remove_child(scene);scene.free();await frames()
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(path);scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return now
	root.add_child(scene);current_scene=scene;await frames(8)
	expect(scene.courtyard_plan.snapshot()==final_plan,"Reopen retains translated and rotated trellis parameters")
	expect(scene.decoration_layout._instances.lantern.global_transform.is_equal_approx(final_lamp),"Reopen retains lantern world pose")
	expect(scene.get_node("Environment/Flowers0_0").global_transform.is_equal_approx(final_flower),"Reopen retains flower world pose")
	scene._begin_construction("trellis");await create_timer(1).timeout
	root.size=Vector2i(960,640);await frames()
	expect(root.get_visible_rect().encloses(scene.island_builder._panel.get_global_rect()),"Trellis controls fit minimum window")
	await shot("05-reopened-small")
	await finish()

func finish_while_checking(builder: Node) -> void:
	builder._values.width.value=.8;builder._values.height.value=2.4
	expect(builder.trellis_preview.pending,"Route check is pending immediately after a parameter edit")
	var wanted: Dictionary=builder.candidate.snapshot()
	var started: int=Time.get_ticks_msec()
	builder.finish()
	expect(builder.busy,"One finish request is retained while its route check runs")
	while builder.busy:
		await process_frame
		if Time.get_ticks_msec()-started>10000: expect(false,"Pending finish completes");break
	print("TRELLIS_PENDING_FINISH_MS ",Time.get_ticks_msec()-started)
	expect(not builder.active and scene.farm_state.snapshot().layout==wanted,"Pending finish saves and exits without a second click")
	scene.focus_detail.set_quality("high")
	for mesh: MeshInstance3D in scene.get_node("Environment/EntranceTrellis").find_children("*","MeshInstance3D",true,false):
		expect(mesh.gi_mode==GeometryInstance3D.GI_MODE_STATIC,"Accepted trellis joins high-quality indirect lighting")
	scene.atmosphere.set_preview_hour(22);await frames(10)
	var lamp: Node3D=scene.decoration_layout._instances.lantern
	var light: OmniLight3D=lamp.get_node("FarmLanternLight")
	expect(light.visible and light.light_energy>0 and light.global_position.distance_to(scene.courtyard_plan.slots.hanging_03-Vector3.UP*.22)<.001,"Night light follows the committed hook")
	await shot("06-high-quality-night")
