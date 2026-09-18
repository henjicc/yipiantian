extends Node3D
## Presentation follows the saved mood and existing layout/supports.
const Assets = preload("res://scenes/environment/courtyard_assets.gd")
var season: String = "daily"
var _wet: Node3D
var _rain_covers: Array[Node3D] = []
var _autumn: Node3D
var _ordinary_bundles: Array[Node3D] = []
var _ground_materials: Array[ShaderMaterial] = []

func configure(courtyard: Node3D) -> void:
	var living: Node3D = courtyard.get_node("LivingDetails")
	var line: Node3D = living.get_node("YardDryingLine")
	for child: Node in line.get_children():
		if child.has_meta("drying_bundle"): _ordinary_bundles.append(child)
	_autumn = Node3D.new(); _autumn.name="AutumnHarvest"
	line.add_child(_autumn)
	for i: int in 6:
		var x: float = -.60+i*.24
		var scale_value: float = .70 + (i%2)*.05
		Assets.place(_autumn,"radish_bundle",Vector3(x,.69-.43*scale_value,0),i*47,scale_value)
		living._beam(_autumn,Vector3(x,.69,0),Vector3(x,.72,0),.007,living._rope)
	living._merge_static_group(_autumn)
	# A small woven rain shelter uses the existing A-frame supports and footprint.
	var canopy := Node3D.new(); canopy.name="RainCover"; line.add_child(canopy)
	var woven:=ShaderMaterial.new();woven.shader=preload("res://presentation/woven_cover.gdshader")
	for x: float in [-.74,.74]:
		living._beam(canopy,Vector3(x,.69,0),Vector3(x,.95,0),.025,living._bamboo)
		for side: float in [-1,1]:
			living._beam(canopy,Vector3(x,.95,0),Vector3(x,.76,side*.34),.024,living._bamboo)
	for side: float in [-1,1]:
		var panel:=BoxMesh.new();panel.size=Vector3(1.80,.009,Vector2(.36,.19).length())
		var mat: MeshInstance3D=living._mesh(canopy,panel,Vector3(0,.855,side*.18),woven)
		mat.rotation.x=side*atan2(.19,.36)
		living._beam(canopy,Vector3(-.9,.76,side*.36),Vector3(.9,.76,side*.36),.014,living._bamboo)
	living._beam(canopy,Vector3(-.9,.965,0),Vector3(.9,.965,0),.025,living._bamboo)
	living._merge_static_group(canopy)
	_rain_covers.append(canopy)
	var trays: Node3D = living.get_node("YardGroundTrays")
	var covers := Node3D.new(); covers.name="RainLids"; trays.add_child(covers)
	for entry: Array in [[Vector3.ZERO,.30],[Vector3(.58,.004,.26),.26],[Vector3(.24,.008,-.44),.23]]:
		var at: Vector3 = entry[0]
		var radius: float = entry[1]+.015
		var profile: Array[Vector2]=[Vector2(radius,0),Vector2(radius*.96,.08),Vector2(radius*.7,.16),Vector2(.01,.21)]
		living._lathe(covers,at+Vector3.UP*.075,profile,woven,48)
		living._ring(covers,at+Vector3.UP*.08,radius,.012,living._bamboo)
		living._ring(covers,at+Vector3.UP*.287,.03,.009,living._rope)
	living._merge_static_group(covers)
	_rain_covers.append(covers)
	for child: Node in courtyard.get_children():
		if child.has_meta("path_stone"):
			if child is MeshInstance3D: child.set_layer_mask_value(2,true)
			for mesh: MeshInstance3D in child.find_children("*","MeshInstance3D",true,false): mesh.set_layer_mask_value(2,true)
	_build_wet_ground(courtyard.plan)
	for mesh: MeshInstance3D in courtyard.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null: continue
		for surface_index: int in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(surface_index)
			if not material is ShaderMaterial or material.shader!=living.PIGMENT: continue
			if material.get_shader_parameter("ground_treatment")==1.0 or material.get_shader_parameter("stone_treatment")==1.0:
				if not _ground_materials.has(material): _ground_materials.append(material)
	set_season(season)

func set_season(id: String) -> void:
	season=id
	if _wet==null: return
	_wet.visible=id=="after_rain"
	for cover: Node3D in _rain_covers: cover.visible=id=="after_rain"
	_autumn.visible=id=="drying"
	for bundle: Node3D in _ordinary_bundles: bundle.visible=id!="drying"
	for material: ShaderMaterial in _ground_materials: material.set_shader_parameter("rain_dampness",1.0 if id=="after_rain" else 0.0)

func _build_wet_ground(plan: RefCounted) -> void:
	_wet=Node3D.new(); _wet.name="DampGround"; add_child(_wet)
	var noise:=FastNoiseLite.new();noise.seed=91823;noise.frequency=.053
	var albedo:=Image.create(128,128,false,Image.FORMAT_RGBA8)
	var orm:=Image.create(128,128,false,Image.FORMAT_RGB8)
	for y: int in 128:
		for x: int in 128:
			var p:=Vector2(x-63.5,y-63.5)/63.5
			var radius: float=p.length()+noise.get_noise_2d(x,y)*.19
			var mask: float=(1.0-smoothstep(.63,.94,radius))*.63
			albedo.set_pixel(x,y,Color(.25,.31,.23,mask))
			orm.set_pixel(x,y,Color(1,.16,0))
	var color:=ImageTexture.create_from_image(albedo)
	var surface:=ImageTexture.create_from_image(orm)
	var count: int=0
	for route: PackedVector3Array in plan.paths:
		if route.size()<2: continue
		var at: Vector3=route[int(route.size()/2)]
		var decal:=Decal.new();decal.name="WetPatch%d"%count
		decal.texture_albedo=color;decal.texture_orm=surface
		decal.cull_mask=2 # Only terrain receivers, never animals, crops or the lake.
		decal.normal_fade=.8
		decal.size=Vector3(1.10+(count%3)*.20,.45,.65+(count%2)*.20)
		decal.position=Vector3(at.x,plan.ground_height+.12,at.z)
		decal.rotation.y=count*2.399
		decal.upper_fade=.05;decal.lower_fade=.25
		_wet.add_child(decal)
		count+=1
		if count>=8: break
