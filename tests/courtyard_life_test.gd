extends SceneTree
## Focused asset/contact/atmosphere inspection; isolated saves and reproducible shots.
var scene: Node3D
var output: String
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _run() -> void:
	output=ProjectSettings.globalize_path("res://../.local/verification/courtyard-life")
	DirAccess.make_dir_recursive_absolute(output)
	root.size=Vector2i(1920,1080)
	scene=load("res://scenes/main.tscn").instantiate()
	var isolated: String=output.path_join("session-%d"%Time.get_ticks_usec())
	scene.store=load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store=load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	root.add_child(scene)
	scene.atmosphere.set_preview_hour(14.25)
	await create_timer(1.5).timeout
	var settings: Dictionary=scene.focus_detail.get_settings()
	check(is_equal_approx(settings.dof_strength,1.7) and is_equal_approx(settings.fog_strength,.28),"Requested default atmosphere")
	var environment: Node3D=scene.get_node("Environment")
	check(environment.has_node("Kitchen"),"New generated kitchen is active")
	check(not environment.has_node("PorchBench"),"Overlapping bench removed")
	var animals: Node3D=environment.get_node("CourtyardAnimals")
	check(animals._swimmers.size()==5 and animals._hens.size()==2,"Bounded ambient animal population")
	for bird: Node3D in animals.get_children():
		if bird.name.begins_with("Lake") or bird.name.begins_with("YardHen"):
			var players: Array[Node]=bird.find_children("*","AnimationPlayer",true,false)
			check(not players.is_empty(),"Bird rig animation imported: "+bird.name)
			check(animals.ready_for_motion,"Distance-driven bird rig ready: "+bird.name)
	check(not environment.get_node("OsmanthusLeaves").is_processing(),"Petals use render-time motion without CPU streaming")
	await shot("01-day-overview.png")
	scene.focus_detail.set_fog_strength(0.0)
	await shot("02-fog-off.png")
	var clear: Image=root.get_texture().get_image()
	scene.focus_detail.set_fog_strength(1.0)
	await shot("03-fog-full.png")
	var hazy: Image=root.get_texture().get_image()
	for island: String in ["WillowNeighbor","EasternCottage"]:
		var node: Node3D=environment.get_node("NeighborIslets/"+island)
		var pixel: Vector2=scene.camera.unproject_position(node.global_position+Vector3(0,1.0,0))
		var change: float=0.0
		for dx: int in range(-6,7):
			for dy: int in range(-6,7):
				var p:=Vector2i(pixel)+Vector2i(dx,dy)
				if p.x>=0 and p.y>=0 and p.x<clear.get_width() and p.y<clear.get_height():
					var a: Color=clear.get_pixelv(p)
					var b: Color=hazy.get_pixelv(p)
					change+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
		check(change>.8,"Lateral island responds to haze: "+island)
		print("LATERAL_HAZE_CHANGE ",island," ",change)
	scene.focus_detail.set_fog_strength(.28)
	var held: float=scene.camera.attributes.dof_blur_amount
	scene._focus_field(0)
	for i: int in 12:
		await create_timer(.08).timeout
		check(scene.camera.attributes.dof_blur_far_enabled and is_equal_approx(held,scene.camera.attributes.dof_blur_amount),"Focus preserves DOF strength")
	await shot("04-field-close.png")
	scene._return_overview()
	await create_timer(1.2).timeout
	scene.atmosphere.set_preview_hour(21.0)
	await shot("05-night-overview.png")
	scene.camera.set_free_view(true)
	scene.camera.position=Vector3(8,7,11)
	scene.camera.look_at(Vector3(.1,.9,-1.7))
	scene.camera.fov=42
	await shot("06-night-lanterns.png")
	scene.atmosphere.set_preview_hour(14.25)
	scene.camera.position=Vector3(-9,7,8)
	scene.camera.look_at(Vector3(-2.7,1.0,-1.5))
	await shot("07-west-contacts.png")
	scene.camera.position=Vector3(10,6,-1.5)
	scene.camera.look_at(Vector3(1.8,.8,-1.7))
	await shot("08-east-contacts.png")
	scene.camera.position=Vector3(-8,5,-8)
	scene.camera.look_at(Vector3(-3.9,.9,-2.5))
	await shot("09-reverse-contacts.png")
	scene.camera.position=Vector3(5,3,12)
	scene.camera.look_at(Vector3(2.9,-.1,8.85))
	scene.camera.fov=35
	await shot("10-swimming.png")
	for i: int in 3:
		await create_timer(.25).timeout
		await shot("motion-%02d.png"%i)
	print("COURTYARD_LIFE_PASS" if failures.is_empty() else str(failures))
	scene.farm_audio.shutdown()
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func shot(filename: String) -> void:
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))
