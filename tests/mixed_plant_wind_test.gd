extends SceneTree
## Isolated real-render proof for foliage attached to static timber / pottery.
const Wind = preload("res://presentation/plant_wind.gd")
var checks: int = 0
var failures: Array[String] = []
var reports: Array[Dictionary] = []
var output_dir: String
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=").replace("\\", "/")
	_run.call_deferred()

func _run() -> void:
	var allowed: String = ProjectSettings.globalize_path("res://../.local/verification").simplify_path() + "/"
	output_dir = ProjectSettings.globalize_path(output_dir).simplify_path()
	if not output_dir.begins_with(allowed) or DisplayServer.get_name() == "headless":
		push_error("Native rendering and an isolated verification output are required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(1200, 1000)
	root.msaa_3d = Viewport.MSAA_4X
	stage = Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("303b40")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 1.0
	stage.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	for kind: String in ["trellis", "flowerpot"]:
		for detail: String in ["high", "low"]:
			await _verify(kind, detail)
	var file := FileAccess.open(output_dir.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "assets": reports, "scope": "Actual source geometry/material mask audit plus native paired renders; no farm or player save is instantiated"}, "\t"))
	file.close()
	stage.free()
	await process_frame
	await process_frame
	print("MIXED_PLANT_WIND checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _verify(kind: String, detail: String) -> void:
	var folder: String = "environment" if kind == "trellis" else "decorations"
	var node: Node3D = load("res://art/%s/%s/%s_%s.glb" % [folder, kind, kind, detail]).instantiate()
	stage.add_child(node)
	var mesh: MeshInstance3D = _mesh(node)
	var original_mesh: Mesh = mesh.mesh
	var original: StandardMaterial3D = mesh.get_active_material(0)
	var texture: Texture2D = original.albedo_texture
	var base: Transform3D = node.global_transform
	Wind.new().apply(node, kind)
	var material: ShaderMaterial = mesh.get_active_material(0)
	_expect(mesh.mesh == original_mesh and material.get_shader_parameter("color_texture") == texture, "%s/%s retains geometry, LOD source and texture" % [kind, detail])
	var box: AABB = mesh.mesh.get_aabb()
	var height: float = box.size.y
	var image: Image = texture.get_image()
	if image.is_compressed():
		_expect(image.decompress() == OK, "Source colour image can be decoded for static-part audit")
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var locked: int = 0
	var moving_leaves: int = 0
	var brown_or_gourd: int = 0
	var unexpected_motion: int = 0
	var motion: Vector4 = mesh.get_instance_shader_parameter("wind_motion")
	for index: int in vertices.size():
		var relative: float = (vertices[index].y - box.position.y) / height
		var anchor: float = smoothstep(motion.y, 1.0, relative)
		var pixel := Vector2i(clampi(int(uvs[index].x * image.get_width()), 0, image.get_width()-1), clampi(int(uvs[index].y * image.get_height()), 0, image.get_height()-1))
		var color: Color = image.get_pixelv(pixel).srgb_to_linear()
		if kind == "trellis":
			var green: float = smoothstep(1.03, 1.12, color.g / maxf(color.r, .001)) * smoothstep(1.25, 1.55, color.g / maxf(color.b, .001))
			if color.r >= color.g:
				brown_or_gourd += 1
				unexpected_motion += int(anchor * green != 0.0)
			if anchor * green > .02:
				moving_leaves += 1
		elif vertices[index].y <= .25:
			locked += 1
			unexpected_motion += int(anchor != 0.0)
		elif anchor > .05:
			moving_leaves += 1
	_expect(unexpected_motion == 0, "%s/%s static wood/gourd colour or pottery below 25cm has zero deformation mask" % [kind, detail])
	_expect(moving_leaves > 100 and (brown_or_gourd > 100 if kind == "trellis" else locked > 100), "Actual source has both a substantial moving foliage region and fixed structure")
	camera.size = 2.6 if kind == "trellis" else .78
	camera.position = Vector3(0, height * .5, 4)
	camera.rotation = Vector3.ZERO
	await create_timer(.45).timeout
	var first: Image = await _capture(kind + "-" + detail + "-a")
	await create_timer(1.7).timeout
	var second: Image = await _capture(kind + "-" + detail + "-b")
	var changed: int = _changed(first, second, Rect2i(Vector2i.ZERO, first.get_size()))
	_expect(changed > 10, "%s/%s foliage visibly moves in paired native renders" % [kind, detail])
	var static_pixels: int = -1
	if kind == "flowerpot":
		var top: Vector2 = camera.unproject_position(Vector3(-.23, .21, 0))
		var bottom: Vector2 = camera.unproject_position(Vector3(.23, 0, 0))
		static_pixels = _changed(first, second, Rect2i(Vector2i(top), Vector2i(bottom-top)))
		_expect(static_pixels == 0, "Pottery body remains pixel-identical while leaves move")
	_expect(node.global_transform == base, "Whole model does not sway as a rigid object")
	reports.append({"kind": kind, "detail": detail, "moving_leaf_vertices": moving_leaves, "locked_pottery_vertices": locked, "fixed_wood_gourd_colour_vertices": brown_or_gourd, "unexpected_structure_motion": unexpected_motion, "changed_pixels": changed, "pottery_changed_pixels": static_pixels})
	node.free()
	await process_frame

func _mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child: Node in node.get_children():
		var found: MeshInstance3D = _mesh(child)
		if found != null:
			return found
	return null

func _capture(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(output_dir.path_join(label + ".png"))
	return image

func _changed(a: Image, b: Image, rect: Rect2i) -> int:
	var count: int = 0
	var area: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, a.get_size()))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var delta: Color = a.get_pixel(x,y)-b.get_pixel(x,y)
			if maxf(absf(delta.r), maxf(absf(delta.g), absf(delta.b))) > .015:
				count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
