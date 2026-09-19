extends SceneTree
const Space=preload("res://layout/island_space.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
const Construction=preload("res://layout/island_construction.gd")
const Cover=preload("res://scenes/environment/ground_cover.gd")
const Circulation=preload("res://layout/courtyard_circulation.gd")
var failures: Array[String]=[]
var checks: int=0

func _initialize() -> void: _run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message);push_error(message)

func _run() -> void:
	expect(Space.cell_at(Vector2(-.01,-.51))==Vector2i(-1,-2),"Negative coordinates use the same floor grid as terrain painting")
	var occupied:=Space.new()
	var a: PackedVector2Array=Space.rectangle(Vector2(.01,.01),Vector2(.1,.1))
	var b: PackedVector2Array=Space.rectangle(Vector2(.3,.3),Vector2(.1,.1))
	occupied.add("pot",a)
	expect(occupied.collisions(b).is_empty(),"Free placements sharing a grid cell do not falsely collide")
	expect(occupied.collisions(a)==["pot"],"Actual overlapping placement is blocked")
	expect(occupied.collisions(a,["pot"]).is_empty(),"Moving an object can exclude its own footprint")
	occupied.add("pot",Space.rectangle(Vector2(2,2),Vector2(.1,.1)))
	expect(occupied.collisions(a).is_empty(),"Moving updates old occupancy")
	occupied.remove("pot")
	expect(occupied.collisions(Space.rectangle(Vector2.ZERO,Vector2(4,4))).is_empty(),"Removal clears occupancy")
	var pose:=Transform3D(Basis(Vector3.UP,.37),Vector3(-.17,0,.28))
	var building: PackedVector2Array=Space.footprint(Vector2(3.7,2.3),pose)
	expect(Space.covered_cells(building).size()>30,"Rotated buildings occupy multiple standard cells")
	expect(is_equal_approx(building[0].distance_to(building[1]),3.7),"Grid indexing retains real dimensions and rotation")
	occupied.add("house",building)
	expect(occupied.collisions(Space.rectangle(Vector2(-.2,.2),Vector2(.1,.1)))==["house"],"Large rotated footprint blocks its interior")
	var bay:=PackedVector2Array([Vector2(0,0),Vector2(4,0),Vector2(4,4),Vector2(3,4),Vector2(3,1),Vector2(1,1),Vector2(1,4),Vector2(0,4)])
	var spanning: PackedVector2Array=Space.rectangle(Vector2(.2,2),Vector2(3.6,.3))
	var corners_supported: bool=true
	for point: Vector2 in spanning: corners_supported=corners_supported and Geometry2D.is_point_in_polygon(point,bay)
	expect(corners_supported and not Space.supported(spanning,bay),"Full footprint rejects a bay crossing even with four supported corners")
	var plan:=Plan.new()
	expect(Circulation.field_placement_issues(plan,{}).is_empty(),"Existing field spacing remains valid")
	var span: Vector2=Plan.cell_span(plan.fields[0])
	expect(span.is_equal_approx(Vector2(.6,.44)),"Crop spacing is independent of the half-meter terrain grid")
	plan.fields[0].position=plan.fields[1].position
	expect(not Circulation.field_placement_issues(plan,{}).is_empty(),"Unified field placement catches actual overlapping beds")
	plan=Plan.new()
	var banks: Array[PackedVector2Array]=plan.water_banks()
	expect(not Space.water_clear(Space.rectangle(Vector2(12,-3),Vector2(1,1)),banks),"Water placement excludes the opposite island too")
	expect(Space.water_clear(Space.rectangle(Vector2(-14,10),Vector2(2,2)),banks),"Open water stays available")
	var slope: Vector2=plan.rim[0]*1.01
	expect(not Geometry2D.is_point_in_polygon(slope,plan.plateau()) and not Space.water_clear(Space.rectangle(slope,Vector2(.02,.02)),banks),"Shore slope is neither flat support nor clear water")
	var endpoints: Array[Vector3]=Construction.bridge_points(plan)
	plan.construction.bridge=[endpoints[0].x,endpoints[0].z,endpoints[1].x,endpoints[1].z,1.2]
	expect(Construction.bridge_issue(plan).is_empty(),"Existing bridge has full-width supported approaches")
	plan.construction.bridge[0]=0;plan.construction.bridge[1]=14
	expect(not Construction.bridge_issue(plan).is_empty(),"Floating bridge approach is rejected")
	plan=Plan.new()
	expect(plan.apply_construction({"land":[[-2,5,4,5],[-4,5,3,5]],"trellis":[],"bridge":[],"buildings":{"house":[],"kitchen":[]},"flocks":preload("res://layout/flock_layout.gd").initial()}),"Connected extension supports the planting fixture")
	var cover:=Cover.new();root.add_child(cover);cover.update_expansion(plan)
	var initial: Dictionary=meshes(cover)
	expect(not initial.is_empty(),"Extension generates actual grass geometry")
	var far_cell: Vector2i=Vector2i(-4,7)
	var far_id: int=cover._tiles[far_cell].get_instance_id()
	plan.fields[0].position=Vector3(0,.2,8)
	plan.paths=[PackedVector3Array([Vector3(-1.5,.13,6.2),Vector3(-1.5,.13,9.2)])]
	cover.update_expansion(plan)
	expect(cover._tiles[far_cell].get_instance_id()==far_id,"Unchanged grass tiles are retained when fields move elsewhere")
	var polygon: PackedVector2Array=plan.field_polygon(0)
	var inside: int=0
	var on_path: int=0
	for vertices: PackedVector3Array in meshes(cover).values():
		for vertex: Vector3 in vertices:
			var point:=Vector2(vertex.x,vertex.z)
			if Geometry2D.is_point_in_polygon(point,polygon): inside+=1
			if Geometry2D.get_closest_point_to_segment(point,Vector2(-1.5,6.2),Vector2(-1.5,9.2)).distance_to(point)<.16: on_path+=1
	expect(inside==0,"Grass blades do not protrude into the new field")
	expect(on_path==0,"Grass clears the route through new land")
	var saved: Dictionary=meshes(cover)
	var reopened:=Cover.new();root.add_child(reopened);reopened.update_expansion(plan)
	expect(meshes(reopened)==saved,"Same final layout produces exactly the same grass on reopen")
	plan.fields[0]=Plan.new().fields[0];plan.paths=[]
	cover.update_expansion(plan)
	expect(meshes(cover)==initial,"Moving the field away restores the original grass without reshuffling")
	var prop: PackedVector2Array=Space.rectangle(Vector2(-1,7),Vector2(1.5,2))
	var prop_inner: PackedVector2Array=Space.rectangle(Vector2(-.85,7.15),Vector2(1.2,1.7))
	cover.update_objects(plan,[prop],true)
	inside=0
	for vertices: PackedVector3Array in meshes(cover).values():
		for vertex: Vector3 in vertices:
			if Geometry2D.is_point_in_polygon(Vector2(vertex.x,vertex.z),prop_inner): inside+=1
	expect(meshes(cover)!=initial and inside==0,"Local prop updates remove actual grass at its world coordinates")
	expect(cover._tiles[far_cell].get_instance_id()==far_id,"Prop updates preserve unrelated grass nodes")
	cover.update_objects(plan,[],true)
	expect(meshes(cover)==initial,"Removing the prop restores exactly the same blades")
	cover.free();reopened.free()
	print("Island space: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func meshes(cover: Node3D) -> Dictionary:
	var result: Dictionary={}
	for cell: Vector2i in cover._tiles:
		result[cell]=cover._tiles[cell].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return result
