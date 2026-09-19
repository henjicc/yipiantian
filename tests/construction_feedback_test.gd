extends "res://../tests/island_fields_test.gd"

func hover(point: Vector3) -> void:
	var event:=InputEventMouseMotion.new();event.position=scene.camera.unproject_position(point);event.window_id=root.get_window_id()
	root.push_input(event,true);await frames()

func _run() -> void:
	root.size=Vector2i(1600,900)
	folder=ProjectSettings.globalize_path("res://../.local/verification/construction-feedback-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder)
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"));scene.clock=func() -> float: return 2000000.0
	root.add_child(scene);current_scene=scene;await frames(8);scene.atmosphere.set_preview_hour(11)
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	var brush: Node=scene.island_builder
	var saved: Dictionary=scene.farm_state.snapshot().layout
	await hover(Vector3(0,.13,6))
	expect(brush._last_cell.distance_to(Vector2(0,6))<.001 and brush.draft==saved,"Hover locates the brush before painting without changing land")
	await shot("01-land-hover-day")
	await drag(Vector3(0,.13,6),Vector3(0,.13,7.5))
	expect(brush.draft!=saved,"Visible brush overlay does not intercept real painting")
	await shot("02-land-drag-day")
	await click(brush._panel.find_child("Cancel",true,false))
	expect(brush.draft==saved,"Panel cancel still receives pointer input above the outline")
	await choose_tool("fields")
	var field: Dictionary=brush.candidate.fields[brush.selected_field]
	var handle: Vector3=brush.candidate.field_transform(brush.selected_field)*Vector3(field.size.x*.5,.12,field.size.y*.5)
	await shot("03-field-handles-day")
	await mouse(scene.camera.unproject_position(handle),true)
	expect(brush._field_gesture=="resize","Visible field size handle remains aligned with its hit target")
	brush._focus_lost();await mouse(scene.camera.unproject_position(handle),false)
	expect(brush.draft==saved,"Cancelling a handle gesture retains authoritative fields")
	await choose_tool("bridge")
	var ends: Array[Vector3]=Construction.bridge_points(scene.courtyard_plan)
	await mouse(scene.camera.unproject_position(ends[1]+Vector3.UP*.12),true)
	expect(brush._bridge_end==1,"Visible east bridge marker selects the east endpoint")
	brush._focus_lost();await mouse(scene.camera.unproject_position(ends[1]+Vector3.UP*.12),false)
	scene.atmosphere.set_preview_hour(21);await frames(8);await shot("04-bridge-night")
	await choose_tool("bench")
	await drag(Vector3(0,.13,9),Vector3(0,.13,9))
	expect(scene.decoration_layout.has_preview() and not scene.decoration_layout.placement_issue(scene.decoration_layout._preview,"bench","").is_empty(),"Unsupported bench keeps actual conflict feedback")
	await shot("05-bench-conflict-night")
	await click(brush._panel.find_child("Cancel",true,false))
	expect(not scene.decoration_layout.has_preview(),"Cancelling removes furniture preview and its outline")
	root.size=Vector2i(960,640);await frames()
	await choose_tool("fields")
	await shot("06-field-small-night")
	expect(root.get_visible_rect().encloses(brush._panel.get_global_rect()),"Selected construction controls fit the small window")
	field=brush.candidate.fields[brush.selected_field]
	handle=brush.candidate.field_transform(brush.selected_field)*Vector3(field.size.x*.5,.12,field.size.y*.5)
	await mouse(scene.camera.unproject_position(handle),true)
	expect(brush._field_gesture=="resize","Resized-window handle still matches the visible marker")
	brush._focus_lost();await mouse(scene.camera.unproject_position(handle),false)
	for id: String in ["trellis","bridge","reed","ducks","house","bench"]:
		await choose_tool(id)
		expect(root.get_visible_rect().encloses(brush._panel.get_global_rect()),"Small-window panel fits "+id)
		if id in ["trellis","reed"]: await shot("06-small-"+id)
	await choose_tool("land");await hover(Vector3(0,.13,6))
	await shot("07-land-small-night")
	await click(brush._panel.find_child("Finish",true,false))
	expect(not brush.active and scene.farm_state.snapshot().layout==saved,"Finish exits cleanly with all cancelled changes absent")
	await finish()
