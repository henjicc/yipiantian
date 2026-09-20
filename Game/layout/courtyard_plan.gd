extends RefCounted
## Shared spatial data. Scene builders consume this instance; farm state owns crops.
## The original metric composition is retained; banks are generated from these contours.
const FIELD_IDS: Array[String] = ["field_01", "field_02", "field_03", "field_04", "field_05", "field_06"]
const FENCE_STYLES: Array[String] = ["bamboo", "crossed", "picket"]
const BankGeometry = preload("res://layout/bank_geometry.gd")
const Construction = preload("res://layout/island_construction.gd")
const IslandSpace = preload("res://layout/island_space.gd")
const Plants = preload("res://layout/plantings.gd")
const Routes=preload("res://layout/player_routes.gd")
var routes: Array=[]
var _route_source: Array=[]
var _route_footprints: Dictionary={}
var plants: Array=[]
var construction: Dictionary = Construction.initial()
var scenery_expansion := Vector2.ZERO
const DECORATION_SCENERY={"ground_01":"YardWaterVats","ground_02":"YardMelonPile","ground_03":"YardGroundTrays","ground_04":"YardBasketStack"}
var ground_height: float = .13
var bank_width: float = 1.0
var _east_ground_source: Array=[]
var _east_ground:=PackedVector2Array()
var east_rim := PackedVector2Array([Vector2(-2.9,-1.1),Vector2(-1.9,-3.5),Vector2(1.3,-3.8),Vector2(3.5,-2.1),Vector2(4.2,.7),Vector2(3.2,3.8),Vector2(.5,4.4),Vector2(-2.8,3.9),Vector2(-3.05,2.5)])
var shelves: Array[Vector3] = [Vector3(-7.1,-.48,2.7),Vector3(-6.2,-.48,4.7),Vector3(-4.0,-.48,6.0),Vector3(-1.1,-.50,6.5),Vector3(2.0,-.46,6.4),Vector3(5.7,-.45,5.55),Vector3(6.5,-.43,2.5)]
var bamboo_positions: Array[Vector3] = [Vector3(-7,.13,-5.2),Vector3(-7.1,.13,-.5),Vector3(5.4,.13,-5.7),Vector3(6.3,.13,2.0),Vector3(13.8,.10,-.8),Vector3(-6.6,.13,-6.6),Vector3(4.7,.13,-7.0),Vector3(5.9,.13,-3.5)]
var reeds: Array[Vector3] = [Vector3(-7.15,.05,2.7),Vector3(-6.55,.04,4.35),Vector3(-4.1,.06,5.85),Vector3(-2.15,.06,6.2),Vector3(.7,.06,6.25),Vector3(3.1,.07,5.85),Vector3(6.0,.06,4.3),Vector3(6.1,.08,3.5),Vector3(6.15,.08,-1.6),Vector3(11.0,.03,-.85),Vector3(14.2,.03,-.35)]
var flower_centres: Array[Vector3] = [Vector3(-5.8,.13,3.45),Vector3(5.25,.13,3.75),Vector3(-5.7,.13,-2.8),Vector3(5.3,.13,-3.0),Vector3(-3.8,.13,5.6),Vector3(2.4,.13,5.7),Vector3(-6.25,.11,4.9),Vector3(-1.8,.13,5.75),Vector3(.2,.13,5.95),Vector3(4.0,.12,5.6),Vector3(6.0,.13,1.0),Vector3(-6.85,.12,2.25),Vector3(11.35,.1,-.8),Vector3(13.6,.1,-1.5),Vector3(-3.4,.13,-2.05)]
var lily_coves: Array[Vector3] = [Vector3(-6.35,-.40,7.25),Vector3(-.9,-.40,8.05),Vector3(5.35,-.40,7.4),Vector3(14.0,-.40,3.4),Vector3(-9.8,-.40,3.6),Vector3(-11.2,-.40,-1.8),Vector3(-7.9,-.40,9.2),Vector3(1.6,-.40,10.8),Vector3(8.9,-.40,7.9)]
var fields: Array[Dictionary] = []
var rim := PackedVector2Array([Vector2(-7.5,-7.6),Vector2(-4.8,-8.4),Vector2(-1,-8.2),Vector2(2.5,-7.9),Vector2(5.6,-6.5),Vector2(6.5,-3.8),Vector2(6.4,-.8),Vector2(6.8,1.3),Vector2(5.8,4.8),Vector2(3.5,6.1),Vector2(.7,6.7),Vector2(-2.5,6.1),Vector2(-5.5,5.6),Vector2(-7.2,3.2),Vector2(-7.6,.2),Vector2(-7.1,-3.6)])
var paths: Array[PackedVector3Array] = [] # Derived by courtyard_circulation after real obstacles exist.
var garden_fences: Array[Dictionary]=[] # Original garden boundary, retained across brush undo.
var anchors := {
	"house": Construction.Buildings.BASE.house, "veranda": Vector3(.65,.13,-2.4),
	"kitchen": Construction.Buildings.BASE.kitchen, "trellis": Vector3(-5.8,.13,1.05),
	"bridge": Vector3(8.1,-.04,-.15), "east_bank": Vector3(12.65,-.02,-2.8),
	"boat": Vector3(9,-.5,4.3), "mooring": Vector3(6.32,-.3,3.85),
}
var angles := {"house": 0.0, "veranda": 0.0, "kitchen": 0.0, "trellis": 90.0, "bridge": -9.0, "east_bank": 0.0, "boat": -24.0}
var slots := {
	"hanging_01": Vector3(-2.5,2.27,-2.05), "hanging_02": Vector3(3.8,2.27,-2.05),
	"hanging_03": Vector3(-5.08,1.82,2.13), "hanging_04": Vector3(-4.85,1.98,-2.95),
}
var props := {
	"PorchHarvestTable": [Vector3(2.95,.41,-2.55),0.0],
	"SidePorchDryingRack": [Vector3(-3.7,.14,-2.72),-9.0],
	"PorchFarmTools": [Vector3(-2.5,.43,-2.9),12.0],
	"WindowWarmth": [Vector3.ZERO,0.0],
	"PathLanternWest": [Vector3(-5.15,.13,2.20),0.0],
	"PathLanternFront": [Vector3(-.8,.13,5.28),90.0],
	"PathLanternEast": [Vector3(5.12,.13,1.85),180.0],
	"YardWaterVats": [Vector3(-5.7,.14,-2.02),18.0],
	"YardFirewood": [Vector3(-4.5,.14,-6.8),90.0],
	"YardStoneMill": [Vector3(5.07,.14,-2.92),-95.0],
	"YardJarCluster": [Vector3(4.6,.14,-2.0),-30.0],
	"YardGroundTrays": [Vector3(-4.05,.14,4.85),40.0],
	"YardBasketStack": [Vector3(3.95,.14,4.55),-20.0],
	"YardBucket": [Vector3(-3.6,.14,-1.42),8.0],
	"YardDryingLine": [Vector3(1.45,.14,5.62),20.0],
	"YardMelonPile": [Vector3(0,.14,4.5),30.0],
	"YardSeedFrames": [Vector3(-2.62,.14,4.65),-25.0],
}
var fences: Array[Dictionary] = []
var fence_style: String = "bamboo"
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
var camera_distance: float = 25.5
var site: String = "original"
var shore_expansion := Vector2.ZERO

func _init() -> void:
	# Ground decoration replaces an authored living area, leaving paths intact.
	for slot: String in DECORATION_SCENERY:
		var point: Vector3=props[DECORATION_SCENERY[slot]][0]
		point.y=ground_height+.005
		slots[slot]=point
	animal_areas.yard = land_bounds()
	for i: int in 7:
		var t: float = i / 6.0
		east_stones.append(Vector3(11.05+t*4.1,-.40,.2+sin(t*PI)*.40))
	for index: int in FIELD_IDS.size():
		var cells: Array[String] = []
		for i: int in 16: cells.append("cell_%02d" % (i+1))
		fields.append({"id": FIELD_IDS[index], "position": Vector3(-3.3 + index % 3 * 3.25,.2,int(index / 3) * 2.8), "yaw": 0.0, "size": Vector2(2.6,2.05), "columns":4, "rows":4, "cells":cells, "seed":91744+index*7919})

func route_footprints() -> Dictionary:
	# This cache belongs to one plan, including private worker plans. No shared
	# mutable geometry is accessed concurrently by navigation and scene updates.
	if routes!=_route_source:
		_route_footprints=Routes.footprints(routes);_route_source=routes.duplicate(true)
	return _route_footprints

func field_transform(index: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(fields[index].yaw)), fields[index].position)

func set_terrain(height: float, width: float) -> void:
	assert(height>=.08 and height<=.38 and width>=.8 and width<=1.2)
	var rise: float=height-ground_height
	ground_height=height
	bank_width=width
	# Land anchors move as rigid objects. The opposite bank mesh receives height
	# directly, while the floating boat and the buried mooring base keep water level.
	for key: String in anchors:
		if key not in ["boat","mooring","east_bank"]: anchors[key].y+=rise
	for key: String in slots: slots[key].y+=rise
	for key: String in props: props[key][0].y+=rise
	for tree: Dictionary in trees: tree.at.y+=rise
	for points: Array in [bamboo_positions,reeds,flower_centres]:
		for i: int in points.size(): points[i].y+=rise
	for i: int in east_path.size(): east_path[i].y+=rise
	for field: Dictionary in fields: field.position.y+=rise
	camera_point.y+=rise
	paths.clear()
	fences.clear()

func field_polygon(index: int, margin: float = 0.0) -> PackedVector2Array:
	return IslandSpace.footprint(fields[index].size, field_transform(index), margin)

func unpainted() -> RefCounted:
	var base: RefCounted=load("res://layout/courtyard_plan.gd").new()
	if shore_expansion!=Vector2.ZERO: base.expand_shore(shore_expansion.x,shore_expansion.y)
	base.set_terrain(ground_height,bank_width)
	return base

func snapshot() -> Dictionary:
	var encoded: Array[Dictionary] = []
	for field: Dictionary in fields:
		encoded.append({"id":field.id,"position":[field.position.x,field.position.y,field.position.z],"yaw":field.yaw,
			"size":[field.size.x,field.size.y],"columns":field.columns,"rows":field.rows,"cells":field.cells.duplicate(),"seed":field.seed})
	return {"shore":[shore_expansion.x,shore_expansion.y],"terrain":[ground_height,bank_width],"fields":encoded,"fence_style":fence_style,"construction":construction.duplicate(true),"plants":plants.duplicate(true),"routes":routes.duplicate(true)}

static func from_snapshot(data: Dictionary) -> RefCounted:
	# This is the disk/edit admission boundary. Reject malformed layouts before any
	# geometry or crop state is rebuilt; JSON must never allocate unbounded meshes.
	if not Plants.valid(data.get("plants")): return null
	if not Routes.valid(data.get("routes")): return null
	if data.size()!=7 or not _numbers(data.get("shore"),2) or not data.get("fields") is Array: return null
	if not Construction.valid(data.get("construction")): return null
	if not _numbers(data.get("terrain"),2): return null
	if data.terrain[0]<.08 or data.terrain[0]>.38 or data.terrain[1]<.8 or data.terrain[1]>1.2: return null
	if not data.get("fence_style") in FENCE_STYLES: return null
	if data.shore[0]<0 or data.shore[0]>8 or data.shore[1]<0 or data.shore[1]>8: return null
	if data.fields.is_empty() or data.fields.size()>12: return null
	var decoded: Array[Dictionary] = []
	var identities: Dictionary = {}
	var total: int = 0
	for value: Variant in data.fields:
		if not value is Dictionary or value.size()!=8: return null
		var field: Dictionary = value
		if not _identity(field.get("id"),"field_") or identities.has(field.id): return null
		identities[field.id] = true
		if not _numbers(field.get("position"),3) or not _numbers(field.get("size"),2): return null
		if not _number(field.get("yaw")) or absf(field.yaw)>180: return null
		if not _integer(field.get("columns"),2,8) or not _integer(field.get("rows"),2,8): return null
		if not _integer(field.get("seed"),0,2147483647): return null
		if absf(field.position[0])>30 or absf(field.position[2])>30: return null
		var size := Vector2(field.size[0],field.size[1])
		var span: Vector2 = (size-Vector2(.20,.29))/Vector2(field.columns,field.rows)
		if span.x<.5999 or span.y<.4399 or span.x>1.2001 or span.y>1.0001: return null
		if not field.get("cells") is Array or field.cells.size()!=int(field.columns)*int(field.rows): return null
		var cells: Array[String] = []
		for cell: Variant in field.cells:
			if not _identity(cell,"cell_") or cells.has(cell): return null
			cells.append(cell)
		total += cells.size()
		if total>384: return null
		decoded.append({"id":field.id,"position":Vector3(field.position[0],field.position[1],field.position[2]),
			"yaw":float(field.yaw),"size":size,"columns":int(field.columns),"rows":int(field.rows),"cells":cells,"seed":int(field.seed)})
	var plan: RefCounted = load("res://layout/courtyard_plan.gd").new()
	if data.shore[0]>0 or data.shore[1]>0: plan.expand_shore(data.shore[0],data.shore[1])
	plan.set_terrain(data.terrain[0],data.terrain[1])
	plan.fields = decoded
	plan.fence_style=data.fence_style
	plan.plants=Plants.canonical(data.plants)
	plan.routes=Routes.canonical(data.routes)
	if not plan.apply_construction(data.construction): return null
	for field: Dictionary in plan.fields:
		if absf(field.position.y-plan.ground_height_at(Vector2(field.position.x,field.position.z))-.07)>.001: return null
	return plan

func apply_construction(value: Dictionary) -> bool:
	construction=value.duplicate(true)
	var regions: Array=[]
	for kind: String in Construction.Flocks.KINDS:
		construction.flocks[kind].count=int(construction.flocks[kind].count)
		regions.append(construction.flocks[kind].area)
	for values: Array in construction.land+construction.east_land+[construction.trellis,construction.bridge]+regions:
		for i: int in values.size(): values[i]=float(values[i])
	# Canonical decimal precision survives JSON without retaining float32 noise
	# from the scene's Vector3 anchors and dimension handles.
	for values: Array in [construction.trellis,construction.bridge]:
		for i: int in values.size(): values[i]=float("%.4f"%values[i])
	if not construction.trellis.is_empty(): construction.trellis[5]=wrapf(construction.trellis[5],-180,180)
	# Boolean edits start from the displayed original curve, so the first
	# brush stroke does not pull every untouched bank corner inward.
	var source: PackedVector2Array=rim if construction.land.is_empty() else BankGeometry.contour(rim)
	var combined: PackedVector2Array=Construction.land_outline(source,construction.land)
	if combined.is_empty(): return false
	rim=combined
	source=east_rim if construction.east_land.is_empty() else BankGeometry.contour(east_rim)
	combined=Construction.land_outline(source,construction.east_land,island_pose(1).affine_inverse())
	if combined.is_empty(): return false
	east_rim=combined
	Construction.Buildings.apply(self)
	var bounds: Rect2=land_bounds()
	scenery_expansion=Vector2(maxf(shore_expansion.x,-7.6-bounds.position.x),maxf(shore_expansion.y,bounds.end.y-6.7))
	animal_areas.yard=bounds
	animal_areas.water=buildable_bounds().grow(5.5)
	# Keep whole clumps clear of the changed waterline, using their original shore.
	for i: int in lily_coves.size():
		var p:=Vector2(lily_coves[i].x,lily_coves[i].z)
		var island: int=1 if p.x>11 else 0
		var affected: bool=false
		for patch: Array in land_patches(island):
			if Rect2(patch[0],patch[1],patch[2],patch[3]).grow(1.6).has_point(p): affected=true;break
		if not affected: continue
		p=Construction.clear_water(p,island_ring(island,1.055),1.5)
		lily_coves[i]=Vector3(p.x,lily_coves[i].y,p.y)
	for i: int in reeds.size():
		var p:=Vector2(reeds[i].x,reeds[i].z)
		var island: int=1 if p.x>9 else 0
		for patch: Array in land_patches(island):
			if Rect2(patch[0],patch[1],patch[2],patch[3]).has_point(p):
				p=Construction.nearest_edge(p,island_ring(island,.95))
				reeds[i]=Vector3(p.x,reeds[i].y,p.y)
				break
	if not construction.trellis.is_empty():
		anchors.trellis=Vector3(construction.trellis[3],ground_height_at(Vector2(construction.trellis[3],construction.trellis[4])),construction.trellis[4])
		angles.trellis=90.0+Construction.trellis_yaw(self)
		var size: Vector3=Construction.trellis_size(self)
		var pose: Transform3D=Construction.trellis_pose(self)
		slots.hanging_03=pose*Vector3(size.y*.5,size.z-.3,size.x*.5-.2)
		# This is generated scenery, not a player placement. Keep the flower clump
		# beside the enlarged bed, away from its poles and the front tree trunk.
		flower_centres[0]=Construction.trellis_flower_center(self)
	if not construction.land.is_empty():
		camera_distance+=maxf(0,bounds.size.length()-Vector2(14.4,15.1).length())*.7
		var center: Vector2=bounds.get_center()
		haze_region=Vector4(center.x,center.y,bounds.size.x*.5+3.5,bounds.size.y*.5+3.0)
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size()!=count: return false
	for item: Variant in value:
		if not _number(item): return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and value>=low and value<=high and float(value)==floorf(value)

static func _identity(value: Variant, prefix: String) -> bool:
	if not value is String or not value.begins_with(prefix): return false
	var suffix: String = value.trim_prefix(prefix)
	return suffix.length()>=2 and suffix.length()<=6 and suffix.is_valid_int() and int(suffix)>0 and value==prefix+"%02d"%int(suffix)

static func cell_span(field: Dictionary) -> Vector2:
	return (field.size-Vector2(.20,.29))/Vector2(field.columns,field.rows)

static func cell_position(field: Dictionary, cell_id: String) -> Vector3:
	var index: int = field.cells.find(cell_id)
	assert(index >= 0)
	var span: Vector2 = cell_span(field)
	var p: Vector2 = -(field.size-Vector2(.20,.29))*.5 + (Vector2(index % int(field.columns),int(index/int(field.columns)))+Vector2.ONE*.5)*span
	return Vector3(p.x,.08,p.y)

static func resized_field(field: Dictionary, columns: int, rows: int, size: Vector2) -> Dictionary:
	# Preserve identities at the same row/column. Removed cells are admitted or
	# rejected by planting state before this definition can become authoritative.
	assert(columns>0 and rows>0 and size.x>.20 and size.y>.29)
	var candidate: Dictionary = field.duplicate(true)
	var next_id: int = 1
	for id: String in field.cells: next_id = maxi(next_id,int(id.trim_prefix("cell_"))+1)
	var cells: Array[String] = []
	for row: int in rows:
		for column: int in columns:
			if row < int(field.rows) and column < int(field.columns):
				cells.append(field.cells[row*int(field.columns)+column])
			else:
				cells.append("cell_%02d" % next_id)
				next_id += 1
	candidate.columns = columns
	candidate.rows = rows
	candidate.size = size
	candidate.cells = cells
	return candidate

func land_patches(island: int) -> Array:
	return construction.east_land if island==1 else construction.land

func island_rim(island: int) -> PackedVector2Array:
	return east_rim if island==1 else rim

func island_pose(island: int) -> Transform2D:
	return Transform2D(-deg_to_rad(angles.east_bank),Vector2(anchors.east_bank.x,anchors.east_bank.z)) if island==1 else Transform2D.IDENTITY

func island_ring(island: int, scale: float) -> PackedVector2Array:
	var painted: bool=not land_patches(island).is_empty()
	return island_pose(island)*BankGeometry.ring(BankGeometry.contour(island_rim(island),painted),scale,bank_width,painted)

func plateau(island: int=0) -> PackedVector2Array:
	if island==1:
		var source: Array=[east_rim,angles.east_bank,anchors.east_bank,bank_width,not construction.east_land.is_empty()]
		if source!=_east_ground_source:
			_east_ground_source=source.duplicate(true);_east_ground=island_ring(1,.96)
		return _east_ground
	return island_ring(0,.96)

func supporting_island(polygon: PackedVector2Array) -> int:
	# An object must stand on one complete plateau, never on a union across water.
	if polygon.size()<3: return -1
	for island: int in 2:
		if IslandSpace.supported(polygon,plateau(island)): return island
	return -1

func ground_height_at(point: Vector2) -> float:
	return ground_height+anchors.east_bank.y if Geometry2D.is_point_in_polygon(point,plateau(1)) else ground_height

func ground_ray(origin: Vector3, direction: Vector3) -> Vector3:
	if direction.y>=-.001: return Vector3.INF
	var fallback: Vector3=Vector3.INF
	var nearest: Vector3=Vector3.INF
	var nearest_distance: float=INF
	for island: int in 2:
		var height: float=ground_height+(anchors.east_bank.y if island==1 else 0.0)
		var distance: float=(height-origin.y)/direction.y
		if distance<0 or distance>200: continue
		var point: Vector3=origin+direction*distance
		if island==0: fallback=point
		if distance<nearest_distance and Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),plateau(island)):
			nearest=point;nearest_distance=distance
	return nearest if nearest.is_finite() else fallback

func buildable_bounds() -> Rect2:
	var result: Rect2=land_bounds()
	for p: Vector2 in plateau(1): result=result.expand(p)
	return result

func water_banks() -> Array[PackedVector2Array]:
	return [island_ring(0,1.055),island_ring(1,1.055)]

func land_bounds() -> Rect2:
	var result := Rect2(rim[0],Vector2.ZERO)
	for p: Vector2 in rim: result = result.expand(p)
	return result

func expand_shore(west: float, south: float) -> void:
	# Called on a fresh plan when selecting a controlled layout. Buildings keep
	# their real size and anchor; perimeter decoration follows the changed shore.
	assert(site == "original" and west >= 0 and south >= 0)
	site = "expanded"
	shore_expansion = Vector2(west,south)
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
