extends "res://../tests/component_lab_scene_test.gd"
const Path = preload("res://scenes/procedural_lab/railing_path.gd")

func _run() -> void:
	var review_4k: bool = "--drawing-review-4k" in OS.get_cmdline_user_args()
	root.size=Vector2i(3840,2160) if review_4k else Vector2i(1600,1000)
	output=ProjectSettings.globalize_path("res://../.local/verification/railing-drawing")
	if review_4k: output+="-4k"
	DirAccess.make_dir_recursive_absolute(output)
	var straight: Array = []
	var curve: Array = []
	var loop: Array = []
	for i: int in 101:
		var t: float = float(i)/100
		straight.append([-4+8*t,.035*sin(t*150)])
		curve.append([-4+8*t,1.8*sin(t*TAU)])
		loop.append([3*cos(t*TAU),2.4*sin(t*TAU)])
	var fitted: Dictionary = Path.fit(straight,1.35)
	expect(not fitted.has("error") and fitted.points.size()==7,"hand jitter is removed instead of adding dozens of posts")
	for shape: Array in [straight,curve,loop,[[-3,2],[1,2],[1,-2]]]:
		var plan: Dictionary = Kit.plan("画线验收",{"stroke":shape,"slope":.18},"railing")
		expect(not plan.has("error"),"valid line, S curve, loop and corner accepted")
		if plan.has("error"): continue
		expect(plan==Kit.plan("画线验收",{"stroke":shape,"slope":.18},"railing"),"seed and stroke reproduce exactly")
		var count: int = plan.points.size() if plan.closed else plan.points.size()-1
		for i: int in count:
			var a: Vector3 = plan.points[i]
			var b: Vector3 = plan.points[(i+1)%plan.points.size()]
			var span := Vector2(a.x-b.x,a.z-b.z)
			expect(span.length()<=1.351 and span.length()>=.279,"spans respect spacing and leave room for solid posts")
		for value: Array in shape:
			var nearest: float = INF
			for i: int in count:
				var a: Vector3 = plan.points[i]
				var b: Vector3 = plan.points[(i+1)%plan.points.size()]
				nearest=minf(nearest,Vector2(value[0],value[1]).distance_to(Geometry2D.get_closest_point_to_segment(Vector2(value[0],value[1]),Vector2(a.x,a.z),Vector2(b.x,b.z))))
			expect(nearest<=.17,"fitted fence stays within 17cm of these representative strokes")
		var model: Node3D = Kit.build(plan)
		for node: MultiMeshInstance3D in model.get_children():
			if node.name.begins_with("fence_post_"):
				expect(node.multimesh.instance_count==plan.points.size(),"closed seam has only one post")
			elif node.name.begins_with("fence_rail"):
				expect(node.multimesh.instance_count==count*3,"closing bay has both rails and brace")
		var posts: MultiMesh = model.get_node("fence_post_near").multimesh
		var rails: MultiMesh = model.get_node("fence_rail_both").multimesh
		for i: int in rails.instance_count:
			for side: float in [-.5,.5]:
				var end: Vector3 = rails.get_instance_transform(i)*Vector3(0,0,side)
				var embedded: bool = false
				for j: int in posts.instance_count:
					var local: Vector3 = posts.get_instance_transform(j).affine_inverse()*end
					if absf(local.x)<.065 and absf(local.z)<.065 and local.y>.02 and local.y<.81: embedded=true
				expect(embedded,"actual rails and braces attach inside solid posts on fitted paths and closing seam")
		model.free()
	expect(Kit.plan("闭合",{"stroke":loop},"railing").closed,"near-start release closes loop")
	for shape: Array in [[[0,0],[.1,0]],[[0,0],[0,0]],[[0,0],[3,3],[0,3],[3,0]],[[0,0],[3,0],[.1,.1]]]:
		expect(Path.fit(shape,1.35).has("error"),"short, repeated, crossing and hairpin paths are rejected")
	var scene: Node3D = load("res://scenes/procedural_lab/component_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	await click(scene.draw_button)
	while scene.busy: await process_frame
	expect(scene.brush.enabled and scene.compare_check.disabled,"real brush button switches mode")
	var camera_before: Transform3D = scene.camera.transform
	await draw(scene,curve,false)
	await create_timer(.15).timeout
	expect(is_instance_valid(scene.brush.preview),"drag displays a live railing preview")
	await capture("01-live-curve")
	await mouse_button(false,screen_point(scene,curve[-1]))
	while scene.busy: await process_frame
	expect(not scene.drawn_paths.is_empty() and not scene.current_plan.closed,"release commits an open curve")
	expect(scene.camera.transform.is_equal_approx(camera_before),"drawing does not rotate or reframe the camera")
	await capture("02-curve")
	await reset_drawing(scene)
	await draw(scene,loop)
	while scene.busy: await process_frame
	expect(scene.current_plan.closed,"mouse-drawn loop closes in the actual scene")
	await capture("03-closed")
	var saved: Array = scene.drawn_paths.duplicate(true)
	await draw(scene,straight,false)
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE; escape.pressed=true
	root.push_input(escape,true); await process_frame
	expect(not scene.brush.active and scene.drawn_paths==saved,"Esc cancels only the pending stroke")
	await draw(scene,straight,false)
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(not scene.brush.active and scene.drawn_paths==saved,"focus loss preserves accepted fence and cancels preview")
	await mouse_button(false,screen_point(scene,straight[-1]))
	await draw(scene,straight,false)
	await mouse_motion(Vector2(160,180))
	await mouse_button(false,Vector2(160,180))
	expect(not scene.brush.active and scene.drawn_paths==saved,"entering panel cancels stroke without replacing fence")
	await draw(scene,[[0,0],[1,0]],false)
	await mouse_motion(screen_point(scene,[8,0]))
	await mouse_button(false,screen_point(scene,[8,0]))
	expect(not scene.brush.active and scene.drawn_paths==saved,"leaving the ground cancels instead of bridging across water")
	await draw(scene,[[0,0],[.1,0]])
	expect(scene.drawn_paths==saved and "太短" in scene.status.text,"invalid stroke keeps the last valid model")
	scene.controls.slope.value=.18; scene.controls.bay.value=.8
	await click(scene.generate_button)
	while scene.busy: await process_frame
	expect(scene.drawn_paths==saved and scene.current_plan.closed,"changing terrain and spacing preserves the drawn loop")
	await click(scene.export_button)
	var exported: Dictionary = JSON.parse_string(DisplayServer.clipboard_get())
	expect(exported.parameters.get("paths",[]).size()==saved.size() and not saved.is_empty(),"copied parameters include reproducible ground-space stroke")
	await capture("04-slope")
	await reset_drawing(scene)
	await draw(scene,straight)
	while scene.busy: await process_frame
	expect(not scene.current_plan.closed and absf(scene.current_plan.points[0].x+4)<.02,"ray-to-ground painting respects the sloped surface")
	scene._select_kind(1)
	while scene.busy: await process_frame
	scene.compare_check.button_pressed=true
	while scene.busy: await process_frame
	scene._select_kind(0)
	while scene.busy: await process_frame
	expect(scene.world.get_child_count()==1 and not scene.drawn_paths.is_empty(),"returning from another kit preserves custom path without applying preset comparison")
	await reset_drawing(scene)
	await draw(scene,loop)
	while scene.busy: await process_frame
	await click(scene.draw_button)
	while scene.busy: await process_frame
	scene.focus("joint"); await capture("05-closed-joint")
	await click(scene.preset_button)
	while scene.busy: await process_frame
	expect(scene.drawn_paths.is_empty() and not scene.brush.enabled and not scene.compare_check.disabled,"restore preset restores camera controls and comparison")
	scene.compare_check.button_pressed=true
	while scene.busy: await process_frame
	expect(scene.world.get_child_count()==3,"existing three-preset comparison still works")
	await capture("06-presets")
	scene.queue_free(); await process_frame
	print("RAILING_DRAWING_TEST failures=%s"%JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func screen_point(scene: Node3D,point: Array) -> Vector2:
	var p: Dictionary = scene.current_plan.settings
	return scene.camera.unproject_position(Vector3(point[0],scene._stage_height(p)+Kit.ground(point[0],p.slope),point[1]))

func reset_drawing(scene: Node3D) -> void:
	await click(scene.preset_button)
	while scene.busy: await process_frame
	await click(scene.draw_button)
	while scene.busy: await process_frame

func mouse_motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=at
	root.push_input(event,true)
	await process_frame

func mouse_button(pressed: bool,at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=at
	root.push_input(event,true)
	await process_frame

func draw(scene: Node3D,points: Array,release: bool=true) -> void:
	await mouse_motion(screen_point(scene,points[0]))
	await mouse_button(true,screen_point(scene,points[0]))
	for point: Array in points: await mouse_motion(screen_point(scene,point))
	if release: await mouse_button(false,screen_point(scene,points[-1]))
