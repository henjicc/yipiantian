extends RefCounted
## World-XZ navigation, built once from visible scene geometry. Rebuilt after layout edits.
const CELL := 0.16
class EdgeGrid extends AStarGrid2D:
	# A free pair of samples can still straddle a thin polygon tip. Grid solidity
	# alone cannot express that blocked edge; cache it during bake, not per frame.
	var blocked_edges: Dictionary = {}
	func _compute_cost(a: Vector2i,b: Vector2i) -> float:
		if blocked_edges.has(Vector4i(a.x,a.y,b.x,b.y)): return INF
		return Vector2(a).distance_to(Vector2(b))
	func _estimate_cost(a: Vector2i,b: Vector2i) -> float:
		return Vector2(a).distance_to(Vector2(b))

var grid := EdgeGrid.new()
var bounds: Rect2
var obstacles: Array[PackedVector2Array] = []
var _obstacle_cells: Dictionary = {}
var allowed := PackedVector2Array()
var points := PackedVector2Array()
var resting := PackedVector2Array()
var radius: float
var _floor_faces: Dictionary = {}
var floor_level: float = .13

func configure(area: Rect2, clearance: float, polygon: PackedVector2Array = PackedVector2Array()) -> void:
	bounds = area
	radius = clearance
	allowed = polygon
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceil(area.size.x / CELL), ceil(area.size.y / CELL)))
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = area.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()

func block(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3: return
	var expanded: Array[PackedVector2Array] = Geometry2D.offset_polygon(polygon, radius)
	for outline: PackedVector2Array in expanded:
		var index: int = obstacles.size()
		obstacles.append(outline)
		var box := Rect2(outline[0], Vector2.ZERO)
		for p: Vector2 in outline: box = box.expand(p)
		for y: int in range(floori(box.position.y), ceili(box.end.y) + 1):
			for x: int in range(floori(box.position.x), ceili(box.end.x) + 1):
				var cell := Vector2i(x, y)
				if not _obstacle_cells.has(cell): _obstacle_cells[cell] = []
				_obstacle_cells[cell].append(index)

func bake() -> void:
	points.clear()
	grid.blocked_edges.clear()
	for y: int in grid.region.size.y:
		for x: int in grid.region.size.x:
			var id := Vector2i(x, y)
			var p: Vector2 = grid.get_point_position(id)
			var solid: bool = not contains(p)
			grid.set_point_solid(id, solid)
			if not solid: points.append(p)
	for p: Vector2 in points:
		var a := Vector2i(((p-bounds.position)/CELL).round())
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1),Vector2i(1,-1)]:
			var b: Vector2i = a+direction
			if not grid.is_in_boundsv(b) or grid.is_point_solid(b): continue
			if not clear_segment(p,grid.get_point_position(b)):
				grid.blocked_edges[Vector4i(a.x,a.y,b.x,b.y)]=true
				grid.blocked_edges[Vector4i(b.x,b.y,a.x,a.y)]=true

func contains(p: Vector2) -> bool:
	if not bounds.grow(-radius).has_point(p): return false
	if not allowed.is_empty() and not Geometry2D.is_point_in_polygon(p, allowed): return false
	for index: int in _obstacle_cells.get(Vector2i(p.floor()), []):
		if Geometry2D.is_point_in_polygon(p, obstacles[index]): return false
	return true

func clear_segment(a: Vector2, b: Vector2) -> bool:
	var count: int = maxi(1, ceili(a.distance_to(b) / (CELL * .45)))
	for i: int in range(count + 1):
		if not contains(a.lerp(b, float(i) / count)): return false
	return true

func nearest(p: Vector2) -> Vector2:
	var id := Vector2i(((p - bounds.position) / CELL).round())
	if grid.is_in_boundsv(id) and not grid.is_point_solid(id): return grid.get_point_position(id)
	var best := p
	var distance: float = INF
	for candidate: Vector2 in points:
		var d: float = p.distance_squared_to(candidate)
		if d < distance:
			distance = d
			best = candidate
	return best

func path(start: Vector2, end: Vector2) -> PackedVector2Array:
	var a := Vector2i(((nearest(start) - bounds.position) / CELL).round())
	var b := Vector2i(((nearest(end) - bounds.position) / CELL).round())
	var raw: PackedVector2Array = grid.get_point_path(a, b)
	var result := PackedVector2Array()
	if raw.is_empty(): return result
	var current: Vector2 = start
	var index: int = 0
	while index < raw.size():
		var next: int = index
		while next + 1 < raw.size() and clear_segment(current, raw[next + 1]): next += 1
		if not clear_segment(current, raw[next]): return PackedVector2Array()
		result.append(raw[next])
		current = raw[next]
		index = next + 1
	return result

func ground_height(p: Vector2) -> float:
	var cell := Vector2i(((p-bounds.position)/CELL).floor())
	var height: float=floor_level
	for face: PackedVector3Array in _floor_faces.get(cell,[]):
		var a:=Vector2(face[0].x,face[0].z)
		var b:=Vector2(face[1].x,face[1].z)-a
		var c:=Vector2(face[2].x,face[2].z)-a
		var point: Vector2=p-a
		var determinant: float=b.cross(c)
		var u: float=point.cross(c)/determinant
		var v: float=b.cross(point)/determinant
		if u>=0 and v>=0 and u+v<=1:
			height=maxf(height,face[0].y+u*(face[1].y-face[0].y)+v*(face[2].y-face[0].y))
	return height

func add_floor(node: Node3D) -> void:
	# Index real low triangles per spatial cell; feet sample the triangle at their
	# exact XZ rather than snapping to a neighbouring grid point on a stone edge.
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree(): continue
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var a: Vector3 = mesh.global_transform * faces[i]
			var b: Vector3 = mesh.global_transform * faces[i + 1]
			var c: Vector3 = mesh.global_transform * faces[i + 2]
			if minf(a.y, minf(b.y, c.y)) < floor_level-.04 or maxf(a.y, maxf(b.y, c.y)) > floor_level+.11: continue
			var av := Vector2(a.x, a.z)
			var bv := Vector2(b.x, b.z)
			var cv := Vector2(c.x, c.z)
			var determinant: float = (bv - av).cross(cv - av)
			if absf(determinant) < .000001: continue
			var lo := Vector2i(((av.min(bv).min(cv) - bounds.position) / CELL).floor())
			var hi := Vector2i(((av.max(bv).max(cv) - bounds.position) / CELL).ceil())
			var triangle:=PackedVector3Array([a,b,c])
			for y: int in range(maxi(0, lo.y), mini(grid.region.size.y, hi.y + 1)):
				for x: int in range(maxi(0, lo.x), mini(grid.region.size.x, hi.x + 1)):
					var id := Vector2i(x, y)
					if not _floor_faces.has(id): _floor_faces[id]=[]
					_floor_faces[id].append(triangle)

static func footprint(node: Node3D, bottom: float, top: float, visible_only: bool = true) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D: meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		if (visible_only and not mesh.is_visible_in_tree()) or mesh.mesh == null: continue
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = mesh.global_transform * vertex
				if p.y >= bottom and p.y <= top: vertices.append(Vector2(p.x, p.z))
	return Geometry2D.convex_hull(vertices) if vertices.size() >= 3 else PackedVector2Array()
