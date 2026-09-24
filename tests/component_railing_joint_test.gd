extends "component_lab_scene_test.gd"
const Parts = preload("res://scenes/procedural_lab/kit_parts.gd")

func _run() -> void:
	var review_4k: bool="--railing-review-4k" in OS.get_cmdline_user_args()
	root.size=Vector2i(3840,2160) if review_4k else Vector2i(1600,1000)
	output=ProjectSettings.globalize_path("res://../.local/verification/railing-rope")
	DirAccess.make_dir_recursive_absolute(output)
	var rail_texture: Texture2D=Parts._source("fence_rail")[0].mesh.surface_get_material(0).albedo_texture
	var rope_surfaces: int=0
	for part: String in ["fence_rail","fence_post","fence_post_low"]:
		for source: Dictionary in Parts._source(part):
			for surface: int in source.mesh.get_surface_count():
				var material: StandardMaterial3D=source.mesh.surface_get_material(surface)
				expect(material.albedo_texture==rail_texture,"timber and rope reuse one original colour atlas")
				expect(not material.normal_enabled and material.normal_texture==null,"all railing relief is disabled and unreferenced")
				expect(material.roughness_texture==null and material.metallic_texture==null,"no extra roughness/metallic maps are sampled")
				if material.resource_name.begins_with("MutedHemp"):
					rope_surfaces+=1
					expect(material.albedo_color.r<.85 and material.albedo_color.g<.85,"rope uses a darker hemp tint")
					var uvs: PackedVector2Array=source.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]
					var uv_bounds := Rect2(uvs[0],Vector2.ZERO)
					for uv: Vector2 in uvs: uv_bounds=uv_bounds.expand(uv)
					expect(uv_bounds.size.x>.005 and uv_bounds.size.y>.03,"rope retains its strand texture UVs after joining/export")
	expect(rope_surfaces==1,"near upright includes one textured hemp surface")
	print("RAILING_MATERIALS shared_atlases=1 normal_maps=0 roughness_maps=0")
	for path: int in 3:
		for options: Dictionary in [{"path":path},{"path":path,"length":2.4,"height":.7,"bay":.8,"slope":-.18},{"path":path,"length":8,"height":1.4,"bay":1.8,"slope":.18}]:
			var model: Node3D=Kit.build(Kit.plan("实木连接验收",options,"railing"))
			var posts: MultiMesh=model.get_node("fence_post_near").multimesh
			var rails: MultiMesh=model.get_node("fence_rail_both").multimesh
			for i: int in rails.instance_count:
				var rail: Transform3D=rails.get_instance_transform(i)
				for side: float in [-.5,.5]:
					var end: Vector3=rail*Vector3(0,0,side)
					var embedded: bool=false
					for j: int in posts.instance_count:
						var local: Vector3=posts.get_instance_transform(j).affine_inverse()*end
						if absf(local.x)<.065 and absf(local.z)<.065 and local.y>.02 and local.y<.81: embedded=true
					expect(embedded,"every actual rail/brace end lies inside a solid upright at turns and slope limits")
			model.free()
	var scene: Node3D=load("res://scenes/procedural_lab/component_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	await capture("railing-default")
	scene.focus("joint"); await capture("railing-joint")
	if review_4k:
		expect(root.scaling_3d_mode==Viewport.SCALING_3D_MODE_BILINEAR and is_equal_approx(root.scaling_3d_scale,.5),"actual 4K lab is bilinear 1080p, not FSR")
	scene.focus("reverse"); await capture("railing-joint-reverse")
	scene.compare_check.button_pressed=true
	while scene.busy: await process_frame
	await capture("railing-three")
	scene.compare_check.button_pressed=false
	while scene.busy: await process_frame
	for options: Dictionary in [{"path":2,"length":8,"height":1.4,"slope":.18},{"path":0,"length":2.4,"height":.7,"slope":-.18}]:
		for key: String in options: scene.controls[key].value=options[key]
		await scene.regenerate()
		var suffix: String="max" if options.path==2 else "min"
		scene.focus("joint"); await capture("railing-"+suffix+"-joint")
		scene.focus("reverse"); await capture("railing-"+suffix+"-reverse")
	scene.focus("all"); scene.distance=40; scene.desired_distance=40
	await capture("railing-far")
	scene.focus("all"); await capture("railing-return")
	print("SOLID_RAILING_TEST failures=%s"%JSON.stringify(failures))
	if failures.is_empty():
		var escape := InputEventKey.new()
		escape.keycode=KEY_ESCAPE; escape.pressed=true
		root.push_input(escape,true)
		await process_frame
		return
	scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
