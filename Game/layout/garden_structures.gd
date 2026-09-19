extends RefCounted
## Runtime-editable verification geometry; reuses the courtyard's pigment material.
const Construction = preload("res://layout/island_construction.gd")
const Poles = preload("res://layout/fence_geometry.gd")
const PIGMENT = preload("res://scenes/environment/pigment.gdshader")

static func _surface() -> SurfaceTool:
	var result:=SurfaceTool.new();result.begin(Mesh.PRIMITIVE_TRIANGLES)
	return result

static func _finish(parent: Node3D, surface: SurfaceTool, tint: Color) -> void:
	var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit()
	var material:=ShaderMaterial.new();material.shader=PIGMENT
	material.set_shader_parameter("base_color",tint)
	material.set_shader_parameter("wash_scale",3.5)
	mesh.material_override=material
	parent.add_child(mesh)

static func trellis(plan: RefCounted) -> Node3D:
	var root:=Node3D.new();root.name="EntranceTrellis"
	root.transform=Construction.trellis_pose(plan)
	var size: Vector3=Construction.trellis_size(plan)
	var bamboo: SurfaceTool=_surface();var joints: SurfaceTool=_surface()
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

static func bridge(plan: RefCounted) -> Node3D:
	var root:=Node3D.new();root.name="AdaptiveBridge"
	var ends: Array[Vector3]=Construction.bridge_points(plan)
	var length: float=ends[0].distance_to(ends[1]);var direction: Vector3=(ends[1]-ends[0]).normalized()
	var width: float=plan.construction.bridge[4]
	var side:=Vector3(-direction.z,0,direction.x)
	var basis:=Basis(side,Vector3.UP,direction)
	# Positive determinant: local X points across, local Z along the bridge.
	if basis.determinant()<0: basis.x=-basis.x
	var deck: SurfaceTool=_surface();var rails: SurfaceTool=_surface()
	var pieces: int=ceili(length/.22)
	for i: int in pieces:
		var t: float=(i+.5)/pieces
		var p: Vector3=ends[0].lerp(ends[1],t)+Vector3.UP*(.04+sin(t*PI)*.22)
		var shape:=BoxMesh.new();shape.size=Vector3(width,.075,length/pieces-.008)
		deck.append_from(shape,0,Transform3D(basis,p))
	var spans: int=ceili(length/.9)
	var supports:=PackedVector2Array()
	for edge: float in [-1.0,1.0]:
		var previous:=Vector3.ZERO
		for i: int in spans+1:
			var t: float=float(i)/spans
			var bottom: Vector3=ends[0].lerp(ends[1],t)+side*(edge*width*.5)+Vector3.UP*(.06+sin(t*PI)*.22)
			var top: Vector3=bottom+Vector3.UP*.65
			Poles._pole(rails,bottom,top,.036)
			if i>0:
				Poles._pole(rails,previous,top,.03)
				Poles._pole(rails,previous-Vector3.UP*.32,top-Vector3.UP*.32,.022)
			previous=top
			if i>0 and i<spans:
				Poles._pole(rails,Vector3(bottom.x,-.8,bottom.z),bottom,.052)
				supports.append(Vector2(bottom.x,bottom.z))
	root.set_meta("bridge_ends",ends)
	root.set_meta("bridge_supports",supports)
	root.set_meta("deck_sections",pieces)
	_finish(root,deck,Color("867354"));_finish(root,rails,Color("61543c"))
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
