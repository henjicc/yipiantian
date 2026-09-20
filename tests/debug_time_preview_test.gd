extends SceneTree
## Actual toolbar, immediate preferences and developer entry points; isolated data.
const Settings = preload("res://settings/settings_store.gd")
var scene: Node3D
var failures: Array[String] = []
var output: String

func _initialize() -> void:
	output = ProjectSettings.globalize_path("res://../.local/verification/settings-toolbar-%d" % Time.get_ticks_usec()).simplify_path()
	_run.call_deferred()

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.store = load("res://farm/farm_store.gd").new(output.path_join("farm"))
	scene.settings_store = Settings.new(output.path_join("preferences"))
	scene.clock = func() -> float: return 1000.0
	root.add_child(scene)
	current_scene = scene
	await create_timer(.5).timeout
	expect(root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "Preview is genuine second-screen fullscreen")
	var bar: HBoxContainer = scene.hud.get_node("Layout/FarmControls")
	scene.hud.show_state({}, {}, "", "", false, -1, "", {"bok_choy": 999})
	expect(bar.get_node("OpenBasket").text == "菜篮", "Basket entry never displays inventory counts")
	expect(bar.get_node("Sow").text == "种植", "Planting entry uses the requested label")
	for icon_id: String in ["plant", "tools", "basket", "build", "settings", "cancel"]:
		var source := Image.load_from_file("res://art/ui/toolbar/%s.png" % icon_id)
		expect(source != null and source.detect_alpha() != Image.ALPHA_NONE, "Generated icon preserves genuine alpha: " + icon_id)
	expect(not scene.hud.has_node("Layout/TimeBadge") and not scene.hud.has_node("Layout/DebugFreeCamera"), "No time or developer buttons on upper HUD")
	for dimensions: Vector2i in [Vector2i(960,600), Vector2i(3840,2160)]:
		root.mode = Window.MODE_WINDOWED
		root.size = dimensions
		await process_frame; await process_frame
		var previous_right: float = -1
		for button: Button in bar.get_children():
			if not button.visible: continue
			var rect := button.get_global_rect()
			expect(root.get_visible_rect().encloses(rect), "Toolbar fits " + str(dimensions))
			expect(button.icon != null and button.expand_icon and button.icon_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Toolbar uses left icon and text")
			expect(rect.position.x >= previous_right, "Toolbar buttons never overlap")
			previous_right = rect.end.x
	root.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	scene.atmosphere.set_preview_hour(12)
	await shot("toolbar.png")
	await click(bar.get_node("Settings"))
	expect(scene.game_menu.visible, "Bottom settings opens modal")
	scene.game_menu._sliders.master.value = 27
	var stored: Dictionary = Settings.new(output.path_join("preferences")).load_settings().settings
	expect(is_equal_approx(stored.master,.27), "Slider preference is on disk before closing menu")
	expect(not scene._settings_dirty and not scene.game_menu._retry.visible, "Successful automatic save leaves no manual save action")
	var file: String = output.path_join("preferences/settings.json")
	var committed: String = FileAccess.get_file_as_string(file)
	FileAccess.set_read_only_attribute(file,true)
	scene.game_menu._sliders.music.value = 22
	expect(scene.game_menu._retry.visible and "未能保存" in scene.game_menu._status.text, "Automatic save failure exposes retry")
	expect(FileAccess.get_file_as_string(file)==committed, "Failed save preserves committed settings")
	FileAccess.set_read_only_attribute(file,false)
	await click(scene.game_menu._retry)
	expect(not scene._settings_dirty and not scene.game_menu._retry.visible, "Retry saves latest value")
	scene.game_menu._show_page(1)
	var ui_size: Vector2 = root.get_texture().get_size()
	for index: int in [1,2,0]:
		await measure_option(scene.game_menu._resolution,index,"resolution")
		expect(root.get_texture().get_size()==ui_size, "Resolution leaves UI at native output")
	var msaa: int = root.msaa_3d
	for index: int in [1,0,2,0]:
		await measure_option(scene.game_menu._quality,index,"quality")
		expect(root.msaa_3d==msaa, "Quality does not invalidate every MSAA pipeline")
	await shot("display.png")
	await developer("free_camera")
	expect(scene.camera.free_view and not scene.game_menu.visible, "Developer free-view entry releases modal input")
	await developer("free_camera")
	expect(not scene.camera.free_view, "Developer button also exits free view")
	await developer("camera_tuning")
	expect(scene.camera_tuning.visible, "Developer entry opens camera tuning")
	await developer("time")
	var panel: PanelContainer = scene.hud.get_node("Layout/DebugTimePreview")
	expect(panel.visible, "Developer entry retains time preview without a HUD clock")
	var slider: HSlider = panel.find_child("TimeSlider",true,false)
	slider.value=1320
	await shot("night.png")
	expect(scene.atmosphere.get_night_weight()>.5, "Developer time slider still changes lighting")
	slider.value=720
	await click(panel.find_child("LiveTime",true,false))
	expect(scene.atmosphere.get_preview_hour()==-1, "Live time restores")
	# Actual scene switch into the existing model room; its return navigation is
	# owned by that tool. All writes before this boundary used the isolated store.
	await developer("models")
	await process_frame; await process_frame
	expect(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://development/model_gallery.tscn", "Model inspection opens the existing model room")
	await shot("models.png")
	print("SETTINGS_TOOLBAR_TEST failures=%d output=%s" % [failures.size(),output])
	quit(0 if failures.is_empty() else 1)

func developer(action: String) -> void:
	scene._open_menu()
	scene.game_menu._show_page(4)
	await process_frame; await process_frame
	await click(scene.game_menu._developer_buttons[action])

func measure_option(option: OptionButton,index: int,kind: String) -> void:
	await RenderingServer.frame_post_draw
	var started: int = Time.get_ticks_usec()
	option.select(index); option.item_selected.emit(index)
	var apply_ms: float = (Time.get_ticks_usec()-started)/1000.0
	var peak_ms: float = 0
	for frame: int in 8:
		var tick: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		peak_ms=maxf(peak_ms,(Time.get_ticks_usec()-tick)/1000.0)
	print("SETTING_SWITCH kind=%s index=%d apply_save_ms=%.2f peak_frame_ms=%.2f foreground=%s" % [kind,index,apply_ms,peak_ms,root.has_focus()])

func click(button: Control) -> void:
	await process_frame; await process_frame
	var point: Vector2 = button.get_global_rect().get_center()
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true)
		await process_frame;await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(output.path_join(name))==OK,"Saved "+name)
