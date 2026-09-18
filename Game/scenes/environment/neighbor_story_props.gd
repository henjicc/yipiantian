extends RefCounted
## Reuse authored, merged courtyard props. Island scale remains exactly one.
const PLACEMENTS := {
	"willow":[["YardBasketStack",Vector2(1.15,1.85),0.0,.7],
		["YardDryingLine",Vector2(.65,0),90.0,.65],
		["PorchHarvestTable",Vector2(1.3,3.05),-10.0,.8]],
	"bamboo":[["YardSeedFrames",Vector2(-.6,-.65),-45.0,.75],
		["YardGroundTrays",Vector2(-2.9,1.85),-35.0,.7],
		["PorchHarvestTable",Vector2(-.15,-1.1),20.0,.7]],
	"ferry":[["YardBasketStack",Vector2(3.5,.05),35.0,.7],
		["YardJarCluster",Vector2(-2.85,1.6),-20.0,.7],
		["PorchHarvestTable",Vector2(.45,3.4),-10.0,.7]],
}

static func create(id: String, island: Node3D, source: Node3D, living: Node3D) -> Node3D:
	var result:=Node3D.new()
	result.name="StoryChanges"
	island.add_child(result)
	var surfaces: Array[Dictionary]=[]
	for mesh: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
		surfaces.append({"mesh":mesh.mesh.generate_triangle_mesh(),"transform":island.global_transform.affine_inverse()*mesh.global_transform})
	for index: int in PLACEMENTS[id].size():
		var entry: Array=PLACEMENTS[id][index]
		var original: Node3D=living.get_node(entry[0])
		var prop: Node3D=original.duplicate(0)
		# Living kitchen contents may be temporarily hidden on the source support.
		for child: Node3D in prop.find_children("*","Node3D",true,false): child.show()
		prop.name="Chapter%d"%(index+1)
		result.add_child(prop)
		prop.rotation=Vector3(0,deg_to_rad(entry[2]),0)
		prop.scale=Vector3.ONE*entry[3]
		var point: Vector2=entry[1]
		var height: float=surface_height(surfaces,point)
		if not is_finite(height):
			push_error("Neighbour story has no support: "+id+" "+str(index))
			prop.queue_free()
			continue
		prop.position=Vector3(point.x,height-.025,point.y)
		prop.visible=false
		prop.set_meta("support_height",height)
	return result

static func surface_height(surfaces: Array[Dictionary], point: Vector2) -> float:
	var height: float=-INF
	for surface: Dictionary in surfaces:
		var transform: Transform3D=surface.transform
		var inverse: Transform3D=transform.affine_inverse()
		# Authored island floors lie below this local ceiling. Starting above the
		# entire model incorrectly lands tables on tree canopies or porch roofs.
		var hit: Dictionary=surface.mesh.intersect_ray(inverse*Vector3(point.x,1.4,point.y),inverse.basis*Vector3.DOWN)
		if not hit.is_empty(): height=maxf(height,(transform*hit.position).y)
	return height
