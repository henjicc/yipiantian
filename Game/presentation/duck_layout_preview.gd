extends Node3D
## Cached flock display and an exclusively owned water-region check.
signal checked
const Animals=preload("res://scenes/environment/courtyard_animals.gd")
const Assets=preload("res://scenes/environment/courtyard_assets.gd")
const Construction=preload("res://layout/island_construction.gd")
var main: Node3D
var animals: Node3D
var pending: bool=false
var message: String=""
var validated: RefCounted
var models: Dictionary={}
var _plan: RefCounted
var _water: RefCounted
var _space: RefCounted
var _area: Array=[]
var _working_area: Array=[]
var _working_water: RefCounted
var _worker: Thread
var _due: int=0
var _hidden: Array[Node3D]=[]
var _retiring: bool=false
var _restored: bool=false

func configure(scene: Node3D) -> void:
	main=scene;animals=main.get_node("Environment/CourtyardAnimals")
	animals.duck_preview=true
	for entry: Dictionary in animals.birds:
		if entry.kind!="duck": continue
		for node: Node3D in [entry.node,entry.wake]:
			if node.visible: _hidden.append(node);node.hide()

func update(plan: RefCounted) -> void:
	var changed: bool=_plan==null or _plan.construction.ducks!=plan.construction.ducks
	_plan=plan;validated=null
	message=Construction.water_area_issue(plan)
	if _area!=plan.construction.ducks.area:
		_area=plan.construction.ducks.area.duplicate();_space=null
		_due=Time.get_ticks_msec()+100
	pending=message.is_empty()
	_sync_water()
	if changed: _show_flock()
	_resolve()

func _sync_water() -> void:
	if not animals.water_ready:
		validated=null;pending=message.is_empty();return
	if _water!=animals.water:
		_water=animals.water;_space=null;validated=null;pending=message.is_empty()
	if _space==null:
		if _area==main.courtyard_plan.construction.ducks.area: _space=animals.duck_space
		elif _area.is_empty(): _space=_water

func _resolve() -> void:
	if not message.is_empty() or not animals.water_ready or _space==null: return
	pending=false
	if int(_plan.construction.ducks.count)>0:
		if _space.points.is_empty(): message="这里没有可活动的水面，请调整范围。"
		elif not _area.is_empty():
			var rect:=Rect2(_area[0],_area[1],_area[2],_area[3])
			var clear: int=0
			for y: int in 7:
				for x: int in 7:
					if _water.contains(rect.position+Vector2((x+.5)/7.0,(y+.5)/7.0)*rect.size): clear+=1
			if clear<35: message="这里的水面太拥挤，请避开岛岸、桥头和密集荷花。"
	if message.is_empty(): validated=_plan
	_show_flock()

func _show_flock() -> void:
	var count: int=int(_plan.construction.ducks.count)
	for id: String in models.keys():
		if int(id.trim_prefix("LakeDuck"))>count: models[id].free();models.erase(id)
	var placed:=PackedVector2Array()
	for i: int in count:
		var id: String="LakeDuck%d"%(i+1)
		var entry: Dictionary=animals.interaction.find(id)
		var point:=Vector2(-10.7+i*.8,1.7+i*.6)
		if not _area.is_empty(): point=Vector2(_area[0],_area[1])+Vector2(_area[2],_area[3])*.5+Vector2.from_angle(i*2.4)*sqrt(i)*.6
		if not entry.is_empty() and _area==main.courtyard_plan.construction.ducks.area: point=entry.position
		if _space!=null and not _space.points.is_empty():
			if entry.is_empty() or _area!=main.courtyard_plan.construction.ducks.area: point=_separated_point(point,placed)
		placed.append(point)
		if not models.has(id):
			models[id]=Assets.place(self,"duck",Vector3.ZERO,0,.88 if i==2 else 1.0)
			models[id].name=id
		models[id].position=Vector3(point.x,-.45,point.y)
		models[id].rotation.y=0.0 if entry.is_empty() else entry.node.rotation.y

func _separated_point(point: Vector2, placed: PackedVector2Array) -> Vector2:
	var best: Vector2=_space.nearest(point)
	var clear: bool=true
	for other: Vector2 in placed:
		if best.distance_squared_to(other)<.75*.75: clear=false;break
	if clear: return best
	var distance: float=INF
	for p: Vector2 in _space.points:
		var occupied: bool=false
		for other: Vector2 in placed:
			if other.distance_squared_to(p)<.75*.75: occupied=true;break
		if occupied: continue
		var d: float=point.distance_squared_to(p)
		if d<distance: best=p;distance=d
	return best

func _process(_delta: float) -> void:
	if _retiring:
		if _worker!=null:
			if _worker.is_alive(): return
			_worker.wait_to_finish();_worker=null
		queue_free();return
	if _plan==null: return
	var previous: RefCounted=validated
	var was_pending: bool=pending
	_sync_water()
	if _worker!=null and not _worker.is_alive():
		var result: RefCounted=_worker.wait_to_finish();_worker=null
		if _working_area==_area and _working_water==_water: _space=result
	if pending: _resolve()
	if previous!=validated or was_pending!=pending: checked.emit()
	if not pending or not animals.water_ready or _space!=null or _worker!=null or Time.get_ticks_msec()<_due: return
	_working_area=_area.duplicate();_working_water=_water;_worker=Thread.new()
	var error: Error=_worker.start(Animals.build_duck_space.bind(_working_area,_water.obstacles.duplicate(),_water._obstacle_cells.duplicate(true)))
	if error!=OK:
		_worker=null;pending=false;message="水域检查未能启动，请重新调整后再试。"
		push_error("Duck region worker: %d"%error);checked.emit()

func accept(plan: RefCounted) -> void:
	animals.apply_ducks(_space,main.farm_state.snapshot().animals,models)
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
	if is_instance_valid(animals): animals.duck_preview=false
	for node: Node3D in _hidden:
		if is_instance_valid(node) and not node.is_queued_for_deletion(): node.show()
	_hidden.clear()

func _exit_tree() -> void:
	if _worker!=null and _worker.is_started(): _worker.wait_to_finish()
	_restore()
