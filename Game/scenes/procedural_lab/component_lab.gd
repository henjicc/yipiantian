extends "res://scenes/procedural_lab/procedural_lab.gd"
const RailingKit = preload("res://scenes/procedural_lab/railing_kit.gd")
var kind: String = "railing"
var kind_picker := OptionButton.new()
var parameter_box: VBoxContainer
var compare_check := CheckButton.new()
var export_button := Button.new()
var generation_ms: float = 0

func _ready() -> void:
	# Island-only controls are constructed by the inherited script, but never used
	# or parented in this scene. Release them before creating the component panel.
	for unused: Control in [overlay_check,focus_bridge,focus_rack,preset_picker]: unused.free()
	DisplayServer.window_set_title("构件生成研究室 · 我有一片田")
	Engine.max_fps = 60
	AudioServer.set_bus_mute(0,true)
	if "--dev-preview" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_setup_environment()
	_setup_ui()
	await regenerate()
	await RenderingServer.frame_post_draw
	print("COMPONENT_LAB_READY kind=%s seed=%s"%[kind,current_plan.seed])
	print("DEV_PREVIEW_READY screen=%d mode=%d size=%s"%[DisplayServer.window_get_current_screen(),DisplayServer.window_get_mode(),DisplayServer.window_get_size()])

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
	panel.offset_left=20; panel.offset_top=20; panel.offset_right=334; panel.offset_bottom=-20
	screen.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	var title := Label.new()
	title.text="构件生成研究室"
	title.add_theme_font_size_override("font_size",28)
	column.add_child(title)
	for text: String in ["木栏杆","竹架"]: kind_picker.add_item(text)
	column.add_child(kind_picker)
	FarmTheme.configure_option(kind_picker)
	kind_picker.item_selected.connect(_select_kind)
	seed_input.text="水乡木作-26"; seed_input.max_length=64
	seed_input.placeholder_text="输入文字或数字种子"
	seed_input.custom_minimum_size.y=38
	seed_input.add_theme_color_override("font_color",Color("353f30"))
	seed_input.add_theme_stylebox_override("normal",FarmTheme.paper(Color("f0eee2"),6))
	column.add_child(seed_input)
	seed_input.text_changed.connect(func(_value: String) -> void: _dirty())
	seed_input.text_submitted.connect(func(_value: String) -> void: regenerate())
	parameter_box=VBoxContainer.new()
	parameter_box.add_theme_constant_override("separation",10)
	column.add_child(parameter_box)
	_populate_parameters()
	var actions := HBoxContainer.new()
	column.add_child(actions)
	generate_button.text="重新生成"
	generate_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	generate_button.pressed.connect(regenerate)
	actions.add_child(generate_button)
	var random_button := Button.new()
	random_button.text="换个种子"
	random_button.pressed.connect(func() -> void:
		seed_input.text=str(randi_range(100000,99999999))
		regenerate())
	actions.add_child(random_button)
	compare_check.text="并排对比三种结构"
	compare_check.toggled.connect(func(_value: bool) -> void: regenerate())
	column.add_child(compare_check)
	export_button.text="复制当前生成参数"
	export_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(JSON.stringify({"version":1,"kind":kind,"seed":current_plan.seed,"parameters":current_plan.settings,"comparison":current_plan.comparison}))
		status.text="已复制当前画面的种子与参数")
	column.add_child(export_button)
	for label: Label in [status,statistics]:
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size",16)
		column.add_child(label)
	var provenance := Label.new()
	provenance.text="木柱：复用 Tripo 成果\n竹节与绑绳：Blender 构件\n主岛日光 · 本地生成"
	provenance.add_theme_font_size_override("font_size",15)
	column.add_child(provenance)
	var top := HBoxContainer.new()
	top.position=Vector2(356,22)
	screen.add_child(top)
	for item: Array in [["完整观察","all"],["近看接头","joint"],["转到背面","reverse"]]:
		var button := Button.new()
		button.text=item[0]
		button.pressed.connect(focus.bind(item[1]))
		top.add_child(button)
	var help := Label.new()
	help.text="左键旋转  ·  右键 / 中键平移  ·  滚轮缩放  ·  Esc 退出"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left=356; help.offset_top=-42; help.offset_bottom=-12
	help.add_theme_font_size_override("font_size",17)
	screen.add_child(help)
	for button: Node in screen.find_children("*","Button",true,false): FarmTheme.pointer_focus(button)

func _populate_parameters() -> void:
	for child: Node in parameter_box.get_children():
		parameter_box.remove_child(child); child.queue_free()
	controls.clear()
	_slider(parameter_box,"length","长度",2.4,8,.2,5.4," 米")
	if kind == "railing":
		_slider(parameter_box,"height","栏高",.7,1.4,.05,1.05," 米")
		_slider(parameter_box,"path","走向：直线 / 转角 / 折线",0,2,1,1)
	else:
		_slider(parameter_box,"height","架高",1.6,2.8,.1,2.1," 米")
		_slider(parameter_box,"width","架宽",1,3,.1,1.8," 米")
	_slider(parameter_box,"bay","最大开间",.8,1.8,.1,1.35," 米")
	_slider(parameter_box,"slope","地面坡度",-.18,.18,.02,0)

func _select_kind(index: int) -> void:
	kind=["railing","rack"][index]
	kind_picker.select(index)
	_populate_parameters()
	regenerate()

func _dirty() -> void:
	status.text="调整后点击「重新生成」"

func regenerate() -> void:
	if busy: return
	if seed_input.text.strip_edges().is_empty():
		status.text="请输入文字或数字种子"
		return
	busy=true; dragging=0; generate_button.disabled=true
	status.text="正在组合构件…"
	await get_tree().process_frame
	var start: int=Time.get_ticks_usec()
	var options: Dictionary={}
	for key: String in controls: options[key]=controls[key].value
	var data: Dictionary=RailingKit.plan(seed_input.text,options,kind)
	data.comparison=[]
	var next := Node3D.new()
	var count: int=3 if compare_check.button_pressed else 1
	for i: int in count:
		var sample: Dictionary=data
		if count == 3:
			var variant: Dictionary=options.duplicate()
			if kind == "railing": variant.path=i
			else:
				variant.length=[2.8,4.6,6.8][i]; variant.width=[1.2,1.8,2.6][i]
			sample=RailingKit.plan(seed_input.text,variant,kind)
			data.comparison.append(sample.settings)
		var holder := Node3D.new()
		holder.position.z=(i-1)*6.0 if count == 3 else 0.0
		holder.position.y=_stage_height(sample.settings)
		holder.add_child(RailingKit.build(sample))
		holder.add_child(_ground(sample.settings))
		if count == 3:
			var label := Label3D.new()
			label.font=preload("res://art/ui/fonts/汇文明朝体.ttf")
			label.text=["直线","转角","折线"][i] if kind == "railing" else ["短窄架","标准架","宽长架"][i]
			label.font_size=48; label.pixel_size=.007
			label.position=Vector3(0,sample.settings.height+.55,0)
			label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
			label.modulate=Color("353f30"); label.outline_modulate=Color("ecebd8")
			holder.add_child(label)
		next.add_child(holder)
	add_child(next)
	if is_instance_valid(world):
		remove_child(world); world.queue_free()
	world=next; current_plan=data
	generation_ms=(Time.get_ticks_usec()-start)/1000.0
	focus("all")
	status.text="已生成 · %.0f 毫秒 · 种子 %s"%[generation_ms,data.seed]
	statistics.text="%d 组结构\n相同部件共享网格与贴图\n远处省略竹节与绑绳细节"%count
	busy=false; generate_button.disabled=false

func _ground(p: Dictionary) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size=Vector2(p.length+1.4,maxf(p.width+1.2,p.length*.7))
	var node := MeshInstance3D.new()
	node.mesh=mesh
	# Shear the stage to the exact same height function used by the feet.
	node.basis=Basis(Vector3(1,p.slope,0),Vector3.UP,Vector3.BACK)
	node.position.y=.13
	var material := ShaderMaterial.new()
	material.shader=preload("res://scenes/environment/pigment.gdshader")
	material.set_shader_parameter("base_color",Color("918566"))
	material.set_shader_parameter("ground_treatment",1.0)
	node.material_override=material
	return node

func _stage_height(p: Dictionary) -> float:
	return absf(p.slope)*(p.length+1.4)*.5

func focus(mode: String) -> void:
	if current_plan.is_empty(): return
	if mode == "reverse":
		yaw+=PI
	else:
		var p: Dictionary=current_plan.settings
		if mode == "joint":
			var at: Vector3=current_plan.points[mini(1,current_plan.points.size()-1)]
			target=at+Vector3(0,_stage_height(p)+p.height*.75,p.width*.41 if kind == "rack" else 0)
			desired_distance=3.5; pitch=.30
		else:
			target=Vector3(0,_stage_height(p)+p.height*.4,0)
			desired_distance=26 if compare_check.button_pressed else maxf(9,p.length*1.75)
			pitch=.55; yaw=.65
		distance=desired_distance
	_update_camera()
