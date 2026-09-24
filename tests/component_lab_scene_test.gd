extends SceneTree
var failures: Array[String] = []
var output: String
var measurements: Array[Dictionary] = []
const Kit = preload("res://scenes/procedural_lab/railing_kit.gd")

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _run() -> void:
	if "--bamboo-review" in OS.get_cmdline_user_args():
		await bamboo_review()
		return
	root.size=Vector2i(1600,1000)
	output=ProjectSettings.globalize_path("res://../.local/verification/component-lab")
	DirAccess.make_dir_recursive_absolute(output)
	for kind: String in ["railing","rack"]:
		for options: Dictionary in [{},{"length":2.4,"height":.7 if kind == "railing" else 1.6,"width":1,"bay":.8,"slope":-.18,"path":0},{"length":8,"height":1.4 if kind == "railing" else 2.8,"width":3,"bay":1.8,"slope":.18,"path":2}]:
			var plan: Dictionary=Kit.plan("验收26",options,kind)
			expect(plan==Kit.plan("验收26",options,kind),"seed and parameters reproduce the plan")
			var points: Array=plan.points
			for i: int in range(points.size()-1):
				var delta: Vector3=points[i+1]-points[i]
				expect(Vector2(delta.x,delta.z).length()<=plan.settings.bay+.001,"bay length stays within requested spacing")
			var model: Node3D=Kit.build(plan)
			if kind == "railing":
				for child: Node in model.get_children():
					if not child.name.begins_with("fence_post_"): continue
					var batch: MultiMesh=child.multimesh
					expect(batch.instance_count==points.size(),"each shared corner has exactly one post")
					for i: int in batch.instance_count:
						var pose: Transform3D=batch.get_instance_transform(i)
						var bounds: AABB=pose*batch.mesh.get_aabb()
						expect(absf(bounds.position.y-Kit.ground(points[i].x,plan.settings.slope))<.015,"actual imported post rests on terrain")
			model.free()
	var scene: Node3D=load("res://scenes/procedural_lab/component_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	await measure(scene,"railing-default")
	await capture("railing")
	scene.focus("joint"); await capture("railing-joint")
	scene.focus("reverse"); await capture("railing-joint-reverse")
	scene.compare_check.button_pressed=true
	while scene.busy: await process_frame
	await capture("railing-three")
	scene.compare_check.button_pressed=false
	while scene.busy: await process_frame
	scene._select_kind(1)
	while scene.busy: await process_frame
	await capture("rack")
	await measure(scene,"rack-default")
	scene.distance=40; scene.desired_distance=40
	await capture("rack-far")
	scene.focus("all")
	await capture("rack-return-near")
	scene.focus("joint"); await capture("rack-joint")
	scene.focus("reverse"); await capture("rack-joint-reverse")
	scene.controls.slope.value=.18
	scene.controls.length.value=8
	scene.seed_input.text="坡地竹架"
	await click(scene.generate_button)
	while scene.busy: await process_frame
	expect(scene.current_plan.seed=="坡地竹架" and is_equal_approx(scene.current_plan.settings.slope,.18),"real button applies edited seed and slope")
	await capture("rack-slope")
	await click(scene.export_button)
	var exported: Variant=JSON.parse_string(DisplayServer.clipboard_get())
	expect(exported is Dictionary and exported.seed=="坡地竹架" and exported.parameters.length==8,"copy exports current generated parameters")
	var before: Node3D=scene.world
	scene.seed_input.text=" "
	await click(scene.generate_button)
	expect(scene.world==before and "请输入" in scene.status.text,"empty seed preserves the visible model")
	scene.seed_input.text="三种竹架"
	scene.compare_check.button_pressed=true
	while scene.busy: await process_frame
	await capture("rack-three")
	root.size=Vector2i(1100,760)
	await capture("small-window")
	var file := FileAccess.open(output+"/measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t")); file.close()
	scene.queue_free()
	await process_frame
	print("COMPONENT_LAB_TEST failures=%s"%JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func measure(scene: Node3D,label: String) -> void:
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	# Performance monitors update periodically. Exclude the preceding screenshot
	# readback and external memory probe before sampling this steady scene.
	await create_timer(2.5).timeout
	var cpu: Array[float]=[]
	var gpu: Array[float]=[]
	var process: Array[float]=[]
	var focused: int=0
	for i: int in 120:
		await process_frame
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())+RenderingServer.get_frame_setup_time_cpu())
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		if DisplayServer.window_is_focused(): focused+=1
	cpu.sort(); gpu.sort(); process.sort()
	var shell: Array=[]
	var code: int=OS.execute("powershell.exe",["-NoProfile","-Command","(Get-Process -Id %d).WorkingSet64"%OS.get_process_id()],shell)
	measurements.append({"case":label,"generation_ms":scene.generation_ms,"cpu_render_median_ms":cpu[60],"gpu_median_ms":gpu[60],"cpu_process_median_ms":process[60],"working_set_bytes":str(shell[0]).strip_edges().to_int() if code==0 else -1,"engine_video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"frames":120,"focused_frames":focused,"viewport":str(root.size),"scale_3d":root.scaling_3d_scale,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_driver_name()})
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),false)

func click(button: Button) -> void:
	var at: Vector2=button.get_global_rect().get_center()
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.position=at; event.pressed=pressed
		root.push_input(event,true)
		await process_frame

func capture(name: String) -> void:
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")

func bamboo_review() -> void:
	var before: bool="--before" in OS.get_cmdline_user_args()
	output=ProjectSettings.globalize_path("res://../.local/verification/bamboo-material/"+("before" if before else "after"))
	DirAccess.make_dir_recursive_absolute(output)
	var scene: Node3D=load("res://scenes/procedural_lab/component_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	scene._select_kind(1)
	while scene.busy: await process_frame
	await capture("01-whole")
	scene.focus("joint"); await capture("02-joint")
	scene.focus("reverse"); await capture("03-reverse")
	if not before:
		var atlas: Texture2D=load("res://art/environment/parametric_kit/bamboo_gongbi_atlas.png")
		expect(atlas.get_width()<=1024 and atlas.get_image().has_mipmaps(),"bamboo atlas has bounded size and mipmaps")
		var parts: GDScript=load("res://scenes/procedural_lab/kit_parts.gd")
		for part: String in ["bamboo","bamboo_low","node","binding"]:
			for source: Dictionary in parts._source(part):
				for surface: int in source.mesh.get_surface_count():
					var mat: StandardMaterial3D=source.mesh.surface_get_material(surface)
					expect(mat.albedo_texture==atlas,"all bamboo surfaces share the painted atlas: "+part)
					expect(mat.albedo_color.r<.9 and mat.albedo_color.g<.9,"authored muted tint survives export: "+part)
					expect(not mat.normal_enabled and mat.normal_texture==null and mat.roughness_texture==null,"bamboo keeps relief off: "+part)
					expect(mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"bamboo remains opaque: "+part)
		for options: Dictionary in [{"length":2.4,"height":1.6,"width":1.0,"slope":-.18},{"length":8.0,"height":2.8,"width":3.0,"slope":.18}]:
			for key: String in options: scene.controls[key].value=options[key]
			await click(scene.generate_button)
			while scene.busy: await process_frame
			scene.focus("all"); await capture("04-boundary-"+str(options.length))
		scene.distance=40; scene.desired_distance=40; scene._update_camera(); await capture("05-far")
		scene.focus("joint"); await capture("06-return")
		for child: Node in scene.get_children():
			if child.has_method("set_preview_hour"):
				child.set_preview_hour(18.5)
		await capture("07-dusk")
	scene.queue_free()
	await process_frame
	print("BAMBOO_MATERIAL_REVIEW failures=%s"%JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
