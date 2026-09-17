extends SceneTree

const Menu = preload("res://ui/game_menu.gd")
const Store = preload("res://settings/settings_store.gd")
var checks: int = 0
var failures: Array[String] = []
var emitted: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var menu := Menu.new()
	root.add_child(menu)
	menu.settings_changed.connect(func(value: Dictionary) -> void: emitted = value)
	menu.present(Store.DEFAULTS)
	await process_frame
	_expect(menu.visible, "Menu opens without changing scene state")
	_expect(root.gui_get_focus_owner() == menu._tabs[0], "Opening captures keyboard focus")
	menu._quit.grab_focus()
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_event.pressed = true
	root.push_input(tab_event)
	await process_frame
	_expect(root.gui_get_focus_owner() == menu._tabs[0], "Real Tab input wraps before reaching underlying HUD")
	tab_event.pressed = false
	root.push_input(tab_event)
	_expect(menu._volume_labels.master.text == "80%", "Volume label reflects actual current value")
	menu._sliders.master.value = 0
	_expect(emitted.master == 0.0, "Muted master is emitted as exact zero")
	_expect(Store.DEFAULTS.master == 0.8, "UI preference copy cannot mutate defaults")
	menu._quality.select(1)
	menu._quality.item_selected.emit(1)
	_expect(emitted.quality == "low" and emitted.dof_enabled, "Low quality keeps saved DOF preference enabled")
	_expect("低画质暂不启用" in menu._dof.text, "Temporary quality effect is described accurately")
	menu._dof.button_pressed = false
	_expect(not emitted.dof_enabled, "DOF toggle changes only its preference")
	menu._show_page(1)
	_expect(menu._pages[1].visible and not menu._pages[0].visible, "Controls page replaces settings inside one modal")
	menu._show_page(2)
	_expect(menu._pages[2].visible and not menu._pages[1].visible, "Sources are accessible without leaving the farm")
	menu.set_status("设置未能保存，本次调整仍然有效。可重试保存。", true)
	_expect(menu._close.text == "暂不保存，返回" and menu._quit.text == "仍然退出", "Failed settings save exposes truthful continue and exit choices")
	menu.present(Store.DEFAULTS, "设置文件无法读取，已使用默认设置。原件保留。")
	_expect(menu._status.text.begins_with("设置文件无法读取"), "Load failures remain visible on reopen")
	for viewport_size: Vector2i in [Vector2i(960, 600), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var panel: Control = menu.get_node("Modal/Paper")
		_expect(root.get_visible_rect().encloses(panel.get_global_rect()), "Entire modal fits logical viewport for %s" % str(viewport_size))
		var physical: Rect2 = root.get_stretch_transform() * panel.get_global_rect()
		_expect(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(physical), "Scaled modal fits physical window %s" % str(viewport_size))
		for control: Control in [menu._close, menu._quit, menu._window, menu._quality, menu._dof]:
			_expect(panel.get_global_rect().encloses(control.get_global_rect()), "Control stays inside modal at %s: %s" % [str(viewport_size), control.name])
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
