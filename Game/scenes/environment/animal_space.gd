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
var _pending_floors: Array[Dictionary] = []
var floor_level: float = .13
var floor_origin:=Vector2.ZERO
var floor_seams: Array[PackedVector2Array]=[]
var component_cells: Dictionary = {}

func configure(area: Rect2, clearance: float, polygon: PackedVector2Array = PackedVector2Array()) -> void:
	bounds = area
	floor_origin=area.position
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
	# The owning navigation worker receives only captured values, never nodes.
	for entry: Dictionary in _pending_floors: _index_floor(entry.faces,entry.pose,entry.height_range)
	_pending_floors.clear()
	component_cells.clear()
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

func keep_largest_component() -> void:
	# Four-way flood is conservative at narrow corners and honors thin barriers.
	var unseen: Dictionary={}
	for p: Vector2 in points: unseen[Vector2i(((p-bounds.position)/CELL).round())]=true
	var largest: Dictionary={}
	while not unseen.is_empty():
		var first: Vector2i=unseen.keys()[0]
		var queue: Array[Vector2i]=[first];var component: Dictionary={first:true};unseen.erase(first)
		var index: int=0
		while index<queue.size():
			var a: Vector2i=queue[index];index+=1
			for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var b: Vector2i=a+direction
				if not unseen.has(b) or grid.blocked_edges.has(Vector4i(a.x,a.y,b.x,b.y)): continue
				unseen.erase(b);component[b]=true;queue.append(b)
		if component.size()>largest.size(): largest=component
	component_cells=largest
	var retained:=PackedVector2Array()
	for p: Vector2 in points:
		var id:=Vector2i(((p-bounds.position)/CELL).round())
		if largest.has(id): retained.append(p)
		else: grid.set_point_solid(id,true)
	points=retained

func contains(p: Vector2) -> bool:
	if not component_cells.is_empty() and not component_cells.has(Vector2i(((p-bounds.position)/CELL).round())): return false
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
	# Apply the same clearance/region test used for every smoothed route segment.
	# Open water does not need a grid search followed by dozens of shorter rays.
	if grid.is_in_boundsv(b) and not grid.is_point_solid(b):
		var target: Vector2=grid.get_point_position(b)
		if clear_segment(start,target): return PackedVector2Array([target])
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
	var height: float=_triangle_height(p)
	if not is_finite(height):
		for polygon: PackedVector2Array in floor_seams:
			if not Geometry2D.is_point_in_polygon(p,polygon): continue
			# Bridge masonry has 14 mm joints. A foot spans those tiny gaps;
			# sampling a neighbouring real face prevents a drop to water level.
			for offset: Vector2 in [Vector2(.025,0),Vector2(-.025,0),Vector2(0,.025),Vector2(0,-.025)]:
				height=maxf(height,_triangle_height(p+offset))
	return height if is_finite(height) else floor_level

func _triangle_height(p: Vector2) -> float:
	var cell := Vector2i(((p-floor_origin)/CELL).floor())
	var height: float=-INF
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

func add_floor(node: Node3D, visible_only: bool=true, height_range: Vector2=Vector2.INF, defer_index: bool=false) -> void:
	# Index real low triangles per spatial cell; feet sample the triangle at their
	# exact XZ rather than snapping to a neighbouring grid point on a stone edge.
	if height_range==Vector2.INF: height_range=Vector2(floor_level-.04,floor_level+.11)
	var meshes: Array[Node]=node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D: meshes.append(node)
	var faces_by_mesh: Dictionary={}
	for mesh: MeshInstance3D in meshes:
		if visible_only and not mesh.is_visible_in_tree(): continue
		if not faces_by_mesh.has(mesh.mesh): faces_by_mesh[mesh.mesh]=mesh.mesh.get_faces()
		var faces: PackedVector3Array=faces_by_mesh[mesh.mesh]
		if defer_index: _pending_floors.append({"faces":faces,"pose":mesh.global_transform,"height_range":height_range})
		else: _index_floor(faces,mesh.global_transform,height_range)

func _index_floor(faces: PackedVector3Array, pose: Transform3D, height_range: Vector2) -> void:
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = pose * faces[i]
		var b: Vector3 = pose * faces[i + 1]
		var c: Vector3 = pose * faces[i + 2]
		if minf(a.y, minf(b.y, c.y)) < height_range.x or maxf(a.y, maxf(b.y, c.y)) > height_range.y: continue
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
		var captured: Dictionary=mesh.get_meta("rigid_footprint",{})
		var surfaces: Array[PackedVector3Array]=[]
		if captured.get("mesh")==mesh.mesh: surfaces.append(captured.vertices)
		else: surfaces=mesh_vertices(mesh)
		for points: PackedVector3Array in surfaces:
			# Native packed-array transformation keeps the same current mesh pose
			# without one script-to-node transform lookup for every hull vertex.
			var world: PackedVector3Array=mesh.global_transform*points
			for p: Vector3 in world:
				if p.y >= bottom and p.y <= top: vertices.append(Vector2(p.x, p.z))
	return Geometry2D.convex_hull(vertices) if vertices.size() >= 3 else PackedVector2Array()

static func capture_rigid_footprint(node: Node3D) -> void:
	# Opt in only for meshes whose local vertices remain fixed, such as the
	# rocking boat. Keep exact unique positions, not an approximate hull/LOD.
	# The owner must recapture after editing vertices in place; replacing the
	# mesh falls back to live sampling. Pose and height filtering stay live.
	var meshes: Array[Node]=node.find_children("*","MeshInstance3D",true,false)
	if node is MeshInstance3D: meshes.append(node)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh==null: continue
		var seen: Dictionary={};var unique:=PackedVector3Array()
		for points: PackedVector3Array in mesh_vertices(mesh):
			for point: Vector3 in points:
				if not seen.has(point): seen[point]=true;unique.append(point)
		mesh.set_meta("rigid_footprint",{"mesh":mesh.mesh,"vertices":unique})
	if node.has_meta("navigation_footprints"): node.remove_meta("navigation_footprints")

static func mesh_vertices(instance: MeshInstance3D) -> Array[PackedVector3Array]:
	# Construction keeps its original CPU vertices so pointer edits do not read
	# the mesh back from the rendering device for each footprint/contact pass.
	if instance.has_meta("construction_vertices"): return [instance.get_meta("construction_vertices")]
	var result: Array[PackedVector3Array]=[]
	for surface: int in instance.mesh.get_surface_count():
		var arrays: Array=instance.mesh.surface_get_arrays(surface)
		if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX]!=null: result.append(arrays[Mesh.ARRAY_VERTEX])
	return result

static func cached_footprint(node: Node3D, bottom: float, top: float) -> PackedVector2Array:
	# Courtyard geometry is static between structural edits. Brush edits invalidate
	# MainBank explicitly; moved reeds/islets invalidate by their world transform.
	var cache: Dictionary=node.get_meta("navigation_footprints",{})
	var band:=Vector2(bottom,top)
	# Small visual wave drift is covered by clearance; only the lily's anchor
	# invalidates navigation, not its animated pitch and roll every frame.
	var pose: Variant=node.get_meta("navigation_anchor",node.global_transform)
	if not cache.has(band) or cache[band].pose!=pose:
		cache[band]={"pose":pose,"polygon":footprint(node,bottom,top,false)}
		node.set_meta("navigation_footprints",cache)
	return cache[band].polygon

static func capture(source: RefCounted) -> Dictionary:
	return {"radius":source.radius,"obstacles":source.obstacles.duplicate(),"cells":source._obstacle_cells.duplicate(true),
		"allowed":source.allowed.duplicate(),"floor":source._floor_faces.duplicate(true),"origin":source.floor_origin,"level":source.floor_level,"seams":source.floor_seams.duplicate()}

static func build_region(area: Array, captured: Dictionary) -> RefCounted:
	var result:=new()
	var rect:=Rect2(area[0],area[1],area[2],area[3])
	result.configure(rect,captured.radius,captured.allowed)
	result.obstacles.assign(captured.obstacles);result._obstacle_cells=captured.cells
	result._floor_faces=captured.floor;result.floor_origin=captured.origin;result.floor_level=captured.level;result.floor_seams.assign(captured.seams)
	result.bake();result.keep_largest_component()
	for p: Vector2 in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]: result.resting.append(result.nearest(p))
	return result
