extends SceneTree
const Flocks=preload("res://layout/flock_layout.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
const State=preload("res://farm/farm_state.gd")
const Navigation=preload("res://scenes/environment/animal_space.gd")
var checks: int=0
var failures: Array[String]=[]
func expect(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message);push_error(message)
func _initialize() -> void:
	var plan:=Plan.new()
	for kind: String in Flocks.KINDS:
		var data: Dictionary=plan.snapshot()
		data.construction.flocks[kind].count=Flocks.SPECIES[kind].limit
		expect(Plan.from_snapshot(data)!=null,"Species maximum is valid: "+kind)
		data.construction.flocks[kind].count+=1
		expect(Plan.from_snapshot(data)==null,"Species maximum enforced: "+kind)
		data.construction.flocks[kind].count=1.5
		expect(Plan.from_snapshot(data)==null,"Fractional count rejected: "+kind)
		data.construction.flocks[kind].count=2;data.construction.flocks[kind].area=[0,0,NAN,3]
		expect(Plan.from_snapshot(data)==null,"Nonfinite boundary rejected: "+kind)
		data.construction.flocks[kind].area=[0,0,2,2];data.construction.flocks[kind].count=8
		expect(Plan.from_snapshot(data)==null,"Raw region density enforced: "+kind)
	var data: Dictionary=plan.snapshot()
	for kind: String in Flocks.KINDS: data.construction.flocks[kind].count=Flocks.SPECIES[kind].limit
	var state:=State.new();expect(state.apply_layout(data,2000000).ok,"All populations can reach validated maximum")
	var snapshot: Dictionary=state.snapshot()
	expect(snapshot.animals.size()==28,"Bounded profiles for all species")
	snapshot.animals.YardHen8.name="小栗";snapshot.animals.LakeGoose8.name="小白"
	expect(state.restore_snapshot(snapshot),"Additional hens and geese have valid durable identities")
	for kind: String in Flocks.KINDS: data.construction.flocks[kind].count=0
	expect(state.apply_layout(data,2000001).ok,"All populations can be removed")
	expect(state.snapshot().animals.YardHen8.name=="小栗" and state.snapshot().animals.LakeGoose8.name=="小白","Removed histories retained for undo")
	var invalid: Dictionary=state.snapshot();invalid.animals.LakeGoose9=invalid.animals.LakeGoose8.duplicate(true)
	expect(not state.restore_snapshot(invalid),"Unbounded archived profile rejected")
	var source:=Navigation.new();source.configure(Rect2(0,0,8,4),.21)
	source.block(PackedVector2Array([Vector2(3.9,0),Vector2(4.1,0),Vector2(4.1,4),Vector2(3.9,4)]));source.bake()
	var region: RefCounted=Navigation.build_region([0,0,8,4],Navigation.capture(source))
	expect(region.points.size()<source.points.size()*.6,"Disconnected fragments do not add to usable region capacity")
	var reachable: bool=true
	for p: Vector2 in region.points:
		if region.path(region.points[0],p).is_empty(): reachable=false;break
	expect(reachable,"Every retained region sample is connected")
	expect(not Flocks.space_issue("goose",8,region).is_empty(),"Obstacle-split region refuses an overcrowded flock")
	var tiny:=Navigation.new();tiny.configure(Rect2(0,0,2,2),.46);tiny.bake()
	var occupied:=PackedVector2Array(tiny.points)
	expect(not Flocks.separated_point(tiny,Vector2.ONE,occupied,.75).is_finite(),"No separated placement fails explicitly instead of stacking")
	var hen_plan:=Plan.new();var construction: Dictionary=hen_plan.Construction.initial();construction.land=[[-3,5,5,5]]
	construction.flocks.hen={"count":4,"area":[-2,6,3,3]};hen_plan.apply_construction(construction)
	expect(Flocks.terrain_issue(hen_plan).is_empty(),"Hens can use expanded land")
	expect(Flocks.land_issue(hen_plan,{}).is_empty(),"Open hen region has usable space")
	var wall: PackedVector2Array=Flocks.Space.rectangle(Vector2(-2,6),Vector2(3,3))
	expect(not Flocks.land_issue(hen_plan,{"building":wall}).is_empty(),"Later construction cannot consume all hen space")
	var water:=Navigation.new();water.configure(Rect2(-20,-10,40,30),.46);water.bake()
	hen_plan.construction.flocks.goose={"count":4,"area":[4,10,4,4]}
	var plants: Array[PackedVector2Array]=[Flocks.Space.rectangle(Vector2(4,10),Vector2(4,4))]
	expect(not Flocks.added_obstacle_issue(hen_plan,"goose",water,plants).is_empty(),"Later plants preserve goose region capacity")
	# Height samples retain their original spatial index when regions move.
	var land:=Navigation.new();land.configure(Rect2(-4,-4,10,10),.21)
	land._floor_faces[Vector2i(25,25)]=[PackedVector3Array([Vector3(0,.22,0),Vector3(1,.22,0),Vector3(0,.22,1)])]
	var copy: RefCounted=Navigation.build_region([-.5,-.5,3,3],Navigation.capture(land))
	expect(is_equal_approx(copy.ground_height(Vector2(.05,.05)),.22),"Region keeps real floor triangle origin for hen feet")
	var across:=Plan.new();across.construction.flocks.hen={"count":2,"area":[4,-2,9,4]}
	expect(Flocks.terrain_issue(across).is_empty() and Flocks.land_issue(across,{}).is_empty(),"A selection can span both banks using the stone bridge")
	across.construction.bridge=[5.4,-.1,11,.1,1.2,1]
	expect(Flocks.terrain_issue(across).is_empty() and Flocks.land_issue(across,{}).is_empty(),"The same hen region works with a parameter bridge")
	across.construction.flocks.hen.area=[7,2,2,2]
	expect(not Flocks.terrain_issue(across).is_empty(),"A water-only rectangle remains invalid for hens")
	print("FLOCKS_TEST checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
