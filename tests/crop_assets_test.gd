extends SceneTree

const Visuals = preload("res://art/crops/crop_visual_catalog.gd")
const Sample = preload("res://scenes/crop_sample/crop_sample.gd")
const Wind = preload("res://presentation/plant_wind.gd")
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""
var scene: Node3D
var planting_only: bool = false
var crop_filter: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshots="):
			capture_dir = argument.trim_prefix("--screenshots=")
		if argument == "--planting-only":
			planting_only = true
		if argument.begins_with("--crop="):
			crop_filter = argument.trim_prefix("--crop=")
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	if planting_only:
		scene = Sample.new()
		root.add_child(scene)
		scene.show_planted_radish()
		await _capture("radish_planted_close.png")
		print("CROP_PLANTING_CAPTURE checks=%d failures=%d" % [checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	var statistics: Dictionary = {}
	if not crop_filter.is_empty() and not Visuals.CROP_IDS.has(crop_filter):
		push_error("Unknown crop filter: " + crop_filter)
		quit(1)
		return
	var greens_audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../ArtSource/Crops/Greens/p2-gongbi-20260918/asset-audit.json"))
	for crop_id: String in Visuals.CROP_IDS:
		if not crop_filter.is_empty() and crop_id != crop_filter:
			continue
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
				if Visuals.P2_STAGE_CROPS.has(crop_id):
					var audit_path: String = "res://../ArtSource/Crops/P2Stages20260919/%s/%s/asset-audit.json" % [crop_id, stage]
					var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(audit_path))
					_expect(report.triangles == int(audit.triangles), "P2 stage matches audited export: " + path)
					_expect(bool(audit.reimport_verified), "P2 stage roundtrip was verified: " + path)
					var expected_min := Vector3(float(audit.min_godot[0]),float(audit.min_godot[1]),float(audit.min_godot[2]))
					var expected_max := Vector3(float(audit.max_godot[0]),float(audit.max_godot[1]),float(audit.max_godot[2]))
					_expect((report.bounds.position-expected_min).length() < .0001 and (report.bounds.end-expected_max).length() < .0001,"P2 soil anchor and size match authored export")
				elif crop_id == "greens" and stage == "mature":
					var tier: String = "greens_mature_low" if low else "greens_mature"
					_expect(report.triangles == int(greens_audit.meshes[tier].triangles), "Imported P2 geometry matches audited export: " + path)
					if not low:
						_expect(report.triangles == int(greens_audit.source_topology.triangles), "High tier preserves full generated geometry")
				else:
					_expect(report.triangles > 0 and report.triangles <= 3600, "Measured stage triangle budget: " + path)
				_expect(report.mesh_instances <= 2 and report.mesh_instances > 0, "No unexpected mesh fragments: " + path)
				if not Visuals.P2_STAGE_CROPS.has(crop_id):
					_expect(absf(report.bounds.position.y) <= 0.008, "Ground root remains at zero: " + path)
				_expect(report.bounds.size.y > 0.04 and report.bounds.size.y < 0.65, "Metre-scale crop height: " + path)
				if crop_id == "greens" or Visuals.P2_STAGE_CROPS.has(crop_id):
					var painted: bool = Visuals.preserves_painted_color(crop_id, stage)
					Wind.new().apply(crop, Visuals.wind_profile(crop_id), painted)
					for mesh: MeshInstance3D in crop.find_children("*", "MeshInstance3D", true, false):
						_expect(mesh.get_instance_shader_parameter("preserve_painted_color") == (1.0 if painted else 0.0), "Painted crop stages bypass legacy colour boost")
						var original: StandardMaterial3D = mesh.mesh.surface_get_material(0)
						var animated: ShaderMaterial = mesh.get_active_material(0)
						_expect(animated.get_shader_parameter("color_texture") == original.albedo_texture, "Wind retains source brushwork texture")
						var motion: Vector4 = mesh.get_instance_shader_parameter("wind_motion")
						_expect(motion.x <= report.bounds.size.y * .025 + .00001 and motion.y > 0.0, "Wind is stage-scaled and root anchored")
						_expect(report.bounds.position.y+report.bounds.size.y*motion.y >= -.0001,"Buried root is below the moving region")
				crop.free()
			if pair.size() == 2:
				if Visuals.scene_path(crop_id, stage, true) != Visuals.scene_path(crop_id, stage, false):
					_expect(pair[1].triangles < pair[0].triangles, "Distinct low mesh uses fewer triangles: " + crop_id + "/" + stage)
				else:
					_expect(pair[1].triangles == pair[0].triangles, "Single-tier crop remains full geometry: " + crop_id + "/" + stage)
				_expect((pair[1].bounds.size - pair[0].bounds.size).length() < 0.03, "LOD retains silhouette bounds: " + crop_id + "/" + stage)
				_expect(pair[0].bounds.end.y > prior_height, "Growth increases above-soil height: " + crop_id + "/" + stage)
				prior_height = pair[0].bounds.end.y
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
