extends SceneTree
## Offline thumbnails of existing assets; no runtime viewport or generated models.
const Structures = preload("res://layout/garden_structures.gd")
const Plan = preload("res://layout/courtyard_plan.gd")
const MODELS: Dictionary = {
	"house":"res://art/environment/house/house_high.glb",
	"kitchen":"res://art/environment/courtyard_life/kitchen_high.glb",
	"fence":"res://art/environment/modules/bamboo_fence.glb",
	"lotus":"res://art/environment/lotus/lotus_high.glb",
	"reed":"res://art/environment/archipelago/reed_high.glb",
	"cattail":"res://art/environment/archipelago/cattail_high.glb",
	"trapa":"res://art/environment/archipelago/trapa_high.glb",
}

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(256,192);viewport.transparent_bg=true
	viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new();viewport.add_child(world)
	var environment := WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("f1eddf")
	environment.environment.ambient_light_energy=.85;world.add_child(environment)
	var light := DirectionalLight3D.new();world.add_child(light)
	light.rotation_degrees=Vector3(-50,-30,0);light.light_energy=1.0
	var camera := Camera3D.new();world.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/ui/construction"))
	for id: String in ["house","kitchen","fence","lotus","reed","cattail","trapa","trellis","bridge","road"]:
		if not OS.get_cmdline_user_args().is_empty() and id not in OS.get_cmdline_user_args(): continue
		var model: Node3D
		var plan := Plan.new()
		if id=="trellis": model=Structures.trellis(plan)
		elif id=="bridge":
			plan.construction.bridge=[0,0,4,0,1.2]
			model=Structures.bridge(plan)
		elif id=="road":
			var courtyard := preload("res://scenes/environment/courtyard.gd").new()
			plan.paths=[PackedVector3Array([Vector3.ZERO,Vector3(0,0,2)])]
			model=courtyard.make_paths(plan);courtyard.free()
		else: model=load(MODELS[id]).instantiate()
		world.add_child(model)
		var bounds := AABB();var first := true
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var box: AABB=mesh.global_transform*mesh.get_aabb()
			bounds=box if first else bounds.merge(box);first=false
		var center: Vector3=bounds.get_center()
		camera.position=center+Vector3(1,1.05,1.4).normalized()*bounds.size.length()*2
		camera.look_at(center);camera.size=bounds.size.length()*1.13
		for frame: int in 4: await process_frame
		await RenderingServer.frame_post_draw
		var output: String="res://art/ui/construction/%s.png"%id
		var error: Error=viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
		if error!=OK: push_error(output);quit(1);return
		print("ICON ",output)
		world.remove_child(model);model.queue_free();await process_frame
	quit()
