extends SceneTree
## Geometry boundaries and per-cell visual ownership, without a player save or GPU.
const Farm = preload("res://farm/farm_state.gd")
const Layout = preload("res://scenes/farm_layout.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var layout := Layout.new()
	# A moved/rotated field retains crop identity and local hit-testing.
	layout.plan.fields[0].position += Vector3(.15,0,-.1)
	layout.plan.fields[0].yaw = 8.0
	root.add_child(layout)
	_expect(layout.fields[0].transform.is_equal_approx(layout.plan.field_transform(0)), "Field uses shared plan transform")
	_expect(layout.field_id(0) == "field_01", "Moving a field preserves its identity")
	var state := Farm.new(1800000000.0)
	for field_id: String in Farm.FIELD_IDS:
		layout.show_field(state.get_field(field_id))
	for field_index: int in 6:
		for cell_id: String in Farm.CELL_IDS:
			var point: Vector3 = layout.fields[field_index].to_global(Layout.cell_center(cell_id))
			_expect(layout.cell_at(field_index, point) == cell_id, "Stable cell centre maps to itself")
	var first: Node3D = layout.fields[0]
	# The outer planting surface must meet the bank without an exposed green slit.
	var bank: MeshInstance3D = first.get_child(0)
	var bank_arrays: Array = bank.mesh.surface_get_arrays(0)
	var bank_height: float = -INF
	for i: int in bank_arrays[Mesh.ARRAY_VERTEX].size():
		if bank_arrays[Mesh.ARRAY_COLOR][i].r > .999:
			bank_height = bank_arrays[Mesh.ARRAY_VERTEX][i].y
			break
	var pad: MeshInstance3D = layout._soil_meshes.field_01.cell_01
	var edge_gap: float = 0.0
	for vertex: Vector3 in pad.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if is_equal_approx(vertex.x, -Layout.CELL_SPAN.x*.5) or is_equal_approx(vertex.z, -Layout.CELL_SPAN.y*.5):
			edge_gap = maxf(edge_gap, absf(vertex.y+pad.position.y-bank_height))
	_expect(is_finite(bank_height) and edge_gap<.0001,"Outer soil pad and bank meet at the same height")
	_expect(layout.cell_at(0, first.to_global(Vector3(-.601, .08, -.66))) == "cell_01", "Left of vertical furrow stays in first column")
	_expect(layout.cell_at(0, first.to_global(Vector3(-.599, .08, -.66))) == "cell_02", "Right of vertical furrow enters second column")
	_expect(layout.cell_at(0, first.to_global(Vector3(-.9, .08, -.441))) == "cell_01", "Before horizontal furrow stays in first row")
	_expect(layout.cell_at(0, first.to_global(Vector3(-.9, .08, -.439))) == "cell_05", "After horizontal furrow enters second row")
	_expect(layout.cell_at(0, first.to_global(Vector3(-1.25, .08, 0))).is_empty(), "Outer bed rim is not a hidden cell")
	state.sow("field_01", "cell_01", "greens", 1800000000.0)
	state.sow("field_01", "cell_02", "radish", 1800000000.0)
	layout.show_field(state.get_field("field_01"))
	var crops: Node3D = first.get_node("Crops")
	var neighbor: Node3D = crops.get_node("cell_02")
	var previous_id: int = neighbor.get_instance_id()
	var previous_transform: Transform3D = neighbor.transform
	state.water("field_01", "cell_01", 1800000000.0)
	layout.show_field(state.get_field("field_01"))
	_expect(crops.get_child_count() == 2 and crops.get_node("cell_02").get_instance_id() == previous_id, "Watering one cell retains both plants and neighbor instance")
	_expect(layout._soil_meshes.field_01.cell_01.material_override != layout._soil_meshes.field_01.cell_02.material_override, "Only the watered cell changes soil material")
	state.settle(1800000270.0)
	layout.show_field(state.get_field("field_01"))
	_expect(crops.get_node("cell_01").get_meta("stage_key") == "greens/young", "Selected crop alone advances to young visual")
	_expect(neighbor.get_instance_id() == previous_id and neighbor.transform == previous_transform, "Neighbor stage and anchor are unchanged")
	layout.select_cell(0, "cell_01")
	_expect(pad.get_instance_shader_parameter("cell_selected") == 1.0 and layout._soil_meshes.field_01.cell_02.get_instance_shader_parameter("cell_selected") == 0.0, "Selection is applied only to the chosen ground surface")
	layout.select_cell(-1, "")
	_expect(pad.get_instance_shader_parameter("cell_selected") == 0.0, "Returning to overview clears the ground selection")
	# Both sides of each shared cell edge use the same height function.
	var left: Array = pad.mesh.surface_get_arrays(0)
	var right_pad: MeshInstance3D = layout._soil_meshes.field_01.cell_02
	var right: Array = right_pad.mesh.surface_get_arrays(0)
	var seam_error: float = 0.0
	for v: Vector3 in left[Mesh.ARRAY_VERTEX]:
		if not is_equal_approx(v.x,.3): continue
		var closest: float = INF
		for other: Vector3 in right[Mesh.ARRAY_VERTEX]:
			if is_equal_approx(other.x,-.3) and is_equal_approx(other.z,v.z):
				closest = minf(closest, absf(v.y-other.y))
		seam_error = maxf(seam_error,closest)
	_expect(seam_error < .00001, "Adjacent soil patches meet without cracks or tile grooves")
	layout.free()
	await process_frame
	print("FARM_GRID_LAYOUT_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
