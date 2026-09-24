extends Node3D
const Generator = preload("res://scenes/procedural_lab/island_generator.gd")
const IslandView = preload("res://scenes/procedural_lab/island_view.gd")
const FarmTheme = preload("res://ui/farm_theme.gd")
var current_plan: Dictionary = {}
var world: Node3D
var camera := Camera3D.new()
var seed_input := LineEdit.new()
var controls: Dictionary = {}
var status := Label.new()
var statistics := Label.new()
var generate_button := Button.new()
var overlay_check := CheckButton.new()
var focus_bridge := Button.new()
var focus_rack := Button.new()
var preset_picker := OptionButton.new()
var target := Vector3.ZERO
var distance: float = 45
var desired_distance: float = 45
var yaw: float = .45
var pitch: float = .72
var dragging: int = 0
var busy: bool = false
var inspect_mode: String = "island"
var panel: PanelContainer

func _ready() -> void:
	DisplayServer.window_set_title("岛屿生成研究室 · 我有一片田")
	Engine.max_fps = 60
	AudioServer.set_bus_mute(0,true)
	# Scene-only launch: no main scene, FarmStore, desktop host or game preference reads.
	if "--dev-preview" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	RenderingServer.global_shader_parameter_set("courtyard_haze_strength",0.0)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_setup_environment()
	_setup_ui()
	await regenerate()
	await RenderingServer.frame_post_draw
	print("PROCEDURAL_LAB_READY seed=%s islands=%d"%[current_plan.seed,current_plan.islands.size()])
	print("DEV_PREVIEW_READY screen=%d mode=%d size=%s"%[DisplayServer.window_get_current_screen(),DisplayServer.window_get_mode(),DisplayServer.window_get_size()])

func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	var sky := WorldEnvironment.new()
	sky.environment = environment
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1000,1000)
	water.mesh = plane
	water.position.y = -.25
	add_child(water)
	var daylight := preload("res://atmosphere/day_night.gd").new()
	add_child(daylight)
	daylight.set_preview_hour(10.5)
	daylight.configure(sun,sky,water)
	daylight.set_process(false)
	water.material_override.set_shader_parameter("wave_strength",.45)
	sun.directional_shadow_max_distance = 140
	RenderingServer.global_shader_parameter_set("courtyard_haze_strength",0.0)
	camera.fov = 42
	camera.far = 1500
	add_child(camera)
	camera.current = true

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = FarmTheme.create()
	layer.add_child(screen)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 20; panel.offset_top = 20; panel.offset_right = 334; panel.offset_bottom = -20
	screen.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = "岛屿生成研究室"
	heading.add_theme_font_size_override("font_size",28)
	column.add_child(heading)
	var intro := Label.new()
	intro.text = "水乡群岛 · 独立试验场景"
	intro.add_theme_font_size_override("font_size",16)
	column.add_child(intro)
	for title: String in ["水乡三岛", "一方小院", "五岛相连", "自定义参数"]: preset_picker.add_item(title)
	preset_picker.set_item_disabled(3,true)
	column.add_child(preset_picker)
	FarmTheme.configure_option(preset_picker)
	preset_picker.item_selected.connect(_preset)
	seed_input.text = "水乡-2026"
	seed_input.placeholder_text = "随机种子：数字或文字"
	seed_input.max_length = 64
	seed_input.custom_minimum_size.y = 38
	seed_input.add_theme_color_override("font_color",Color("353f30"))
	seed_input.add_theme_stylebox_override("normal",FarmTheme.paper(Color("f0eee2"),6))
	column.add_child(seed_input)
	seed_input.text_changed.connect(func(_text: String) -> void: _dirty())
	seed_input.text_submitted.connect(func(_text: String) -> void: regenerate())
	_slider(column,"count","岛屿数量",1,5,1,3)
	_slider(column,"radius","岛屿尺度",6.5,10,.5,Generator.DEFAULTS.radius," 米")
	_slider(column,"coast","岸线变化",0,1,.05,.65)
	_slider(column,"gap","岛间留水",2,7,.5,3," 米")
	_slider(column,"density","植被数量上限",0,28,1,14)
	_slider(column,"bridge_width","桥面宽度",1.1,2.2,.1,1.5," 米")
	_slider(column,"arch","桥面起拱",0,1.2,.1,.65," 米")
	_slider(column,"rack_length","竹架长度",2,4,.25,3," 米")
	_slider(column,"rack_height","竹架高度",1.5,2.8,.1,2.1," 米")
	var actions := HBoxContainer.new()
	column.add_child(actions)
	generate_button.text = "生成岛屿"
	generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_button.pressed.connect(regenerate)
	actions.add_child(generate_button)
	var random_button := Button.new()
	random_button.text = "换个种子"
	random_button.pressed.connect(func() -> void:
		seed_input.text = str(randi_range(100000,99999999))
		regenerate())
	actions.add_child(random_button)
	status.text = ""
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size",16)
	column.add_child(status)
	statistics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	statistics.add_theme_font_size_override("font_size",16)
	column.add_child(statistics)
	overlay_check.text = "显示岸线与占地"
	overlay_check.toggled.connect(func(on: bool) -> void:
		if is_instance_valid(world): world.markers.visible = on)
	column.add_child(overlay_check)
	var copy_button := Button.new()
	copy_button.text = "复制种子与参数"
	copy_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(JSON.stringify({"seed":current_plan.seed,"parameters":current_plan.settings}))
		status.text = "已复制当前画面的种子与参数")
	column.add_child(copy_button)
	var footer := Label.new()
	footer.text = "地表 / 岸石 / 植物：沿用主岛质感\n木桥：Tripo 构件 + 程序拼装\n空间不足时少放设施，优先留通路\n本场景不读写农场存档"
	footer.add_theme_font_size_override("font_size",14)
	column.add_child(footer)
	var top := HBoxContainer.new()
	top.position = Vector2(356,22)
	screen.add_child(top)
	var all := Button.new()
	all.text = "群岛全景"; all.pressed.connect(func() -> void: focus("all"))
	top.add_child(all)
	var island_button := Button.new()
	island_button.text = "近看岛屿"; island_button.pressed.connect(func() -> void: focus("island"))
	top.add_child(island_button)
	focus_bridge.text = "近看桥梁"; focus_bridge.pressed.connect(func() -> void: focus("bridge"))
	top.add_child(focus_bridge)
	focus_rack.text = "近看竹架"; focus_rack.pressed.connect(func() -> void: focus("rack"))
	top.add_child(focus_rack)
	var help := Label.new()
	help.text = "左键拖动旋转  ·  右键 / 中键平移  ·  滚轮缩放  ·  Esc 退出"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 356; help.offset_top = -44; help.offset_bottom = -14
	help.add_theme_font_size_override("font_size",17)
	screen.add_child(help)
	for button: Node in screen.find_children("*","Button",true,false): FarmTheme.pointer_focus(button)

func _slider(parent: Node,key: String,title: String,low: float,high: float,step: float,value: float,suffix: String = "") -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation",0)
	parent.add_child(row)
	var label := Label.new()
	label.add_theme_font_size_override("font_size",17)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low; slider.max_value = high; slider.step = step; slider.value = value
	slider.custom_minimum_size = Vector2(0,24)
	row.add_child(slider)
	controls[key] = slider
	var update := func(v: float) -> void:
		label.text = "%s   %s%s"%[title,str(int(v)) if step>=1 else str(snappedf(v,.01)),suffix]
		_dirty()
	slider.value_changed.connect(update)
	update.call(value)

func _dirty() -> void:
	status.text = "参数已修改，点击「生成岛屿」应用"
	if not current_plan.is_empty(): preset_picker.select(3)

func _preset(index: int) -> void:
	var values: Dictionary = Generator.DEFAULTS.duplicate()
	values.count = [3,1,5][index]
	values.coast = [.65,.35,.9][index]
	for key: String in controls: controls[key].value = values[key]
	preset_picker.select(index)
	regenerate()

func regenerate() -> void:
	if busy: return
	if seed_input.text.strip_edges().is_empty():
		status.text = "请输入一个数字或文字种子"
		return
	busy = true
	dragging = 0
	generate_button.disabled = true
	status.text = "正在生成岸线、连接与庭院…"
	await get_tree().process_frame
	await get_tree().process_frame
	var started: int = Time.get_ticks_msec()
	var options: Dictionary = {}
	for key: String in controls: options[key] = controls[key].value
	var data: Dictionary = Generator.generate(seed_input.text,options)
	if not data.error.is_empty():
		status.text = data.error
	else:
		var next := IslandView.new()
		add_child(next)
		next.build(data)
		if is_instance_valid(world):
			remove_child(world)
			world.queue_free()
		world = next
		current_plan = data
		world.markers.visible = overlay_check.button_pressed
		focus_bridge.disabled = world.bridge_targets.is_empty()
		focus_rack.disabled = world.rack_targets.is_empty()
		focus(inspect_mode)
		statistics.text = "%d 座岛 · %d 座桥 · %d 栋屋\n%d 块菜畦 · %d 座竹架 · %d 簇植被"%[data.islands.size(),data.links.size(),world.counts.get("house",0),world.counts.get("field",0),world.counts.get("rack",0),world.counts.get("tree",0)+world.counts.get("bamboo",0)+world.counts.get("flowers",0)]
		status.text = "已生成 · %.2f 秒 · 种子 %s"%[(Time.get_ticks_msec()-started)/1000.0,data.seed]
	busy = false
	generate_button.disabled = false

func focus(mode: String) -> void:
	inspect_mode = mode
	if mode == "island":
		target = IslandView.v3(current_plan.islands[0].center,.35)
		desired_distance = current_plan.islands[0].bound*2.5
		pitch = .50
	elif mode == "bridge" and not world.bridge_targets.is_empty():
		target = world.bridge_targets[0]
		var link: Dictionary = current_plan.links[0]
		desired_distance = maxf(12,link.start.distance_to(link.end)*2.2)
		pitch = .58
	elif mode == "rack" and not world.rack_targets.is_empty():
		target = world.rack_targets[0]; desired_distance = 10; pitch = .42
	else:
		inspect_mode = "all"
		var bounds := Rect2(current_plan.islands[0].center,Vector2.ZERO)
		for island: Dictionary in current_plan.islands:
			bounds = bounds.expand(island.center-Vector2.ONE*island.bound)
			bounds = bounds.expand(island.center+Vector2.ONE*island.bound)
		target = IslandView.v3(bounds.get_center())
		desired_distance = maxf(28,bounds.size.length()*1.08)
		pitch = .78
	distance = desired_distance
	_update_camera()

func _process(delta: float) -> void:
	distance = lerpf(distance,desired_distance,1-exp(-delta*10))
	_update_camera()

func _update_camera() -> void:
	var offset := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.position = target+offset
	camera.look_at(target)
	# Place the subject in the unobscured portion of the full-width viewport.
	camera.h_offset = -distance*.075

func _input(event: InputEvent) -> void:
	# Releases must end a gesture even when the pointer has crossed into the panel.
	if event is InputEventMouseButton and not event.pressed: dragging = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]: dragging = event.button_index
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: desired_distance = maxf(4,desired_distance*.88)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: desired_distance = minf(180,desired_distance/ .88)
	if event is InputEventMouseMotion and dragging != 0:
		if dragging == MOUSE_BUTTON_LEFT:
			yaw -= event.relative.x*.005
			pitch = clampf(pitch+event.relative.y*.004,.16,1.42)
		else:
			target += (-camera.basis.x*event.relative.x+Vector3(camera.basis.z.x,0,camera.basis.z.z).normalized()*event.relative.y)*distance*.0011

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		dragging = 0

func _resize() -> void:
	dragging = 0
	get_viewport().scaling_3d_scale = minf(1.0,1080.0/maxf(1,DisplayServer.window_get_size().y))
