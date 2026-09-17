extends RefCounted
## Shared spatial data. Scene builders consume this instance; farm state owns crops.
## The original metric composition is retained; banks are generated from these contours.
const FIELD_IDS: Array[String] = ["field_01", "field_02", "field_03", "field_04", "field_05", "field_06"]
const BankGeometry = preload("res://layout/bank_geometry.gd")
var ground_height: float = .13
var bank_width: float = 1.0
var east_rim := PackedVector2Array([Vector2(-2.9,-1.1),Vector2(-1.9,-3.5),Vector2(1.3,-3.8),Vector2(3.5,-2.1),Vector2(4.2,.7),Vector2(3.2,3.8),Vector2(.5,4.4),Vector2(-2.8,3.9),Vector2(-3.05,2.5)])
var shelves: Array[Vector3] = [Vector3(-7.1,-.48,2.7),Vector3(-6.2,-.48,4.7),Vector3(-4.0,-.48,6.0),Vector3(-1.1,-.50,6.5),Vector3(2.0,-.46,6.4),Vector3(5.7,-.45,5.55),Vector3(6.5,-.43,2.5)]
var bamboo_positions: Array[Vector3] = [Vector3(-7,.13,-5.2),Vector3(-7.1,.13,-.5),Vector3(5.4,.13,-5.7),Vector3(6.3,.13,2.0),Vector3(13.8,.10,-.8),Vector3(-6.6,.13,-6.6),Vector3(4.7,.13,-7.0),Vector3(5.9,.13,-3.5)]
var reeds: Array[Vector3] = [Vector3(-7.15,.05,2.7),Vector3(-6.55,.04,4.35),Vector3(-4.1,.06,5.85),Vector3(-2.15,.06,6.2),Vector3(.7,.06,6.25),Vector3(3.1,.07,5.85),Vector3(6.0,.06,4.3),Vector3(6.1,.08,3.5),Vector3(6.15,.08,-1.6),Vector3(11.0,.03,-.85),Vector3(14.2,.03,-.35)]
var flower_centres: Array[Vector3] = [Vector3(-5.8,.13,3.45),Vector3(5.25,.13,3.75),Vector3(-5.7,.13,-2.8),Vector3(5.3,.13,-3.0),Vector3(-3.8,.13,5.6),Vector3(2.4,.13,5.7),Vector3(-6.25,.11,4.9),Vector3(-1.8,.13,5.75),Vector3(.2,.13,5.95),Vector3(4.0,.12,5.6),Vector3(6.0,.13,1.0),Vector3(-6.85,.12,2.25),Vector3(11.35,.1,-.8),Vector3(13.6,.1,-1.5),Vector3(-3.4,.13,-2.05)]
var lily_coves: Array[Vector3] = [Vector3(-6.35,-.40,7.25),Vector3(-.9,-.40,8.05),Vector3(5.35,-.40,7.4),Vector3(14.0,-.40,3.4),Vector3(-9.8,-.40,3.6),Vector3(-11.2,-.40,-1.8),Vector3(-7.9,-.40,9.2),Vector3(1.6,-.40,10.8),Vector3(8.9,-.40,7.9)]
var fields: Array[Dictionary] = []
var rim := PackedVector2Array([Vector2(-7.5,-7.6),Vector2(-4.8,-8.4),Vector2(-1,-8.2),Vector2(2.5,-7.9),Vector2(5.6,-6.5),Vector2(6.5,-3.8),Vector2(6.4,-.8),Vector2(6.8,1.3),Vector2(5.8,4.8),Vector2(3.5,6.1),Vector2(.7,6.7),Vector2(-2.5,6.1),Vector2(-5.5,5.6),Vector2(-7.2,3.2),Vector2(-7.6,.2),Vector2(-7.1,-3.6)])
var paths: Array[PackedVector3Array] = [
	PackedVector3Array([Vector3(-6,.115,2.9),Vector3(-5.25,.115,-1.7),Vector3(-2,.115,-1.8),Vector3(2.5,.115,-1.7),Vector3(6.2,.115,-.6)]),
	PackedVector3Array([Vector3(-4.9,.115,4.65),Vector3(-.5,.115,4.65),Vector3(4.8,.115,4.7)]),
	PackedVector3Array([Vector3(-1.68,.115,-1),Vector3(-1.68,.115,4.1)]),
	PackedVector3Array([Vector3(1.57,.115,-1),Vector3(1.57,.115,4.1)]),
]
var anchors := {
	"house": Vector3(.65,.13,-4.65), "veranda": Vector3(.65,.13,-2.4),
	"kitchen": Vector3(-4.5,.115,-5), "trellis": Vector3(-5.8,.13,1.05),
	"bridge": Vector3(8.1,-.04,-.15), "east_bank": Vector3(12.65,-.02,-2.8),
	"boat": Vector3(9,-.5,4.3), "mooring": Vector3(6.32,-.3,3.85),
}
var angles := {"house": 0.0, "veranda": 0.0, "kitchen": 0.0, "trellis": 90.0, "bridge": -9.0, "east_bank": 0.0, "boat": -24.0}
var slots := {
	"ground_01": Vector3(-5.35,.16,-1.85), "ground_02": Vector3(4.7,.16,-1.8),
	"ground_03": Vector3(-5,.16,4.7), "ground_04": Vector3(4.75,.16,4.8),
	"hanging_01": Vector3(-2.5,2.27,-2.05), "hanging_02": Vector3(3.8,2.27,-2.05),
	"hanging_03": Vector3(-5.08,1.82,2.13), "hanging_04": Vector3(-4.85,1.98,-2.95),
}
var props := {
	"PorchHarvestTable": [Vector3(2.95,.41,-2.55),0.0],
	"SidePorchDryingRack": [Vector3(-3.7,.14,-2.72),-9.0],
	"PorchFarmTools": [Vector3(-2.5,.43,-2.9),12.0],
	"WindowWarmth": [Vector3.ZERO,0.0],
	"YardWaterVats": [Vector3(-5.28,.14,-.62),18.0],
	"YardFirewood": [Vector3(-4.9,.14,-3.28),-14.0],
	"YardStoneMill": [Vector3(5.07,.14,-2.92),-95.0],
	"YardJarCluster": [Vector3(5.22,.14,2.45),-30.0],
	"YardGroundTrays": [Vector3(-5.3,.14,2.3),40.0],
	"YardBasketStack": [Vector3(4.25,.14,4.22),-20.0],
	"YardBucket": [Vector3(-2.15,.14,-1.28),8.0],
	"YardDryingLine": [Vector3(1.45,.14,5.62),20.0],
	"YardMelonPile": [Vector3(1.15,.14,4.24),30.0],
	"YardSeedFrames": [Vector3(-2.62,.14,4.2),-25.0],
}
var fences: Array[Dictionary] = []
var animal_areas := {"water": Rect2(-14.5,-6,25,19.5), "yard": Rect2(-6.25,-6.8,12,11.75)}
var animal_rest := {
	"water": PackedVector2Array([Vector2(-11,1),Vector2(-10,6),Vector2(-3,10),Vector2(5,10)]),
	"yard": PackedVector2Array([Vector2(-4.9,-1.7),Vector2(5,-1.6),Vector2(-.5,4.6),Vector2(-1.7,1.4)]),
}
var trees: Array[Dictionary] = [
	{"asset":"osmanthus","id":"WestTree","at":Vector3(-6.05,.09,4.3),"yaw":15.0,"size":1.0,"wind":"osmanthus"},
	{"asset":"osmanthus","id":"RearTree","at":Vector3(3.8,.09,-6.25),"yaw":-27.0,"size":1.12,"wind":"osmanthus"},
	{"asset":"willow","id":"EastBankTree","at":Vector3(13.15,.09,-4.8),"yaw":-35.0,"size":.96,"wind":"osmanthus"},
	{"asset":"bamboo","id":"RearSmallTree","at":Vector3(-2.5,.10,-7.45),"yaw":80.0,"size":1.05,"wind":"bamboo"},
	{"asset":"willow","id":"RearWestCanopy","at":Vector3(-5.9,.09,-7.0),"yaw":-72.0,"size":.85,"wind":"osmanthus"},
	{"asset":"bamboo","id":"RearEastCanopy","at":Vector3(5.5,.10,-5.95),"yaw":57.0,"size":.95,"wind":"bamboo"},
]
var root_bay := Vector3(-6.65,-.43,5.4)
var east_path := PackedVector3Array([Vector3(10.52,.112,.23),Vector3(13.35,.112,-1.45)])
var east_stones := PackedVector3Array()
var haze_region := Vector4(0,-1,10.8,10)
var camera_point := Vector3(.25,.75,0)
var camera_distance: float = 28.6
var site: String = "original"

func _init() -> void:
	for i: int in 7:
		var t: float = i / 6.0
		east_stones.append(Vector3(11.05+t*4.1,-.40,.2+sin(t*PI)*.40))
	for index: int in FIELD_IDS.size():
		fields.append({"id": FIELD_IDS[index], "position": Vector3(-3.3 + index % 3 * 3.25,.2,int(index / 3) * 2.8), "yaw": 0.0, "size": Vector2(2.6,2.05)})
	for i: int in 4: fences.append({"position": Vector3(-4.8+i*2,.14,-7.2), "yaw": 0.0, "height": 1.0})
	for z: float in [-2.8,-.6,3.6]: fences.append({"position": Vector3(-6.65,.14,z), "yaw": 90.0, "height": 1.0})
	for z: float in [-4.1,-2]: fences.append({"position": Vector3(6.02,.14,z), "yaw": 75.0, "height": 1.0})
	for x: float in [-3,-.85,1.3]: fences.append({"position": Vector3(x,.14,5.15), "yaw": 0.0, "height": .68})

func field_transform(index: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(fields[index].yaw)), fields[index].position)

func plateau() -> PackedVector2Array:
	return BankGeometry.ring(BankGeometry.contour(rim), .96, bank_width)

func land_bounds() -> Rect2:
	var result := Rect2(rim[0],Vector2.ZERO)
	for p: Vector2 in rim: result = result.expand(p)
	return result

func expand_shore(west: float, south: float) -> void:
	# Called on a fresh plan when selecting a controlled layout. Buildings keep
	# their real size and anchor; perimeter decoration follows the changed shore.
	assert(site == "original" and west >= 0 and south >= 0)
	site = "expanded"
	var old_rim: PackedVector2Array = rim.duplicate()
	for i: int in rim.size():
		rim[i] += Vector2(-west * (1-smoothstep(-7,-2,rim[i].x)), south * smoothstep(1,6,rim[i].y))
	root_bay = _follow_shore(root_bay,old_rim)
	for points: Array in [shelves,reeds,lily_coves]:
		for i: int in points.size():
			if points[i].x < 8: points[i] = _follow_shore(points[i],old_rim)
	for tree: Dictionary in trees:
		if tree.at.x < 8: tree.at = _follow_shore(tree.at,old_rim)
	for points: Array in [bamboo_positions,flower_centres]:
		for i: int in points.size():
			var p: Vector3 = points[i]
			# Preserve flowers around the house and objects inside the working yard.
			if p.x < -5.5 or (p.x < 8 and (p.z > 5 or p.x > 5)): points[i] = _follow_shore(p,old_rim)
	anchors.mooring = _follow_shore(anchors.mooring,old_rim)
	anchors.boat = _follow_shore(anchors.boat,old_rim)
	var bounds: Rect2 = land_bounds()
	animal_areas.yard = bounds
	animal_areas.water = bounds.grow(5.5)
	for i: int in animal_rest.water.size():
		var p: Vector2 = animal_rest.water[i]
		var mapped: Vector3 = _follow_shore(Vector3(p.x,0,p.y),old_rim)
		animal_rest.water[i] = Vector2(mapped.x,mapped.z)
	haze_region = Vector4(-west*.5,-1+south*.5,10.8+west*.75,10+south*.75)
	camera_point += Vector3(-west*.3,0,south*.3)
	camera_distance += maxf(west,south)*1.7

func _follow_shore(point: Vector3, old_rim: PackedVector2Array) -> Vector3:
	var p := Vector2(point.x,point.z)
	var distance: float = INF
	var shift := Vector2.ZERO
	for i: int in old_rim.size():
		var j: int = (i+1)%old_rim.size()
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p,old_rim[i],old_rim[j])
		var d: float = p.distance_squared_to(closest)
		if d < distance:
			distance = d
			var t: float = old_rim[i].distance_to(closest)/old_rim[i].distance_to(old_rim[j])
			shift = rim[i].lerp(rim[j],t)-closest
	return point+Vector3(shift.x,0,shift.y)
