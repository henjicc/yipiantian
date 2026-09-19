extends SceneTree
const Geometry=preload("res://layout/construction_mesh.gd")
const Fence=preload("res://layout/fence_geometry.gd")
const Structures=preload("res://layout/garden_structures.gd")
const Plan=preload("res://layout/courtyard_plan.gd")
var failures: Array[String]=[]

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message);push_error(message)

func _initialize() -> void:
	# Compare actual generated pole triangles against Godot's dimensioned
	# cylinder. Non-uniform scaling must not change thickness, caps or shading.
	for ends: Array in [[Vector3.ZERO,Vector3(0,2.4,0)],[Vector3(-2,.3,1),Vector3(3,1.8,2)],[Vector3(2,1,0),Vector3(-1,1,-3)]]:
		var a: Vector3=ends[0];var b: Vector3=ends[1]
		var assembled:=Geometry.new();Fence._pole(assembled,a,b,.036)
		var shape:=CylinderMesh.new();shape.top_radius=.036;shape.bottom_radius=.036
		shape.height=a.distance_to(b);shape.radial_segments=10;shape.rings=1
		var expected: Array=shape.get_mesh_arrays()
		var pose:=Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5)
		var points: PackedVector3Array=expected[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=expected[Mesh.ARRAY_NORMAL]
		var match_vertices: bool=assembled.vertices.size()==points.size()
		var match_normals: bool=true
		for i: int in points.size():
			match_vertices=match_vertices and assembled.vertices[i].distance_to(pose*points[i])<.00001
			match_normals=match_normals and assembled.normals[i].distance_to(pose.basis*normals[i])<.00001
		expect(match_vertices,"Pole preserves actual cylinder thickness and end caps")
		expect(match_normals,"Pole normals follow orientation without scale distortion")
		expect(assembled.indices==expected[Mesh.ARRAY_INDEX] and assembled.uvs==expected[Mesh.ARRAY_TEX_UV],"Pole preserves triangle winding and UV layout")
		var uploaded: Array=assembled.commit().surface_get_arrays(0)
		expect(uploaded[Mesh.ARRAY_VERTEX].size()==points.size(),"Upload retains indexed vertices")
	var plan:=Plan.new();plan.construction.bridge=[5.4,-.1,11.0,.1,1.2,1]
	var bridge: Node3D=Structures.bridge(plan)
	expect(bridge.get_meta("bridge_supports").size()==12,"Six bridge spans retain paired water supports")
	expect(bridge.get_meta("deck_sections")==26,"Bridge retains planks at the requested span")
	bridge.free()
	var construction=preload("res://layout/island_construction.gd")
	for bank_offset: float in [-.02,.8]:
		plan.anchors.east_bank.y=bank_offset
		for style: int in [0,1]:
			plan.construction.bridge[5]=style
			bridge=Structures.bridge(plan)
			var ends: Array[Vector3]=bridge.get_meta("bridge_ends")
			expect(is_equal_approx(ends[0].y,plan.ground_height) and is_equal_approx(ends[1].y,plan.ground_height+bank_offset),"Bridge endpoints use both real plateau heights")
			var mesh: MeshInstance3D=bridge.get_child(0)
			var triangles: TriangleMesh=mesh.mesh.generate_triangle_mesh()
			var count: int=bridge.get_meta("deck_sections")
			for i: int in [0,count/2,count-1]:
				var a: Vector3=construction.bridge_profile(ends,style,float(i)/count)
				var b: Vector3=construction.bridge_profile(ends,style,float(i+1)/count)
				var center: Vector3=(a+b)*.5
				var hit: Dictionary=triangles.intersect_segment(center+Vector3.UP*2,center-Vector3.UP*2)
				expect(not hit.is_empty() and absf(hit.position.y-center.y)<.0001,"Real plank top follows slope and style at section %d"%i)
			expect(construction.bridge_issue(plan).is_empty(),"Moderate bank height difference remains supported")
			bridge.free()
	plan.anchors.east_bank.y=3.0
	expect(construction.bridge_issue(plan).contains("高差"),"An excessive bank slope is rejected")
	for style: String in Plan.FENCE_STYLES:
		var spans: Array[Dictionary]=[{"a":Vector3.ZERO,"b":Vector3(2,0,0),"height":1.0}]
		var fence: Node3D=Fence.build(spans,style)
		expect(fence.find_children("*","MeshInstance3D",true,false).size()==2 and fence.has_node("Contacts") and fence.get_meta("fence_spans")==spans,"Fence preserves geometry and gate data: "+style)
		fence.free()
	print("CONSTRUCTION_MESH ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
