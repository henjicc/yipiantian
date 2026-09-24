extends "component_lab_scene_test.gd"
const HouseKit = preload("res://scenes/procedural_lab/house_kit.gd")

func _run() -> void:
	root.size=Vector2i(1600,1000)
	output=ProjectSettings.globalize_path("res://../.local/verification/component-house-final")
	DirAccess.make_dir_recursive_absolute(output)
	var cases: Array[Dictionary]=[{}, {"bays":2,"depth":3.6,"height":2.4,"pitch":22,"porch":0,"openings":0}, {"bays":3,"depth":5.2,"height":3.2,"pitch":38,"porch":1,"openings":2}, {"bays":2,"depth":5.2,"height":2.4,"pitch":38,"porch":1,"openings":1}]
	for options: Dictionary in cases:
		var data: Dictionary=HouseKit.plan("廊屋验收-26",options)
		expect(data==HouseKit.plan("廊屋验收-26",options),"house layout reproduces from seed and parameters")
		var model: Node3D=HouseKit.build(data)
		var doors: int=0
		var lowest: float=INF
		var opening := AABB(Vector3(data.door_x-.62,HouseKit.FLOOR+.12,data.settings.depth*.5-.06),Vector3(1.24,1.94,.12))
		for node: Node in model.get_children():
			if node.name.ends_with("_far"): continue
			var batch: MultiMesh=node.multimesh
			if node.name.begins_with("house_door"): doors+=batch.instance_count
			for i: int in batch.instance_count:
				var pose: Transform3D=batch.get_instance_transform(i)
				var bounds: AABB=pose*batch.mesh.get_aabb()
				lowest=minf(lowest,bounds.position.y)
				if node.name.begins_with("house_wall"):
					expect(not bounds.intersects(opening),"front wall leaves the selected door opening clear")
				if node.name.begins_with("house_post"):
					expect(bounds.position.y>=.472 and bounds.position.y<=.481,"column feet land on stone foundation")
					expect(bounds.end.y<HouseKit.roof_y(pose.origin.z,data.settings)-.025,"posts remain below ceramic roof")
				if node.name.begins_with("house_door"):
					expect(absf(pose.origin.x-data.door_x)<.001,"door geometry follows chosen bay")
			expect(not batch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].is_empty(),"all referenced modules imported")
		expect(doors==1,"each house has one complete double door")
		expect(absf(lowest-.13)<.002,"actual foundation and steps rest on ground")
		model.free()
	var scene: Node3D=load("res://scenes/procedural_lab/component_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	scene._select_kind(3)
	while scene.busy: await process_frame
	var first: float=scene.generation_ms
	await scene.regenerate(); await measure(scene,"house-default-warm")
	measurements[-1].first_generation_ms=first
	await capture("house-default")
	scene.focus("reverse"); await capture("house-back")
	scene.focus("joint"); await capture("house-joint")
	scene.focus("reverse"); await capture("house-joint-reverse")
	scene.focus("all"); scene.distance=40; scene.desired_distance=40
	await capture("house-far"); scene.focus("all"); await capture("house-return-near")
	scene.seed_input.text="右门小院"; scene.controls.openings.value=2; scene.controls.bays.value=2
	await click(scene.generate_button)
	while scene.busy: await process_frame
	expect(scene.current_plan.door_bay==1 and scene.current_plan.settings.bays==2,"real UI applies bay count and door scheme")
	await click(scene.export_button)
	var copied: Dictionary=JSON.parse_string(DisplayServer.clipboard_get())
	expect(copied.kind=="house" and copied.parameters.bays==2 and copied.parameters.openings==2,"copy records displayed house configuration")
	scene.compare_check.button_pressed=true
	while scene.busy: await process_frame
	await capture("house-three")
	scene.compare_check.button_pressed=false
	while scene.busy: await process_frame
	for i: int in range(1,cases.size()):
		for key: String in cases[i]: scene.controls[key].value=cases[i][key]
		await scene.regenerate(); await capture("house-boundary-%d"%i)
		scene.focus("reverse"); await capture("house-boundary-%d-back"%i)
	for key: String in HouseKit.DEFAULTS: scene.controls[key].value=HouseKit.DEFAULTS[key]
	await scene.regenerate()
	var generated: Node3D=scene.world.get_child(0); generated.position.x=-4.9
	var reference := Node3D.new(); reference.position.x=4.9
	var house: Node3D=load("res://art/environment/house/house_high.glb").instantiate()
	house.position.y=.13; reference.add_child(house)
	reference.add_child(scene._ground(HouseKit.DEFAULTS)); scene.world.add_child(reference)
	for pair: Array in [[generated,"参数化民居"],[reference,"主岛民居"]]:
		var label := Label3D.new(); label.font=preload("res://art/ui/fonts/汇文明朝体.ttf")
		label.text=pair[1]; label.font_size=48; label.pixel_size=.007; label.position.y=5.6
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; pair[0].add_child(label)
	scene.target=Vector3(0,2.2,0); scene.yaw=.10; scene.pitch=.35; scene.distance=29; scene.desired_distance=29
	await capture("house-main-island-comparison")
	scene.yaw+=PI; await capture("house-main-island-comparison-reverse")
	root.size=Vector2i(1100,760)
	await scene.regenerate()
	await capture("house-small-window")
	await click(scene.export_button)
	expect("已复制" in scene.status.text,"house copy control remains accessible in small window")
	var file := FileAccess.open(output+"/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t")); file.close()
	scene.queue_free(); await process_frame
	print("COMPONENT_HOUSE_TEST failures=%s"%JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
