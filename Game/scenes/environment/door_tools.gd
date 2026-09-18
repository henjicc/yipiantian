extends Node3D
## Doorway props only. Menu design remains a concept until selected.
const HOE = preload("res://art/characters/farmer/hoe.glb")
const CHAIR = preload("res://art/characters/farmer/chair.glb")
var hoe: Node3D
var chair: Node3D

func _ready() -> void:
	var environment: Node3D = get_parent()
	var pose := Transform3D(Basis(Vector3.UP,deg_to_rad(environment.plan.angles.veranda)),environment.plan.anchors.veranda)
	hoe = HOE.instantiate()
	hoe.name = "DoorHoe"
	add_child(hoe)
	hoe.position = pose * Vector3(.82,.30,.18)
	hoe.rotation.y = deg_to_rad(environment.plan.angles.veranda) + PI*.5
	chair = CHAIR.instantiate()
	chair.name = "RestChair"
	add_child(chair)
	chair.position = pose * Vector3(-.90,.30,.10)
	chair.rotation.y = deg_to_rad(environment.plan.angles.veranda) - PI*.5
