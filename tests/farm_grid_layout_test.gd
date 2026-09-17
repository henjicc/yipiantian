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
	root.add_child(layout)
	var state := Farm.new(1800000000.0)
	for field_id: String in Farm.FIELD_IDS:
		layout.show_field(state.get_field(field_id))
	for field_index: int in 6:
		for cell_id: String in Farm.CELL_IDS:
			var point: Vector3 = layout.fields[field_index].to_global(Layout.cell_center(cell_id))
			_expect(layout.cell_at(field_index, point) == cell_id, "Stable cell centre maps to itself")
	var first: Node3D = layout.fields[0]
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
	_expect(layout._cell_frame.visible and layout._cell_frame.position == first.position + Layout.cell_center("cell_01"), "Selected-cell outline follows its exact soil location")
	layout.select_cell(-1, "")
	_expect(not layout._cell_frame.visible, "Returning to overview clears the small outline")
	layout.free()
	await process_frame
	print("FARM_GRID_LAYOUT_TEST checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
