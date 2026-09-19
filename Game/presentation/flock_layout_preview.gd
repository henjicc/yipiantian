extends Node3D
## Cached flock display and an exclusively owned habitat-region check.
signal checked
const Animals=preload("res://scenes/environment/courtyard_animals.gd")
const Assets=preload("res://scenes/environment/courtyard_assets.gd")
const Flocks=preload("res://layout/flock_layout.gd")
var kind: String
var main: Node3D
var animals: Node3D
var pending: bool=false
var message: String=""
var validated: RefCounted
var models: Dictionary={}
var _plan: RefCounted
var _source: RefCounted
var _space: RefCounted
var _area: Array=[]
var _working_area: Array=[]
var _working_source: RefCounted
var _worker: Thread
var _due: int=0
var _hidden: Array[Node3D]=[]
var _retiring: bool=false
var _restored: bool=false

func configure(scene: Node3D, species: String) -> void:
	kind=species;main=scene;animals=main.get_node("Environment/CourtyardAnimals")
	animals.preview_kind=kind
	for entry: Dictionary in animals.birds:
		if entry.kind!=kind: continue
		for node: Node3D in [entry.node,entry.wake]:
			if is_instance_valid(node) and node.visible: _hidden.append(node);node.hide()

func update(plan: RefCounted) -> void:
	var changed: bool=_plan==null or _plan.construction.flocks[kind]!=plan.construction.flocks[kind]
	_plan=plan;validated=null
	message=Flocks.terrain_issue(plan)
	if _area!=plan.construction.flocks[kind].area:
		_area=plan.construction.flocks[kind].area.duplicate();_space=null
		_due=Time.get_ticks_msec()+100
	pending=message.is_empty()
	_sync_source()
	if changed: _show_flock()
	_resolve()

func _sync_source() -> void:
	if not _source_ready():
		validated=null;pending=message.is_empty();return
	if _source!=_current_source():
		_source=_current_source();_space=null;validated=null;message=Flocks.terrain_issue(_plan);pending=message.is_empty()
	if _space==null:
		if _area==main.courtyard_plan.construction.flocks[kind].area: _space=animals.flock_spaces[kind]
		elif _area.is_empty(): _space=_source

func _source_ready() -> bool:
	return animals.yard_ready if kind=="hen" else animals.water_ready

func _current_source() -> RefCounted:
	return animals.yard if kind=="hen" else animals.water

func _resolve() -> void:
	if not message.is_empty() or not _source_ready() or _space==null: return
	pending=false
	message=Flocks.space_issue(kind,int(_plan.construction.flocks[kind].count),_space)
	_show_flock()
	if message.is_empty(): validated=_plan

func _show_flock() -> void:
	var count: int=int(_plan.construction.flocks[kind].count)
	for identity: String in models.keys():
		if int(identity.trim_prefix(Flocks.SPECIES[kind].prefix))>count: models[identity].free();models.erase(identity)
	var placed:=PackedVector2Array()
	for other: Dictionary in animals.birds:
		if other.kind!=kind and (other.kind=="hen")== (kind=="hen"): placed.append(other.position)
	for i: int in count:
		var identity: String=Flocks.id(kind,i)
		var entry: Dictionary=animals.interaction.find(identity)
		var point: Vector2=Flocks.start(kind,i,_area)
		if not entry.is_empty() and _area==main.courtyard_plan.construction.flocks[kind].area: point=entry.position
		if _space!=null and not _space.points.is_empty():
			if entry.is_empty() or _area!=main.courtyard_plan.construction.flocks[kind].area:
				point=Flocks.separated_point(_space,point,placed,Flocks.SPECIES[kind].spacing)
		if not point.is_finite():
			message="动物之间没有足够间距，请扩大范围或减少数量。";validated=null
			if models.has(identity): models[identity].hide()
			continue
		placed.append(point)
		if not models.has(identity):
			models[identity]=Assets.place(self,kind,Vector3.ZERO,0,Flocks.size(kind,i))
			models[identity].name=identity
		models[identity].show()
		var level: float=-.25-Animals.PROFILES[kind].draft
		if kind=="hen": level=(_space if _space!=null else animals.yard).ground_height(point)
		models[identity].position=Vector3(point.x,level,point.y)
		models[identity].rotation.y=(PI if kind=="goose" else 0.0) if entry.is_empty() else entry.node.rotation.y

func _process(_delta: float) -> void:
	if _retiring:
		if _worker!=null:
			if _worker.is_alive(): return
			_worker.wait_to_finish();_worker=null
		queue_free();return
	if _plan==null: return
	var previous: RefCounted=validated
	var was_pending: bool=pending
	_sync_source()
	if _worker!=null and not _worker.is_alive():
		var result: RefCounted=_worker.wait_to_finish();_worker=null
		if _working_area==_area and _working_source==_source: _space=result
	if pending: _resolve()
	if previous!=validated or was_pending!=pending: checked.emit()
	if not pending or not _source_ready() or _space!=null or _worker!=null or Time.get_ticks_msec()<_due: return
	_working_area=_area.duplicate();_working_source=_source;_worker=Thread.new()
	var error: Error=_worker.start(Animals.Space.build_region.bind(_working_area,Animals.Space.capture(_source)))
	if error!=OK:
		_worker=null;pending=false;message="活动区域检查未能启动，请重新调整后再试。"
		push_error("Flock region worker: %d"%error);checked.emit()

func accept(plan: RefCounted) -> void:
	animals.apply_flock(kind,_space,main.farm_state.snapshot().animals,models)
	var environment: Node3D=main.get_node("Environment")
	plan.paths=environment.plan.paths.duplicate();plan.garden_fences=environment.plan.garden_fences.duplicate(true)
	environment.plan=plan;main.courtyard_plan=plan;main.farm.plan=plan
	environment.get_node("LivingDetails").plan=plan
	_restore()

func retire() -> void:
	_retiring=true;pending=false;hide();_restore()
	if _worker==null: queue_free()

func _restore() -> void:
	if _restored: return
	_restored=true
	if is_instance_valid(animals): animals.preview_kind=""
	for node: Node3D in _hidden:
		if is_instance_valid(node) and not node.is_queued_for_deletion(): node.show()
	_hidden.clear()

func _exit_tree() -> void:
	if _worker!=null and _worker.is_started(): _worker.wait_to_finish()
	_restore()
