extends SceneTree
## Actual input, props and original bird rigs, with isolated player data.
const ThemeFactory = preload("res://ui/farm_theme.gd")
const PigmentStyle = preload("res://ui/pigment_style.gd")
var scene: Node3D
var folder: String
var failures: Array[String] = []
var actions: int = 0
var visual: bool
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func mouse(point: Vector2, down: bool, button: int=MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position=point; event.button_index=button; event.pressed=down
	event.window_id=root.get_window_id()
	root.push_input(event,true)
	await physics_frame; await process_frame
func click(point: Vector2) -> void:
	var event := InputEventMouseMotion.new(); event.position=point
	event.window_id=root.get_window_id()
	root.push_input(event,true); await physics_frame; await process_frame
	await mouse(point,true); await mouse(point,false)
func point(index: int, id: String) -> Vector2:
	return scene.camera.unproject_position(scene.farm.fields[index].to_global(scene.farm.cell_position(index,id)))
func petal(id: String) -> Vector2:
	var button: Control=scene.field_menu.cards.get_node(id)
	return button.global_position+button.center
func shot(label: String) -> void:
	if not visual: return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func run() -> void:
	visual="--visual" in OS.get_cmdline_user_args()
	folder=ProjectSettings.globalize_path("res://../.local/verification/field-menu")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1600,900)
	scene=load("res://scenes/main.tscn").instantiate()
	var isolated: String=folder.path_join("session-%d"%Time.get_ticks_usec())
	scene.store=load("res://farm/farm_store.gd").new(isolated)
	scene.settings_store=load("res://settings/settings_store.gd").new(isolated.path_join("preferences"))
	scene.clock=func() -> float: return 1800000000.0
	root.add_child(scene)
	scene.get_node("Environment/CourtyardAnimals")._rng.seed=20260919
	scene.farm_changed.connect(func(_result: Dictionary) -> void: actions+=1)
	await create_timer(1.0).timeout
	var button_frame:=ThemeFactory.create().get_stylebox("normal","Button")
	check(button_frame is PigmentStyle,"Controls use continuous-UV pigment with runtime outlines, not sliced bitmaps")
	scene.atmosphere.set_preview_hour(14.0)
	var build: Button = scene.hud.get_node("Layout/BuildIsland")
	var settings: Button = scene.hud.get_node("Layout/ViewControls/Settings")
	check(is_equal_approx(build.size.x, settings.size.x) and is_equal_approx(build.size.y, settings.size.y), "Construction and settings have equal dimensions")
	check(scene.hud.get_node("Layout/ViewControls").get_child_count() == 1, "No duplicate decoration, overview or reset HUD buttons")
	for badge_name: String in ["OpenBasket", "TimeBadge"]:
		var badge: Button = scene.hud.get_node("Layout/" + badge_name)
		for state: String in ["normal", "hover", "pressed"]:
			check(badge.get_theme_stylebox(state) is StyleBoxEmpty, "Status badge has no background: " + badge_name + state)
	await shot("simplified-hud")
	scene.camera.drag(Vector2(12, 8), false)
	scene.camera.zoom(-2.0)
	while scene.camera.is_transitioning(): await process_frame
	var original_pose: Transform3D = scene.camera.global_transform
	scene._focus_field(0)
	while scene.camera.is_transitioning(): await process_frame
	scene._focus_field(1)
	while scene.camera.is_transitioning(): await process_frame
	await mouse(Vector2(8,400), true, MOUSE_BUTTON_WHEEL_DOWN)
	while scene.camera.is_transitioning(): await process_frame
	await process_frame
	check(not scene.camera.focused and scene.selected_field == -1, "Backward wheel exits chained field focus")
	check(scene.camera.global_transform.is_equal_approx(original_pose), "Backward wheel restores pre-focus pose, not previous field or default overview")
	scene.camera.reset_view()
	while scene.camera.is_transitioning(): await process_frame
	await click(build.get_global_rect().get_center())
	check(scene.island_builder.active, "Construction entry opens combined building tools")
	await click(scene.island_builder.choices.categories.objects.get_global_rect().get_center())
	check(scene.island_builder.choices.items.bench.is_visible_in_tree(), "Decorations remain reachable inside construction")
	await click(scene.island_builder._finish.get_global_rect().get_center())
	check(not scene.island_builder.active, "Construction exits without edits")
	while scene.camera.is_transitioning(): await process_frame
	var animals: Node3D=scene.get_node("Environment/CourtyardAnimals")
	while not animals.ready_for_motion: await process_frame
	animals.set_process(false)
	print("INPUT_CONTEXT viewport=",root.get_visible_rect()," window=",root.size," target=",point(0,"cell_01")," hit=",scene._farm_hit(point(0,"cell_01"))," available=",scene._tools_available())
	await click(point(0,"cell_01"))
	check(scene.camera.focused and scene.selected_field==0 and not scene.field_menu.active and actions==0,"Overview click only focuses the whole field")
	while scene.camera.is_transitioning(): await process_frame
	check(scene._farm_hit(point(1,"cell_01")).get("cell", "").is_empty(),"Adjacent field never exposes cells before focus")
	await click(point(0,"cell_01"))
	check(scene.field_menu.active and actions==0,"Soil click opens menu without changing farm")
	if not scene.field_menu.active: quit(1); return
	await shot("menu")
	for angle: float in [PI * 4.0 / 3.0, PI * 5.0 / 3.0]:
		for offset: float in [-.01, .01]:
			var sample := Vector2(160,160) + Vector2.from_angle(angle + offset) * 100.0
			var covered: bool = false
			for entry: Control in scene.field_menu.cards.get_children():
				covered = covered or Geometry2D.is_point_in_polygon(sample, entry.polygon)
			check(covered, "Action fan boundaries have no open angular gap")
	await click(petal("sow"))
	check(scene.field_menu.active and actions==0,"Sow opens crop choice without planting")
	await shot("seeds")
	var menu_center: Vector2 = scene.field_menu.cards.size * .5
	for angle_index: int in 120:
		var sample: Vector2 = menu_center + Vector2.from_angle(angle_index * TAU / 120.0 + .002) * 140.0
		var covered: bool = false
		for entry: Node in scene.field_menu.cards.get_children():
			if entry is Button:
				covered = covered or Geometry2D.is_point_in_polygon(sample, entry.polygon)
		check(covered, "Crop ring boundaries have no open angular gap")
	await click(petal("radish"))
	check(actions==1 and scene.farm_state.get_cell(scene.farm.field_id(0),"cell_01").crop_id=="radish","Selected seed commits once to captured cell")
	check(scene.selected_tool.is_empty(),"Menu is one-shot")
	await click(point(0,"cell_01")); await click(petal("water"))
	check(actions==2 and scene.farm_state.get_cell(scene.farm.field_id(0),"cell_01").watered,"Water reaches captured cell")
	await click(point(0,"cell_02"))
	await click(Vector2(8,400))
	check(not scene.field_menu.active and actions==2,"Outside click cancels without falling through")
	await mouse(point(0,"cell_02"),true)
	await mouse(point(0,"cell_03"),false)
	check(not scene.field_menu.active,"Cross-cell release does not open menu")
	await click(point(0,"cell_02"))
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not scene.field_menu.active and actions==2,"Focus loss cancels pending menu")
	scene._select_tool("water")
	await click(point(5,"cell_13"))
	check(scene.selected_field==5 and not scene.field_menu.active and actions==2,"Armed tool switches adjacent field focus without farming")
	while scene.camera.is_transitioning(): await process_frame
	await click(point(5,"cell_13")); await click(petal("weed"))
	check(scene.farm_state.get_cell(scene.farm.field_id(5),"cell_13").ground=="rough","Weed action clears weeds")
	await click(point(5,"cell_13")); await click(petal("till"))
	check(scene.farm_state.get_cell(scene.farm.field_id(5),"cell_13").ground=="ready","Context menu preserves till action")
	# Inspect contact from both sides using game-owned rendering, no desktop capture.
	scene.focus_detail.set_depth_of_field(false)
	scene.camera.set_process(false)
	var tools: Node3D=scene.get_node("Environment/DoorTools")
	for direction: float in [-1.0,1.0]:
		var center := Vector3(.7,1.0,-2.2)
		scene.camera.position=center+Vector3(direction*3.7,2.5,5)
		scene.camera.look_at(center)
		tools.set_hover("weed")
		await shot("porch-%s"%direction)
	tools.set_hover("")
	for id: String in tools.tools:
		var prop: Node3D=tools.tools[id]
		var visible_point := Vector2.INF
		# Sample real mesh vertices, accepting only frontmost exact prop hits.
		for mesh: MeshInstance3D in prop.find_children("*","MeshInstance3D",true,false):
			var vertices: PackedVector3Array=mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for i: int in range(0,vertices.size(),maxi(1,vertices.size()/70)):
				var sample: Vector2=scene.camera.unproject_position(mesh.to_global(vertices[i]))
				if scene._scene_entry_at(sample)=="tool_"+id: visible_point=sample; break
			if visible_point!=Vector2.INF: break
		check(visible_point!=Vector2.INF,"Visible prop can be picked: "+id)
		if visible_point!=Vector2.INF:
			scene._pointer_position=visible_point; scene._update_hover()
			check(prop.find_children("*","MeshInstance3D",true,false)[0].material_overlay!=null,"Hover outlines only actual prop: "+id)
			if id=="weed": await shot("hoe-hover")
			await click(visible_point)
			check(scene.selected_palette=="sow" if id=="sow" else scene.selected_tool==id,"Prop equips its corresponding action: "+id)
			scene.field_menu.dismiss(); scene._cancel_tool()
	scene.field_menu.present_seeds(Vector2(1590,20))
	await process_frame;await process_frame
	var seed_panel: Control=scene.field_menu.cards
	check(root.get_visible_rect().encloses(seed_panel.get_global_rect()),"Crop picker fits at viewport edge")
	var reached: Array[String] = []
	var used_rings: Dictionary={}
	for id: String in scene.Crops.seeds(false):
		check(scene.field_menu.cards.has_node(id),"Concentric picker exposes "+id)
		if scene.field_menu.cards.has_node(id):
			reached.append(id)
			used_rings[scene.field_menu.cards.get_node(id).ring_index]=true
	check(reached.size()==12 and reached.has("garlic") and used_rings.size()==2,"All twelve crops are reachable across two crop rings")
	check(not scene.field_menu.cards.has_node("CenterBezel") and not scene.field_menu.cards.has_node("Ruyi0"),"Radial picker uses a clean procedural fine rim without wood ornaments")
	root.size=Vector2i(960,600);await process_frame;await process_frame
	scene.field_menu.present_seeds(Vector2(950,20))
	check(root.get_visible_rect().encloses(scene.field_menu.cards.get_global_rect()),"Concentric crop picker fits the compact window at its edge")
	await shot("seeds-compact")
	scene.field_menu.present_seeds(Vector2(480,300),true)
	check(scene.field_menu.cards.has_node("luffa") and not scene.field_menu.cards.has_node("greens"),"Trellis ring offers only its climbing crop")
	root.size=Vector2i(1600,900);await process_frame;await process_frame
	scene.atmosphere.set_preview_hour(21.0)
	scene.field_menu.present_seeds(Vector2(800,450))
	await shot("seeds-night")
	scene.atmosphere.set_preview_hour(14.0)
	var escape := InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
	root.push_input(escape,true);await process_frame
	check(not scene.field_menu.active,"Escape closes the crop picker")
	await click(scene.hud.get_node("Layout/FarmControls/Tools").get_global_rect().get_center())
	check(not scene.field_menu.active and scene.selected_palette=="tools","Bottom tools open a horizontal tray, never the radial picker")
	await create_timer(.3).timeout
	await shot("tools-row")
	await click(scene.hud.get_node("Layout/ToolChoices/Water").get_global_rect().get_center())
	check(scene.selected_tool=="water" and not scene.field_menu.active,"Horizontal tray equips without applying to stale target")
	scene._cancel_tool()
	await click(scene.hud.get_node("Layout/FarmControls/Sow").get_global_rect().get_center())
	await create_timer(.3).timeout
	check(scene.selected_palette=="sow" and not scene.field_menu.active,"Bottom sow opens horizontal crop choices")
	await shot("crop-row")
	await click(scene.hud.get_node("Layout/CropChoices/greens").get_global_rect().get_center())
	check(scene.selected_tool=="sow" and scene.selected_crop=="greens","Horizontal crop card equips the selected seed")
	scene._cancel_tool()
	# A short real navigation sample verifies changing speeds, bounded travel and neck motion.
	var limits: Dictionary={}; var beaks: Dictionary={}
	for entry: Dictionary in animals.birds:
		limits[entry.node.name]=Vector2(INF,0); beaks[entry.node.name]=[]
	for frame: int in 540:
		animals._process(1.0/30.0)
		for entry: Dictionary in animals.birds:
			check(entry.space.contains(entry.position),"Bird remains inside navigable space")
			check(entry.velocity.length()<=entry.speed+.0001,"Gait does not exceed collision speed bound")
			if entry.state in ["walk","swim"] and entry.velocity.length()>.025:
				var speeds: Vector2=limits[entry.node.name]
				limits[entry.node.name]=Vector2(minf(speeds.x,entry.velocity.length()),maxf(speeds.y,entry.velocity.length()))
				beaks[entry.node.name].append(entry.node.to_local(entry.pose.beak_world_position()))
	for kind: String in ["duck","hen"]:
		var varied: bool=false
		var neck_moves: bool=false
		for entry: Dictionary in animals.birds:
			if entry.kind!=kind: continue
			var speeds: Vector2=limits[entry.node.name]
			if speeds.y-speeds.x>.06: varied=true
			var points: Array=beaks[entry.node.name]
			if points.size()>2:
				var bounds := AABB(points[0],Vector3.ZERO)
				for p: Vector3 in points: bounds=bounds.expand(p)
				if bounds.size.length()>.015: neck_moves=true
			if visual:
				var center: Vector3=entry.node.position+Vector3.UP*.2
				scene.camera.position=center+Vector3(1.0,.5,.7);scene.camera.look_at(center)
				await shot(kind+"-gait")
				break
		check(varied,kind+" has observable propulsion / glide or step / pause rhythm")
		check(neck_moves,kind+" changes its skinned beak position during locomotion")
	print("FIELD_MENU_PASS" if failures.is_empty() else "FIELD_MENU_FAIL "+str(failures))
	print("CAPTURES ",folder)
	scene.farm_audio.shutdown();scene.queue_free()
	await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
