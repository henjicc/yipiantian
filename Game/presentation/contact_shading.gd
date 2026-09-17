extends Node3D
## Projected contact darkening where props meet a surface.
##
## Screen-space AO cannot draw this case: Godot averages occlusion over
## `ssao_radius`, which is far wider than a three-centimetre post, so a thin
## upright produces almost no darkening on the surface it stands on and reads as
## pasted on. SSAO still carries wide contacts (vessels, trays, kerb stones);
## this pass only adds the pools SSAO structurally cannot see.
##
## Contacts are found from real vertex positions, so moving or replacing a module
## moves its pool with it. Decoration only: no collision, no farm state.

const RESOLUTION := 1024
const ORIGIN := Vector2(-8.0, -8.8)
const EXTENT := Vector2(15.2, 16.0)
const CELL := 0.20
const TINT := Color(0.13, 0.115, 0.095)

var _levels: Dictionary = {}
var _origin: Vector2 = ORIGIN
var _extent: Vector2 = EXTENT

func configure_bounds(bounds: Rect2) -> void:
	_origin = bounds.position
	_extent = bounds.size


## `planes` are world Y heights of the surfaces this node can rest on.
func collect(node: Node3D, planes: Array) -> void:
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		var placement: Transform3D = mesh_instance.global_transform
		for surface: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for plane: float in planes:
				_gather(vertices, placement, float(plane))


func _gather(vertices: PackedVector3Array, placement: Transform3D, plane: float) -> void:
	var cells: Dictionary = _levels.get(plane, {})
	var found: bool = false
	for vertex: Vector3 in vertices:
		var point: Vector3 = placement * vertex
		# A band, not a tolerance: posts are often bedded below the surface they
		# stand on, and a cylinder has no vertices at the height it passes through.
		if point.y > plane + 0.10 or point.y < plane - 0.16:
			continue
		found = true
		var key := Vector2i(floori(point.x / CELL), floori(point.z / CELL))
		var bucket: Array = cells.get(key, [Vector2.ZERO, 0.0, Vector2(INF, INF), Vector2(-INF, -INF)])
		bucket[0] += Vector2(point.x, point.z)
		bucket[1] += 1.0
		bucket[2] = bucket[2].min(Vector2(point.x, point.z))
		bucket[3] = bucket[3].max(Vector2(point.x, point.z))
		cells[key] = bucket
	if found:
		_levels[plane] = cells


func bake() -> void:
	for plane: float in _levels:
		var texture: ImageTexture = _paint(_levels[plane])
		if texture == null:
			continue
		var decal := Decal.new()
		decal.name = "ContactPool%d" % roundi(plane * 100.0)
		decal.texture_albedo = texture
		# A tight vertical box keeps each level's pools off the other level's
		# geometry: ground pools must not reappear along the veranda deck edge.
		decal.size = Vector3(_extent.x, 0.24, _extent.y)
		decal.position = Vector3(_origin.x + _extent.x * 0.5, plane + 0.045, _origin.y + _extent.y * 0.5)
		decal.cull_mask = 2
		decal.upper_fade = 0.2
		decal.lower_fade = 0.2
		decal.normal_fade = 0.0
		add_child(decal)


func _paint(cells: Dictionary) -> ImageTexture:
	if cells.is_empty():
		return null
	var data := PackedByteArray()
	data.resize(RESOLUTION * RESOLUTION * 4)
	var scale: Vector2 = Vector2(RESOLUTION, RESOLUTION) / _extent
	var red: int = roundi(TINT.r * 255.0)
	var green: int = roundi(TINT.g * 255.0)
	var blue: int = roundi(TINT.b * 255.0)
	var painted: bool = false
	for key: Vector2i in cells:
		var bucket: Array = cells[key]
		var centre: Vector2 = bucket[0] / bucket[1]
		var spread: float = (bucket[3] - bucket[2]).length()
		# Slim uprights get the tight, strong pool; broad feet are already carried
		# by SSAO, so they only receive a hint and never a painted-on dark patch.
		var radius: float = clampf(spread * 0.5 + 0.125, 0.14, 0.44)
		var strength: float = lerpf(0.66, 0.26, smoothstep(0.10, 0.75, spread))
		var pixel_radius: Vector2 = Vector2(radius, radius) * scale
		var middle: Vector2 = (centre - _origin) * scale
		var min_x: int = maxi(0, floori(middle.x - pixel_radius.x))
		var max_x: int = mini(RESOLUTION - 1, ceili(middle.x + pixel_radius.x))
		var min_y: int = maxi(0, floori(middle.y - pixel_radius.y))
		var max_y: int = mini(RESOLUTION - 1, ceili(middle.y + pixel_radius.y))
		for y: int in range(min_y, max_y + 1):
			for x: int in range(min_x, max_x + 1):
				var distance: float = ((Vector2(x + 0.5, y + 0.5) - middle)/scale).length() / radius
				if distance >= 1.0:
					continue
				var alpha: int = roundi(strength * pow(1.0 - distance, 2.0) * 255.0)
				var index: int = (y * RESOLUTION + x) * 4
				if alpha <= data[index + 3]:
					continue
				painted = true
				data[index] = red
				data[index + 1] = green
				data[index + 2] = blue
				data[index + 3] = alpha
	if not painted:
		return null
	return ImageTexture.create_from_image(Image.create_from_data(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8, data))
