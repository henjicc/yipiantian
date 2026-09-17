extends Node3D
## Low clustered grass joins roots, paths and soil. No gameplay or collision ownership.
const SHADER = preload("res://scenes/environment/meadow.gdshader")
var _rim := PackedVector2Array([Vector2(-7.5,-7.6),Vector2(-4.8,-8.4),Vector2(-1,-8.2),Vector2(2.5,-7.9),Vector2(5.6,-6.5),Vector2(6.5,-3.8),Vector2(6.4,-.8),Vector2(6.8,1.3),Vector2(5.8,4.8),Vector2(3.5,6.1),Vector2(.7,6.7),Vector2(-2.5,6.1),Vector2(-5.5,5.6),Vector2(-7.2,3.2),Vector2(-7.6,.2),Vector2(-7.1,-3.6)])
var _rng := RandomNumberGenerator.new()

func build(courtyard: Node3D) -> void:
	_rng.seed = 943172
	_build_trellis_bed()
	_build_foundation_contacts()
	var soil_gradient := Gradient.new()
	soil_gradient.colors = PackedColorArray([Color(.33,.28,.16,.52),Color(.40,.36,.20,0)])
	var root_soil := GradientTexture2D.new()
	root_soil.gradient = soil_gradient
	root_soil.width = 64; root_soil.height = 64
	root_soil.fill = GradientTexture2D.FILL_RADIAL
	root_soil.fill_from = Vector2(.5,.5); root_soil.fill_to = Vector2(.98,.5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for attempt: int in 16500:
		var p := Vector2(_rng.randf_range(-7.4,6.65), _rng.randf_range(-8.1,6.5))
		if not _allowed(p, courtyard): continue
		var patch: float = (sin(p.x*2.7+p.y*.6)+sin(p.y*3.2-p.x*.8))*.25+.5
		if _rng.randf() > lerpf(.12,.7,patch): continue
		_tuft(surface, Vector3(p.x,.128,p.y), _rng.randf_range(.045,.13), 4)
	# Dense short collars hide the generated meshes' abrupt root/ground seam.
	for child: Node in courtyard.get_children():
		if not child is Node3D or not (str(child.name).begins_with("Bamboo") or str(child.name).begins_with("Flowers") or str(child.name).ends_with("Tree")): continue
		var centre: Vector3 = child.position
		if centre.x > 8.0: continue
		var soil := Decal.new()
		soil.name = "RootSoil"
		soil.texture_albedo = root_soil
		soil.size = Vector3(1.1,.25,1.1)
		soil.position = Vector3(centre.x,.19,centre.z)
		soil.cull_mask = 2
		add_child(soil)
		for i: int in 55:
			var angle: float = _rng.randf()*TAU
			var radius: float = sqrt(_rng.randf())*.48
			var p: Vector3 = centre + Vector3(cos(angle)*radius,0,sin(angle)*radius)
			p.y = .131
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),_rim):
				_tuft(surface,p,_rng.randf_range(.06,.18),4)
	var grass := MeshInstance3D.new()
	grass.name = "RootedMeadow"
	grass.mesh = surface.commit()
	grass.material_override = ShaderMaterial.new()
	grass.material_override.shader = SHADER
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.extra_cull_margin = .04
	add_child(grass)

func _build_foundation_contacts() -> void:
	# Short, irregular weathered aprons around the two fixed building footprints.
	# Only the island receives these colour decals; occlusion is still real SSAO.
	var noise := FastNoiseLite.new()
	noise.seed = 74019
	noise.frequency = .065
	for footprint: Rect2 in [Rect2(-2.8,-2.975,6.9,1.15),Rect2(-5.6,-6.25,2.6,2.5)]:
		var extent: Vector2 = footprint.size + Vector2.ONE*.44
		var image := Image.create(256,128,false,Image.FORMAT_RGBA8)
		for y: int in 128:
			for x: int in 256:
				var p := (Vector2((x+.5)/256.0,(y+.5)/128.0)-Vector2.ONE*.5)*extent
				var q: Vector2 = p.abs()-footprint.size*.5
				var distance: float = q.max(Vector2.ZERO).length()+minf(maxf(q.x,q.y),0.0)
				var amount: float = 1.0-smoothstep(.0,.13+noise.get_noise_2d(x,y)*.05,distance)
				image.set_pixel(x,y,Color(.32,.29,.20,amount*.38))
		var decal := Decal.new()
		decal.name = "FoundationWeathering"
		decal.texture_albedo = ImageTexture.create_from_image(image)
		decal.size = Vector3(extent.x,.18,extent.y)
		decal.position = Vector3(footprint.get_center().x,.17,footprint.get_center().y)
		decal.cull_mask = 2
		add_child(decal)

func _build_trellis_bed() -> void:
	# Physical space for the requested future climbing crop area; no fake crop state.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in 48:
		for col: int in 12:
			for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var uv := Vector2((col+offset.x)/12.0,(row+offset.y)/48.0)
				var edge: float = minf(minf(uv.x,1-uv.x)*1.25,minf(uv.y,1-uv.y)*4.65)
				var dirt: float = smoothstep(0.0,.20,edge)
				var p := Vector3(-5.80+(uv.x-.5)*1.25,.134+dirt*.045,1.05+(uv.y-.5)*4.65)
				surface.set_color(Color(dirt,0,0))
				surface.set_uv(uv)
				surface.add_vertex(p)
	surface.generate_normals()
	var bed := MeshInstance3D.new()
	bed.name = "ClimbingBed"
	bed.mesh = surface.commit()
	var soil := ShaderMaterial.new()
	soil.shader = preload("res://scenes/environment/soil.gdshader")
	soil.set_shader_parameter("loam_albedo",preload("res://art/environment/soil/loam_baked_albedo.png"))
	soil.set_shader_parameter("loam_normal",preload("res://art/environment/soil/loam_baked_normal.png"))
	soil.set_shader_parameter("loam_surface",preload("res://art/environment/soil/loam_baked_surface.png"))
	soil.set_shader_parameter("bank",true)
	bed.material_override = soil
	add_child(bed)

func _allowed(p: Vector2, courtyard: Node3D) -> bool:
	if not Geometry2D.is_point_in_polygon(p,_rim): return false
	# Keep the house, porch, six interactive beds and stepping-stone centres clear.
	if p.y < -2.85 and p.x > -5.8 and p.x < 4.7: return false
	if p.y < -1.95 and p.y > -3.2 and p.x > -4.4 and p.x < 4.4: return false
	if p.x > -6.45 and p.x < -5.05 and p.y > -1.25 and p.y < 3.65: return false
	for row: int in 2:
		for col: int in 3:
			var d: Vector2 = (p-Vector2(-3.3+col*3.25,row*2.8)).abs()
			if d.x < 1.37 and d.y < 1.09: return false
	if (absf(p.x+1.68)<.22 or absf(p.x-1.57)<.22) and p.y > -1.3 and p.y < 4.2: return false
	if absf(p.y-4.65)<.24 and absf(p.x)<5.1: return false
	if absf(p.y+1.75)<.23 and p.x>-5.3 and p.x<5.5: return false
	for id: String in courtyard.SLOT_POSITIONS:
		if id.begins_with("ground"):
			var at: Vector3 = courtyard.SLOT_POSITIONS[id]
			if p.distance_to(Vector2(at.x,at.z))<.46: return false
	return true

func _tuft(surface: SurfaceTool, at: Vector3, height: float, count: int) -> void:
	var tint: float = _rng.randf_range(.82,1.15)
	for blade: int in count:
		var angle: float = _rng.randf()*TAU
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-direction.z,0,direction.x)
		var root_point: Vector3 = at + direction*_rng.randf_range(.0,.035)
		var h: float = height*_rng.randf_range(.65,1.2)
		var width: float = _rng.randf_range(.009,.018)
		for section: int in 3:
			var a: float = section/3.0
			var b: float = (section+1)/3.0
			var pa: Vector3 = root_point+Vector3.UP*h*a+direction*h*a*a*.45
			var pb: Vector3 = root_point+Vector3.UP*h*b+direction*h*b*b*.45
			var points: Array[Vector3] = [pa-side*width*(1-a),pa+side*width*(1-a),pb+side*width*(1-b),pa-side*width*(1-a),pb+side*width*(1-b),pb-side*width*(1-b)]
			for i: int in 6:
				surface.set_color(Color(tint,tint,tint))
				surface.set_normal((Vector3.UP*.8-direction*.2).normalized())
				surface.set_uv(Vector2(0,a if i in [0,1,3] else b))
				surface.add_vertex(points[i])
