extends Node3D
## Low clustered grass joins roots, paths and soil. No gameplay or collision ownership.
const SHADER = preload("res://scenes/environment/meadow.gdshader")
const Space = preload("res://scenes/environment/animal_space.gd")
const IslandSpace = preload("res://layout/island_space.gd")
const BUILDING_EXCLUSIONS={"MainHouse":0,"Kitchen":1,"PorchDeck":3,"SidePorchDryingRack":4,"YardFirewood":5}
const BRIDGE_EXCLUSION: int=6
var _rim: PackedVector2Array
var _exclusions: Array[PackedVector2Array] = []
var object_footprints: Array[PackedVector2Array] = []
var _rng := RandomNumberGenerator.new()

func build(courtyard: Node3D) -> void:
	_rim = courtyard.plan.unpainted().plateau()
	_rng.seed = 943172
	_build_trellis_bed(courtyard.plan)
	_build_foundation_contacts(courtyard.plan)
	for key: String in ["MainHouse","Kitchen","EntranceTrellis"]:
		_exclusions.append(Space.footprint(courtyard.get_node(key),courtyard.plan.ground_height-.13,courtyard.plan.ground_height+.57))
	# The veranda is a module, but it uses the same plan anchor as its apron.
	var porch := PackedVector2Array()
	var porch_pose := Transform3D(Basis(Vector3.UP,deg_to_rad(courtyard.plan.angles.veranda)),courtyard.plan.anchors.veranda)
	for p: Vector2 in [Vector2(-3.5,-.65),Vector2(3.5,-.65),Vector2(3.5,.75),Vector2(-3.5,.75)]:
		var world: Vector3 = porch_pose * Vector3(p.x,0,p.y)
		porch.append(Vector2(world.x,world.z))
	_exclusions.append(porch)
	for key: String in ["SidePorchDryingRack","YardFirewood"]:
		_exclusions.append(Space.footprint(courtyard.get_node("LivingDetails/"+key),courtyard.plan.ground_height-.13,courtyard.plan.ground_height+.57))
	_exclusions.append(Space.footprint(courtyard.get_bridge(),courtyard.plan.ground_height-.08,courtyard.plan.ground_height+.75))
	var soil_gradient := Gradient.new()
	soil_gradient.colors = PackedColorArray([Color(.33,.28,.16,.52),Color(.40,.36,.20,0)])
	var root_soil := GradientTexture2D.new()
	root_soil.gradient = soil_gradient
	root_soil.width = 64; root_soil.height = 64
	root_soil.fill = GradientTexture2D.FILL_RADIAL
	root_soil.fill_from = Vector2(.5,.5); root_soil.fill_to = Vector2(.98,.5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trellis_roots:=Node3D.new();trellis_roots.name="TrellisRoots";add_child(trellis_roots)
	var trellis_surface:=SurfaceTool.new();trellis_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trellis_ground: PackedVector2Array=courtyard.plan.plateau(courtyard.plan.supporting_island(preload("res://layout/island_construction.gd").trellis_footprint(courtyard.plan)))
	# Dense short collars hide the generated meshes' abrupt root/ground seam.
	for child: Node in courtyard.get_children():
		if not child is Node3D or not (str(child.name).begins_with("Bamboo") or str(child.name).begins_with("Flowers") or str(child.name).ends_with("Tree")): continue
		var centre: Vector3 = child.position
		var follows_trellis: bool=String(child.name).begins_with("Flowers0_")
		if centre.x > 8.0 and not follows_trellis: continue
		_rng.seed=hash(String(child.name))+943172
		var soil := Decal.new()
		soil.name = "RootSoil"
		soil.texture_albedo = root_soil
		soil.size = Vector3(1.1,.25,1.1)
		soil.position = Vector3(centre.x,courtyard.plan.ground_height_at(Vector2(centre.x,centre.z))+.06,centre.z)
		soil.cull_mask = 2
		if follows_trellis: trellis_roots.add_child(soil)
		else: add_child(soil)
		for i: int in 55:
			var angle: float = _rng.randf()*TAU
			var radius: float = sqrt(_rng.randf())*.48
			var p: Vector3 = centre + Vector3(cos(angle)*radius,0,sin(angle)*radius)
			p.y = courtyard.plan.anchors.trellis.y+.001 if follows_trellis else courtyard.plan.ground_height+.001
			if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),trellis_ground if follows_trellis else _rim):
				_tuft(trellis_surface if follows_trellis else surface,p,_rng.randf_range(.06,.18),4)
	var grass := MeshInstance3D.new()
	grass.name = "RootedMeadow"
	grass.mesh = surface.commit()
	grass.material_override = ShaderMaterial.new()
	grass.material_override.shader = SHADER
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.extra_cull_margin = .04
	add_child(grass)
	var rooted:=MeshInstance3D.new();rooted.mesh=trellis_surface.commit();rooted.material_override=grass.material_override
	rooted.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;rooted.extra_cull_margin=.04;trellis_roots.add_child(rooted)
	var core:=get_script().new() as Node3D
	core.name="CoreGrass";add_child(core)
	core._exclusions=_exclusions.duplicate()
	core.object_footprints.assign(preload("res://presentation/decoration_geometry.gd").footprints(courtyard.prepared_decorations,courtyard.plan.ground_height).values())
	core.update_tiles(courtyard.plan,false)
	var expansion:=get_script().new() as Node3D
	expansion.name="ExpansionGrass";courtyard.add_child(expansion)
	expansion._exclusions=_exclusions.duplicate()
	expansion.object_footprints=core.object_footprints.duplicate()
	expansion.update_expansion(courtyard.plan)

var _tiles: Dictionary={}
var _tile_shapes: Dictionary={}

func copy_tiles(source: Node3D) -> void:
	_tile_shapes=source._tile_shapes.duplicate(true)
	_exclusions=source._exclusions.duplicate()
	object_footprints=source.object_footprints.duplicate()
	for cell: Vector2i in source._tiles:
		var tile: Node3D=source._tiles[cell].duplicate()
		add_child(tile);_tiles[cell]=tile

func update_expansion(plan: RefCounted) -> void:
	update_tiles(plan,true)

func update_objects(plan: RefCounted, polygons: Array, expansion_only: bool) -> void:
	if object_footprints==polygons: return
	var changes: Array=[]
	for polygon: PackedVector2Array in object_footprints+polygons:
		if object_footprints.has(polygon) and polygons.has(polygon): continue
		changes.append(polygon)
	object_footprints.assign(polygons)
	var changed: Dictionary=grass_cells(changes)
	if not changed.is_empty(): update_tiles(plan,expansion_only,changed)

static func grass_cells(polygons: Array) -> Dictionary:
	# Grass caches use one metre cells, independently of the half metre placement grid.
	var result: Dictionary={}
	for polygon: PackedVector2Array in polygons:
		for cell: Vector2i in IslandSpace.covered_cells(polygon):
			result[Vector2i(floori(cell.x*IslandSpace.CELL),floori(cell.y*IslandSpace.CELL))]=true
	return result

func update_tiles(plan: RefCounted, expansion_only: bool, changed: Dictionary={}) -> void:
	if expansion_only and plan.construction.land.is_empty():
		for tile: Node3D in _tiles.values(): tile.free()
		_tiles.clear();_tile_shapes.clear();return
	var base: PackedVector2Array=plan.unpainted().plateau()
	var plateau: PackedVector2Array=plan.plateau()
	var bounds: Rect2=plan.land_bounds()
	var fields: Array[PackedVector2Array]=[]
	for index: int in plan.fields.size(): fields.append(plan.field_polygon(index,.07))
	fields.append_array(plan.route_footprints().values())
	fields.append_array(_exclusions)
	if not plan.construction.trellis.is_empty(): fields.append(preload("res://layout/island_construction.gd").trellis_footprint(plan))
	fields.append_array(object_footprints)
	for id: String in plan.slots:
		if not id.begins_with("ground"): continue
		var at: Vector3=plan.slots[id]
		fields.append(IslandSpace.rectangle(Vector2(at.x,at.z)-Vector2.ONE*.46,Vector2.ONE*.92))
	var wanted: Dictionary={}
	for z: int in range(floori(bounds.position.y),ceili(bounds.end.y)):
		for x: int in range(floori(bounds.position.x),ceili(bounds.end.x)):
			var cell:=Vector2i(x,z)
			if not changed.is_empty() and not changed.has(cell): continue
			var rect:=PackedVector2Array([Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)])
			var pieces: Array[PackedVector2Array]=Geometry2D.clip_polygons(rect,base) if expansion_only else Geometry2D.intersect_polygons(rect,base)
			if pieces.is_empty(): continue
			var shape: Array[PackedVector2Array]=[]
			for piece: PackedVector2Array in pieces: shape.append_array(Geometry2D.intersect_polygons(piece,plateau))
			if shape.is_empty(): continue
			var blocked: Array[PackedVector2Array]=[]
			for field: PackedVector2Array in fields:
				if IslandSpace.overlaps(rect,field): blocked.append(field)
			var routes: Array[PackedVector2Array]=[]
			var tile_bounds:=Rect2(Vector2(x,z),Vector2.ONE).grow(.23)
			for route: PackedVector3Array in plan.paths:
				for i: int in range(route.size()-1):
					var a:=Vector2(route[i].x,route[i].z);var b:=Vector2(route[i+1].x,route[i+1].z)
					if tile_bounds.intersects(Rect2(a,Vector2.ZERO).expand(b),true): routes.append(PackedVector2Array([a,b]))
			var signature: Array=[shape,blocked,routes,plan.ground_height]
			wanted[cell]=true
			if _tile_shapes.get(cell)==signature: continue
			if _tiles.has(cell): _tiles[cell].free();_tiles.erase(cell)
			_tile_shapes[cell]=signature
			var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var count: int=0
			for attempt: int in 80:
				# Independent tuft seeds keep untouched blades fixed when a field or
				# path clips a different part of this same tile.
				_rng.seed=hash(Vector3i(x,z,attempt))+943172
				var p:=Vector2(x+_rng.randf(),z+_rng.randf())
				var density: float=_rng.randf();var height: float=_rng.randf_range(.045,.13)
				var patch: float=(sin(p.x*2.7+p.y*.6)+sin(p.y*3.2-p.x*.8))*.25+.5
				if density>lerpf(.12,.7,patch): continue
				if not _clear_planting(p,blocked,routes): continue
				for polygon: PackedVector2Array in shape:
					if Geometry2D.is_point_in_polygon(p,polygon):
						_tuft(surface,Vector3(p.x,plan.ground_height-.002,p.y),height,4);count+=1;break
			if count==0: continue
			var grass:=MeshInstance3D.new();grass.mesh=surface.commit()
			grass.material_override=ShaderMaterial.new();grass.material_override.shader=SHADER
			grass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(grass);_tiles[cell]=grass
	for cell: Vector2i in _tile_shapes.keys():
		if not changed.is_empty() and not changed.has(cell): continue
		if not wanted.has(cell):
			if _tiles.has(cell): _tiles[cell].free();_tiles.erase(cell)
			_tile_shapes.erase(cell)

static func _clear_planting(point: Vector2, fields: Array[PackedVector2Array], routes: Array[PackedVector2Array]) -> bool:
	for field: PackedVector2Array in fields:
		if Geometry2D.is_point_in_polygon(point,field): return false
	for segment: PackedVector2Array in routes:
		if Geometry2D.get_closest_point_to_segment(point,segment[0],segment[1]).distance_to(point)<.23: return false
	return true

func _build_foundation_contacts(plan: RefCounted) -> void:
	# Aprons follow building anchors, with dimensions in each building's local space.
	# Only the island receives these colour decals; occlusion is still real SSAO.
	var noise := FastNoiseLite.new()
	noise.seed = 74019
	noise.frequency = .065
	for item: Dictionary in [{"anchor":"veranda","rect":Rect2(-3.45,-.575,6.9,1.15)},{"anchor":"kitchen","rect":Rect2(-1.1,-1.25,2.6,2.5)}]:
		var footprint: Rect2 = item.rect
		var pose := Transform3D(Basis(Vector3.UP,deg_to_rad(plan.angles[item.anchor])),plan.anchors[item.anchor])
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
		decal.name = "HouseFoundation" if item.anchor=="veranda" else "KitchenFoundation"
		decal.texture_albedo = ImageTexture.create_from_image(image)
		decal.size = Vector3(extent.x,.18,extent.y)
		decal.transform = pose
		var anchor: Vector3=plan.anchors[item.anchor]
		decal.position = pose * Vector3(footprint.get_center().x,plan.ground_height_at(Vector2(anchor.x,anchor.z))+.04-anchor.y,footprint.get_center().y)
		decal.cull_mask = 2
		add_child(decal)

func _build_trellis_bed(plan: RefCounted) -> void:
	# Physical space for the requested future climbing crop area; no fake crop state.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in 48:
		for col: int in 12:
			for offset: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var uv := Vector2((col+offset.x)/12.0,(row+offset.y)/48.0)
				var edge: float = minf(minf(uv.x,1-uv.x)*1.25,minf(uv.y,1-uv.y)*4.65)
				var dirt: float = smoothstep(0.0,.20,edge)
				var p := Vector3((uv.x-.5)*1.25,.004+dirt*.045,(uv.y-.5)*4.65)
				surface.set_color(Color(dirt,0,0))
				surface.set_uv(uv)
				surface.add_vertex(p)
	surface.generate_normals()
	var bed := MeshInstance3D.new()
	bed.name = "ClimbingBed"
	bed.mesh = surface.commit()
	var size: Vector3=preload("res://layout/island_construction.gd").trellis_size(plan)
	bed.scale=Vector3(size.y/1.25,1,size.x/4.65)
	bed.position = plan.anchors.trellis
	bed.rotation.y = deg_to_rad(plan.angles.trellis-90.0)
	var soil := ShaderMaterial.new()
	soil.shader = preload("res://scenes/environment/soil.gdshader")
	soil.set_shader_parameter("loam_albedo",preload("res://art/environment/soil/loam_baked_albedo.png"))
	soil.set_shader_parameter("loam_normal",preload("res://art/environment/soil/loam_baked_normal.png"))
	soil.set_shader_parameter("loam_surface",preload("res://art/environment/soil/loam_baked_surface.png"))
	soil.set_shader_parameter("bank",true)
	bed.material_override = soil
	add_child(bed)

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
