extends "component_lab_scene_test.gd"
const TreeKit = preload("res://scenes/procedural_lab/tree_kit.gd")
const HouseKit = preload("res://scenes/procedural_lab/house_kit.gd")
const Parts = preload("res://scenes/procedural_lab/kit_parts.gd")

func _run() -> void:
	root.size=Vector2i(1600,1000)
	output=ProjectSettings.globalize_path("res://../.local/verification/component-collection")
	DirAccess.make_dir_recursive_absolute(output)
	var scene: Node3D=load("res://scenes/procedural_lab/component_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	_clear(scene)
	var start: int=Time.get_ticks_usec()
	var plans: Array[Dictionary]=[Kit.plan("组合验收",{},"railing"),Kit.plan("组合验收",{},"rack"),TreeKit.plan("组合验收",{}),HouseKit.plan("组合验收",{})]
	var positions: Array[Vector3]=[Vector3(0,0,5),Vector3(5.2,0,1),Vector3(-5.2,0,0),Vector3(0,0,-4.2)]
	for i: int in plans.size():
		scene.kind=plans[i].kind
		var holder := Node3D.new(); holder.position=positions[i]
		holder.add_child(scene._build(plans[i])); holder.add_child(scene._ground(plans[i].settings))
		scene.world.add_child(holder)
		_label(holder,["木栏杆","竹架","桂花树","江南民居"][i],6.0 if i==2 else 5.6)
	scene.generation_ms=(Time.get_ticks_usec()-start)/1000.0
	scene._set_wind(true)
	scene.target=Vector3(0,1.6,0); scene.yaw=.55; scene.pitch=.48
	scene.distance=24; scene.desired_distance=24
	scene.statistics.text="组合场景 · 四类构件"
	scene.status.text="四类构件 · 同光照测量"
	await measure(scene,"four-kinds-first-build")
	await capture("collection-near")
	await _tree_pixels(scene,plans[2].bounds)
	for d: float in [25.0,26.0,27.0,24.0]:
		scene.distance=d; scene.desired_distance=d
		await capture("collection-transition-%d"%d)
		await _tree_pixels(scene,plans[2].bounds)
	scene.distance=43; scene.desired_distance=43
	await measure(scene,"four-kinds-far")
	await capture("collection-far")
	# A second build must reuse the existing static mesh resources, not copy them.
	var meshes: Dictionary={}
	for key: String in Parts.sources: meshes[key]=Parts.sources[key][0].mesh
	start=Time.get_ticks_usec()
	for data: Dictionary in plans:
		scene.kind=data.kind
		scene.seed_input.text=data.seed
		var model: Node3D=scene._build(scene._plan(data.settings)); model.free()
	var warm_ms: float=(Time.get_ticks_usec()-start)/1000.0
	for key: String in meshes:
		expect(meshes[key]==Parts.sources[key][0].mesh,"repeated static module shares its mesh: "+key)
	measurements[0].warm_four_build_ms=warm_ms
	for kind: String in ["railing","rack"]:
		_clear(scene); scene.kind=kind
		scene.kind_picker.select(0 if kind=="railing" else 1)
		scene._populate_parameters(); scene.statistics.text="主岛同光照对照"
		var data: Dictionary=Kit.plan("主岛对照",{"path":0},kind)
		var generated := Node3D.new(); generated.position.z=3
		generated.add_child(Kit.build(data)); generated.add_child(scene._ground(data.settings))
		_label(generated,"参数化木栏杆" if kind=="railing" else "参数化竹架",3.1)
		scene.world.add_child(generated)
		var reference := Node3D.new(); reference.position.z=-3
		if kind=="railing":
			var spans: Array[Dictionary]=[]
			for i: int in 3:
				spans.append({"a":Vector3(-2.7+i*1.8,.13,0),"b":Vector3(-2.7+(i+1)*1.8,.13,0),"height":1.05})
			reference.add_child(preload("res://layout/fence_geometry.gd").build(spans))
		else:
			# Off-tree owner applies the actual courtyard material without starting
			# the full courtyard, simulation, save loading or background islands.
			var owner: Node3D=preload("res://scenes/environment/courtyard.gd").new()
			var model: Node3D=owner._module("climbing_trellis",Vector3(0,.13,0),0)
			owner.remove_child(model); owner.free(); reference.add_child(model)
		reference.add_child(scene._ground(data.settings))
		_label(reference,"主岛竹栏" if kind=="railing" else "主岛竹架",3.1)
		scene.world.add_child(reference)
		scene.target=Vector3(0,1.1,0); scene.pitch=.4; scene.yaw=1.1
		scene.distance=19; scene.desired_distance=19
		await capture(kind+"-main-island-comparison")
		scene.yaw+=PI; await capture(kind+"-main-island-comparison-reverse")
	var file := FileAccess.open(output+"/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t")); file.close()
	scene.queue_free(); await process_frame
	print("COMPONENT_COLLECTION_TEST failures=%s"%JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _clear(scene: Node3D) -> void:
	for node: Node in scene.world.get_children():
		scene.world.remove_child(node); node.free()

func _label(holder: Node3D,text: String,height: float) -> void:
	var label := Label3D.new(); label.font=preload("res://art/ui/fonts/汇文明朝体.ttf")
	label.text=text; label.font_size=48; label.pixel_size=.007; label.position.y=height
	label.modulate=Color("353f30"); label.outline_modulate=Color("ecebd8")
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.alpha_cut=Label3D.ALPHA_CUT_DISCARD
	holder.add_child(label)

func _tree_pixels(scene: Node3D,bounds: AABB) -> void:
	var holder: Node3D=scene.world.get_child(2)
	var model: Node3D=holder.get_child(0)
	var rect := Rect2(scene.camera.unproject_position(holder.to_global(bounds.position)),Vector2.ZERO)
	for i: int in 8: rect=rect.expand(scene.camera.unproject_position(holder.to_global(bounds.get_endpoint(i))))
	rect=rect.intersection(Rect2(Vector2.ZERO,Vector2(root.size)))
	await RenderingServer.frame_post_draw
	var visible_image: Image=root.get_texture().get_image()
	model.visible=false
	await process_frame; await RenderingServer.frame_post_draw
	var hidden_image: Image=root.get_texture().get_image()
	var changed: int=0
	for y: int in range(int(rect.position.y),int(rect.end.y),2):
		for x: int in range(int(rect.position.x),int(rect.end.x),2):
			var a: Color=visible_image.get_pixel(x,y); var b: Color=hidden_image.get_pixel(x,y)
			if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>.2: changed+=1
	expect(changed>100,"tree remains visibly rendered through LOD boundary at camera distance %f: %d samples"%[scene.distance,changed])
	model.visible=true
	await process_frame
