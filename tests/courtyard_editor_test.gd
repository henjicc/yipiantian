extends SceneTree
const Plan=preload("res://layout/courtyard_plan.gd")
const Store=preload("res://farm/farm_store.gd")
const Presets=preload("res://layout/courtyard_presets.gd")
const Fence=preload("res://layout/fence_geometry.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
var scene: Node3D
var now: float=200000
var failures: Array[String]=[]
var folder: String
var visual: bool=false

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func checked() -> void:
	var editor: Node=scene.courtyard_edit.editor
	var start: int=Time.get_ticks_msec()
	while editor._checked!=editor.revision or editor.busy:
		await process_frame
		if Time.get_ticks_msec()-start>45000:
			expect(false,"Draft validation completes")
			break

func replaced(old: Node) -> void:
	var start: int=Time.get_ticks_msec()
	while is_instance_valid(old) and old.is_inside_tree():
		await process_frame
		if Time.get_ticks_msec()-start>60000:
			expect(false,"Saved scene replacement completes")
			return
	scene=root.get_node("FarmScene")
	await process_frame
	await physics_frame

func shot(name: String) -> void:
	if not visual: return
	await create_timer(.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(name))

func _run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	folder=ProjectSettings.globalize_path("res://../.local/verification/courtyard-editor-%d"%Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	scene=load("res://scenes/main.tscn").instantiate()
	scene.name="FarmScene"
	scene.store=Store.new(folder.path_join("farm"))
	scene.settings_store=load("res://settings/settings_store.gd").new(folder.path_join("settings"))
	scene.clock=func() -> float: return now
	root.add_child(scene)
	await process_frame
	scene.atmosphere.set_preview_hour(14.25)
	var original: Dictionary=scene.farm_state.snapshot()
	scene._begin_decoration()
	scene.decoration_layout.hud.get_node("Layout/Controls").find_child("Courtyard",true,false).pressed.emit()
	await checked()
	var editor: Node=scene.courtyard_edit.editor
	expect(editor.active and not scene.decoration_layout.active,"Existing arrangement entry opens one modal layout editor")
	expect(not scene._tools_available(),"Planting cannot run behind layout editor")
	expect(editor.chart.invalid.is_empty(),"Default layout is admitted")
	expect(editor._confirm.disabled,"Unchanged layout is not a new action")
	await shot("editor-original.png")
	if "--presets" in OS.get_cmdline_user_args():
		for i: int in Presets.IDS.size():
			editor._preset.item_selected.emit(i+1)
			await checked()
			print("PRESET ",Presets.IDS[i]," issues=",editor.chart.invalid)
			expect(editor.chart.invalid.is_empty(),"Named arrangement has supported fields and reachable entrances: "+Presets.IDS[i])
			var routes:=Circulation.new()
			routes.build(editor.draft,scene.courtyard_edit._blocks)
			for path: PackedVector3Array in editor.draft.paths:
				for j: int in range(path.size()-1):
					expect(routes.road.clear_segment(Vector2(path[j].x,path[j].z),Vector2(path[j+1].x,path[j+1].z)),"Preset roads never cross an obstacle")
			expect(scene.farm_state.snapshot()==original,"Choosing an arrangement is preview-only")
			editor._fence.item_selected.emit(i)
			await checked()
			expect(editor.draft.fence_style==Plan.FENCE_STYLES[i],"Fence picker updates draft")
			await shot("preset-"+Presets.IDS[i]+".png")
			if visual:
				expect(RenderingServer.viewport_get_update_mode(editor._fence_preview._viewport.get_viewport_rid())==RenderingServer.VIEWPORT_UPDATE_DISABLED,"Fence sample stops rendering after one update")
			var mesh: Node3D=Fence.build(editor.draft.fences,editor.draft.fence_style)
			expect(mesh.get_meta("fence_spans")==editor.draft.fences,"Fence style preserves exact collision/gate spans")
			mesh.free()
		# A preset must keep non-default dimensions, all IDs, and additional beds.
		var custom: RefCounted=Plan.from_snapshot(editor.draft.snapshot())
		custom.fields[0]=Plan.resized_field(custom.fields[0],5,3,Vector2(3.2,1.61))
		var extra: Dictionary=custom.fields[1].duplicate(true)
		extra.id="field_20"
		custom.fields.append(extra)
		var arranged: RefCounted=Presets.arrange(custom,"original")
		expect(arranged.fields.size()==7 and arranged.fields[-1].id=="field_20","Presets retain additional field identities")
		expect(arranged.fields[0].cells==custom.fields[0].cells and arranged.fields[0].size==custom.fields[0].size,"Presets preserve custom cell IDs and dimensions")
		var malformed: Dictionary=arranged.snapshot()
		malformed.fence_style="unknown"
		expect(Plan.from_snapshot(malformed)==null,"Unknown saved fence styles are rejected")
		editor._reset_draft()
		await checked()
	if "--ui-only" in OS.get_cmdline_user_args():
		var point: Vector2=editor.chart.global_position+editor.chart.world_to_map(Vector2(-3.3,0))
		var down:=InputEventMouseButton.new()
		down.button_index=MOUSE_BUTTON_LEFT
		down.position=point
		down.pressed=true
		Input.parse_input_event(down)
		await process_frame
		var motion:=InputEventMouseMotion.new()
		motion.position=point+Vector2(-4,0)
		motion.relative=Vector2(-4,0)
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await create_timer(.45).timeout
		expect(editor.chart.is_dragging() and not editor.busy,"Pausing during a drag does not trigger a blocking route check")
		expect(editor.draft.fields[0].position.x < -3.3,"Real viewport mouse gesture moves the selected field")
		down.pressed=false
		down.position=motion.position
		Input.parse_input_event(down)
		await checked()
		expect(not editor.chart.is_dragging(),"Mouse release finishes the drag and validates its final position")
		editor._root.find_child("RotateRight",true,false).pressed.emit()
		expect(is_equal_approx(editor.draft.fields[0].yaw,15),"Rotation control updates the selected field")
		editor._spacing.item_selected.emit(1)
		expect(Plan.cell_span(editor.draft.fields[0]).is_equal_approx(Vector2(.8,.64)),"Spacing choice changes field geometry")
		await checked()
		await shot("editor-interaction.png")
		root.mode=Window.MODE_WINDOWED
		root.size=Vector2i(960,600)
		await process_frame
		await process_frame
		await shot("editor-small-window.png")
		var viewport: Rect2=root.get_visible_rect()
		expect(viewport.encloses(editor._confirm.get_global_rect()),"Confirm remains fully reachable at minimum window size")
		expect(viewport.encloses(editor._selector.get_global_rect()),"Field selector remains inside minimum window size")
		var escape:=InputEventKey.new()
		escape.keycode=KEY_ESCAPE
		escape.pressed=true
		Input.parse_input_event(escape)
		await process_frame
		expect(not editor.active and scene.farm_state.snapshot()==original,"Real Escape cancels all draft edits without changing crops")
		await finish()
		return
	editor._move_field(0,Vector2(-3.3,2.8))
	await checked()
	expect(not editor.chart.invalid.is_empty() and editor._confirm.disabled,"Overlapping field edit cannot commit")
	expect(scene.farm_state.snapshot()==original,"Draft movement never touches authoritative crops or layout")
	var cancel:=InputEventKey.new()
	cancel.keycode=KEY_ESCAPE
	cancel.pressed=true
	scene._input(cancel)
	expect(not editor.active and scene.farm_state.snapshot()==original,"Escape cancels without saving draft")
	scene._begin_courtyard_edit()
	editor._select(2)
	editor._remove_field()
	await checked()
	expect(editor.chart.invalid.has("occupied_cell_removed") and editor._confirm.disabled,"Removing planted field is rejected with crop reason")
	editor.cancel()
	scene._begin_courtyard_edit()
	editor._values.west.value=2.5
	editor._values.south.value=3
	editor._move_field(0,Vector2(-8,1))
	editor._change("yaw",10)
	editor._select(1)
	editor._values.rows.value=3
	editor._add_field()
	editor._move_field(6,Vector2(-3.3,6.9))
	editor._fence.item_selected.emit(1)
	await checked()
	print("EDITOR_DRAFT issues=",editor.chart.invalid," message=",editor._message.text)
	expect(editor.chart.invalid.is_empty() and not editor._confirm.disabled,"Expanded seven-field player draft has supported fields and connected roads")
	expect(editor.draft.fields[1].rows==3,"Row control resizes a real field")
	await shot("editor-expanded.png")
	# An actual write failure must preserve live state and leave the draft retryable.
	var pending: String=scene.store.directory.path_join(Store.PENDING)
	DirAccess.make_dir_absolute(pending)
	editor._confirm.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	expect(not editor.busy and editor.active,"Failed save returns to editable draft")
	expect(scene.farm_state.snapshot()==original,"Failed save does not mutate authoritative island")
	expect(scene.store.load_state().farm==original,"Failed save retains committed disk island")
	DirAccess.remove_absolute(pending)
	var before: Node=scene
	editor._confirm.pressed.emit()
	await replaced(before)
	expect(scene.farm_state.field_ids().size()==7 and scene.farm.fields.size()==7,"Confirmed layout rebuilds all fields from saved state")
	expect(scene.courtyard_plan.shore_expansion==Vector2(2.5,3),"Expansion survives scene reload")
	expect(scene.courtyard_plan.fence_style=="crossed" and scene.get_node("Environment/BoundaryFence").get_meta("fence_style")=="crossed","Confirmed fence choice rebuilds actual scene geometry")
	expect(scene.get_node("Environment").circulation.issues.is_empty(),"Final real-world roads remain connected")
	expect(scene.previous_layout==original.layout,"Undo history crosses scene rebuild")
	expect(scene.farm_state.get_cell("field_03","cell_06").crop_id==original.fields.field_03.cells.cell_06.crop_id,"Unmoved planted crop identity survives editing")
	expect(is_equal_approx(scene.atmosphere.get_preview_hour(),14.25),"Scene rebuild preserves preview lighting")
	for i: int in scene.farm.fields.size():
		var field: Node3D=scene.farm.fields[i]
		for cell: String in scene.farm_state.cell_ids(scene.farm.field_id(i)):
			if scene.farm_state.get_cell(scene.farm.field_id(i),cell).crop_id.is_empty(): continue
			var crop: Node3D=field.get_node("Crops/"+cell)
			expect(crop!=null and crop.is_visible_in_tree(),"Planted crop remains visible after rebuilding layout")
	await shot("expanded-world.png")
	if "--inspect-reload" in OS.get_cmdline_user_args():
		scene.camera.set_process(false)
		scene.camera.global_position=Vector3(5,4,4)
		scene.camera.look_at(Vector3(3.2,.2,1))
		scene.focus_detail.set_depth_of_field(false)
		await shot("rebuilt-crops.png")
		await finish()
		return
	var new_id: String=scene.farm_state.field_ids()[-1]
	scene.farm_state.sow(new_id,"cell_01","greens",now)
	scene._save_farm()
	scene._begin_courtyard_edit()
	editor=scene.courtyard_edit.editor
	editor._undo_button.pressed.emit()
	await checked()
	expect(editor.chart.invalid.has("occupied_cell_removed"),"Undo refuses to erase crops planted since expansion")
	editor.cancel()
	now+=86400
	scene.farm_state.settle(now)
	scene.farm_state.harvest(new_id,"cell_01",now)
	scene._save_farm()
	scene._begin_courtyard_edit()
	editor._undo_button.pressed.emit()
	await checked()
	expect(not editor._confirm.disabled,"Undo becomes available after harvesting newly added field")
	before=scene
	editor._confirm.pressed.emit()
	await replaced(before)
	expect(scene.farm_state.snapshot().layout==original.layout,"Undo restores original layout")
	expect(scene.farm_state.snapshot().harvested.greens==1,"Undo never rewinds earned harvest")
	expect(scene.previous_layout.is_empty(),"One-step undo is consumed once")
	var reopened:=Store.new(scene.store.directory)
	expect(reopened.load_state().farm==scene.farm_state.snapshot(),"Saved layout and crops reopen exactly")
	await finish()

func finish() -> void:
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	print("COURTYARD_EDITOR failures=",failures.size()," evidence=",folder)
	quit(0 if failures.is_empty() else 1)
