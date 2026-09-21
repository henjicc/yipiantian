extends RefCounted
## Runtime-editable verification geometry; reuses the courtyard's pigment material.
const Construction = preload("res://layout/island_construction.gd")
const Poles = preload("res://layout/fence_geometry.gd")
const PIGMENT = preload("res://scenes/environment/pigment.gdshader")
const Passage=preload("res://layout/bridge_passage.gd")
const ConstructionMesh=preload("res://layout/construction_mesh.gd")
static var _plank_arrays: Array=[]

static func _surface() -> ConstructionMesh:
	return ConstructionMesh.new()

static func _finish(parent: Node3D, surface: ConstructionMesh, tint: Color) -> void:
	var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit()
	mesh.set_meta("construction_vertices",surface.vertices)
	var material:=ShaderMaterial.new();material.shader=PIGMENT
	material.set_shader_parameter("base_color",tint)
	material.set_shader_parameter("wash_scale",3.5)
	mesh.material_override=material
	parent.add_child(mesh)

static func trellis(plan: RefCounted) -> Node3D:
	var root:=Node3D.new();root.name="EntranceTrellis"
	root.transform=Construction.trellis_pose(plan)
	var size: Vector3=Construction.trellis_size(plan)
	var bamboo: ConstructionMesh=_surface();var joints: ConstructionMesh=_surface()
	var bays: int=ceili(size.x/1.2)
	for i: int in bays+1:
		var z: float=-size.x*.5+size.x*i/bays
		for side: float in [-1.0,1.0]:
			var p:=Vector3(side*size.y*.5,0,z)
			Poles._pole(bamboo,p,p+Vector3.UP*size.z,.044)
			for height: float in [.35,.95,1.55,size.z-.06]:
				if height>size.z: continue
				Poles._pole(joints,p+Vector3.UP*height,p+Vector3.UP*(height+.025),.052)
		Poles._pole(bamboo,Vector3(-size.y*.5-.1,size.z,z),Vector3(size.y*.5+.1,size.z,z),.038)
		if i<bays:
			var next: float=z+size.x/bays
			for side: float in [-1.0,1.0]:
				for h: float in [.6,size.z-.15]: Poles._pole(bamboo,Vector3(side*size.y*.5,h,z),Vector3(side*size.y*.5,h,next),.022)
	for x: float in [-size.y*.5,0.0,size.y*.5]: Poles._pole(bamboo,Vector3(x,size.z,-size.x*.5),Vector3(x,size.z,size.x*.5),.032)
	root.set_meta("post_count",(bays+1)*2)
	root.set_meta("structure_size",size)
	_finish(root,bamboo,Color("93845b"));_finish(root,joints,Color("61533a"))
	return root

static func authored_bridge(plan: RefCounted) -> Node3D:
	var root: Node3D=load("res://art/environment/modules/stone_bridge.glb").instantiate()
	root.name="AuthoredBridge";root.position=plan.anchors.bridge;root.rotation.y=deg_to_rad(plan.angles.bridge)
	root.set_meta("bridge_water_shapes",Passage.water_shapes(plan))
	root.set_meta("bridge_seamed_deck",Passage.deck_strip(plan))
	return root

static func bridge(plan: RefCounted) -> Node3D:
	var root:=Node3D.new();root.name="AdaptiveBridge"
	var ends: Array[Vector3]=Construction.bridge_points(plan)
	var length: float=Vector2(ends[1].x-ends[0].x,ends[1].z-ends[0].z).length()
	var direction:=Vector3(ends[1].x-ends[0].x,0,ends[1].z-ends[0].z).normalized()
	var width: float=plan.construction.bridge[4]
	var style: int=Construction.bridge_style(plan)
	var side: Vector3=Vector3.UP.cross(direction)
	var deck: ConstructionMesh=_surface();var rails: ConstructionMesh=_surface()
	var pieces: int=ceili(length/.22)
	if _plank_arrays.is_empty():
		var shape:=BoxMesh.new();shape.size=Vector3.ONE
		_plank_arrays=shape.get_mesh_arrays()
	for i: int in pieces:
		var a: Vector3=Construction.bridge_profile(ends,style,float(i)/pieces)
		var b: Vector3=Construction.bridge_profile(ends,style,float(i+1)/pieces)
		var tangent: Vector3=(b-a).normalized()
		var up: Vector3=tangent.cross(side).normalized()
		var basis:=Basis(side,up,tangent)*Basis.from_scale(Vector3(width,.075,a.distance_to(b)+.001))
		# The upper face follows the profile, including both actual bank levels.
		# Adjacent segments meet; thickness extends below the walking surface.
		deck.append(_plank_arrays,Transform3D(basis,(a+b)*.5-up*.0375))
	var spans: int=ceili(length/.9)
	var rail_height: float=Construction.bridge_rail_height(plan)
	var supports:=PackedVector2Array()
	# Assemble masonry courses independently: rail thickness never scales with
	# span or deck width. New bays are added as the bridge becomes longer.
	for edge: float in [-1.0,1.0]:
		for i: int in spans+1:
			var bottom: Vector3=Construction.bridge_profile(ends,style,float(i)/spans)+side*(edge*width*.5)
			_block(rails,bottom+Vector3.UP*(rail_height*.5),Vector3(.10,rail_height,.10),Basis(side,Vector3.UP,direction))
			_block(rails,bottom+Vector3.UP*(rail_height+.025),Vector3(.13,.05,.13),Basis(side,Vector3.UP,direction))
		for i: int in spans:
			var a: Vector3=Construction.bridge_profile(ends,style,float(i)/spans)+side*(edge*width*.5)
			var b: Vector3=Construction.bridge_profile(ends,style,float(i+1)/spans)+side*(edge*width*.5)
			var tangent: Vector3=(b-a).normalized()
			var up: Vector3=tangent.cross(side).normalized()
			var rail_basis:=Basis(side,up,tangent)
			_block(rails,(a+b)*.5+Vector3.UP*(rail_height-.055),Vector3(.10,.11,a.distance_to(b)),rail_basis)
			_block(rails,(a+b)*.5+Vector3.UP*(rail_height*.48),Vector3(.065,rail_height*.62,maxf(.1,a.distance_to(b)-.13)),rail_basis)
	for bottom: Vector3 in Passage.supports(plan):
		_block(rails,Vector3(bottom.x,(bottom.y-.8)*.5,bottom.z),Vector3(.104,bottom.y+.8,.104),Basis.IDENTITY)
		supports.append(Vector2(bottom.x,bottom.z))
	root.set_meta("rail_height",rail_height)
	root.set_meta("rail_bays",spans)
	root.set_meta("bridge_ends",ends)
	root.set_meta("bridge_style",style)
	root.set_meta("bridge_supports",supports)
	root.set_meta("bridge_water_shapes",Passage.water_shapes(plan))
	root.set_meta("deck_sections",pieces)
	_finish(root,deck,Color("b8b9aa"));root.get_child(0).name="Deck"
	_finish(root,rails,Color("c4c5b8"))
	return root

static func trellis_support(plan: RefCounted) -> Node3D:
	var root:=Node3D.new();root.name="TrellisSupport";root.transform=Construction.trellis_pose(plan)
	var surface:=_surface()
	var hook: Vector3=root.transform.affine_inverse()*plan.slots.hanging_03
	if plan.construction.trellis.is_empty():
		var rise: Vector3=Vector3.UP*(plan.ground_height-.13)
		var a: Vector3=root.transform.affine_inverse()*(Vector3(-5.4,2.09,2.13)+rise)
		var b: Vector3=root.transform.affine_inverse()*(Vector3(-5.08,2.09,2.13)+rise)
		Poles._pole(surface,a,b,.025);Poles._pole(surface,b,hook,.012)
	else: Poles._pole(surface,hook+Vector3.UP*.3,hook,.012)
	_finish(root,surface,Color("89794c"))
	return root

static func _block(surface: ConstructionMesh, center: Vector3, size: Vector3, basis: Basis) -> void:
	surface.append(_plank_arrays,Transform3D(basis*Basis.from_scale(size),center))
