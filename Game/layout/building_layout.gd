extends RefCounted
## Authored building assemblies share one rigid pose; gameplay state stays separate.
const BASE={"house":Vector3(.65,.13,-4.65),"kitchen":Vector3(-4.5,.115,-5)}
const STRUCTURES={"house":["MainHouse","PorchDeck"],"kitchen":["Kitchen"]}
const PROPS={"house":["PorchHarvestTable","PorchFarmTools","WindowWarmth"],"kitchen":["SidePorchDryingRack","YardFirewood"]}
const SLOTS={"house":["hanging_01","hanging_02"],"kitchen":["hanging_04"]}

static func initial() -> Dictionary:
	return {"house":[],"kitchen":[]}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size()!=2: return false
	for id: String in BASE:
		if not data.get(id) is Array: return false
		if data[id].is_empty(): continue
		if data[id].size()!=3: return false
		for value: Variant in data[id]:
			if not (value is float or value is int) or not is_finite(float(value)): return false
		if absf(data[id][0])>24 or absf(data[id][1])>24 or data[id][2]<-180 or data[id][2]>=180: return false
	return true

static func pose(plan: RefCounted, id: String) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles[id])),plan.anchors[id])

static func parameters(plan: RefCounted, id: String) -> Array:
	return [float("%.4f"%plan.anchors[id].x),float("%.4f"%plan.anchors[id].z),float(plan.angles[id])]

static func delta(plan: RefCounted, id: String) -> Transform3D:
	var origin: Vector3=BASE[id]+Vector3.UP*(plan.ground_height-.13)
	return pose(plan,id)*Transform3D(Basis.IDENTITY,origin).affine_inverse()

static func apply(plan: RefCounted) -> void:
	for id: String in BASE:
		var values: Array=plan.construction.buildings[id]
		if values.is_empty(): continue
		for i: int in 3: values[i]=float("%.4f"%values[i])
		values[2]=wrapf(values[2],-180,180)
		plan.anchors[id].x=values[0];plan.anchors[id].z=values[1];plan.angles[id]=values[2]
		plan.anchors[id].y=plan.ground_height_at(Vector2(values[0],values[1]))+BASE[id].y-.13
		var transform: Transform3D=delta(plan,id)
		if id=="house":
			plan.anchors.veranda=transform*plan.anchors.veranda
			plan.angles.veranda=values[2]
		for prop: String in PROPS[id]:
			plan.props[prop][0]=transform*plan.props[prop][0]
			plan.props[prop][1]+=values[2]
		for slot: String in SLOTS[id]: plan.slots[slot]=transform*plan.slots[slot]
