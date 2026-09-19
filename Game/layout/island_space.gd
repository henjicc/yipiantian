extends RefCounted
## Metric XZ geometry shared by construction, fields and decorations.
## Grid cells accelerate overlap queries; they never resize or quantize a model.
const CELL: float = .5
var _polygons: Dictionary = {}
var _cells: Dictionary = {}

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i((point / CELL).floor())

static func snap(point: Vector2) -> Vector2:
	return point.snapped(Vector2.ONE * CELL)

static func rectangle(origin: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([origin, origin + Vector2(size.x, 0), origin + size, origin + Vector2(0, size.y)])

static func footprint(size: Vector2, pose: Transform3D, margin: float = 0) -> PackedVector2Array:
	var half: Vector2 = size * .5 + Vector2.ONE * margin
	var result := PackedVector2Array()
	for point: Vector2 in rectangle(-half, half * 2):
		var world: Vector3 = pose * Vector3(point.x, 0, point.y)
		result.append(Vector2(world.x, world.z))
	return result

static func supported(polygon: PackedVector2Array, ground: PackedVector2Array) -> bool:
	# Testing corners alone admits rectangles spanning concave bays or holes.
	return polygon.size() >= 3 and ground.size() >= 3 and Geometry2D.clip_polygons(polygon, ground).is_empty()

static func overlaps(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return a.size() >= 3 and b.size() >= 3 and not Geometry2D.intersect_polygons(a, b).is_empty()

static func water_clear(polygon: PackedVector2Array, banks: Array[PackedVector2Array]) -> bool:
	if polygon.size() < 3: return false
	for bank: PackedVector2Array in banks:
		if overlaps(polygon, bank): return false
	return true

static func _bounding_cells(polygon: PackedVector2Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if polygon.size() < 3: return result
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon: bounds = bounds.expand(point)
	var first: Vector2i = cell_at(bounds.position)
	var end: Vector2i = cell_at(bounds.end)
	for y: int in range(first.y, end.y + 1):
		for x: int in range(first.x, end.x + 1):
			result.append(Vector2i(x,y))
	return result

static func covered_cells(polygon: PackedVector2Array) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	for cell: Vector2i in _bounding_cells(polygon):
		if overlaps(polygon,rectangle(Vector2(cell)*CELL,Vector2.ONE*CELL)): result.append(cell)
	return result

func add(id: String, polygon: PackedVector2Array) -> void:
	remove(id)
	if polygon.size() < 3: return
	_polygons[id] = polygon
	# The index only finds candidates. Bounding cells avoid clipping every
	# footprint against every cell; collisions still tests the exact polygons.
	for cell: Vector2i in _bounding_cells(polygon):
		if not _cells.has(cell): _cells[cell] = []
		_cells[cell].append(id)

func remove(id: String) -> void:
	if not _polygons.has(id): return
	for cell: Vector2i in _bounding_cells(_polygons[id]):
		_cells[cell].erase(id)
		if _cells[cell].is_empty(): _cells.erase(cell)
	_polygons.erase(id)

func collisions(polygon: PackedVector2Array, excluded: Array[String] = []) -> Array[String]:
	var nearby: Dictionary = {}
	for cell: Vector2i in _bounding_cells(polygon):
		for id: String in _cells.get(cell, []): nearby[id] = true
	var result: Array[String] = []
	for id: String in nearby:
		# Two freely positioned objects can share a cell without touching.
		if id not in excluded and overlaps(polygon, _polygons[id]): result.append(id)
	result.sort()
	return result
