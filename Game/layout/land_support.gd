extends RefCounted
## Shore edits preserve the ground currently carrying authored/player content.
const Space=preload("res://layout/island_space.gd")
const Construction=preload("res://layout/island_construction.gd")
const Routes=preload("res://layout/player_routes.gd")
const Bank=preload("res://layout/bank_geometry.gd")

static func capture(main: Node3D, island: int=0) -> Dictionary:
	var plan: RefCounted=main.courtyard_plan
	var environment: Node3D=main.get_node("Environment")
	var protected: Dictionary={}
	for key: String in environment.layout_obstacles:
		var node: Node=environment.get_node_or_null(NodePath(key))
		if node!=null and node.has_meta("shore_stone"): continue
		if key.begins_with("BankReeds") or key.begins_with("Lotus") or key.begins_with("player_plant_"): continue
		if preload("res://layout/bridge_passage.gd").is_bridge(key): continue
		protected[key]=environment.layout_obstacles[key]
	protected.merge(main.decoration_layout.ground_footprints())
	for i: int in plan.fields.size(): protected["田块%d"%i]=plan.field_polygon(i,.14)
	protected["桥头"]=Construction.bridge_approaches(plan)[island]
	# Preserve the currently usable approaches as well as the object feet.
	for i: int in plan.paths.size():
		var line: PackedVector3Array=plan.paths[i]
		for j: int in range(1,line.size()):
			protected["通路%d_%d"%[i,j]]=Routes.strip(Vector2(line[j-1].x,line[j-1].z),Vector2(line[j].x,line[j].z),.28,0)
	var flock: Dictionary=plan.construction.flocks.hen
	if flock.count>0 and not flock.area.is_empty(): protected["鸡群活动区域"]=Construction.rectangle(flock.area)
	for bird: Dictionary in environment.get_node("CourtyardAnimals").birds:
		if bird.kind=="hen": protected["小鸡"+String(bird.node.name)]=Space.rectangle(bird.position-Vector2.ONE*.23,Vector2.ONE*.46)
	# Root collars are static authored meshes; retain their supported ground.
	for child: Node in environment.get_children():
		var id: String=String(child.name)
		if child is Node3D and (id.begins_with("Bamboo") or id.begins_with("Flowers") or id.ends_with("Tree")):
			var at: Vector3=child.position
			protected["根部"+id]=Space.rectangle(Vector2(at.x,at.z)-Vector2.ONE*.55,Vector2.ONE*1.1)
	var grounded: Dictionary={}
	var plateau: PackedVector2Array=plan.plateau(island)
	var original: PackedVector2Array=plan.unpainted().plateau(island)
	for key: String in protected:
		# Fixed root collars already overhang some authored banks. Filling the
		# water under that overhang must not acquire new, irreversible support.
		# The trellis flower moves with player construction and uses current land.
		var fixed_root: bool=key.begins_with("根部") and not key.begins_with("根部Flowers0_")
		var pieces: Array[PackedVector2Array]=Geometry2D.intersect_polygons(protected[key],original if fixed_root else plateau)
		if not pieces.is_empty(): grounded[key]=pieces
	return grounded

static func issue(plateau: PackedVector2Array, protected: Dictionary) -> String:
	for key: String in protected:
		for polygon: PackedVector2Array in protected[key]:
			# Boolean clipping quantizes vertices. Ignore only sub-millimetre
			# numerical slivers from clipping an already clipped support polygon.
			var lost: float=0
			for piece: PackedVector2Array in Geometry2D.clip_polygons(polygon,plateau):
				for i: int in piece.size(): lost+=(piece[i]-piece[0]).cross(piece[(i+1)%piece.size()]-piece[0])*.5
			if absf(lost)>.00001:
				if key.begins_with("田块"): return "这里承托着田块，请先移动田块。"
				if key=="桥头": return "请保留桥头下方及出口的土地。"
				if key.begins_with("通路"): return "请保留已有物件之间的通路。"
				if key=="鸡群活动区域": return "请先调整鸡群活动区域，再缩减这里的土地。"
				if key.begins_with("小鸡"): return "小鸡在这里，请等它走开再缩地。"
				return "这里承托着物件或植物，请保留其下方的土地。"
	return ""

static func plateau(rim: PackedVector2Array, plan: RefCounted, island: int=0) -> PackedVector2Array:
	return plan.island_pose(island)*Bank.ring(Bank.contour(rim,true),.96,plan.bank_width,true)

static func neighbor_issue(environment: Node3D, plan: RefCounted) -> String:
	var neighbors: Node3D=environment.get_node("NeighborIslets")
	var edges: Array[PackedVector2Array]=[]
	for bank: PackedVector2Array in plan.water_banks(): edges.append_array(Geometry2D.offset_polygon(bank,.5))
	for polygon: PackedVector2Array in neighbors.construction_obstacles(plan):
		for edge: PackedVector2Array in edges:
			if Space.overlaps(edge,polygon): return "这里靠近邻岛，请为两座岛保留水道。"
	return ""
