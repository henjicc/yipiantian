extends SceneTree
## Actual saved variable fields, input, surface joins and recovery reconstruction.
const Plan = preload("res://layout/courtyard_plan.gd")
const Farm = preload("res://farm/farm_state.gd")
const Store = preload("res://farm/farm_store.gd")
const Decorations = preload("res://farm/decoration_state.gd")
var failures: Array[String] = []
var output := ProjectSettings.globalize_path("res://../.local/verification/variable-fields")
var folder: String
var now: float = 1800000000.0
var scene: Node3D

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1600,900)
	folder = output.path_join("session-%d" % Time.get_ticks_usec())
	var plan := Plan.new()
	plan.expand_shore(0,3)
	plan.fields[0] = Plan.resized_field(plan.fields[0],5,3,Vector2(3.2,1.61))
	plan.fields[0].yaw = 10.0
	plan.fields[1] = Plan.resized_field(plan.fields[1],3,4,Vector2(2.0,2.05))
	var extra: Dictionary = plan.fields[2].duplicate(true)
	extra.id = "field_07"
	extra.position = Vector3(-3.3,.2,6.9)
	extra.yaw = -12.0
	plan.fields.append(extra)
	var state := Farm.new(now,plan.snapshot())
	state.sow("field_01","cell_06","spinach",now)
	state.water("field_01","cell_06",now)
	var store := Store.new(folder)
	store.load_state()
	expect(store.save(state.snapshot(),Decorations.new().snapshot()).ok,"Prepared variable layout saves")
	await _open()
	expect(scene._loaded and scene.farm.fields.size()==7,"Saved seven-field geometry exists before first refresh")
	expect(scene.courtyard_plan.snapshot()==plan.snapshot(),"Shore expansion, rows, sizes and transforms restored")
	for i: int in scene.farm.fields.size():
		var field: Node3D = scene.farm.fields[i]
		for cell_id: String in scene.farm.cell_ids(i):
			var point: Vector3 = field.to_global(scene.farm.cell_position(i,cell_id))
			expect(scene.farm.cell_at(i,point)==cell_id,"Variable/rotated cell hit retains ID")
		var size: Vector2 = field.get_meta("field_size")
		var collider: CollisionShape3D = field.get_child(field.get_child_count()-1)
		expect(collider.shape.size.is_equal_approx(Vector3(size.x,.16,size.y)),"Field collider follows dimensions")
	_check_seam()
	var animals: Node3D = scene.get_node("Environment/CourtyardAnimals")
	for field: Node3D in scene.farm.fields:
		expect(not animals.yard.contains(Vector2(field.position.x,field.position.z)),"Changed field excludes roaming hens")
	scene.atmosphere.set_preview_hour(14.25)
	if "--visual" in OS.get_cmdline_user_args(): await _shot("overview.png")
	scene._focus_field(0)
	await create_timer(.9).timeout
	var field: Node3D = scene.farm.fields[0]
	var selected: Vector3 = field.to_global(scene.farm.cell_position(0,"cell_17"))
	var hit: Dictionary = scene._farm_hit(scene.camera.unproject_position(selected))
	expect(hit.get("field",-1)==0 and hit.get("cell","")=="cell_17","Camera ray picks the additional fifth column")
	scene._select_cell("cell_17")
	scene._select_crop("lettuce")
	scene._apply_tool()
	expect(scene.farm_state.get_cell("field_01","cell_17").crop_id=="lettuce","Normal sow tool accepts new cell ID")
	expect(field.get_node("Crops").has_node("cell_17"),"New cell's planted visual is present")
	var depths: Vector2 = scene.focus_detail.protected_depth_range()
	for item: Node3D in scene.farm.fields:
		var size: Vector2 = item.get_meta("field_size")
		for x: float in [-size.x*.5,size.x*.5]:
			for z: float in [-size.y*.5,size.y*.5]:
				var depth: float = -scene.camera.to_local(item.to_global(Vector3(x,.08,z))).z
				expect(depth>=depths.x and depth<=depths.y,"Expanded soil remains in protected DOF range")
	if "--visual" in OS.get_cmdline_user_args(): await _shot("fifth-column.png")
	var planted: Dictionary = scene.farm_state.snapshot()
	await _close()
	await _open()
	expect(scene.farm_state.snapshot()==planted,"Reopening restores both layout and planted cell exactly")
	# Corrupt main: default geometry may show behind the recovery overlay, but
	# recovery must replace it with the saved seven-field island and all consumers.
	await _close()
	var file := FileAccess.open(folder.path_join(Store.MAIN),FileAccess.WRITE)
	file.store_string("truncated{")
	file.close()
	await _open()
	expect(not scene._loaded and not scene.farm.visible,"Invalid save does not expose a fake playable farm")
	scene._recover_storage()
	await create_timer(.5).timeout
	for node: Node in root.get_children():
		if node is Node3D and node.get_script()==load("res://scenes/main.gd"): scene = node
	expect(scene._loaded and scene.farm.fields.size()==7,"Recovery rebuilds all variable fields")
	expect(scene.get_node("Environment").plan == scene.farm.plan and scene.courtyard_plan.shore_expansion==Vector2(0,3),"Recovery shares restored shore and layout")
	expect(scene.farm_state.get_cell("field_01","cell_17").crop_id=="lettuce","Recovery preserves new-column crop")
	await _close()
	print("VARIABLE_FIELDS_PASS" if failures.is_empty() else "VARIABLE_FIELDS_FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func _check_seam() -> void:
	var left: MeshInstance3D = scene.farm._soil_meshes.field_01.cell_01
	var right: MeshInstance3D = scene.farm._soil_meshes.field_01.cell_02
	var span: Vector2 = Plan.cell_span(scene.courtyard_plan.fields[0])
	var a: Array = left.mesh.surface_get_arrays(0)
	var b: Array = right.mesh.surface_get_arrays(0)
	var error: float = 0
	for i: int in a[Mesh.ARRAY_VERTEX].size():
		var v: Vector3 = a[Mesh.ARRAY_VERTEX][i]
		if not is_equal_approx(v.x,span.x*.5): continue
		var closest: float = INF
		for j: int in b[Mesh.ARRAY_VERTEX].size():
			var other: Vector3 = b[Mesh.ARRAY_VERTEX][j]
			if is_equal_approx(other.x,-span.x*.5) and is_equal_approx(other.z,v.z):
				closest = minf(closest,absf(v.y-other.y)+a[Mesh.ARRAY_NORMAL][i].distance_to(b[Mesh.ARRAY_NORMAL][j]))
		error = maxf(error,closest)
	expect(error<.0001,"Resized neighboring patches share height and normal without seam")

func _open() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = Store.new(folder)
	scene.settings_store = load("res://settings/settings_store.gd").new(folder.path_join("preferences"))
	scene.clock = func() -> float: return now
	root.add_child(scene)
	await process_frame
	await physics_frame
	await process_frame

func _close() -> void:
	scene.farm_audio.shutdown()
	await create_timer(.1).timeout
	scene.queue_free()
	await process_frame
	await process_frame

func _shot(filename: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))
