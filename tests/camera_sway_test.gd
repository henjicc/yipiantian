extends SceneTree

var failures: Array[String] = []
var output: String

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	output = ProjectSettings.globalize_path("res://../.local/verification/camera-sway")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600,900)
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	scene.store = load("res://farm/farm_store.gd").new(output.path_join("farm"))
	scene.settings_store = load("res://settings/settings_store.gd").new(output.path_join("preferences"))
	root.add_child(scene)
	await create_timer(1).timeout
	var camera: FarmCamera = scene.camera
	camera.set_process(false)
	var original_view: Vector3 = camera.view
	var original_point: Vector3 = camera.focus_point
	camera.configure_sway(true, 2.0)
	for frame: int in 119: camera._process(1.0/60.0)
	expect(camera.h_offset == 0 and camera.v_offset == 0, "No sway before idle deadline")
	var largest: float = 0
	for frame: int in 1200:
		camera._process(1.0/60.0)
		largest = maxf(largest, Vector2(camera.h_offset,camera.v_offset).length())
	expect(largest > .01 and largest < .042, "Idle motion exists and stays subtle")
	expect(camera.view == original_view and camera.focus_point == original_point, "Sway does not contaminate remembered framing")
	var before := Vector2(camera.h_offset,camera.v_offset)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel)
	expect(Vector2(camera.h_offset,camera.v_offset) == before, "Input does not snap sway offset")
	camera.zoom(-2)
	camera.drag(Vector2(12,5), true)
	var panned: Vector3 = camera.focus_point
	for frame: int in 110: camera._process(1.0/60.0)
	expect(camera.focus_point == panned and camera.view.z < original_view.z - 1.9, "Pan preserves wheel distance and its own target")
	expect(Vector2(camera.h_offset,camera.v_offset).length() < .0001, "Interaction fades sway away")
	camera.configure_sway(true,0)
	for frame: int in 600: camera._process(1.0/60.0)
	for frame: int in 120:
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(1,0)
		root.push_input(motion)
		camera._process(1.0/60.0)
	expect(Vector2(camera.h_offset,camera.v_offset).length()<.0001, "Zero delay still respects continuous activity")
	for frame: int in 600: camera._process(1.0/60.0)
	before = Vector2(camera.h_offset,camera.v_offset)
	scene._focus_field(0)
	expect(Vector2(camera.h_offset,camera.v_offset) == before, "Field focus starts without offset snap")
	camera.set_process(true)
	await create_timer(1.2).timeout
	expect(camera.focused and camera.focus_point.distance_to(camera._anchor)<.001, "Field focus reaches intended target with sway enabled")
	camera.configure_sway(false,30)
	await create_timer(2).timeout
	expect(Vector2(camera.h_offset,camera.v_offset).length()<.0001, "Disable settles to stable framing")
	scene._return_overview()
	await create_timer(1).timeout
	var front: Node3D = scene.find_child("PathLanternFront",true,false)
	expect(front != null and front.find_children("*","MeshInstance3D",true,false).is_empty(), "Foreground lamp and pole removed")
	expect(is_equal_approx(front.get_node("GardenFillLight").omni_range, 5.6), "Field illumination footprint retained")
	scene.atmosphere.set_preview_hour(21)
	await shot("night.png")
	camera.preview_overview({"yaw":-12.0,"pitch":20.0,"distance":25.5,"fov":36.0,"target_x":.25,"target_y":.75,"target_z":0.0})
	await shot("night-left.png")
	camera.preview_overview({"yaw":68.0,"pitch":20.0,"distance":25.5,"fov":36.0,"target_x":.25,"target_y":.75,"target_z":0.0})
	await shot("night-right.png")
	scene.atmosphere.set_preview_hour(12)
	await shot("day.png")
	print("CAMERA_SWAY_TEST failures=%d %s" % [failures.size(),str(failures)])
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func shot(filename: String) -> void:
	await create_timer(.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))
