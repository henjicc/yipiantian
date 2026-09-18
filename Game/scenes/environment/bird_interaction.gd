extends RefCounted
## Short lived approaches share the animals' normal routes, steering and poses.
const Companions=preload("res://farm/animal_companions.gd")
var owner: Node3D
var profiles: Dictionary=Companions.initial_state()
var active: Dictionary={}
func find(id: String) -> Dictionary:
	for entry: Dictionary in owner.birds:
		if String(entry.node.name)==id: return entry
	return {}
func status(id: String) -> String:
	if not active.has(id): return ""
	var contact: Dictionary=active[id]
	if contact.phase=="approach": return "正走过来" if Companions.kind(id)=="hen" else "正游过来"
	return "正在吃菜叶" if contact.feed else "陪你待一会儿"
func prepare(id: String,camera: Camera3D,visible: Callable=Callable()) -> Dictionary:
	var entry: Dictionary=find(id)
	if entry.is_empty() or active.has(id): return {}
	var toward: Vector2=Vector2(camera.global_position.x,camera.global_position.z)-entry.position
	for length: float in [1.3,.9,.6]:
		for angle: float in [0.0,.7,-.7,1.4,-1.4,PI]:
			var direction: Vector2=toward.normalized().rotated(angle)
			var target: Vector2=entry.space.nearest(entry.position+direction*length)
			if target.distance_to(entry.position)<.45: continue
			var route: PackedVector2Array=entry.space.path(entry.position,target)
			if route.is_empty(): continue
			var distance: float=0.0
			var last: Vector2=entry.position
			for corner: Vector2 in route:
				distance+=last.distance_to(corner);last=corner
			if distance>length*2.0+1.0: continue
			var occupied: bool=false
			for other: Dictionary in owner.birds:
				if other!=entry and other.space==entry.space and target.distance_to(other.position)<entry.radius+other.radius+.3: occupied=true
			if occupied: continue
			var previous: Vector2=route[route.size()-2] if route.size()>1 else entry.position
			var forward: Vector2=(target-previous).normalized()
			var food_point: Vector2=target+forward*(.14 if entry.kind=="hen" else .24)
			if not entry.space.contains(food_point): continue
			var spot:=Vector3(food_point.x,entry.space.ground_height(food_point)+.025 if entry.kind=="hen" else -.235,food_point.y)
			if visible.is_valid() and not visible.call(spot): continue
			return {"target":target,"route":route,"heading":atan2(forward.x,forward.y)}
	return {}
func retry(entry: Dictionary) -> bool:
	var id: String=entry.node.name
	if not active.has(id) or active[id].phase!="approach": return false
	# A neighbour can temporarily occupy a narrow path. Keep the agreed target
	# and retry through the same steering instead of discarding the shared food.
	var route: PackedVector2Array=entry.space.path(entry.position,active[id].target)
	if route.is_empty(): return false
	entry.route=route;entry.waypoint=0;entry.stuck=0;entry.buddy=null
	entry.state="walk" if entry.kind=="hen" else "swim"
	return true
func begin(id: String,request: Dictionary,feed: bool) -> void:
	var entry: Dictionary=find(id)
	entry.route=request.route;entry.waypoint=0;entry.timer=0;entry.stuck=0
	entry.buddy=null;entry.interest=Vector2.INF
	entry.state="walk" if entry.kind=="hen" else "swim"
	var contact: Dictionary=request.duplicate(true)
	contact.merge({"phase":"approach","elapsed":0.0,"feed":feed,"food":null})
	if feed:
		var offset:=Vector2(sin(request.heading),cos(request.heading))*(.14 if entry.kind=="hen" else .24)
		contact.food=_leaves(request.target+offset,entry)
	active[id]=contact
func arrive(entry: Dictionary) -> bool:
	var id: String=entry.node.name
	if not active.has(id): return false
	var contact: Dictionary=active[id]
	if contact.phase!="approach" or entry.position.distance_to(contact.target)>.24:
		cancel(id);return false
	contact.phase="response";contact.elapsed=0.0
	entry.state=("peck" if entry.kind=="hen" else "probe") if contact.feed else "observe"
	entry.timer=7.0;entry.route=PackedVector2Array();entry.buddy=null;entry.interest=Vector2.INF
	return true
func advance(entry: Dictionary,delta: float) -> void:
	var id: String=entry.node.name
	if not active.has(id): return
	var contact: Dictionary=active[id]
	contact.elapsed+=delta
	if contact.phase=="response":
		entry.heading=rotate_toward(entry.heading,contact.heading,delta*2.0)
		if contact.food!=null:
			contact.food.scale=Vector3.ONE*maxf(.01,1.0-contact.elapsed/7.0)
	if contact.elapsed>45: cancel(id)
func cancel(id: String) -> void:
	if not active.has(id): return
	var food: Node3D=active[id].food
	if is_instance_valid(food): food.queue_free()
	active.erase(id)
func rest_target(entry: Dictionary) -> Vector2:
	var id: String=entry.node.name
	var profile: Dictionary=profiles[id]
	var index: int=profile.preference if profile.preference>=0 else Companions.IDS.find(id)%entry.space.resting.size()
	return entry.space.resting[index]
func _leaves(point: Vector2,entry: Dictionary) -> Node3D:
	var cluster:=MeshInstance3D.new()
	var mesh:=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 5:
		var angle: float=i*2.4
		var center:=Vector3(sin(angle),0,cos(angle))*.05
		var long:=Vector3(cos(angle),0,-sin(angle))*.022
		var wide:=Vector3(sin(angle),.003,cos(angle))*.012
		for p: Vector3 in [center-long,center+wide,center+long,center-long,center+long,center-wide]: mesh.add_vertex(p)
	mesh.generate_normals();cluster.mesh=mesh.commit()
	var material:=StandardMaterial3D.new();material.albedo_color=Color("718d48");material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=1
	cluster.material_override=material;cluster.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(cluster)
	cluster.global_position=Vector3(point.x,entry.space.ground_height(point)+.018 if entry.kind=="hen" else -.235,point.y)
	return cluster
