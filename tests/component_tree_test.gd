extends "component_lab_scene_test.gd"
## Reuse the lab's capture/input/measurement helpers; exercise tree-specific risks.
const TreeKit = preload("res://scenes/procedural_lab/tree_kit.gd")

func _run() -> void:
	root.size=Vector2i(1600,1000)
	output=ProjectSettings.globalize_path("res://../.local/verification/component-tree-final")
	DirAccess.make_dir_recursive_absolute(output)
	var cases: Array[Dictionary]=[{}, {"height":3,"spread":2.8,"density":0,"bias":0}, {"height":5.8,"spread":6,"density":1,"bias":.7}, {"height":3,"spread":6,"density":1,"bias":.7}, {"height":5.8,"spread":2.8,"density":0,"bias":0}]
	for options: Dictionary in cases:
		var data: Dictionary=TreeKit.plan("桂花验收-26",options)
		expect(data==TreeKit.plan("桂花验收-26",options),"tree seed and parameters reproduce geometry and placements")
		expect(data.clusters!=TreeKit.plan("桂花验收-27",options).clusters,"different seeds change crown placements")
		var model: Node3D=TreeKit.build(data)
		var trunk: MeshInstance3D=model.get_node("Framework_near")
		expect(absf(trunk.mesh.get_aabb().position.y-.13)<.004,"actual rootstock remains grounded at parameter bounds")
		var bounds: AABB=trunk.mesh.get_aabb()
		var low := bounds.position
		var high := bounds.end
		var wood: PackedVector3Array=trunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var largest_gap: float=0
		for anchor: Vector3 in data.anchors:
			var gap: float=INF
			for vertex: Vector3 in wood: gap=minf(gap,anchor.distance_to(vertex))
			largest_gap=maxf(largest_gap,gap)
		expect(largest_gap<.12,"leaf attachment stays within branch collar: %f"%largest_gap)
		for node: Node in model.get_children():
			if not node.name.begins_with("tree_cluster_near"): continue
			var mesh: Mesh=node.multimesh.mesh
			var arrays: Array=mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			for i: int in vertices.size():
				if vertices[i].y<.15: expect(weights[i].r==0 and weights[i].g==0,"authored stem attachment cannot drift in wind")
			for i: int in node.multimesh.instance_count:
				var pose: Transform3D=node.multimesh.get_instance_transform(i)
				for vertex: Vector3 in vertices:
					var v: Vector3=pose*vertex; low=low.min(v); high=high.max(v)
		expect(absf((high-low).y-data.settings.height)<.01,"actual generated tree height matches metres in UI")
		expect(absf(maxf((high-low).x,(high-low).z)-data.settings.spread)<.01,"actual generated crown span matches metres in UI")
		expect(low.y>=.129,"no leaves extend below the stage")
		model.free()
	var scene: Node3D=load("res://scenes/procedural_lab/component_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	scene._select_kind(2)
	while scene.busy: await process_frame
	# Warm generation is separate from first resource loading/shader compilation.
	var first_generation: float=scene.generation_ms
	await scene.regenerate()
	await measure(scene,"tree-default-warm")
	measurements[-1].first_generation_ms=first_generation
	measurements[-1].cluster_count=scene.current_plan.clusters.size()
	await capture("tree-default")
	scene.focus("joint"); await capture("tree-joint")
	scene.focus("reverse"); await capture("tree-joint-reverse")
	scene.wind_check.button_pressed=false
	for node: Node in scene.world.find_children("tree_cluster*","MultiMeshInstance3D",true,false):
		expect(node.get_instance_shader_parameter("wind_motion")==Vector4.ZERO,"wind toggle freezes branch and leaf motion")
	await capture("tree-static")
	scene.wind_check.button_pressed=true
	await capture("tree-wind-a"); await create_timer(.8).timeout; await capture("tree-wind-b")
	scene.focus("all"); scene.distance=40; scene.desired_distance=40
	await capture("tree-far")
	scene.focus("all"); await capture("tree-return-near")
	scene.seed_input.text="偏冠桂花"
	scene.controls.bias.value=.7; scene.controls.spread.value=5.8
	await click(scene.generate_button)
	while scene.busy: await process_frame
	expect(scene.current_plan.seed=="偏冠桂花" and is_equal_approx(scene.current_plan.settings.bias,.7),"real controls regenerate the selected tree")
	await click(scene.export_button)
	var copied: Dictionary=JSON.parse_string(DisplayServer.clipboard_get())
	expect(copied.kind=="tree" and copied.seed=="偏冠桂花" and is_equal_approx(copied.parameters.bias,.7),"tree copy exports currently displayed parameters")
	scene.compare_check.button_pressed=true
	while scene.busy: await process_frame
	scene.yaw=PI*.5; scene.pitch=.28; scene.distance=29; scene.desired_distance=29
	await capture("tree-three")
	scene.compare_check.button_pressed=false
	while scene.busy: await process_frame
	for i: int in [3,4]:
		for key: String in cases[i]: scene.controls[key].value=cases[i][key]
		await scene.regenerate()
		await capture("tree-boundary-%d"%i)
	# Show the actual adopted main-island tree beside this generator, with the
	# same sun, environment and camera. Keep reference geometry/material intact.
	for key: String in TreeKit.DEFAULTS: scene.controls[key].value=TreeKit.DEFAULTS[key]
	scene.seed_input.text="水乡木作-26"; await scene.regenerate()
	var generated: Node3D=scene.world.get_child(0); generated.position.x=-3.3
	generated.rotation.y=-scene.current_plan.shape.yaw
	var reference := Node3D.new(); reference.position.x=3.3
	var tree: Node3D=load("res://art/environment/osmanthus/osmanthus_high.glb").instantiate()
	tree.position.y=.13; reference.add_child(tree)
	TreeKit.wind.apply(tree,"osmanthus")
	var stage: Node3D=scene._ground(TreeKit.DEFAULTS); reference.add_child(stage)
	scene.world.add_child(reference)
	for pair: Array in [[generated,"参数化桂花"],[reference,"主岛桂花"]]:
		var label := Label3D.new(); label.font=preload("res://art/ui/fonts/汇文明朝体.ttf")
		label.text=pair[1]; label.font_size=48; label.pixel_size=.006
		label.position.y=4.8; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		pair[0].add_child(label)
	scene.target=Vector3(0,2,0); scene.yaw=.10; scene.pitch=.25; scene.distance=20; scene.desired_distance=20
	await capture("tree-main-island-comparison")
	scene.yaw+=PI; await capture("tree-main-island-comparison-reverse")
	var file := FileAccess.open(output+"/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t")); file.close()
	scene.queue_free(); await process_frame
	print("COMPONENT_TREE_TEST failures=%s"%JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
