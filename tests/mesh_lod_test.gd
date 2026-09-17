extends SceneTree
## Real imported meshes and render counters: near detail must recover after distance.
const Detail = preload("res://presentation/focus_detail.gd")
var output: String
var checks: int = 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var camera: Camera3D

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	assert(output.begins_with(ProjectSettings.globalize_path("res://../.local/").simplify_path()))
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	Engine.max_fps = 60
	camera = Camera3D.new(); camera.fov = 40; camera.far = 1000
	root.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("8c989f")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35,-25,0)
	root.add_child(sun)
	var paths: Array[String] = []
	_collect("res://art", paths)
	paths.sort()
	for path: String in paths:
		var asset: Node3D = load(path).instantiate(); root.add_child(asset)
		var meshes: Array[Node] = asset.find_children("*", "MeshInstance3D", true, false)
		var bounds := AABB(); var initialized := false
		var base_triangles: int = 0; var coarsest_triangles: int = 0; var auto_lods: int = 0
		var base_faces := PackedVector3Array(); var lowest_faces := PackedVector3Array()
		for mesh: MeshInstance3D in meshes:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var b: AABB = mesh.global_transform * mesh.mesh.get_aabb()
			bounds = bounds.merge(b) if initialized else b; initialized = true
			for surface: int in mesh.mesh.get_surface_count():
				var data: Dictionary = RenderingServer.mesh_get_surface(mesh.mesh.get_rid(),surface)
				var count: int = data.get("index_count",data.vertex_count)
				base_triangles += count/3
				var levels: Array = data.get("lods",[])
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for index: int in vertices.size(): indices.append(index)
				for index: int in indices: base_faces.append(mesh.global_transform*vertices[index])
				if not levels.is_empty():
					var bytes: PackedByteArray = levels[-1].index_data
					var stride: int = 2 if data.vertex_count <= 65536 else 4
					indices.clear()
					for index: int in range(0, bytes.size(), stride): indices.append(bytes.decode_u16(index) if stride == 2 else bytes.decode_u32(index))
				for index: int in indices: lowest_faces.append(mesh.global_transform*vertices[index])
				auto_lods += levels.size()
				coarsest_triangles += count/3 if levels.is_empty() else levels[-1].index_data.size()/(2 if data.vertex_count <= 65536 else 4)/3
		var centre: Vector3 = bounds.get_center()
		var radius: float = bounds.size.length()*0.5
		var direction := Vector3(.35,.20,1).normalized()
		camera.position = centre + direction*radius*3.2; camera.look_at(centre)
		root.mesh_lod_threshold = 0.0
		var full: int = await primitives()
		root.mesh_lod_threshold = 1.0
		for mesh: MeshInstance3D in meshes: mesh.lod_bias = 0.0
		var broken: int = await primitives()
		for mesh: MeshInstance3D in meshes: mesh.lod_bias = Detail.OVERVIEW_BIAS
		var near_count: int = await primitives()
		expect(near_count >= full*.70, "Near silhouette retains detail: " + path)
		if not path.contains("_low"):
			await capture(path.get_file().get_basename()+"-near.png")
		camera.position = centre + direction*radius*40.0; camera.look_at(centre)
		var far_count: int = await primitives()
		expect(far_count > 0 and far_count <= near_count, "Distance selection remains active: " + path)
		camera.position = centre + direction*radius*3.2; camera.look_at(centre)
		expect(await primitives() == near_count, "Approaching restores geometry: " + path)
		var base_topology: Dictionary = topology(base_faces)
		var lowest_topology: Dictionary = topology(lowest_faces)
		if base_topology.boundary_edges == 0:
			expect(lowest_topology.boundary_edges == 0,"Closed source gains no open borders: " + path)
		records.append({"asset":path,"base_triangles":base_triangles,"coarsest_triangles":coarsest_triangles,"auto_lod_levels":auto_lods,"draw_full":full,"draw_bias_zero":broken,"draw_near":near_count,"draw_far":far_count,"base_topology":base_topology,"lowest_topology":lowest_topology})
		asset.free()
	var reduced: int = 0
	for record: Dictionary in records:
		if record.draw_far < record.draw_near: reduced += 1
		if record.asset.ends_with("_low.glb"):
			var high_path: String = record.asset.replace("_low.glb","_high.glb")
			if not ResourceLoader.exists(high_path): high_path = record.asset.replace("_low.glb",".glb")
			for high: Dictionary in records:
				if high.asset == high_path and high.base_topology.boundary_edges == 0:
					expect(record.base_topology.boundary_edges == 0,"Authored low tier preserves closed source: " + record.asset)
	expect(reduced > 0,"LOD still reduces distant models; global rendering is not forced to full detail")
	var file := FileAccess.open(output.path_join("mesh-lod.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"resolution":"1280x720","records":records,"checks":checks,"failures":failures},"\t")); file.close()
	for failure: String in failures: push_error(failure)
	print("MESH_LOD_TEST assets=%d checks=%d failures=%d" % [records.size(),checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func primitives() -> int:
	for i: int in 4: await RenderingServer.frame_post_draw
	return RenderingServer.viewport_get_render_info(root.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)

func capture(name: String) -> void:
	expect(root.get_texture().get_image().save_png(output.path_join(name)) == OK,"Saved " + name)

func _collect(folder: String, paths: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".glb"): paths.append(folder.path_join(file))
	for child: String in DirAccess.get_directories_at(folder): _collect(folder.path_join(child),paths)

func topology(faces: PackedVector3Array) -> Dictionary:
	# Position-only weld in an audit copy: UV/material seams aren't physical holes.
	# Boundaries can be intentional (thin leaves); report them, never auto-fill them.
	var vertices: Dictionary = {}; var points: Array[Vector3] = []; var edges: Dictionary = {}
	var degenerate: int = 0
	for i: int in range(0,faces.size(),3):
		var ids: Array[int] = []
		for j: int in 3:
			var point: Vector3 = faces[i+j].snapped(Vector3.ONE*.00001)
			if not vertices.has(point):
				vertices[point] = vertices.size(); points.append(point)
			ids.append(vertices[point])
		if ids[0] == ids[1] or ids[1] == ids[2] or ids[2] == ids[0]:
			degenerate += 1; continue
		for j: int in 3:
			var key := Vector2i(mini(ids[j],ids[(j+1)%3]),maxi(ids[j],ids[(j+1)%3]))
			edges[key] = int(edges.get(key,0))+1
	var boundary: int = 0; var length: float = 0; var nonmanifold: int = 0
	for edge: Vector2i in edges:
		if edges[edge] == 1:
			boundary += 1; length += points[edge.x].distance_to(points[edge.y])
		elif edges[edge] > 2: nonmanifold += 1
	return {"weld_grid_metres":.00001,"boundary_edges":boundary,"boundary_length_metres":length,"overconnected_edges":nonmanifold,"degenerate_after_weld":degenerate}
