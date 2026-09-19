extends RefCounted
## Starting arrangements, never new farms: keep all existing field/cell identities.
const Plan=preload("res://layout/courtyard_plan.gd")
const IDS: Array[String]=["original","west","front"]
const NAMES: Array[String]=["原院","西畔菜圃","前庭宽院"]

static func arrange(current: RefCounted, id: String) -> RefCounted:
	assert(id in IDS)
	var result:=Plan.new()
	var positions: Array[Vector3]=[]
	for field: Dictionary in result.fields: positions.append(field.position)
	if id=="west":
		result.expand_shore(2.5,0)
		positions[0]=Vector3(-7.5,.2,0)
	elif id=="front":
		result.expand_shore(2.5,3)
		positions[0]=Vector3(-8,.2,1)
		positions[5]=Vector3(-3.3,.2,6.9)
	result.set_terrain(current.ground_height,current.bank_width)
	result.fields=current.fields.duplicate(true)
	result.fence_style=current.fence_style
	result.plants=current.plants.duplicate(true)
	for i: int in mini(positions.size(),result.fields.size()):
		result.fields[i].position=positions[i]
		result.fields[i].position.y=current.ground_height+.07
		result.fields[i].yaw=0.0
	if id=="west": result.fields[0].yaw=90.0
	elif id=="front": result.fields[0].yaw=10.0
	result.apply_construction(current.construction)
	# Extra or enlarged beds are intentionally retained, then spatially validated.
	# An arrangement is not permission to delete crops or secretly shrink their beds.
	return result
