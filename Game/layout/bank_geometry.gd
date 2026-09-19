extends RefCounted
## Runtime counterpart of ArtSource/Environment/build_smooth_banks.py.
## Controlled simple contours; nine rounded slope rings, a level plateau and closed bottom.
const PROFILE := [Vector2(.87,.13),Vector2(.96,.13),Vector2(.985,.105),Vector2(1.01,.035),Vector2(1.035,-.09),Vector2(1.055,-.25),Vector2(1.075,-.48),Vector2(1.065,-.76),Vector2(1.015,-1.02)]

static func contour(points: PackedVector2Array, painted: bool=false) -> PackedVector2Array:
	if painted:
		# Corner cutting stays inside each local corner; Catmull-Rom can overshoot
		# short brush steps and cross itself at the neck of a concave peninsula.
		var smooth: PackedVector2Array=points.duplicate()
		for pass_index: int in 2:
			var next:=PackedVector2Array()
			for i: int in smooth.size():
				var a: Vector2=smooth[i];var b: Vector2=smooth[(i+1)%smooth.size()]
				var fraction: float=minf(.25,.18/maxf(.001,a.distance_to(b)))
				next.append(a.lerp(b,fraction));next.append(a.lerp(b,1-fraction))
			smooth=next
		if Geometry2D.is_polygon_clockwise(smooth): smooth.reverse()
		return smooth
	var result := PackedVector2Array()
	for i: int in points.size():
		var a: Vector2 = points[posmod(i - 1, points.size())]
		var b: Vector2 = points[i]
		var c: Vector2 = points[(i + 1) % points.size()]
		var d: Vector2 = points[(i + 2) % points.size()]
		for j: int in 16:
			var t: float = j / 16.0
			result.append(.5 * (2*b + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t))
	if Geometry2D.is_polygon_clockwise(result): result.reverse()
	return result

static func ring(outline: PackedVector2Array, scale_value: float, width: float, painted: bool=false) -> PackedVector2Array:
	var result := PackedVector2Array()
	if painted:
		# Local outward extrusion avoids shrinking an L-shaped brush stroke across
		# the original island. The two flat cap rings share the same boundary.
		var offset: float=maxf(0,scale_value-.96)*6.0*width
		for i: int in outline.size():
			var a: Vector2=(outline[i]-outline[posmod(i-1,outline.size())]).normalized()
			var b: Vector2=(outline[(i+1)%outline.size()]-outline[i]).normalized()
			var na:=Vector2(a.y,-a.x);var nb:=Vector2(b.y,-b.x)
			var normal: Vector2=(na+nb).normalized()
			result.append(outline[i]*.96+normal*offset/maxf(.6,normal.dot(na)))
		return result
	# Width grows the slope outside the usable plateau, not into planted land.
	var factor: float=scale_value if scale_value<=.96 else .96+(scale_value-.96)*width
	for p: Vector2 in outline: result.append(p*factor)
	return result

static func build(points: PackedVector2Array, height: float = .13, width: float = 1.0, painted: bool=false) -> ArrayMesh:
	var outline := contour(points,painted)
	var cap: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	if cap.is_empty():
		push_error("Bank contour cannot be triangulated")
		return null
	var n: int = outline.size()
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for r: int in PROFILE.size():
		var band: PackedVector2Array = ring(outline, PROFILE[r].x, width,painted)
		for i: int in n:
			var wave: float = (sin(i / float(n) * TAU * 7 + .4) + .45 * sin(i / float(n) * TAU * 13)) * .012
			# Caps remain planar; all surface height comes from the same definition.
			# Keep the submerged skirt and waterline fixed as land height changes.
			var y: float = PROFILE[r].y + (height-.13)*clampf((PROFILE[r].y+.25)/.38,0,1)
			if r > 1 and r < PROFILE.size() - 1: y += wave
			vertices.append(Vector3(band[i].x, y, band[i].y))
	# 2D CCW triangles in XZ are Godot clockwise faces viewed from above.
	indices.append_array(cap)
	for r: int in range(PROFILE.size() - 1):
		for i: int in n:
			var a: int = r * n + i
			var b: int = r * n + (i + 1) % n
			indices.append_array(PackedInt32Array([a,a+n,b,b,a+n,b+n]))
	var bottom: int = (PROFILE.size() - 1) * n
	for i: int in range(0, cap.size(), 3):
		indices.append_array(PackedInt32Array([bottom+cap[i],bottom+cap[i+2],bottom+cap[i+1]]))
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i: int in range(0, indices.size(), 3):
		var a: int = indices[i]
		var b: int = indices[i+1]
		var c: int = indices[i+2]
		var normal: Vector3 = (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for i: int in normals.size(): normals[i] = normals[i].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, StandardMaterial3D.new())
	return mesh
