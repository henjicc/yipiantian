extends RefCounted
## Stable root identities on the trellis; display geometry never owns crop state.
const Construction=preload("res://layout/island_construction.gd")
const FIELD_ID: String="trellis"
const SPACING: float=.8

static func slots(plan: RefCounted) -> Dictionary:
	var size: Vector3=Construction.trellis_size(plan)
	var extent: int=floori((size.x*.5-.35)/SPACING)
	var result: Dictionary={}
	var sides: Array[int]=[-1]
	if size.y>=1.2: sides.append(1)
	for side: int in sides:
		for column: int in range(-extent,extent+1):
			var id: String=("left" if side<0 else "right")+"_%d"%column
			var point:=Vector3(side*(size.y*.5-.1),0,column*SPACING)
			point.y=soil_height(point,size)+.002
			result[id]=point
	return result

static func soil_height(point: Vector3,size: Vector3) -> float:
	# Same normalized profile as GroundCover's resizable climbing bed.
	var edge: float=minf((size.y*.5-absf(point.x))*1.25/size.y,(size.x*.5-absf(point.z))*4.65/size.x)
	return .004+smoothstep(0.0,.20,edge)*.045

static func definition(plan: RefCounted) -> Dictionary:
	return {"id":FIELD_ID,"cells":slots(plan).keys()}
