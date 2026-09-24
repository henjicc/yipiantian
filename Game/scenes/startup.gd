extends CanvasLayer
## Lightweight entry: preferences, threaded resources, staged construction,
## first-run measurement/choice, then ownership passes to the farm scene.

const FarmTheme = preload("res://ui/farm_theme.gd")
const Settings = preload("res://settings/settings_store.gd")
const Presets = preload("res://settings/graphics_presets.gd")
const Benchmark = preload("res://settings/startup_benchmark.gd")
const FARM: String = "res://scenes/main.tscn"
var settings_store: Settings
var farm_store: RefCounted
var farm_scene: Node3D
var _loaded: Dictionary
var _first: bool = false
var _recording: bool = false
var _loading: bool = false
var _resource_worker: Thread
var _packed: PackedScene
var _status: Label
var _progress: ProgressBar
var _choices: VBoxContainer
const SLIDER_TIERS: Array[String] = ["low", "standard", "high"]
var _slider: HSlider
var _tier_labels: Array[Label] = []
var _continue: Button
var _unsaved_continue: Button
var _retry: Button
var _recommendation: Label
var _selected: String = "standard"
var _recommended: String = "standard"
var _measured: bool = false
var _starting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().min_size = Vector2i(960, 600)
	if OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	_build_ui()
	_begin.call_deferred()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Loading"
	root.theme = FarmTheme.create()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var background := ColorRect.new()
	background.color = FarmTheme.PAPER
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 560
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "我有一片田"
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_status = Label.new()
	_status.name = "Stage"
	_status.text = "正在读取设置…"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_progress = ProgressBar.new()
	_progress.name = "Progress"
	_progress.custom_minimum_size.y = 8
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", FarmTheme.paper(FarmTheme.EDGE, 4))
	_progress.add_theme_stylebox_override("fill", FarmTheme.paper(FarmTheme.LEAF, 4))
	column.add_child(_progress)
	_choices = VBoxContainer.new()
	_choices.name = "QualityChoices"
	column.add_child(_choices)
	_recommendation = Label.new()
	_recommendation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recommendation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choices.add_child(_recommendation)
	_slider = HSlider.new()
	_slider.name = "QualitySlider"
	_slider.min_value = 0
	_slider.max_value = 2
	_slider.step = 1
	_slider.tick_count = 3
	_slider.ticks_on_borders = true
	_slider.custom_minimum_size.y = 40
	_slider.mouse_force_pass_scroll_events = false
	_choices.add_child(_slider)
	var labels := HBoxContainer.new()
	_choices.add_child(labels)
	for index: int in 3:
		var label := Label.new()
		label.text = ["低", "中", "高"][index]
		label.horizontal_alignment = [HORIZONTAL_ALIGNMENT_LEFT, HORIZONTAL_ALIGNMENT_CENTER, HORIZONTAL_ALIGNMENT_RIGHT][index]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.add_child(label)
		_tier_labels.append(label)
	_slider.value_changed.connect(_select_slider)
	_continue = Button.new()
	_continue.text = "进入农场"
	_continue.custom_minimum_size.y = 52
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var fill: Color = FarmTheme.INK.lightened(.1) if state == "hover" else FarmTheme.INK
		_continue.add_theme_stylebox_override(state, FarmTheme.framed_paper(fill, true))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_continue.add_theme_color_override(state, FarmTheme.PAPER)
	_choices.add_child(_continue)
	_continue.pressed.connect(_confirm)
	_unsaved_continue = Button.new()
	_unsaved_continue.text = "本次使用，不保存"
	_unsaved_continue.custom_minimum_size.y = 44
	_choices.add_child(_unsaved_continue)
	_unsaved_continue.hide()
	_unsaved_continue.pressed.connect(func() -> void:
		if _starting: return
		_starting = true
		_choices.hide()
		_progress.show()
		_apply_tier(_selected)
		while farm_scene._high_quality_pending: await get_tree().process_frame
		await _finish())
	_choices.hide()
	_retry = Button.new()
	_retry.text = "重试加载"
	_retry.custom_minimum_size.y = 44
	column.add_child(_retry)
	_retry.pressed.connect(_request_resources)
	_retry.hide()
	var notice := Label.new()
	notice.name = "DevelopmentNotice"
	notice.text = "当前为开发中试玩版，可能存在较多问题，\n内容与体验仍在完善。"
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 17)
	column.add_child(notice)


func _begin() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--record-session="): _recording = true
	if not _recording:
		if settings_store == null: settings_store = Settings.new()
		_loaded = settings_store.load_settings()
		_first = _loaded.ok and _loaded.kind == "first"
		if _first:
			var memory: Dictionary = OS.get_memory_info()
			_recommended = Presets.recommend(RenderingServer.get_video_adapter_type(), int(memory.get("physical", 0)), OS.get_processor_count(), get_window().size.x * get_window().size.y)
	await show_stage(3.0, "正在加载模型与贴图…")
	_request_resources()


func _request_resources() -> void:
	if _loading or is_instance_valid(farm_scene): return
	_retry.hide()
	_status.text = "正在加载模型与贴图…"
	_progress.indeterminate = true
	_resource_worker = Thread.new()
	# In 4.7.2 load_threaded_request leaks LoadToken objects with this scene's
	# dependency graph. A single owned worker with synchronous resource loading
	# avoids that path; scene instantiation remains on the main thread.
	var error: Error = _resource_worker.start(func() -> Resource: return ResourceLoader.load(FARM, "PackedScene"))
	if error != OK:
		_resource_worker = null
		_fail("农场资源未能开始加载，请重试。", "request_%d" % error)
		return
	_loading = true


func _process(_delta: float) -> void:
	if not _loading or _resource_worker.is_alive(): return
	var resource: Resource = _resource_worker.wait_to_finish()
	_resource_worker = null
	_loading = false
	_progress.indeterminate = false
	if not resource is PackedScene:
		_fail("农场资源加载失败，请重试。", "resource_failed")
		return
	_packed = resource
	_assemble.call_deferred()


func _exit_tree() -> void:
	if _resource_worker != null and _resource_worker.is_started():
		_resource_worker.wait_to_finish()


func show_stage(value: float, message: String) -> void:
	_progress.value = value
	_status.text = message
	print("STARTUP_STAGE progress=%.0f text=%s" % [value, message])
	# Two frame boundaries let Control layout and the renderer present this stage
	# before the next synchronous geometry batch starts.
	await get_tree().process_frame
	await get_tree().process_frame


func _assemble() -> void:
	await show_stage(45.0, "正在读取农场存档…")
	var packed: PackedScene = _packed
	_packed = null
	if packed == null:
		_fail("农场场景无法打开，请重试。", "scene_missing")
		return
	farm_scene = packed.instantiate()
	farm_scene.process_mode = Node.PROCESS_MODE_DISABLED
	farm_scene.startup_progress = show_stage
	if not _recording:
		farm_scene.settings_store = settings_store
		farm_scene.startup_preferences = _loaded
	if farm_store != null: farm_scene.store = farm_store
	get_tree().root.add_child(farm_scene)
	if not farm_scene.startup_complete: await farm_scene.startup_finished
	farm_scene.startup_progress = Callable()
	farm_scene.get_node("Environment").startup_progress = Callable()
	farm_scene.process_mode = Node.PROCESS_MODE_INHERIT
	farm_scene.set_process_input(false)
	farm_scene.set_process_unhandled_input(false)
	farm_scene.camera.free_input_enabled = false
	if _first:
		await _measure()
		_show_choice()
	else:
		await _finish()


func _apply_tier(tier: String) -> void:
	var previous: Dictionary = farm_scene.settings_values.duplicate(true)
	farm_scene.settings_values.merge(Presets.values(tier, get_window().size.y, RenderingServer.get_current_rendering_method() == "forward_plus"), true)
	farm_scene._apply_settings(previous)


func _measure() -> void:
	await show_stage(96.0, "正在进行首次性能测试，约需几秒…")
	if not farm_scene._loaded or DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return
	var old_vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	farm_scene.window_activity.set_startup_benchmark(true)
	_apply_tier("standard")
	var result: Dictionary = await Benchmark.sample(get_tree(), get_window())
	if result.ok:
		_measured = true
		if result.p90_ms > 22.2:
			_recommended = "low"
		elif result.p90_ms <= 16.7:
			await show_stage(97.0, "正在检查高画质表现…")
			_apply_tier("high")
			while farm_scene._high_quality_pending: await get_tree().process_frame
			var high: Dictionary = await Benchmark.sample(get_tree(), get_window())
			print("STARTUP_BENCHMARK_HIGH result=%s" % str(high))
			_recommended = "high" if high.ok and high.p90_ms <= 20.0 else "standard"
		else:
			_recommended = "standard"
	print("STARTUP_BENCHMARK result=%s recommendation=%s" % [str(result), _recommended])
	farm_scene.window_activity.set_startup_benchmark(false)
	DisplayServer.window_set_vsync_mode(old_vsync)


func _show_choice() -> void:
	_status.text = "为你的农场选择画质"
	_progress.hide()
	_selected = _recommended
	var index: int = Presets.ORDER.find(_recommended)
	_recommendation.text = ("根据刚才的运行表现，推荐%s。" if _measured else "本次未取得稳定测试结果，先推荐%s。") % Presets.TITLES[index]
	_recommendation.text += "\n之后可以在设置中调整。"
	_slider.set_value_no_signal(SLIDER_TIERS.find(_recommended))
	_select_slider(_slider.value)
	_choices.show()
	_slider.grab_focus()
	print("STARTUP_CHOICE_READY recommendation=%s measured=%s" % [_recommended, _measured])


func _select_slider(value: float) -> void:
	_selected = SLIDER_TIERS[int(value)]
	for index: int in _tier_labels.size():
		_tier_labels[index].add_theme_color_override("font_color", FarmTheme.INK if index == int(value) else FarmTheme.Tokens.MUTED)


func _confirm() -> void:
	if _starting: return
	_starting = true
	_choices.hide()
	_progress.show()
	await show_stage(98.0, "正在应用所选画质…")
	_apply_tier(_selected)
	while farm_scene._high_quality_pending: await get_tree().process_frame
	farm_scene._settings_dirty = true
	if not farm_scene._save_settings():
		_starting = false
		_choices.show()
		_progress.hide()
		_status.text = "画质已应用，但设置未能保存，请重试。"
		_continue.text = "重试保存并进入农场"
		_unsaved_continue.show()
		_continue.grab_focus()
		return
	await _finish()


func _finish() -> void:
	await show_stage(99.0, "正在准备进入农场…")
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	_progress.value = 100
	get_tree().current_scene = farm_scene
	farm_scene.set_process_input(true)
	farm_scene.set_process_unhandled_input(true)
	farm_scene.camera.free_input_enabled = true
	if OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview"):
		farm_scene._report_preview_ready.call_deferred()
	print("STARTUP_COMPLETE")
	queue_free()


func _fail(message: String, reason: String) -> void:
	_progress.indeterminate = false
	_status.text = message
	_retry.show()
	_retry.grab_focus()
	push_warning("STARTUP_FAILED stage=" + reason)
