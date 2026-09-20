extends SceneTree

const Menu = preload("res://ui/game_menu.gd")
const Store = preload("res://settings/settings_store.gd")
var checks: int = 0
var failures: Array[String] = []
var emitted: Dictionary = {}
var visual: bool = false
var capture_folder: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	visual = "--visual" in OS.get_cmdline_user_args()
	capture_folder = ProjectSettings.globalize_path("res://../.local/verification/game-menu")
	DirAccess.make_dir_recursive_absolute(capture_folder)
	root.size = Vector2i(1280, 720)
	var menu := Menu.new()
	root.add_child(menu)
	menu.settings_changed.connect(func(value: Dictionary) -> void: emitted = value)
	menu.present(Store.DEFAULTS)
	await process_frame
	if visual:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_folder.path_join("tiled-frame-settings.png"))
	_expect(menu.visible, "Menu opens without changing scene state")
	_expect(root.gui_get_focus_owner() == menu._tabs[0], "Opening captures keyboard focus")
	var focus: StyleBoxFlat = menu._tabs[0].get_theme_stylebox("focus")
	_expect(not focus.draw_center, "Keyboard focus leaves selected pigment visible")
	_expect(menu._tabs[0].get_theme_color("font_pressed_color") == preload("res://ui/ui_tokens.gd").INK, "Selected text retains dark readable ink")
	_expect(menu._tabs[0].get_theme_color("font_hover_pressed_color") == preload("res://ui/ui_tokens.gd").INK, "Hovered selected text cannot fall back to white")
	menu._close.grab_focus()
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_event.pressed = true
	root.push_input(tab_event)
	await process_frame
	_expect(root.gui_get_focus_owner() == menu._tabs[0], "Real Tab input wraps before reaching underlying HUD")
	tab_event.pressed = false
	root.push_input(tab_event)
	_expect(menu._volume_labels.master.text == "80%", "Volume label reflects actual current value")
	for option: OptionButton in [menu._window, menu._quality, menu._resolution]:
		for index: int in option.item_count:
			_expect(not option.get_popup().is_item_radio_checkable(index), "Dropdown has no radio bullet")
		_expect(option.get_theme_constant("arrow_margin") >= 14, "Arrow has safe right inset")
	_expect(menu._quality.get_popup().get_theme_stylebox("hover").corner_radius_top_left <= 4, "Dropdown highlight has compact corners")
	menu._sliders.master.value = 0
	_expect(emitted.master == 0.0, "Muted master is emitted as exact zero")
	_expect(Store.DEFAULTS.master == 0.8, "UI preference copy cannot mutate defaults")
	menu._quality.select(1)
	menu._quality.item_selected.emit(1)
	_expect(emitted.quality == "low" and emitted.dof_enabled, "Low quality keeps saved DOF preference enabled")
	_expect("低画质暂不启用" in menu._dof.text, "Temporary quality effect is described accurately")
	menu._dof.button_pressed = false
	_expect(not emitted.dof_enabled, "DOF toggle changes only its preference")
	menu._sway.button_pressed = true
	_expect(emitted.sway_enabled and menu._sway_delay.editable, "Sway toggle enables idle delay")
	menu._sway_delay.value = 75
	_expect(emitted.sway_idle_seconds == 75, "Custom idle duration is emitted")
	menu._show_page(2)
	_expect(menu._pages[2].visible and not menu._pages[0].visible, "Controls page replaces settings inside one modal")
	menu._show_page(3)
	_expect(menu._pages[3].visible and not menu._pages[2].visible, "Sources are accessible without leaving the farm")
	if visual:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_folder.path_join("pigment-sources.png"))
	menu.set_status("设置未能保存，本次调整仍然有效。可重试保存。", true)
	_expect(menu._close.text == "暂不保存，返回" and menu._quit.text == "仍然退出", "Failed settings save exposes truthful continue and exit choices")
	menu.present(Store.DEFAULTS, "设置文件无法读取，已使用默认设置。原件保留。")
	_expect(menu._status.text.begins_with("设置文件无法读取"), "Load failures remain visible on reopen")
	menu._show_page(1)
	for viewport_size: Vector2i in [Vector2i(960, 600), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var panel: Control = menu.get_node("Modal/Paper")
		_expect(root.get_visible_rect().encloses(panel.get_global_rect()), "Entire modal fits logical viewport for %s" % str(viewport_size))
		var physical: Rect2 = root.get_stretch_transform() * panel.get_global_rect()
		_expect(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(physical), "Scaled modal fits physical window %s" % str(viewport_size))
		for control: Control in [menu._close, menu._quit, menu._window, menu._resolution, menu._quality, menu._dof]:
			_expect(panel.get_global_rect().encloses(control.get_global_rect()), "Control stays inside modal at %s: %s" % [str(viewport_size), control.name])
		if visual and viewport_size == Vector2i(3840, 2160):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_folder.path_join("tiled-frame-4k.png"))
			menu._quality.show_popup()
			menu._quality.get_popup().set_focused_item(1)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_folder.path_join("dropdown-refined-4k.png"))
			menu._quality.get_popup().hide()
	_expect(not menu.has_node("SaveSettings") and not menu._retry.visible, "No manual save button on normal settings")
	_expect(menu._tabs[0].text == "音量" and menu._tabs[1].text == "显示" and menu._tabs[3].text == "关于", "Settings categories and About use requested labels")
	if OS.is_debug_build() and OS.has_feature("editor"):
		menu._show_page(4)
		_expect(menu._developer_buttons.size() == 4, "Developer tab contains camera, free view, model and time tools")
		if visual:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_folder.path_join("developer.png"))
	menu.queue_free()
	await process_frame
	print("GAME_MENU_TEST checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
