extends Node3D
## Isolated material review. No farm, player save, or gameplay state is loaded.

const ORIGINAL = preload("res://art/crops/greens/greens_mature.glb")
const Wind = preload("res://presentation/plant_wind.gd")
const CANDIDATE := "res://development/greens_pbr/greens_pbr.glb"
var plants: Array[Node3D] = []
var sun: DirectionalLight3D
var environment: Environment
var camera: Camera3D
var cameras: Array[Camera3D] = []
var suns: Array[DirectionalLight3D] = []
var orbit_yaw := 0.0
var orbit_pitch := .38
var view_size := .78
var view_target := Vector3(0,.22,0)
var dragging := 0
var title_right: Label
var candidate_materials: Array[ShaderMaterial] = []
var yaw := 0.0
var light_index := 0
var normals_enabled := true
var original_color: Texture2D
var generated_colors: Array[Texture2D] = []
var use_generated_color := false
var fresh_enabled := true

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--dev-preview"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	get_viewport().mesh_lod_threshold = 0.0
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d9dcd8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e7ece7")
	environment.ambient_light_energy = .45
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var views := HBoxContainer.new()
	views.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	views.add_theme_constant_override("separation",2)
	views.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(views)
	for side: int in 2:
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		views.add_child(container)
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.mesh_lod_threshold = 0.0
		container.add_child(viewport)
		var slot := Node3D.new()
		viewport.add_child(slot)
		var world := WorldEnvironment.new()
		world.environment = environment
		slot.add_child(world)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45,-35,0)
		light.light_energy = 1.0
		light.shadow_enabled = true
		slot.add_child(light)
		suns.append(light)
		var view_camera := Camera3D.new()
		view_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		slot.add_child(view_camera)
		view_camera.current = true
		cameras.append(view_camera)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(.72,.72)
		floor_mesh.mesh = plane
		var floor_material := StandardMaterial3D.new()
		floor_material.albedo_color = Color("b9bcb5")
		floor_material.roughness = 1.0
		floor_mesh.material_override = floor_material
		slot.add_child(floor_mesh)
		var available: bool = side == 1 and ResourceLoader.exists(CANDIDATE)
		if side == 1 and not available:
			continue
		var plant: Node3D = (load(CANDIDATE) if available else ORIGINAL).instantiate()
		slot.add_child(plant)
		plants.append(plant)
		if available:
			_prepare_candidate(plant)
		else:
			original_color = _find_color(plant)
			Wind.new().apply(plant,"greens",true)
			_freeze(plant)
	camera = cameras[0]
	sun = suns[0]
	_update_cameras()
	_build_ui()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("DEV_PREVIEW_READY screen=%d mode=%d size=%s" % [DisplayServer.window_get_current_screen(),get_window().mode,DisplayServer.window_get_size()])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			await _capture(arg.trim_prefix("--capture="))

func _update_cameras() -> void:
	var direction := Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))
	for view_camera: Camera3D in cameras:
		view_camera.size = view_size
		view_camera.position = view_target + direction * 2.0
		view_camera.look_at(view_target)

func _input(event: InputEvent) -> void:
	# A release over a toolbar or outside the original viewport must end dragging.
	if event is InputEventMouseButton and not event.pressed and event.button_index == dragging:
		dragging = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: dragging = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
			dragging = event.button_index
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			view_size = clampf(view_size * (.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/.88),.20,2.4)
			_update_cameras()
	elif event is InputEventMouseMotion and dragging != 0:
		if dragging == MOUSE_BUTTON_LEFT:
			orbit_yaw -= event.relative.x * .008
			orbit_pitch = clampf(orbit_pitch + event.relative.y * .008,-1.35,1.35)
		elif dragging == MOUSE_BUTTON_MIDDLE:
			var step: float = view_size / maxf(get_viewport().get_visible_rect().size.y,1.0)
			view_target += (-camera.global_basis.x*event.relative.x+camera.global_basis.y*event.relative.y)*step
		_update_cameras()

func _freeze(node: Node) -> void:
	if node is MeshInstance3D:
		node.set_instance_shader_parameter("wind_motion",Vector4.ZERO)
		node.set_instance_shader_parameter("haze_exempt",1.0)
		node.set_instance_shader_parameter("fresh_leaf_color",0.0)
	for child: Node in node.get_children():
		_freeze(child)

func _prepare_candidate(node: Node) -> void:
	if node is MeshInstance3D:
		for surface: int in node.mesh.get_surface_count():
			var source: StandardMaterial3D = node.get_active_material(surface)
			assert(source.normal_texture != null and source.roughness_texture != null,"PBR candidate must include both maps")
			var material := ShaderMaterial.new()
			material.shader = Wind.WIND_SHADER
			material.set_shader_parameter("base_color",source.albedo_color)
			generated_colors.append(source.albedo_texture)
			material.set_shader_parameter("color_texture",original_color)
			material.set_shader_parameter("textured",source.albedo_texture != null)
			material.set_shader_parameter("base_roughness",source.roughness)
			material.set_shader_parameter("base_specular",.08)
			material.set_shader_parameter("normal_textured",source.normal_texture != null)
			material.set_shader_parameter("normal_texture",source.normal_texture)
			material.set_shader_parameter("normal_strength",.9)
			material.set_shader_parameter("leaf_detail_only",true)
			material.set_shader_parameter("leaf_backlight",.30)
			material.set_shader_parameter("roughness_range",Vector2(.58,.88))
			material.set_shader_parameter("roughness_textured",source.roughness_texture != null)
			material.set_shader_parameter("roughness_texture",source.roughness_texture)
			var channels: Array[Vector4] = [Vector4(1,0,0,0),Vector4(0,1,0,0),Vector4(0,0,1,0),Vector4(0,0,0,1),Vector4(1.0/3,1.0/3,1.0/3,0)]
			material.set_shader_parameter("roughness_channel",channels[source.roughness_texture_channel])
			node.set_surface_override_material(surface,material)
			candidate_materials.append(material)
		node.set_instance_shader_parameter("preserve_painted_color",1.0)
		node.set_instance_shader_parameter("fresh_leaf_color",1.0)
		node.set_instance_shader_parameter("wind_motion",Vector4.ZERO)
		node.set_instance_shader_parameter("haze_exempt",1.0)
	for child: Node in node.get_children():
		_prepare_candidate(child)

func _find_color(node: Node) -> Texture2D:
	if node is MeshInstance3D:
		return (node.get_active_material(0) as StandardMaterial3D).albedo_texture
	for child: Node in node.get_children():
		var texture: Texture2D = _find_color(child)
		if texture != null: return texture
	return null

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var layout := Control.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(layout)
	for side: int in 2:
		var label := Label.new()
		label.text = "原材质 · 已摆正" if side == 0 else ("候选 · 清新配色＋叶面细节" if not candidate_materials.is_empty() else "候选 · 资源尚未导入")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color",Color("303b32"))
		label.add_theme_font_size_override("font_size",30)
		layout.add_child(label)
		label.anchor_left = side * .5
		label.anchor_right = (side + 1) * .5
		label.position.y = 45
		if side == 1: title_right = label
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",18)
	layout.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	controls.grow_horizontal = Control.GROW_DIRECTION_BOTH
	controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	controls.position.y -= 38
	_button(controls,"向左转",func() -> void: _rotate(-PI/6.0))
	_button(controls,"向右转",func() -> void: _rotate(PI/6.0))
	_button(controls,"切换光照",_cycle_light)
	var normal_button: Button = _button(controls,"法线开／关",_toggle_normals)
	normal_button.disabled = candidate_materials.is_empty()
	var color_button: Button = _button(controls,"切换配色",_toggle_color)
	color_button.disabled = candidate_materials.is_empty()
	_button(controls,"冷暖对比",_toggle_fresh)
	_button(controls,"复位",_reset)
	_button(controls,"返回农场",func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))

func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(142,48)
	button.add_theme_font_size_override("font_size",23)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _rotate(amount: float) -> void:
	yaw += amount
	for plant: Node3D in plants: plant.rotation.y = yaw

func _cycle_light() -> void:
	light_index = (light_index + 1) % 3
	for light: DirectionalLight3D in suns:
		light.rotation_degrees = [Vector3(-45,-35,0),Vector3(-22,65,0),Vector3(-30,160,0)][light_index]

func _toggle_normals() -> void:
	normals_enabled = not normals_enabled
	for material: ShaderMaterial in candidate_materials:
		material.set_shader_parameter("normal_textured",normals_enabled and material.get_shader_parameter("normal_texture") != null)
	_update_title()

func _toggle_color() -> void:
	use_generated_color = not use_generated_color
	for index: int in candidate_materials.size():
		candidate_materials[index].set_shader_parameter("color_texture",generated_colors[index] if use_generated_color else original_color)
	_update_title()

func _update_title() -> void:
	title_right.text = "候选 · " + ("Tripo新配色" if use_generated_color else ("清新配色" if fresh_enabled else "原配色")) + "＋叶面细节" + ("" if normals_enabled else "（关闭法线）")

func _toggle_fresh() -> void:
	fresh_enabled = not fresh_enabled
	for mesh: Node in plants[1].find_children("*","MeshInstance3D",true,false):
		mesh.set_instance_shader_parameter("fresh_leaf_color",1.0 if fresh_enabled else 0.0)
	_update_title()

func _reset() -> void:
	orbit_yaw = 0.0
	orbit_pitch = .38
	view_size = .78
	view_target = Vector3(0,.22,0)
	dragging = 0
	_update_cameras()
	_rotate(-yaw)
	light_index = 2
	_cycle_light()
	if not normals_enabled: _toggle_normals()
	if use_generated_color: _toggle_color()
	if not fresh_enabled: _toggle_fresh()

func _capture(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var normal_on: Image
	for view: int in 3:
		await get_tree().create_timer(.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("comparison-%d.png" % view))
		if view == 0: normal_on = get_viewport().get_texture().get_image()
		_rotate(PI/2.0)
		_cycle_light()
	_reset()
	_toggle_normals()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("normals-off.png"))
	var normal_off: Image = get_viewport().get_texture().get_image()
	var changed := 0
	var peak := 0.0
	for y: int in range(int(normal_on.get_height()*.25),int(normal_on.get_height()*.73),3):
		for x: int in range(int(normal_on.get_width()*.55),int(normal_on.get_width()*.94),3):
			var difference: Color = normal_on.get_pixel(x,y)-normal_off.get_pixel(x,y)
			var delta: float = maxf(absf(difference.r),maxf(absf(difference.g),absf(difference.b)))
			peak = maxf(peak,delta)
			if delta > .003: changed += 1
	assert(changed > 30,"Normal map must visibly affect the candidate under fixed lighting")
	var report := FileAccess.open(directory.path_join("normal-check.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"changed_sample_pixels":changed,"max_channel_delta":peak,"normal_strength":.9,"maps":candidate_materials.size()},"  "))
	report.close()
	_toggle_normals()
	_toggle_color()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("new-color.png"))
	_reset()
	print("MATERIAL_COMPARISON_CAPTURED ",directory)
	get_tree().quit()
