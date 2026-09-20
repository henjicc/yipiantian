extends CanvasLayer
## The scene applies preferences and owns saving. This modal only presents intent.

signal settings_changed(value: Dictionary)
signal save_requested
signal close_requested
signal quit_requested
signal wallpaper_requested
signal developer_requested(action: String)

const FarmTheme = preload("res://ui/farm_theme.gd")
const QUALITY_VALUES: Array[String] = ["standard", "low", "high"]
const RESOLUTION_VALUES: Array[String] = ["native", "1080", "1440", "2160"]
var _root: Control
var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _sliders: Dictionary = {}
var _volume_labels: Dictionary = {}
var _window: OptionButton
var _quality: OptionButton
var _resolution: OptionButton
var _sway: Button
var _sway_delay: SpinBox
var _dof: Button
var _status: Label
var _close: Button
var _quit: Button
var _retry: Button
var _developer_buttons: Dictionary = {}
var _wallpaper: Button
var _values: Dictionary = {}
var _populating: bool = false
var _page_index: int = 0
var _paper: PanelContainer
var _quit_confirmation: PanelContainer
var _keep_playing: Button


func _ready() -> void:
	layer = 30
	_root = Control.new()
	_root.name = "Modal"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = FarmTheme.create()
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.15, 0.20, 0.15, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var panel := PanelContainer.new()
	_paper = panel
	panel.name = "Paper"
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -275
	panel.offset_bottom = 275
	var style: StyleBox = FarmTheme.framed_paper()
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	var titles: Array[String] = ["音量", "显示", "操作", "关于"]
	if OS.is_debug_build() and OS.has_feature("editor"):
		titles.append("开发者")
	for title: String in titles:
		var tab: Button = _button(tabs, title)
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index: int = _tabs.size()
		tab.pressed.connect(func() -> void: _show_page(index))
		_tabs.append(tab)
	var content := Control.new()
	content.name = "Pages"
	content.custom_minimum_size = Vector2(560, 340)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	var settings := VBoxContainer.new()
	content.add_child(settings)
	settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages.append(settings)
	for entry: Array in [["master", "总音量"], ["music", "音乐"], ["effects", "音效"]]:
		var row: HBoxContainer = _row(settings, entry[1])
		var slider := HSlider.new()
		slider.name = entry[0].capitalize()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(250, 42)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var number := Label.new()
		number.custom_minimum_size.x = 62
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(number)
		_sliders[entry[0]] = slider
		_volume_labels[entry[0]] = number
		var key: String = entry[0]
		slider.value_changed.connect(func(value: float) -> void:
			number.text = "%d%%" % roundi(value)
			_change(key, value / 100.0))
	var display := VBoxContainer.new()
	display.name = "Display"
	content.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages.append(display)
	_window = OptionButton.new()
	_window.name = "WindowMode"
	_window.add_item("窗口")
	_window.add_item("全屏")
	FarmTheme.configure_option(_window)
	_window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_window.custom_minimum_size.y = 42
	_row(display, "窗口模式").add_child(_window)
	_window.item_selected.connect(func(index: int) -> void: _change("fullscreen", index == 1))
	_resolution = OptionButton.new()
	_resolution.name = "RenderResolution"
	for title: String in ["原生（最清晰）", "1080p", "1440p", "2160p（4K）"]:
		_resolution.add_item(title)
	FarmTheme.configure_option(_resolution)
	_resolution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resolution.custom_minimum_size.y = 42
	_row(display, "分辨率").add_child(_resolution)
	_resolution.item_selected.connect(func(index: int) -> void: _change("resolution", RESOLUTION_VALUES[index]))
	_quality = OptionButton.new()
	_quality.name = "Quality"
	_quality.add_item("标准")
	_quality.add_item("低画质")
	_quality.add_item("高画质")
	FarmTheme.configure_option(_quality)
	_quality.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quality.custom_minimum_size.y = 42
	_row(display, "画质").add_child(_quality)
	_quality.item_selected.connect(func(index: int) -> void:
		_change("quality", QUALITY_VALUES[index])
		_refresh_dof())
	_dof = _button(_row(display, "景深"), "开启")
	_dof.name = "DepthOfField"
	_dof.toggle_mode = true
	_dof.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dof.toggled.connect(func(enabled: bool) -> void:
		_change("dof_enabled", enabled)
		_refresh_dof())
	_sway = _button(_row(display, "轻微晃动"), "已关闭")
	_sway.name = "CameraSway"
	_sway.toggle_mode = true
	_sway.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sway.toggled.connect(func(enabled: bool) -> void:
		_change("sway_enabled", enabled)
		_refresh_sway())
	_sway_delay = SpinBox.new()
	_sway_delay.name = "SwayIdleSeconds"
	_sway_delay.min_value = 0
	_sway_delay.max_value = 600
	_sway_delay.step = 1
	_sway_delay.suffix = "秒"
	var delay_edit: LineEdit = _sway_delay.get_line_edit()
	delay_edit.add_theme_stylebox_override("normal", FarmTheme.framed_paper())
	delay_edit.add_theme_stylebox_override("read_only", FarmTheme.framed_paper())
	delay_edit.add_theme_color_override("font_color", FarmTheme.INK)
	delay_edit.add_theme_color_override("font_uneditable_color", FarmTheme.INK.lightened(.3))
	_sway_delay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sway_delay.custom_minimum_size.y = 42
	_row(display, "空闲后晃动").add_child(_sway_delay)
	_sway_delay.value_changed.connect(func(value: float) -> void: _change("sway_idle_seconds", roundi(value)))
	_wallpaper = _button(_row(display, "桌面"), "设为桌面壁纸")
	_wallpaper.name = "DesktopWallpaper"
	_wallpaper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallpaper.tooltip_text = "在当前屏幕安静展示农场；双击系统托盘图标返回游戏。"
	_wallpaper.pressed.connect(func() -> void: wallpaper_requested.emit())
	var operations: RichTextLabel = _text_page(content, "操作说明")
	operations.text = "[b]照料田地[/b]\n空手点击田格展开菜单，选择动作；播种时再选蔬菜。点空白、右键或 Esc 关闭菜单。门前种子篮、锄头、水壶可拿起对应工具，再点击土地连续操作；底部种植／工具按钮展开横排选择。拿着种子时滚轮换菜，右键、Esc 或取消按钮放下工具。每轮可浇水一次，不同作物节省的生长时间不同；成熟收获一篮。\n\n[b]照料菜架[/b]\n点击架脚的种植位靠近，再点种植位播种丝瓜；也可点藤蔓或果实浇水、收获。扩架增加位置，缩架前先收获会被移除的作物。\n\n[b]观察院落[/b]\n放下种子后滚轮缩放。点击田块靠近，向后滚轮返回聚焦前的机位；中键拖动转动视角，Shift＋中键平移。\n\n[b]返回与布置[/b]\n右键或 Esc 先放下工具，再清除选格、返回全景。“建设”内选择土地、建筑或摆件：选装饰、点空位，再确认；旋转适用于地面装饰。\n\n作物按现实时间生长。离开后再次进入，会继续上次的农场。"
	var sources: RichTextLabel = _text_page(content, "关于")
	sources.text = "[b]我有一片田[/b]\n图像：OpenAI 图像生成，依项目定稿参考制作。\n模型草案：Tripo；模型整理与补制：Blender。\n场景、界面与交互：Godot。\n音乐、环境声与操作声：项目内合成制作。\n\n[b]中文字体[/b]\n汇文明朝体 · Huiwen-mincho\n原字体随游戏内置，无需安装。\n字体内版权标记：Public Domain。"
	if OS.is_debug_build() and OS.has_feature("editor"):
		var developer := VBoxContainer.new()
		developer.name = "Developer"
		developer.add_theme_constant_override("separation", 10)
		content.add_child(developer)
		developer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pages.append(developer)
		for entry: Array in [["camera_tuning", "相机调节"], ["free_camera", "自由视角"], ["models", "模型检查"], ["time", "昼夜预览"]]:
			var button := _button(developer, entry[1])
			button.name = entry[0]
			_developer_buttons[entry[0]] = button
			button.pressed.connect(func() -> void: developer_requested.emit(entry[0]))
	_status = Label.new()
	_status.name = "SettingsStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 17)
	column.add_child(_status)
	_retry = _button(column, "重试保存")
	_retry.name = "RetrySettings"
	_retry.pressed.connect(func() -> void: save_requested.emit())
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_quit = _button(actions, "退出游戏")
	_quit.name = "QuitGame"
	_quit.custom_minimum_size.x = 180
	_style_exit(_quit)
	_quit.pressed.connect(func() -> void:
		_paper.hide()
		_quit_confirmation.show()
		_keep_playing.grab_focus())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_close = _button(actions, "返回农场")
	_close.name = "ReturnToFarm"
	_close.custom_minimum_size.x = 180
	_close.pressed.connect(func() -> void: close_requested.emit())
	_build_quit_confirmation()
	_show_page(0)
	hide()


func present(value: Dictionary, message: String = "") -> void:
	cancel_quit_confirmation()
	_values = value.duplicate(true)
	_populating = true
	for key: String in _sliders:
		_sliders[key].set_value_no_signal(roundf(float(value[key]) * 100.0))
		_volume_labels[key].text = "%d%%" % roundi(float(value[key]) * 100.0)
	_window.select(1 if value.fullscreen else 0)
	_quality.select(QUALITY_VALUES.find(value.quality))
	_resolution.select(RESOLUTION_VALUES.find(value.resolution))
	_refresh_dof()
	_refresh_sway()
	_sway_delay.set_value_no_signal(value.sway_idle_seconds)
	_populating = false
	set_status(message)
	_show_page(0)
	show()
	_refresh_focus_chain(0)
	_tabs[0].grab_focus()


func set_status(message: String, can_leave_unsaved: bool = false) -> void:
	_status.text = message
	_status.visible = not message.is_empty()
	_retry.visible = can_leave_unsaved
	_close.text = "暂不保存，返回" if can_leave_unsaved else "返回农场"
	_quit.text = "仍然退出" if can_leave_unsaved else "退出游戏"
	_refresh_focus_chain(_page_index)


func dismiss() -> void:
	cancel_quit_confirmation()
	_window.get_popup().hide()
	_quality.get_popup().hide()
	_resolution.get_popup().hide()
	hide()


func _refresh_sway() -> void:
	_sway.set_pressed_no_signal(_values.sway_enabled)
	_sway.text = "已开启" if _values.sway_enabled else "已关闭"
	_sway_delay.editable = _values.sway_enabled


func _refresh_dof() -> void:
	if _values.is_empty():
		return
	_dof.set_pressed_no_signal(_values.dof_enabled)
	_dof.text = ("已开启" if _values.dof_enabled else "已关闭") + (" · 低画质暂不启用" if _values.quality == "low" else "")


func _change(key: String, value: Variant) -> void:
	if _populating:
		return
	if _values.get(key) == value: return
	_values[key] = value
	settings_changed.emit(_values.duplicate(true))


func _show_page(index: int) -> void:
	_page_index = index
	_window.get_popup().hide()
	_quality.get_popup().hide()
	_resolution.get_popup().hide()
	for page: int in _pages.size():
		_pages[page].visible = page == index
		_tabs[page].set_pressed_no_signal(page == index)
	_refresh_focus_chain(index)


func _refresh_focus_chain(index: int) -> void:
	# A Control modal blocks pointer input, but default keyboard traversal may still
	# reach HUD buttons. Explicit wrapping keeps both Tab and arrows in this menu.
	var controls: Array[Control] = []
	for tab: Button in _tabs:
		controls.append(tab)
	_collect_focus(_pages[index], controls)
	if _retry.visible: controls.append(_retry)
	controls.append_array([_quit, _close])
	for position: int in controls.size():
		var control: Control = controls[position]
		control.focus_mode = Control.FOCUS_ALL
		var previous: NodePath = control.get_path_to(controls[(position - 1 + controls.size()) % controls.size()])
		var next: NodePath = control.get_path_to(controls[(position + 1) % controls.size()])
		control.focus_previous = previous
		control.focus_next = next
		control.focus_neighbor_left = previous
		control.focus_neighbor_top = previous
		control.focus_neighbor_right = next
		control.focus_neighbor_bottom = next


func _text_page(parent: Control, node_name: String) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.name = node_name
	text.bbcode_enabled = true
	text.selection_enabled = true
	text.add_theme_color_override("default_color", FarmTheme.INK)
	text.add_theme_constant_override("line_separation", 5)
	parent.add_child(text)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pages.append(text)
	return text


func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 108
	row.add_child(label)
	return row


func _button(parent: Control, title: String) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	FarmTheme.pointer_focus(button)
	parent.add_child(button)
	return button

func _collect_focus(node: Node, controls: Array[Control]) -> void:
	if node is BaseButton or node is Range or node is RichTextLabel:
		controls.append(node)
	for child: Node in node.get_children():
		_collect_focus(child, controls)


func show_free_view(active: bool) -> void:
	if _developer_buttons.has("free_camera"):
		_developer_buttons.free_camera.text = "退出自由视角" if active else "自由视角"


func _style_exit(button: Button) -> void:
	for state: String in ["hover", "pressed", "hover_pressed"]:
		var style := FarmTheme.framed_paper(FarmTheme.Tokens.DANGER_HOVER if state == "hover" else FarmTheme.Tokens.DANGER_PRESSED)
		style.set("edge", FarmTheme.Tokens.DANGER)
		button.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, FarmTheme.Tokens.DANGER)
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus").duplicate()
	focus.border_color = FarmTheme.Tokens.DANGER
	button.add_theme_stylebox_override("focus", focus)


func _build_quit_confirmation() -> void:
	_quit_confirmation = PanelContainer.new()
	_quit_confirmation.name = "QuitConfirmation"
	_root.add_child(_quit_confirmation)
	_quit_confirmation.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_quit_confirmation.offset_left = -230
	_quit_confirmation.offset_right = 230
	_quit_confirmation.offset_top = -80
	_quit_confirmation.offset_bottom = 80
	var column := VBoxContainer.new()
	_quit_confirmation.add_child(column)
	var label := Label.new()
	label.text = "确定退出游戏？"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(label)
	var row := HBoxContainer.new()
	column.add_child(row)
	var confirm := _button(row, "确认退出")
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_exit(confirm)
	confirm.pressed.connect(func() -> void:
		cancel_quit_confirmation()
		quit_requested.emit())
	_keep_playing = _button(row, "继续游戏")
	_keep_playing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keep_playing.pressed.connect(cancel_quit_confirmation)
	for pair: Array in [[confirm, _keep_playing], [_keep_playing, confirm]]:
		var path: NodePath = pair[0].get_path_to(pair[1])
		for property: String in ["focus_next", "focus_previous", "focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom"]:
			pair[0].set(property, path)
	_quit_confirmation.hide()


func cancel_quit_confirmation() -> bool:
	if not _quit_confirmation.visible: return false
	_quit_confirmation.hide()
	_paper.show()
	_quit.grab_focus()
	return true
