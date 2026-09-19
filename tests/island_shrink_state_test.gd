extends SceneTree
const Construction=preload("res://layout/island_construction.gd")
const Space=preload("res://layout/island_space.gd")
const Support=preload("res://layout/land_support.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
var checks: int=0
var failures: int=0

func expect(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1;push_error(message)

func _initialize() -> void:
	var original: PackedVector2Array=Space.rectangle(Vector2.ZERO,Vector2(6,6))
	var stamps: Array=[]
	expect(Construction.brush_cell(Vector2(-.000002,-8.500002))==Construction.brush_cell(Vector2(.000002,-8.499998)),"Numerical ray-plane noise does not shift a boundary stroke to its neighboring cell")
	var shore: PackedVector2Array=Construction.paint(stamps,original,Vector2(3,6),true)
	expect(stamps.size()==1 and not Geometry2D.is_point_in_polygon(Vector2(3.1,5.8),shore),"Erase removes existing shore without requiring an additive stamp")
	expect(Geometry2D.is_point_in_polygon(Vector2(1,1),shore),"Distant land remains intact")
	var restored: PackedVector2Array=Construction.land_outline(original,stamps)
	expect(restored==shore,"Persisted cut reconstructs the same polygon")
	shore=Construction.paint(stamps,shore,Vector2(3,5.5))
	expect(Geometry2D.is_point_in_polygon(Vector2(3.1,5.8),shore),"Later addition refills an erased shore")
	expect(Construction.land_outline(original,stamps)==shore,"Alternating add and erase order survives reconstruction")
	var rejected: Array=[]
	expect(Construction.paint(rejected,original,Vector2(3,3),true)==original and rejected.is_empty(),"Interior lake is refused without mutating the stroke log")
	expect(Construction.land_outline(original,[[2.5,0,1,6,-1]]).is_empty(),"Cutting into disconnected islands is refused")
	expect(Construction.land_outline(original,[[0,0,6,6,-1]]).is_empty(),"Erasing all land is refused")
	expect(Construction.paint(rejected,original,Vector2(12,12),true)==original and rejected.is_empty(),"Water-only erase is a no-op")
	var data: Dictionary=Construction.initial();data.land=[[0,5.5,1.5,1.5,-1]]
	expect(Construction.valid(data),"Subtractive stamps satisfy current save format")
	data.land[0][4]=0
	expect(not Construction.valid(data),"Unknown operation is rejected at the data boundary")
	data.land[0][4]=-1;data.land[0][0]=.1
	expect(not Construction.valid(data),"Erase still obeys the half-metre grid")
	var plan:=Plan.new();var layout: Dictionary=plan.snapshot()
	for tree: Dictionary in plan.trees:
		var roots: PackedVector2Array=Space.rectangle(Vector2(tree.at.x,tree.at.z)-Vector2.ONE*.55,Vector2.ONE*1.1)
		var pieces: Array[PackedVector2Array]=Geometry2D.intersect_polygons(roots,plan.plateau())
		var cuts: Array=[]
		var shape: PackedVector2Array=Construction.paint(cuts,preload("res://layout/bank_geometry.gd").contour(plan.rim),Vector2(-8,-2),true)
		expect(Support.issue(Support.plateau(shape,plan),{tree.id:pieces}).is_empty(),"Editing west shore retains distant supported root ground: "+tree.id)
	layout.construction.land=[[-7.5,-2,1.5,1.5,-1]]
	var decoded: RefCounted=Plan.from_snapshot(layout)
	expect(decoded!=null and decoded.rim!=plan.rim,"Original island supports subtractive layout data")
	if decoded!=null:
		var json: Dictionary=JSON.parse_string(JSON.stringify(decoded.snapshot()))
		expect(Plan.from_snapshot(json).snapshot()==decoded.snapshot(),"JSON round trip preserves erase parameters")
		var dressing=preload("res://presentation/shore_dressing.gd")
		var unchanged: bool=true
		var stones: Array[Dictionary]=dressing.stones(decoded)
		for stone: Dictionary in dressing.stones(plan):
			if Vector2(stone.at.x,stone.at.z).distance_to(Vector2(-7,-1.5))>3 and stone not in stones: unchanged=false
		expect(unchanged,"Distant authored rocks keep their exact distribution after a cut")
		var local_dressing: bool=true
		for p: Vector2 in dressing.added_points(decoded):
			if p.distance_to(Vector2(-7,-1.5))>3: local_dressing=false
		expect(local_dressing,"New shore decoration stays local to the edited shore")
	var protected: Dictionary={"田块0":[Space.rectangle(Vector2(2,4),Vector2(1,1))]}
	var trimmed: PackedVector2Array=Construction.land_outline(original,[[2,4.5,1.5,1.5,-1]])
	expect(not Support.issue(trimmed,protected).is_empty(),"Partial field support loss is refused even if its centre remains")
	expect(Support.issue(original,protected).is_empty(),"Unchanged supported content stays valid")
	print("ISLAND_SHRINK_STATE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
