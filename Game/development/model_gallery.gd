extends "res://development/greens_material_comparison.gd"
## Extends the existing review camera and lighting controls; edits are preview-only.
const Catalog = preload("res://development/model_catalog.gd")
var entries: Array[Dictionary] = []
var filtered: Array[Dictionary] = []
var icons: Dictionary = {}
var list: ItemList
var search: LineEdit
var category: OptionButton
var slot_picker: OptionButton
var compare: CheckButton
var info_labels: Array[Label] = []
var slots: Array[Node3D] = []
var view_panels: Array[VBoxContainer] = []
var selected_paths: Array[String] = ["",""]
var slot_models: Array[Node3D] = [null,null]
var status: Label
var rotation_control: HSlider
var roughness_control: HSlider
var wind_control: CheckButton
var updating := false
var thumb_view: SubViewport
var thumb_root: Node3D
var thumb_camera: Camera3D

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--dev-preview"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d9dcd8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e7ece7")
	environment.ambient_light_energy = .6
	entries = Catalog.scan()
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.path < b.path)
	_build_gallery()
	_reset_view()
	_refresh_list()
	_select_path("res://art/crops/greens/greens_mature.glb",0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("DEV_PREVIEW_READY screen=%d mode=%d size=%s" % [DisplayServer.window_get_current_screen(),get_window().mode,DisplayServer.window_get_size()])
	_make_thumbnails()

func _build_gallery() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = _panel_theme()
	add_child(ui)
	var background := ColorRect.new()
	background.color = Color("e9ece5")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(background)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	ui.add_child(margin)
	var main := HBoxContainer.new()
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_theme_constant_override("separation",14)
	margin.add_child(main)
	var sidebar := VBoxContainer.new()
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar.custom_minimum_size.x = 470
	sidebar.add_theme_constant_override("separation",10)
	main.add_child(sidebar)
	var heading := HBoxContainer.new()
	sidebar.add_child(heading)
	var title := _label("模型检查室",27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation",8)
	sidebar.add_child(nav)
	_nav_button(nav,"青菜材质对照",func() -> void: get_tree().change_scene_to_file("res://development/greens_material_comparison.tscn"))
	_nav_button(nav,"返回农场",func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation",8)
	sidebar.add_child(filters)
	search = LineEdit.new()
	search.placeholder_text = "搜索名称、来源或文件名…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text: String) -> void: _refresh_list())
	filters.add_child(search)
	category = OptionButton.new()
	for value: String in ["全部","作物","环境","摆件","建筑模块","院落生活","远景与水生","小样"]: category.add_item(value)
	category.item_selected.connect(func(_index: int) -> void: _refresh_list())
	filters.add_child(category)
	status = _label("",16)
	sidebar.add_child(status)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.max_columns = 3
	list.fixed_column_width = 140
	list.fixed_icon_size = Vector2i(116,80)
	list.icon_mode = ItemList.ICON_MODE_TOP
	list.max_text_lines = 2
	list.add_theme_font_size_override("font_size",15)
	list.item_selected.connect(func(index: int) -> void: _select_path(filtered[index].path,slot_picker.selected))
	sidebar.add_child(list)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	main.add_child(content)
	var views := HBoxContainer.new()
	views.mouse_filter = Control.MOUSE_FILTER_IGNORE
	views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	views.add_theme_constant_override("separation",14)
	content.add_child(views)
	for index: int in 2:
		var panel := VBoxContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		views.add_child(panel)
		view_panels.append(panel)
		var info := _label("选择模型",19)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size.y = 88
		info_labels.append(info)
		panel.add_child(info)
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(container)
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.mesh_lod_threshold = 0.0
		container.add_child(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		_add_lighting(stage)
		var view_camera := Camera3D.new()
		view_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		view_camera.current = true
		stage.add_child(view_camera)
		cameras.append(view_camera)
		var slot := Node3D.new()
		stage.add_child(slot)
		slots.append(slot)
		var floor_mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.8,2.8)
		floor_mesh.mesh = plane
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("b9c1b7")
		material.roughness = 1
		floor_mesh.material_override = material
		stage.add_child(floor_mesh)
	view_panels[1].hide()
	camera = cameras[0]
	sun = suns[0]
	content.add_child(_label("左键旋转 · 中键平移 · 滚轮缩放 ｜ 两侧同步视角，模型等比例适配展示；调整仅本次预览生效",16))
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("separation",10)
	content.add_child(controls)
	compare = CheckButton.new()
	compare.text = "双模型"
	compare.add_theme_font_size_override("font_size",18)
	compare.toggled.connect(_set_compare)
	controls.add_child(compare)
	slot_picker = OptionButton.new()
	slot_picker.add_item("选择／调整左侧")
	slot_picker.add_item("选择／调整右侧")
	slot_picker.disabled = true
	slot_picker.add_theme_font_size_override("font_size",18)
	slot_picker.item_selected.connect(func(_index: int) -> void: _sync_controls())
	controls.add_child(slot_picker)
	controls.add_child(_label("朝向",18))
	rotation_control = HSlider.new()
	rotation_control.custom_minimum_size.x = 130
	rotation_control.min_value = -180
	rotation_control.max_value = 180
	rotation_control.value_changed.connect(func(value: float) -> void:
		if not updating: slots[slot_picker.selected].rotation_degrees.y = value)
	controls.add_child(rotation_control)
	controls.add_child(_label("粗糙度",18))
	roughness_control = HSlider.new()
	roughness_control.custom_minimum_size.x = 100
	roughness_control.min_value = .05
	roughness_control.max_value = 1
	roughness_control.step = .01
	roughness_control.value_changed.connect(_set_roughness)
	controls.add_child(roughness_control)
	wind_control = CheckButton.new()
	wind_control.text = "植物微风"
	wind_control.add_theme_font_size_override("font_size",18)
	wind_control.toggled.connect(_set_slot_wind)
	controls.add_child(wind_control)
	_control_button(controls,"切换光照",_cycle_light)
	_control_button(controls,"复位视角",_reset_view)
	_control_button(controls,"恢复原材质",func() -> void: _select_path(selected_paths[slot_picker.selected],slot_picker.selected))

func _nav_button(parent: Control, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0,40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",18)
	button.pressed.connect(action)
	parent.add_child(button)

func _control_button(parent: Control, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(108,40)
	button.add_theme_font_size_override("font_size",18)
	button.pressed.connect(action)
	parent.add_child(button)

func _panel_theme() -> Theme:
	var theme := Theme.new()
	var ink := Color("304339")
	var deep := Color("1f2f27")
	var disabled := Color("8b978e")
	for cls: String in ["Button","CheckButton","OptionButton","LineEdit"]:
		theme.set_color("font_color",cls,ink)
		theme.set_color("font_hover_color",cls,deep)
		theme.set_color("font_pressed_color",cls,deep)
		theme.set_color("font_disabled_color",cls,disabled)
	theme.set_color("font_placeholder_color","LineEdit",Color("828f85"))
	var normal := _stylebox(Color("f3f5f0"),Color("bfc8be"))
	var hot := _stylebox(Color("ffffff"),Color("a9b5a9"))
	var pressed := _stylebox(Color("e2e8df"),Color("a9b5a9"))
	var focus := _stylebox(Color("f3f5f0"),Color("6fa392"),2)
	var dim := _stylebox(Color("e4e8e1"),Color("cdd3cb"))
	for cls: String in ["Button","OptionButton","LineEdit"]:
		theme.set_stylebox("normal",cls,normal)
		theme.set_stylebox("hover",cls,hot)
		theme.set_stylebox("pressed",cls,pressed)
		theme.set_stylebox("focus",cls,focus)
		theme.set_stylebox("disabled",cls,dim)
	return theme

func _stylebox(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(5)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box

func _label(value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("304339"))
	return label

func _add_lighting(stage: Node3D, thumbnail: bool = false) -> void:
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	light.shadow_enabled = not thumbnail
	stage.add_child(light)
	if not thumbnail: suns.append(light)

func _refresh_list() -> void:
	list.clear()
	filtered.clear()
	var query := search.text.strip_edges().to_lower()
	var group := category.get_item_text(category.selected)
	for entry: Dictionary in entries:
		if group != "全部" and entry.category != group: continue
		if not query.is_empty() and not query in (entry.name+entry.path+entry.source).to_lower(): continue
		filtered.append(entry)
		var index := list.add_item(entry.name,icons.get(entry.path))
		list.set_item_tooltip(index,entry.source+"\n"+entry.path)
	status.text = "%d / %d 个模型" % [filtered.size(),entries.size()]

func _select_path(path: String, index: int) -> void:
	if path.is_empty(): return
	var resource: Resource = load(path)
	var model: Node3D
	if resource is PackedScene: model = resource.instantiate() as Node3D
	elif resource is Mesh:
		var mesh := MeshInstance3D.new()
		mesh.mesh = resource
		model = mesh
	if model == null:
		status.text = "无法预览："+path.get_file()
		return
	if slot_models[index] != null:
		slots[index].remove_child(slot_models[index])
		slot_models[index].queue_free()
	slots[index].rotation = Vector3.ZERO
	slots[index].add_child(model)
	slot_models[index] = model
	selected_paths[index] = path
	var bounds := _bounds(model)
	var span := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
	model.scale /= maxf(span,.001)
	model.position -= Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)/maxf(span,.001)
	_prepare_review_materials(model,path)
	var triangles := 0
	var surfaces := 0
	for mesh: MeshInstance3D in _meshes(model):
		for surface: int in mesh.mesh.get_surface_count():
			var count: int = mesh.mesh.surface_get_array_index_len(surface)
			if count == 0: count = mesh.mesh.surface_get_array_len(surface)
			triangles += count / 3
			surfaces += 1
	var entry := Catalog.describe(path)
	info_labels[index].text = entry.source+"\n"+entry.name+"   ·   %d 三角 / %d 表面   ·   原尺寸 %.2f × %.2f × %.2f 米" % [triangles,surfaces,bounds.size.x,bounds.size.y,bounds.size.z]+"\n"+path.trim_prefix("res://")
	info_labels[index].tooltip_text = "制作记录："+entry.evidence+"\n单体导入预览；不加载农场行为、场景组合或运行时LOD。"
	_sync_controls()

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and node.mesh != null: result.append(node)
	for child: Node in node.get_children(): result.append_array(_meshes(child))
	return result

func _bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in _meshes(model):
		var box: AABB = model.get_parent().global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func _prepare_review_materials(model: Node3D,path: String) -> void:
	# Duplicate materials so temporary sliders never mutate shared imported resources.
	for mesh: MeshInstance3D in _meshes(model):
		for surface: int in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material != null: mesh.set_surface_override_material(surface,material.duplicate())
	var kind := ""
	if "/greens_pbr/" in path:
		var original: Node3D = ORIGINAL.instantiate()
		original_color = _find_color(original)
		original.free()
		_prepare_candidate(model)
		candidate_materials.clear()
		generated_colors.clear()
		kind = "greens"
	elif "/crops/" in path:
		kind = "greens" if "/greens/" in path else ("radish" if "/radish/" in path else "autumn_crop")
	else:
		for candidate: String in ["tree","bamboo","flowers","lotus","osmanthus","trellis","flowerpot"]:
			if ("/"+candidate+"/") in path: kind = candidate
	if kind.is_empty(): return
	for mesh: MeshInstance3D in _meshes(model):
		for surface: int in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is ShaderMaterial and material.shader == Wind.WIND_SHADER: continue
			if not material is StandardMaterial3D or material.normal_enabled or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return
	Wind.new().apply(model,kind,kind == "greens" and ("mature" in path or "/greens_pbr/" in path))
	for mesh: MeshInstance3D in _meshes(model):
		if "/greens_pbr/" in path: mesh.set_instance_shader_parameter("leaf_roughness_variation",0.0)
		mesh.set_instance_shader_parameter("haze_exempt",1.0)
		var motion: Vector4 = mesh.get_instance_shader_parameter("wind_motion")
		# Wind shader works in world metres; scale motion with the fitted review model.
		motion.x *= model.scale.x
		motion.w *= model.scale.x
		mesh.set_instance_shader_parameter("wind_authored_bend",float(mesh.get_instance_shader_parameter("wind_authored_bend"))*model.scale.x)
		mesh.set_meta("gallery_motion",motion)
		mesh.set_instance_shader_parameter("wind_motion",motion)

func _set_compare(enabled: bool) -> void:
	view_panels[1].visible = enabled
	slot_picker.disabled = not enabled
	if enabled:
		slot_picker.select(1)
		if slot_models[1] == null: _select_path(selected_paths[0],1)
	else: slot_picker.select(0)
	_sync_controls()

func _sync_controls() -> void:
	updating = true
	rotation_control.value = slots[slot_picker.selected].rotation_degrees.y
	var model := slot_models[slot_picker.selected]
	wind_control.disabled = true
	roughness_control.value = .95
	if model != null:
		for mesh: MeshInstance3D in _meshes(model):
			if mesh.has_meta("gallery_motion"):
				wind_control.disabled = false
				wind_control.button_pressed = mesh.get_instance_shader_parameter("wind_motion") != Vector4.ZERO
			var material := mesh.get_active_material(0)
			if material is StandardMaterial3D: roughness_control.value = material.roughness
			elif material is ShaderMaterial: roughness_control.value = material.get_shader_parameter("base_roughness")
	updating = false

func _set_roughness(value: float) -> void:
	if updating or slot_models[slot_picker.selected] == null: return
	for mesh: MeshInstance3D in _meshes(slot_models[slot_picker.selected]):
		mesh.set_instance_shader_parameter("leaf_roughness_variation",0.0)
		for surface: int in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is StandardMaterial3D: material.roughness = value
			elif material is ShaderMaterial: material.set_shader_parameter("base_roughness",value)

func _set_slot_wind(enabled: bool) -> void:
	if updating or slot_models[slot_picker.selected] == null: return
	for mesh: MeshInstance3D in _meshes(slot_models[slot_picker.selected]):
		if mesh.has_meta("gallery_motion"):
			mesh.set_instance_shader_parameter("wind_motion",mesh.get_meta("gallery_motion") if enabled else Vector4.ZERO)
			mesh.set_instance_shader_parameter("wind_authored",1.0 if enabled and mesh.get_meta("plant_wind_kind","") == "osmanthus" else 0.0)

func _reset_view() -> void:
	orbit_yaw = .25
	orbit_pitch = .30
	view_size = 1.5
	view_target = Vector3(0,.45,0)
	dragging = 0
	_update_cameras()

func _make_thumbnails() -> void:
	thumb_view = SubViewport.new()
	thumb_view.size = Vector2i(144,120)
	thumb_view.own_world_3d = true
	thumb_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(thumb_view)
	thumb_root = Node3D.new()
	thumb_view.add_child(thumb_root)
	_add_lighting(thumb_root,true)
	thumb_camera = Camera3D.new()
	thumb_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	thumb_camera.size = 1.45
	thumb_root.add_child(thumb_camera)
	thumb_camera.position = Vector3(1.1,1.0,2)
	thumb_camera.look_at(Vector3(0,.4,0))
	for entry: Dictionary in entries:
		if not is_inside_tree(): return
		var resource: Resource = load(entry.path)
		if not resource is PackedScene: continue
		var model: Node3D = resource.instantiate() as Node3D
		if model == null: continue
		thumb_root.add_child(model)
		var box := _bounds(model)
		var span := maxf(.001,maxf(box.size.x,maxf(box.size.y,box.size.z)))
		model.scale /= span
		model.position -= Vector3(box.get_center().x,box.position.y,box.get_center().z)/span
		thumb_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_inside_tree(): return
		icons[entry.path] = ImageTexture.create_from_image(thumb_view.get_texture().get_image())
		for index: int in filtered.size():
			if filtered[index].path == entry.path: list.set_item_icon(index,icons[entry.path])
		thumb_root.remove_child(model)
		model.queue_free()
		await get_tree().process_frame
	thumb_view.queue_free()
