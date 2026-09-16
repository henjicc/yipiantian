extends SceneTree
## Reads imported mesh LOD data; import flags alone are not evidence of usable LODs.

var records: Array[Dictionary] = []
var output_path: String = ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output_path = arg.trim_prefix("--output=")
	_run.call_deferred()


func _run() -> void:
	for folder: String in ["res://art/crops", "res://art/environment", "res://art/decorations"]:
		_scan(folder)
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "meshes": records}, "\t"))
	var with_lods: int = 0
	for record: Dictionary in records:
		if record.lod_triangles.size() > 0:
			with_lods += 1
	print("FOCUS_DETAIL_AUDIT meshes=%d with_real_lods=%d" % [records.size(), with_lods])
	quit(0 if records.size() > 0 else 1)


func _scan(folder: String) -> void:
	for child: String in DirAccess.get_directories_at(folder):
		_scan(folder.path_join(child))
	for filename: String in DirAccess.get_files_at(folder):
		if filename.get_extension() != "glb":
			continue
		var path: String = folder.path_join(filename)
		var packed := load(path) as PackedScene
		var instance: Node = packed.instantiate()
		_inspect(instance, path)
		instance.free()


func _inspect(node: Node, path: String) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		for surface: int in mesh.get_surface_count():
			var data: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
			var triangles: int = int(data.get("index_count", data.get("vertex_count", 0))) / 3
			var index_size: int = 2 if int(data.get("vertex_count", 0)) <= 65536 else 4
			var lod_triangles: Array[int] = []
			var edges: Array[float] = []
			for lod: Dictionary in data.get("lods", []):
				lod_triangles.append(lod.index_data.size() / index_size / 3)
				edges.append(lod.edge_length)
			records.append({"path": path, "mesh": str(node.name), "surface": surface, "base_triangles": triangles, "lod_triangles": lod_triangles, "lod_edges": edges})
	for child: Node in node.get_children():
		_inspect(child, path)
