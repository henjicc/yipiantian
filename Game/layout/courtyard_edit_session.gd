extends Node
## Resolves draft geometry, real obstacles and live planting admission for the UI.
## Saving/replacing the running scene remains the main scene's transaction.
signal apply_requested(snapshot: Dictionary, undo: bool)
signal closed
const Plan = preload("res://layout/courtyard_plan.gd")
const Circulation = preload("res://layout/courtyard_circulation.gd")
const Editor = preload("res://ui/courtyard_editor.gd")
const FarmState = preload("res://farm/farm_state.gd")
const Courtyard = preload("res://scenes/environment/courtyard.gd")
var editor: Editor
var state: FarmState
var _shore: Array = []
var _blocks: Dictionary = {}
var _decorations: Dictionary = {}

func _ready() -> void:
	editor=Editor.new()
	add_child(editor)
	editor.check_requested.connect(_check)
	editor.apply_requested.connect(func(snapshot: Dictionary, undo: bool) -> void: apply_requested.emit(snapshot,undo))
	editor.closed.connect(func() -> void: closed.emit())

func begin(environment: Node3D, farm_state: FarmState, decorations: Dictionary, undo: Dictionary) -> void:
	state=farm_state
	_shore=environment.plan.snapshot().shore+environment.plan.snapshot().terrain
	_blocks=environment.layout_obstacles.duplicate(true)
	_decorations=decorations
	var occupied: Dictionary={}
	for id: String in state.field_ids():
		occupied[id]=[]
		for cell: String in state.cell_ids(id):
			if not state.get_cell(id,cell).crop_id.is_empty(): occupied[id].append(cell)
	editor.present(state.snapshot().layout,undo,occupied)

func _check(snapshot: Dictionary, revision: int) -> void:
	var plan: RefCounted=Plan.from_snapshot(snapshot)
	var issues: Array[String]=[]
	if plan==null:
		issues.append("invalid_layout")
		editor.checked(revision,null,_blocks,issues,"田格总数最多 384 格，每块田最多 8 行 × 8 列。")
		return
	# Draw feedback before potentially rebuilding shore-bound model footprints.
	editor.set_busy(true,"正在校对位置与通路…")
	await get_tree().process_frame
	await get_tree().process_frame
	if not editor.active or revision!=editor.revision:
		editor.set_busy(false)
		return
	if _shore!=snapshot.shore+snapshot.terrain:
		var probe:=Courtyard.new()
		probe.plan=plan
		probe.layout_probe=true
		probe.process_mode=Node.PROCESS_MODE_DISABLED
		add_child(probe)
		_blocks=probe.layout_obstacles.duplicate(true)
		_shore=snapshot.shore+snapshot.terrain
		remove_child(probe)
		probe.free()
	var obstacles: Dictionary=_blocks.duplicate(true)
	obstacles.merge(_decorations)
	issues=Circulation.field_placement_issues(plan,obstacles)
	var message: String=""
	var candidate:=FarmState.new()
	candidate.restore_snapshot(state.snapshot())
	var admission: Dictionary=candidate.apply_layout(snapshot,Time.get_unix_time_from_system())
	if not admission.ok:
		issues.append(admission.reason)
		message="将移除的田格里还有作物，请先收获，或保留这些田格。"
	elif not issues.is_empty():
		message="红色田块碰到了岸边、物件或其他田块，请移到空地并留出间距。"
	else:
		var routes:=Circulation.new()
		routes.build(plan,obstacles)
		issues.append_array(routes.issues)
		if not issues.is_empty(): message="这里会挡住通路，请挪开田块，为屋前、桥头和田边留出通道。"
	editor.checked(revision,plan,obstacles,issues,message)
	editor.set_busy(false)
