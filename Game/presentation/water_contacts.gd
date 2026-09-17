extends RefCounted
## Static waterline sliced from the actual bank, stones and bridge. Baked once
## per courtyard; unlike screen depth it also describes vertical/offscreen banks.
const SIZE := 512
const EXTENT := 24.0
const REACH := 2.4

static func build(sources: Array[Node3D], height: float) -> ImageTexture:
	var distances := PackedFloat32Array()
	distances.resize(SIZE * SIZE)
	distances.fill(REACH * REACH)
	var faces: Dictionary = {}
	for source: Node3D in sources:
		_slice(source, height, faces, distances)
	return ImageTexture.create_from_image(Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RF, distances.to_byte_array()))

static func _slice(node: Node3D, height: float, cache: Dictionary, distances: PackedFloat32Array) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		if not cache.has(mesh): cache[mesh] = mesh.get_faces()
		var vertices: PackedVector3Array = cache[mesh]
		for index: int in range(0, vertices.size(), 3):
			var triangle: Array[Vector3] = [node.global_transform * vertices[index], node.global_transform * vertices[index + 1], node.global_transform * vertices[index + 2]]
			var crossings: Array[Vector2] = []
			for edge: int in 3:
				var a: Vector3 = triangle[edge]
				var b: Vector3 = triangle[(edge + 1) % 3]
				if (a.y <= height and b.y > height) or (b.y <= height and a.y > height):
					var point: Vector3 = a.lerp(b, (height - a.y) / (b.y - a.y))
					crossings.append(Vector2(point.x, point.z))
			if crossings.size() == 2: _raster_segment(crossings[0], crossings[1], distances)
	for child: Node in node.get_children():
		if child is Node3D: _slice(child, height, cache, distances)

static func _raster_segment(a: Vector2, b: Vector2, distances: PackedFloat32Array) -> void:
	var texel: float = EXTENT * 2.0 / SIZE
	var low: Vector2 = (a.min(b) - Vector2.ONE * REACH + Vector2.ONE * EXTENT) / texel
	var high: Vector2 = (a.max(b) + Vector2.ONE * REACH + Vector2.ONE * EXTENT) / texel
	var delta: Vector2 = b - a
	var length_squared: float = maxf(delta.length_squared(), 0.000001)
	for y: int in range(maxi(0, floori(low.y)), mini(SIZE, ceili(high.y))):
		for x: int in range(maxi(0, floori(low.x)), mini(SIZE, ceili(high.x))):
			var point := Vector2((x + 0.5) * texel - EXTENT, (y + 0.5) * texel - EXTENT)
			var nearest: Vector2 = a + delta * clampf((point - a).dot(delta) / length_squared, 0.0, 1.0)
			var offset: int = y * SIZE + x
			distances[offset] = minf(distances[offset], point.distance_squared_to(nearest))
