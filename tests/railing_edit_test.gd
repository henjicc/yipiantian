extends "res://../tests/railing_drawing_test.gd"
const Edit = preload("res://scenes/procedural_lab/railing_edit.gd")

func _run() -> void:
	var review_4k: bool = "--edit-review-4k" in OS.get_cmdline_user_args()
	root.size=Vector2i(3840,2160) if review_4k else Vector2i(1600,1000)
	output=ProjectSettings.globalize_path("res://../.local/verification/railing-edit"+("-4k" if review_4k else ""))
	DirAccess.make_dir_recursive_absolute(output)
	var original: Array = Edit.from_plan(Kit.plan("擦除",{"stroke":[[-4,0],[4,0]]},"railing"))
	var gap: Array = Edit.erase(original,[[0,0]])
	expect(gap.size()==2,"erasing a middle post leaves two independent runs")
	expect(Edit.erase(original,[[0,4]])==original,"erasing empty ground leaves every path unchanged")
	expect(absf(gap[0].points[-1][0]+.35)<.001 and absf(gap[1].points[0][0]-.35)<.001,"eraser clips actual geometry at its visible radius")
	expect(Edit.validate(gap,1.35).is_empty(),"cut ends retain enough room for posts")
	for reverse_a: bool in [false,true]:
		for reverse_b: bool in [false,true]:
			var halves: Array = gap.duplicate(true)
			if reverse_a: halves[0].points.reverse()
			if reverse_b: halves[1].points.reverse()
			for reverse_stroke: bool in [false,true]:
				var line: Array = [[-.37,.06],[.38,-.05]]
				if reverse_stroke: line.reverse()
				var repaired: Dictionary = Edit.draw(halves,line,1.35)
				expect(not repaired.has("error") and repaired.paths.size()==1,"all endpoint orientations reconnect into one path")
				if repaired.has("error"): continue
				var built: Dictionary = Kit.plan("补接",{"paths":repaired.paths},"railing")
				var model: Node3D = Kit.build(built)
				var posts: MultiMesh = model.get_node("fence_post_near").multimesh
				for i: int in posts.instance_count:
					for j: int in range(i+1,posts.instance_count):
						expect(posts.get_instance_transform(i).origin.distance_to(posts.get_instance_transform(j).origin)>.27,"snapped joint has no doubled posts")
				model.free()
	var swept: Array = Edit.erase(original,[[-3,0],[3,0]])
	expect(swept.size()==2 and swept[0].points[-1][0]<-3.3 and swept[1].points[0][0]>3.3,"fast eraser drag cannot skip the middle")
	expect(Edit.erase(original,[[-4,0],[4,0]]).is_empty(),"entire path can be erased")
	var square: Array = [{"points":[[-3,-3],[3,-3],[3,3],[-3,3]],"closed":true}]
	var opened: Array = Edit.erase(square,[[0,-3]])
	expect(opened.size()==1 and not opened[0].closed,"cutting a closed loop opens one path across its old seam")
	var sealed: Dictionary = Edit.draw(opened,[opened[0].points[-1],opened[0].points[0]],1.35)
	expect(not sealed.has("error") and sealed.paths.size()==1 and sealed.paths[0].closed,"connecting ends of the same run closes the loop again")
	var extended: Dictionary = Edit.draw(gap,[gap[0].points[0],[-5,1]],1.35)
	expect(not extended.has("error") and extended.paths.size()==2,"one-end continuation preserves the other independent fragment")
	expect(Edit.draw(original,[[0,-2],[0,2]],1.35).has("error"),"drawing through intact railing rejects an unsupported crossing")
	var scene: Node3D = load("res://scenes/procedural_lab/component_lab.tscn").instantiate()
	root.add_child(scene)
	while scene.current_plan.is_empty() or scene.busy: await process_frame
	await click(scene.draw_button)
	while scene.busy: await process_frame
	await mouse_motion(screen_point(scene,[-4,0]))
	expect(scene.brush.cursor.visible and is_equal_approx(scene.brush.cursor_radius,.22),"draw mode shows a ground ring even before pressing")
	await capture("01-draw-ring")
	await draw(scene,[[-4,0],[4,0]])
	while scene.busy: await process_frame
	await click(scene.erase_button)
	while scene.busy: await process_frame
	await mouse_motion(screen_point(scene,[0,0]))
	expect(scene.brush.cursor.visible and is_equal_approx(scene.brush.cursor_radius,Edit.RADIUS),"eraser ring matches the actual cut radius")
	await capture("02-erase-ring")
	await draw(scene,[[0,0]],false)
	await create_timer(.15).timeout
	expect(scene.drawn_paths.size()==1 and scene.brush.edit_result.paths.size()==2,"erasure is previewed without committing while held")
	await capture("03-erase-preview")
	await mouse_button(false,screen_point(scene,[0,0]))
	while scene.busy: await process_frame
	expect(scene.drawn_paths.size()==2,"release commits both remaining fragments")
	await capture("04-gap")
	var kept: Array = scene.drawn_paths.duplicate(true)
	await draw(scene,[[-2,0]],false)
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE; escape.pressed=true
	root.push_input(escape,true); await process_frame
	expect(scene.drawn_paths==kept and not scene.brush.active,"Escape cancels erase without losing accepted pieces")
	await draw(scene,[[-2,0]],false)
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(scene.drawn_paths==kept and not scene.brush.cursor.visible,"focus loss cancels erasure and hides its ring")
	await mouse_button(false,screen_point(scene,[-2,0]))
	await mouse_motion(Vector2(160,180))
	expect(not scene.brush.cursor.visible,"brush ring hides over the panel")
	await click(scene.draw_button)
	while scene.busy: await process_frame
	await mouse_motion(screen_point(scene,[-.38,.06]))
	expect(absf(scene.brush.cursor.position.x+.35)<.02 and absf(scene.brush.cursor.position.z)<.02,"nearby endpoint visibly attracts the drawing ring")
	await capture("05-snap-ring")
	await draw(scene,[[-.38,.06],[.38,-.05]])
	while scene.busy: await process_frame
	expect(scene.drawn_paths.size()==1,"UI stroke reconnects both fragments automatically")
	await capture("06-repaired")
	await click(scene.undo_button)
	while scene.busy: await process_frame
	expect(scene.drawn_paths==kept,"undo restores the exact previous cut")
	await click(scene.erase_button)
	while scene.busy: await process_frame
	await draw(scene,[[-4,0],[4,0]])
	while scene.busy: await process_frame
	expect(scene.custom_railing and scene.current_plan.points.is_empty(),"erasing everything keeps an empty editable stage, not a preset")
	scene.focus("joint")
	await click(scene.undo_button)
	while scene.busy: await process_frame
	expect(scene.drawn_paths==kept,"undo after clearing all restores both fragments")
	scene.controls.slope.value=.18
	await click(scene.generate_button)
	while scene.busy: await process_frame
	await mouse_motion(screen_point(scene,[2,0]))
	var ring: MeshInstance3D = scene.brush.cursor
	for index: int in [0,6,30,90]:
		var vertex: Vector3 = ring.global_transform*(ring.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][index])
		expect(absf(vertex.y-scene._stage_height(scene.current_plan.settings)-Kit.ground(vertex.x,.18)-.045)<.001,"every ring vertex conforms to the slope")
	await capture("07-slope-ring")
	await click(scene.export_button)
	await create_timer(.25).timeout
	var exported: Variant = JSON.parse_string(DisplayServer.clipboard_get())
	expect(exported is Dictionary and exported.parameters.paths.size()==2,"copy includes all disjoint edited paths")
	root.size=Vector2i(1100,760)
	await process_frame
	expect(scene.undo_button.get_global_rect().end.x<root.get_visible_rect().size.x,"edit toolbar remains reachable in a smaller window")
	await capture("08-small-window")
	scene.queue_free(); await process_frame
	print("RAILING_EDIT_TEST failures=%s"%JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
