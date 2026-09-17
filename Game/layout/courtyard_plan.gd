extends RefCounted
## Shared spatial data. Scene builders consume this instance; farm state owns crops.
## The original metric composition is retained; banks are generated from these contours.
const FIELD_IDS: Array[String] = ["field_01", "field_02", "field_03", "field_04", "field_05", "field_06"]
const BankGeometry = preload("res://layout/bank_geometry.gd")
var ground_height: float = .13
var bank_width: float = 1.0
var east_rim := PackedVector2Array([Vector2(-2.9,-1.1),Vector2(-1.9,-3.5),Vector2(1.3,-3.8),Vector2(3.5,-2.1),Vector2(4.2,.7),Vector2(3.2,3.8),Vector2(.5,4.4),Vector2(-2.8,3.9),Vector2(-3.05,2.5)])
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

func _init() -> void:
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
