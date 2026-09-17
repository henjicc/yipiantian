extends SceneTree
## Renders original assets through Godot at their real UI sizes; no raster edits.

const ThemeFactory = preload("res://ui/farm_theme.gd")
const ICON = preload("res://art/ui/game-icon.png")
var output: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	_run.call_deferred()


func _run() -> void:
	if output.is_empty():
		push_error("An explicit preview screenshot output path is required")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var layout := Control.new()
	layout.theme = ThemeFactory.create()
	root.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("f4ecd9")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_child(background)
	for row: int in 3:
		var plate := ColorRect.new()
		plate.position = Vector2(24, 24 + row * 174)
		plate.size = Vector2(1232, 162)
		plate.color = [Color("f4ecd9"), Color("252922"), Color("85867b")][row]
		layout.add_child(plate)
		for index: int in 3:
			var dimension: int = [32, 48, 128][index]
			var picture := TextureRect.new()
			picture.texture = ICON
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.position = Vector2(60 + 240 * index, 24 + row * 174 + (162 - dimension) * 0.5)
			picture.size = Vector2(dimension, dimension)
			layout.add_child(picture)
	var font_label := Label.new()
	font_label.text = "我有一片田  ·  青菜 12 篮  ·  白萝卜 8 篮  ·  16:30\n设置已保存  ·  播种  ·  浇水  ·  收获"
	font_label.position = Vector2(36, 562)
	layout.add_child(font_label)
	var icons: Array[String] = ["sow", "water", "harvest", "basket", "sun", "moon"]
	for index: int in icons.size():
		var icon := TextureRect.new()
		icon.texture = load("res://art/ui/%s.svg" % icons[index])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.size = Vector2(40, 40)
		icon.position = Vector2(40 + index * 90, 654)
		layout.add_child(icon)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var result: Error = root.get_texture().get_image().save_png(output)
	print("UI_ASSET_PREVIEW result=%d sizes=32,48,128 output=%s" % [result, output])
	quit(0 if result == OK else 1)
