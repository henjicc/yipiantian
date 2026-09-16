extends SceneTree

const Visuals = preload("res://art/crops/crop_visual_catalog.gd")
const Sample = preload("res://scenes/crop_sample/crop_sample.gd")
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""
var scene: Node3D
var planting_only: bool = false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			capture_dir = argument.trim_prefix("--screenshots=")
		if argument == "--planting-only":
			planting_only = true
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	if planting_only:
		scene = Sample.new()
		root.add_child(scene)
		scene.show_planted_radish()
		await _capture("radish_planted_close.png")
		print("CROP_PLANTING_CAPTURE checks=%d failures=%d" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	var statistics: Dictionary = {}
	for crop_id: String in Visuals.CROP_IDS:
		var prior_height: float = 0.0
		for stage: String in Visuals.STAGES:
			var pair: Array[Dictionary] = []
			for low: bool in [false, true]:
				var path: String = Visuals.scene_path(crop_id, stage, low)
				_expect(ResourceLoader.exists(path), "Resource exists: " + path)
				if not ResourceLoader.exists(path):
					continue
				var crop: Node3D = Visuals.instantiate(crop_id, stage, low)
				_expect(crop != null, "GLB instantiates: " + path)
				if crop == null:
					continue
				var report: Dictionary = _inspect(crop)
				pair.append(report)
				statistics[path] = {"triangles": report.triangles, "mesh_instances": report.mesh_instances,
					"bounds_position": str(report.bounds.position), "bounds_size": str(report.bounds.size)}
				_expect(report.triangles > 0 and report.triangles <= 3600, "Measured stage triangle budget: " + path)
				_expect(report.mesh_instances <= 2 and report.mesh_instances > 0, "No unexpected mesh fragments: " + path)
				_expect(absf(report.bounds.position.y) <= 0.008, "Ground root remains at zero: " + path)
				_expect(report.bounds.size.y > 0.04 and report.bounds.size.y < 0.65, "Metre-scale crop height: " + path)
				crop.free()
			if pair.size() == 2:
				_expect(pair[1].triangles < pair[0].triangles, "Low mesh uses fewer triangles: " + crop_id + "/" + stage)
				_expect((pair[1].bounds.size - pair[0].bounds.size).length() < 0.03, "LOD retains silhouette bounds: " + crop_id + "/" + stage)
				_expect(pair[0].bounds.size.y > prior_height, "Growth increases height: " + crop_id + "/" + stage)
				prior_height = pair[0].bounds.size.y
	if not capture_dir.is_empty() and failures.is_empty():
		scene = Sample.new()
		root.add_child(scene)
		await create_timer(0.5).timeout
		for low: bool in [false, true]:
			var detail: String = "low" if low else "high"
			scene.set_night(false)
			scene.show_comparison(low)
			await _capture("stages_%s_front.png" % detail)
			scene.show_comparison(low, PI)
			await _capture("stages_%s_back.png" % detail)
			scene.show_field_overview(low)
			await _capture("fields_%s.png" % detail)
			scene.show_field_overview(low, true)
			await _capture("fields_mature_%s.png" % detail)
			scene.set_night(true)
			scene.show_comparison(low)
			await _capture("stages_%s_night.png" % detail)
		scene.set_night(false)
		for crop_id: String in Visuals.CROP_IDS:
			for stage: String in Visuals.STAGES:
				scene.show_single(crop_id, stage, false)
				await _capture("%s_%s_close.png" % [crop_id, stage])
		var file := FileAccess.open(capture_dir.path_join("asset-stats.json"), FileAccess.WRITE)
		_expect(file != null, "Write measured asset statistics")
		if file != null:
			file.store_string(JSON.stringify(statistics, "  ") + "\n")
	for failure: String in failures:
		push_error(failure)
	print("CROP_ASSETS_TEST checks=%d failures=%d stats=%s" % [checks, failures.size(), JSON.stringify(statistics)])
	quit(0 if failures.is_empty() else 1)


func _inspect(crop: Node3D) -> Dictionary:
	var report: Dictionary = {"triangles": 0, "mesh_instances": 0, "bounds": AABB()}
	_collect(crop, Transform3D.IDENTITY, report)
	return report


func _collect(node: Node, parent_transform: Transform3D, report: Dictionary) -> void:
	var transform: Transform3D = parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		_expect(mesh != null, "Imported mesh exists")
		if mesh != null:
			var bounds: AABB = transform * mesh.get_aabb()
			report.bounds = bounds if report.mesh_instances == 0 else report.bounds.merge(bounds)
			report.mesh_instances += 1
			for surface in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				report.triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
				var material := mesh.surface_get_material(surface) as BaseMaterial3D
				_expect(material != null and material.albedo_texture != null, "Colour texture survives import")
				if material != null:
					_expect(material.roughness >= 0.8 and material.metallic == 0.0, "Matte nonmetal crop material")
	for child: Node in node.get_children():
		_collect(child, transform, report)


func _capture(filename: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1920, 1080), "Native 1080p screenshot: " + filename)
	_expect(image.save_png(capture_dir.path_join(filename)) == OK, "Save " + filename)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
