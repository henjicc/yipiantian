extends Node3D

signal farm_changed(result: Dictionary)

const Crops = preload("res://farm/crop_catalog.gd")
const ToolCursor = preload("res://ui/tool_cursor.gd")
const FieldMenu = preload("res://ui/field_menu.gd")
var field_menu: FieldMenu
var _menu_target: Dictionary = {}
const FarmState = preload("res://farm/farm_state.gd")
const FarmStore = preload("res://farm/farm_store.gd")
const DecorationState = preload("res://farm/decoration_state.gd")
const DecorationLayout = preload("res://scenes/decoration_layout.gd")
const FarmAudio = preload("res://audio/farm_audio.gd")
const DayNight = preload("res://atmosphere/day_night.gd")
const WindowActivity = preload("res://atmosphere/window_activity.gd")
const FocusDetail = preload("res://presentation/focus_detail.gd")
const HUD = preload("res://scenes/farm_hud.gd")
const SettingsStore = preload("res://settings/settings_store.gd")
const GameMenu = preload("res://ui/game_menu.gd")
const DesktopWallpaper = preload("res://platform/desktop_wallpaper.gd")
var desktop_wallpaper: DesktopWallpaper
var _wallpaper_issue: String = ""
const CameraTuning = preload("res://ui/camera_tuning.gd")
const CourtyardPlan = preload("res://layout/courtyard_plan.gd")
const CourtyardEditSession = preload("res://layout/courtyard_edit_session.gd")
const HarvestBook = preload("res://ui/harvest_book.gd")
const KitchenDisplay=preload("res://presentation/kitchen_display.gd")
const AnimalPanel=preload("res://ui/animal_panel.gd")
const GardenAlbum=preload("res://presentation/garden_album.gd")
const SeasonalCourtyard=preload("res://presentation/seasonal_courtyard.gd")
var seasonal_courtyard: SeasonalCourtyard
var garden_album: GardenAlbum
var animal_panel: AnimalPanel
var _pressed_animal: String=""
var _pressed_entry: String=""
var kitchen_display: KitchenDisplay
var harvest_book: HarvestBook
var courtyard_plan := CourtyardPlan.new()
var courtyard_edit: CourtyardEditSession
const IslandBuilder=preload("res://ui/island_builder.gd")
var island_builder: IslandBuilder
var _construction_resume: Dictionary = {}
# One-step undo is session history, carried across a spatial scene rebuild.
# It reverses layout only, never harvests, elapsed growth or subsequent planting.
var previous_layout: Dictionary = {}
var _presentation_resume: Dictionary = {}

@onready var farm: FarmLayout = $Farm
@onready var camera: FarmCamera = $Camera3D
# One clock boundary: tests inject a callable before adding the scene to the tree.
var clock: Callable = Time.get_unix_time_from_system
var farm_state: FarmState
var decoration_state: DecorationState
var decoration_layout: DecorationLayout
var farm_audio: FarmAudio
var atmosphere: DayNight
var window_activity: WindowActivity
var focus_detail: FocusDetail
var store: FarmStore
var hud: HUD
var settings_store: SettingsStore
var game_menu: GameMenu
var settings_values: Dictionary = {}
var _settings_dirty: bool = false
var _settings_issue: String = ""
var _allow_leave_settings: bool = false
var selected_field: int = -1
var selected_cell: String = ""
var selected_palette: String = ""
var selected_tool: String = ""
var selected_crop: String = "greens"
var hover_field: int = -1
var hover_cell: String = ""
var _pointer_position := Vector2(-100, -100)
var tool_cursor: ToolCursor
var camera_tuning: CameraTuning
var _dragging: bool = false
var _press_position := Vector2.INF
var _press_dragged: bool = false
var _pressed_field: int = -1
var _pressed_cell: String = ""
var _press_context: Dictionary = {}
var _tool_press: Dictionary = {}
var _picks: Array[Dictionary] = []
var _loaded: bool = false
var _save_failed: bool = false
var _record_session: String = ""
var _exiting: bool = false
var _startup_state: Dictionary = {}
var _startup_admitted: bool = false


func _enter_tree() -> void:
	_startup_admitted = _prepare_stores()
	if _startup_admitted:
		_startup_state = store.load_state()
		if _startup_state.ok and _startup_state.kind == "loaded":
			courtyard_plan = CourtyardPlan.from_snapshot(_startup_state.farm.layout)
	# Children build their geometry in _ready; share one plan before that happens.
	$Environment.plan = courtyard_plan
	$Farm.plan = courtyard_plan
	$Camera3D.configure_layout(courtyard_plan.camera_point, courtyard_plan.camera_distance)

func _prepare_stores() -> bool:
	# Recording is explicitly isolated before any player-state load. A release package
	# does not carry the recording implementation and refuses its launch parameter.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--record-session="):
			if not OS.has_feature("editor"):
				push_error("Development recording arguments are unavailable in this build.")
				get_tree().quit(1)
				return false
			_record_session = argument.trim_prefix("--record-session=").simplify_path()
			var allowed: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join(".local/recordings")
			if not _record_session.is_absolute_path() or not _record_session.replace("\\", "/").begins_with(allowed.replace("\\", "/") + "/"):
				push_error("Recording session must be inside the project's isolated recording directory.")
				get_tree().quit(1)
				return false
			store = FarmStore.new(_record_session.path_join("farm"))
			settings_store = SettingsStore.new(_record_session.path_join("preferences"))
	if store == null:
		store = FarmStore.new()
	return true

func _ready() -> void:
	if not _startup_admitted: return
	get_tree().auto_accept_quit = false
	get_window().min_size = Vector2i(960, 600)
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	field_menu = FieldMenu.new()
	field_menu.name = "FieldMenu"
	add_child(field_menu)
	field_menu.action_requested.connect(_field_menu_action)
	hud.tool_press_started.connect(_start_tool_press)
	hud.tool_requested.connect(_finish_tool_press)
	hud.crop_requested.connect(_select_crop)
	hud.cancel_tool_requested.connect(_cancel_tool)
	hud.palette_requested.connect(_open_palette)
	harvest_book=HarvestBook.new()
	kitchen_display=KitchenDisplay.new()
	kitchen_display.name="KitchenDisplay"
	add_child(kitchen_display)
	kitchen_display.configure($Environment)
	harvest_book.name="HarvestBook"
	add_child(harvest_book)
	hud.basket_requested.connect(_open_basket)
	harvest_book.closed.connect(func() -> void:
		camera.free_input_enabled=true
		_cancel_input()
		_refresh_hud())
	harvest_book.share_requested.connect(func(id: String, visit: int, basket: Dictionary) -> void: _exchange(id,visit,basket,""))
	harvest_book.gift_requested.connect(func(id: String, visit: int, crop: String) -> void: _exchange(id,visit,{},crop))
	harvest_book.view_requested.connect(_view_neighbor)
	harvest_book.kitchen_requested.connect(_kitchen_action)
	harvest_book.season_requested.connect(_change_season)
	harvest_book.kitchen_view_requested.connect(func(station: String) -> void:
		var framing: Dictionary=kitchen_display.viewpoint(station)
		focus_detail.protect_neighbor(framing.subject)
		camera.view_neighbor(framing.point,framing.view)
		hud.hide())
	harvest_book.view_closed.connect(func() -> void:
		camera.leave_neighbor()
		hud.show())
	tool_cursor = ToolCursor.new()
	animal_panel=AnimalPanel.new()
	animal_panel.name="AnimalPanel"
	add_child(animal_panel)
	animal_panel.action_requested.connect(_animal_action)
	animal_panel.closed.connect(func() -> void:
		camera.leave_neighbor()
		hud.show()
		_cancel_input()
		_refresh_hud())
	add_child(tool_cursor)
	hud.overview_requested.connect(_return_overview)
	hud.reset_requested.connect(_reset_view)
	hud.retry_requested.connect(_retry_storage)
	hud.recovery_requested.connect(_recover_storage)
	hud.exit_requested.connect(_finish_exit)
	hud.decoration_requested.connect(_begin_decoration)
	hud.settings_requested.connect(_open_menu)
	hud.free_view_requested.connect(_toggle_free_view)
	if OS.is_debug_build():
		camera_tuning = CameraTuning.new()
		camera_tuning.camera = camera
		hud.get_node("Layout").add_child(camera_tuning)
		hud.camera_tuning_requested.connect(_toggle_camera_tuning)
		camera_tuning.visibility_changed.connect(_refresh_hud)
		camera_tuning.depth_of_field_changed.connect(func(enabled: bool, strength: float) -> void:
			settings_values.dof_enabled = enabled
			focus_detail.set_depth_of_field(enabled, strength))
		camera_tuning.fog_strength_changed.connect(func(strength: float) -> void:
			focus_detail.set_fog_strength(strength))
	camera.motion_finished.connect(_refresh_hud)
	camera.motion_finished.connect(func() -> void:
		if not camera.neighbor_view and focus_detail!=null: focus_detail.protect_neighbor(null))
	_load_game(_startup_state)
	_startup_state = {}
	# The courtyard owns all slot transforms and art; no duplicate fallback layout.
	var courtyard: Node3D = $Environment
	decoration_layout = DecorationLayout.new()
	decoration_layout.name = "Decorations"
	add_child(decoration_layout)
	decoration_layout.configure(courtyard, camera, decoration_state if _loaded else DecorationState.new())
	decoration_layout.mode_changed.connect(_on_decoration_mode_changed)
	decoration_layout.change_requested.connect(_change_decoration)
	decoration_layout.update_life(farm_state.snapshot().kitchen)
	farm_audio = FarmAudio.new()
	farm_audio.name = "FarmAudio"
	add_child(farm_audio)
	atmosphere = DayNight.new()
	atmosphere.name = "DayNight"
	add_child(atmosphere)
	atmosphere.configure($DirectionalLight3D, $WorldEnvironment, courtyard.get_water_surface())
	hud.preview_hour_requested.connect(func(hour: float) -> void: atmosphere.set_preview_hour(hour))
	hud.time_preview_opened.connect(func() -> void:
		_cancel_input()
		camera.cancel_free_gesture()
		decoration_layout.cancel_pointer_gesture())
	atmosphere.set_backdrop_material(courtyard.get_backdrop_material())
	atmosphere.window_warmth_changed.connect(courtyard.set_window_warmth)
	courtyard.set_window_warmth(atmosphere.get_window_warmth())
	atmosphere.night_weight_changed.connect(courtyard.set_night_weight)
	courtyard.set_night_weight(atmosphere.get_night_weight())
	atmosphere.night_weight_changed.connect(farm_audio.set_night_weight)
	farm_audio.set_night_weight(atmosphere.get_night_weight())
	atmosphere.night_weight_changed.connect(decoration_layout.set_night_weight)
	decoration_layout.set_night_weight(atmosphere.get_night_weight())
	seasonal_courtyard=SeasonalCourtyard.new()
	seasonal_courtyard.name="SeasonalCourtyard"
	courtyard.add_child(seasonal_courtyard)
	seasonal_courtyard.configure(courtyard)
	_apply_season()
	window_activity = WindowActivity.new()
	window_activity.name = "WindowActivity"
	window_activity.foreground_changed.connect(farm_audio.set_foreground)
	add_child(window_activity)
	farm_audio.set_foreground(window_activity.is_foreground())
	decoration_layout.confirmed.connect(_refresh_lanterns)
	_refresh_lanterns()
	focus_detail = FocusDetail.new()
	focus_detail.name = "FocusDetail"
	add_child(focus_detail)
	focus_detail.configure(camera, farm.fields, courtyard, decoration_layout)
	focus_detail.quality_changed.connect(atmosphere.set_quality)
	_setup_settings()
	desktop_wallpaper = DesktopWallpaper.new()
	desktop_wallpaper.name = "DesktopWallpaper"
	add_child(desktop_wallpaper)
	desktop_wallpaper.changed.connect(_wallpaper_changed)
	desktop_wallpaper.visibility_changed.connect(window_activity.set_wallpaper_visible)
	desktop_wallpaper.restoring.connect(window_activity.begin_wallpaper_restore)
	desktop_wallpaper.quit_requested.connect(_request_exit)
	desktop_wallpaper.failed.connect(func(message: String) -> void:
		push_warning(message)
		_wallpaper_issue = message
		if not desktop_wallpaper.active and not desktop_wallpaper.busy:
			game_menu.present(settings_values, message))
	courtyard_edit=CourtyardEditSession.new()
	courtyard_edit.name="CourtyardEditor"
	add_child(courtyard_edit)
	courtyard_edit.apply_requested.connect(_apply_courtyard)
	courtyard_edit.closed.connect(_refresh_hud)
	decoration_layout.hud.courtyard_requested.connect(_begin_courtyard_edit)
	island_builder=IslandBuilder.new();island_builder.name="IslandBuilder";add_child(island_builder)
	island_builder.commit_requested.connect(_apply_construction)
	island_builder.closed.connect(func() -> void:
		camera.set_construction_framing(false);hud.show();_cancel_input();_refresh_hud())
	hud.construction_requested.connect(_begin_construction)
	if not _construction_resume.is_empty():
		camera.focus_point=_construction_resume.point;camera.view=_construction_resume.view
		_begin_construction.call_deferred(_construction_resume.tool)
	if not _presentation_resume.is_empty():
		focus_detail.set_depth_of_field(_presentation_resume.dof_enabled,_presentation_resume.dof_strength)
		focus_detail.set_fog_strength(_presentation_resume.fog_strength)
		atmosphere.set_preview_hour(_presentation_resume.hour)
	if OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview"):
		_report_preview_ready.call_deferred()
	garden_album=GardenAlbum.new();garden_album.name="GardenAlbum";add_child(garden_album);garden_album.configure(self)
	var timer := Timer.new()
	timer.name = "SettlementTimer"
	timer.wait_time = 1.0
	timer.timeout.connect(settle_farm)
	add_child(timer)
	timer.start()
	var save_timer := Timer.new()
	save_timer.name = "SaveTimer"
	save_timer.wait_time = 30.0
	save_timer.timeout.connect(func() -> void:
		if _loaded and not _save_failed and not _layout_active() and not (garden_album!=null and garden_album.busy):
			_save_farm())
	add_child(save_timer)
	save_timer.start()
	if not _record_session.is_empty():
		var recording: Node = load("res://development/recording_session.gd").new()
		recording.session_dir = _record_session
		recording.farm_scene = self
		add_child(recording)


func _load_game(initial: Dictionary = {}) -> void:
	var result: Dictionary = store.load_state() if initial.is_empty() else initial
	if not result.ok:
		_loaded = false
		farm.visible = false
		hud.show_storage_issue(result.kind, false)
		return
	if result.kind == "missing":
		farm_state = FarmState.new(clock.call(),courtyard_plan.snapshot())
		decoration_state = DecorationState.new()
	else:
		if result.farm.layout != courtyard_plan.snapshot():
			# Recovery can restore a different island. Recreate all spatial consumers
			# together rather than retaining obsolete colliders, haze or animal routes.
			_reload_saved_scene.call_deferred()
			return
		farm_state = FarmState.new()
		farm_state.restore_snapshot(result.farm)
		decoration_state = DecorationState.new()
		decoration_state.restore_snapshot(result.decorations)
	decoration_state.unlock(farm_state.snapshot().harvested)
	$Environment/CourtyardAnimals.interaction.profiles=farm_state.snapshot().animals
	if decoration_layout != null:
		decoration_layout.bind_state(decoration_state)
		decoration_layout.update_life(farm_state.snapshot().kitchen)
		_refresh_lanterns()
	_loaded = true
	_refresh_neighbor_stories()
	kitchen_display.refresh(farm_state.snapshot().kitchen)
	farm.visible = true
	if seasonal_courtyard!=null: _apply_season()
	settle_farm()
	_save_farm()
	print("FARM_LOAD stage=%s version=%d migrated=%s saved=%s" % [result.kind, FarmStore.VERSION, result.get("migrated", false), not _save_failed])

func _reload_saved_scene() -> void:
	_loaded = false
	process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(farm_audio): farm_audio.shutdown()
	await get_tree().create_timer(.1,true,false,true).timeout
	var replacement: Node3D = load("res://scenes/main.tscn").instantiate()
	replacement.name=name
	replacement.store = store
	replacement.settings_store = settings_store
	replacement.clock = clock
	replacement.previous_layout=previous_layout.duplicate(true)
	if island_builder!=null and island_builder.active:
		replacement._construction_resume={"tool":island_builder.tool,"point":camera.focus_point,"view":camera.view}
	if focus_detail!=null:
		replacement._presentation_resume=focus_detail.get_settings()
		replacement._presentation_resume.hour=atmosphere.get_preview_hour()
	var tree: SceneTree = get_tree()
	var parent: Node = get_parent()
	var was_current: bool = tree.current_scene == self
	parent.remove_child(self)
	parent.add_child(replacement)
	if was_current: tree.current_scene = replacement
	queue_free()


func _save_farm() -> bool:
	if not _loaded:
		return false
	var result: Dictionary = store.save(farm_state.snapshot(), decoration_state.snapshot())
	_save_failed = not result.ok
	if _save_failed:
		if garden_album!=null: garden_album.end_photo()
		if harvest_book!=null: harvest_book.dismiss()
		if animal_panel!=null: animal_panel.dismiss()
		if game_menu != null:
			game_menu.dismiss()
		if decoration_layout != null:
			decoration_layout.finish_mode()
		_cancel_input()
		selected_tool = ""
		selected_palette = ""
		hud.show_storage_issue(result.kind, true)
	else:
		hud.show_saved()
	_refresh_hud()
	return result.ok


func _retry_storage() -> void:
	if _loaded:
		settle_farm()
		_save_farm()
	else:
		_load_game()


func _recover_storage() -> void:
	var result: Dictionary = store.recover()
	if not result.ok:
		hud.show_storage_issue(result.kind, false)
		return
	_load_game()


func _request_exit() -> void:
	if _exiting:
		return
	if garden_album!=null and garden_album.busy: return
	_cancel_input()
	if not _loaded:
		_finish_exit()
		return
	if game_menu != null:
		if (_settings_dirty or not _settings_issue.is_empty()) and not _allow_leave_settings:
			_open_menu()
			if not _save_settings():
				return
		game_menu.dismiss()
	if decoration_layout != null:
		decoration_layout.finish_mode()
	settle_farm()
	if _save_farm():
		_finish_exit()


func _finish_exit() -> void:
	if _exiting:
		return
	_exiting = true
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	# Admission is final: saving succeeded, or the player explicitly chose to
	# leave without saving. No UI, timers, focus events or repeated close may write
	# state or restart audio during the short mixer drain.
	get_viewport().gui_disable_input = true
	process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(farm_audio):
		farm_audio.shutdown()
	await get_tree().create_timer(0.1, true, false, true).timeout
	await get_tree().process_frame
	get_tree().quit()


func settle_farm() -> void:
	if not _loaded:
		return
	var result: Dictionary = farm_state.settle(clock.call())
	harvest_book.update_time(clock.call())
	if result.ok:
		refresh_farm()


func refresh_farm() -> void:
	for field_id: String in farm_state.field_ids():
		farm.show_field(farm_state.get_field(field_id))
	_refresh_hud()


func _refresh_hud() -> void:
	if hud == null or not _loaded:
		return
	var cell: Dictionary = {} if hover_field < 0 or hover_cell.is_empty() else farm_state.get_cell(farm.field_id(hover_field), hover_cell)
	var state: Dictionary=farm_state.snapshot()
	hud.show_state(cell, state.harvested, selected_tool, selected_crop, camera.is_transitioning() or _save_failed or camera.free_view or _basket_active() or (camera_tuning != null and camera_tuning.visible), selected_field, selected_palette, state.inventory)
	hud.show_decoration_mode(decoration_layout != null and decoration_layout.active)
	if _layout_active(): hud.show_decoration_mode(true)

func _basket_active() -> bool:
	return harvest_book!=null and harvest_book.active

func _animal_active() -> bool:
	return animal_panel!=null and animal_panel.active

func _animal_at(point: Vector2) -> String:
	var animals: Node=$Environment/CourtyardAnimals
	var chosen: String=""
	var depth: float=INF
	for bird: Dictionary in animals.birds:
		var center: Vector3=bird.node.global_position+Vector3.UP*(.24 if bird.kind=="hen" else (.48 if bird.kind=="duck" else .67))*bird.node.scale.x
		if camera.is_position_behind(center): continue
		var projected: Vector2=camera.unproject_position(center)
		var edge: Vector2=camera.unproject_position(center+camera.global_basis.x*bird.radius)
		var radius: float=clampf(projected.distance_to(edge),12,42)
		if point.distance_to(projected)>radius: continue
		var distance: float=camera.global_position.distance_to(center)
		if distance<depth and decoration_layout.world_point_visible(center,animals):
			chosen=bird.node.name;depth=distance
	return chosen

func _open_animal(id: String) -> void:
	if not _tools_available(): return
	var bird: Dictionary=$Environment/CourtyardAnimals.interaction.find(id)
	if bird.is_empty(): return
	_cancel_tool();hud.hide_time_preview();camera.cancel_zoom()
	var data: Dictionary=farm_state.snapshot()
	animal_panel.present(id,data.animals[id],data.inventory)
	focus_detail.protect_neighbor(bird.node)
	camera.view_neighbor(bird.node.global_position+Vector3.UP*.25,Vector3(27.5,24,5.8))
	hud.hide()
	_refresh_hud()

func _animal_action(id: String,action: String,value: Variant,revision: int) -> void:
	if not _animal_active() or animal_panel.animal_id!=id or not _loaded or _save_failed: return
	var interaction: RefCounted=$Environment/CourtyardAnimals.interaction
	var approach: Dictionary={}
	if action in ["feed","call"]:
		approach=interaction.prepare(id,camera,decoration_layout.world_point_visible)
		if approach.is_empty(): animal_panel.show_issue("这会儿没有能靠近的空位");return
	var candidate:=FarmState.new();candidate.restore_snapshot(farm_state.snapshot())
	var result: Dictionary=candidate.animal_action(id,action,value,revision)
	if not result.ok:
		animal_panel.show_issue("名字请用一到十二个字" if result.reason=="invalid_name" else "这次操作未完成")
		return
	var saved: Dictionary=store.save(candidate.snapshot(),decoration_state.snapshot())
	if not saved.ok:
		_save_failed=true;animal_panel.dismiss();hud.show_storage_issue(saved.kind,true);_refresh_hud();return
	farm_state.restore_snapshot(candidate.snapshot())
	var data: Dictionary=farm_state.snapshot()
	interaction.profiles=data.animals
	if not approach.is_empty(): interaction.begin(id,approach,action=="feed")
	animal_panel.refresh(data.animals[id],data.inventory)
	animal_panel.set_activity(interaction.status(id))
	farm_audio.play_ui()
	_refresh_hud()

func _open_basket() -> void:
	if not _tools_available(): return
	_cancel_tool()
	hud.hide_time_preview()
	camera.cancel_free_gesture()
	camera.cancel_zoom()
	camera.free_input_enabled=false
	harvest_book.update_time(clock.call())
	harvest_book.present(farm_state.snapshot())
	_refresh_hud()

func _scene_entry_at(point: Vector2) -> String:
	var hit: MeshInstance3D=decoration_layout.environment_surface_at(point)
	if hit==null: return ""
	var tool: String = $Environment/DoorTools.tool_for_mesh(hit)
	if not tool.is_empty(): return "tool_" + tool
	for item: String in ["drying_rack","tea_table","pot"]:
		var placed: Node=decoration_layout._instances.get(item)
		if placed!=null and (placed==hit or placed.is_ancestor_of(hit)):
			return {"drying_rack":"rack","tea_table":"table","pot":"jar"}[item]
	var courtyard: Node3D=$Environment
	for pair: Array in [["Kitchen","stove"],["LivingDetails/SidePorchDryingRack","rack"],
		["LivingDetails/YardJarCluster","jar"],["LivingDetails/PorchHarvestTable","table"],
		["NeighborIslets/WillowNeighbor","willow"],["NeighborIslets/BambooNeighbor","bamboo"],
		["NeighborIslets/EasternCottage","ferry"]]:
		var source: Node=courtyard.get_node(pair[0])
		if source==hit or source.is_ancestor_of(hit): return pair[1]
	return ""

func _open_scene_entry(id: String) -> void:
	if not _tools_available(): return
	if id.begins_with("tool_"):
		_cancel_input()
		var tool: String = id.trim_prefix("tool_")
		if tool=="sow":
			_cancel_tool()
			_menu_target = {}
			field_menu.present_seeds(_pointer_position)
		else: _select_tool(tool)
		return
	if id in ["willow","bamboo","ferry"]:
		harvest_book.tab="neighbors"
		harvest_book.neighbor=id
		harvest_book._history_open=false
	elif id in ["stove","rack","jar","table"]:
		harvest_book.tab="kitchen"
		var choices: Dictionary={"stove":"leaf_stir","rack":"root_dry","jar":"leaf_pickle"}
		if choices.has(id): harvest_book.kitchen_page.recipe=choices[id]
	else: return
	_open_basket()

func _exchange(id: String, visit: int, basket: Dictionary, gift: String) -> void:
	if not _basket_active() or not _loaded or _save_failed: return
	var candidate:=FarmState.new()
	candidate.restore_snapshot(farm_state.snapshot())
	var result: Dictionary=candidate.share_basket(id,visit,basket) if gift.is_empty() else candidate.claim_gift(id,visit,gift)
	if not result.ok:
		harvest_book.refresh(farm_state.snapshot())
		return
	# Inventory and delivery receipt are one durable transaction. A failed write
	# never publishes the draft or charges the player; reopening can retry it.
	var saved: Dictionary=store.save(candidate.snapshot(),decoration_state.snapshot())
	if not saved.ok:
		_save_failed=true
		harvest_book.dismiss()
		hud.show_storage_issue(saved.kind,true)
		_refresh_hud()
		return
	farm_state.restore_snapshot(candidate.snapshot())
	_refresh_neighbor_stories()
	harvest_book.refresh(farm_state.snapshot())
	farm_audio.play_ui()
	_refresh_hud()

func _refresh_neighbor_stories() -> void:
	$Environment/NeighborIslets.show_stories(farm_state.snapshot().neighbors,$Environment/LivingDetails)

func _kitchen_action(action: String, request: Dictionary, revision: int) -> void:
	if not _basket_active() or not _loaded or _save_failed: return
	var candidate:=FarmState.new()
	candidate.restore_snapshot(farm_state.snapshot())
	var result: Dictionary=candidate.kitchen_action(action,request,revision,clock.call())
	if not result.ok:
		harvest_book.refresh(farm_state.snapshot())
		return
	var saved: Dictionary=store.save(candidate.snapshot(),decoration_state.snapshot())
	if not saved.ok:
		_save_failed=true
		harvest_book.dismiss()
		hud.show_storage_issue(saved.kind,true)
		_refresh_hud()
		return
	farm_state.restore_snapshot(candidate.snapshot())
	kitchen_display.refresh(farm_state.snapshot().kitchen)
	decoration_layout.update_life(farm_state.snapshot().kitchen)
	if action=="share": harvest_book.tab="journal"
	harvest_book.update_time(clock.call())
	harvest_book.refresh(farm_state.snapshot())
	farm_audio.play_ui()
	_refresh_hud()

func _change_season(id: String) -> void:
	if not _basket_active() or not _loaded or _save_failed: return
	var candidate:=FarmState.new()
	candidate.restore_snapshot(farm_state.snapshot())
	if not candidate.set_season(id): return
	if candidate.snapshot().season!=farm_state.snapshot().season:
		var saved: Dictionary=store.save(candidate.snapshot(),decoration_state.snapshot())
		if not saved.ok:
			_save_failed=true
			harvest_book.dismiss()
			hud.show_storage_issue(saved.kind,true)
			_refresh_hud()
			return
		farm_state.restore_snapshot(candidate.snapshot())
		_apply_season()
	harvest_book.refresh(farm_state.snapshot())
	farm_audio.play_ui()

func _apply_season() -> void:
	var id: String=farm_state.snapshot().season
	seasonal_courtyard.set_season(id)
	atmosphere.set_season(id)
	farm_audio.set_season(id)

func _change_decoration(candidate: Dictionary) -> void:
	if not _loaded or _save_failed: return
	var replacement:=DecorationState.new()
	if not replacement.restore_snapshot(candidate): return
	var candidate_farm:=FarmState.new();candidate_farm.restore_snapshot(farm_state.snapshot())
	if replacement.snapshot()!=decoration_state.snapshot(): candidate_farm.remember("arrange",clock.call())
	var saved: Dictionary=store.save(candidate_farm.snapshot(),replacement.snapshot())
	if not saved.ok:
		_save_failed=true
		decoration_layout.finish_mode()
		hud.show_storage_issue(saved.kind,true)
		_refresh_hud()
		return
	decoration_state=replacement
	farm_state.restore_snapshot(candidate_farm.snapshot())
	decoration_layout.accept_state(replacement)
	_refresh_hud()

func _view_neighbor(id: String) -> void:
	var scene_view: Dictionary=$Environment/NeighborIslets.story_view(id)
	focus_detail.protect_neighbor(scene_view.island)
	camera.view_neighbor(scene_view.point,scene_view.view)
	hud.hide()

func _layout_active() -> bool:
	return (courtyard_edit!=null and courtyard_edit.editor.active) or (island_builder!=null and island_builder.active)

func _begin_construction(tool: String = "land") -> void:
	if not _loaded or _save_failed: return
	if decoration_layout.active: decoration_layout.finish_mode()
	_cancel_tool();_cancel_input();field_menu.dismiss();hud.hide_time_preview()
	camera.cancel_zoom()
	camera.set_construction_framing(true,_construction_resume.is_empty())
	_construction_resume={}
	island_builder.begin(self,tool);hud.hide()

func _apply_construction(snapshot: Dictionary, undo: bool) -> void:
	if not island_builder.active or island_builder.busy: return
	island_builder.set_busy(true,"正在检查岸边、支承和通路…")
	await get_tree().process_frame
	var plan: RefCounted=CourtyardPlan.from_snapshot(snapshot)
	if plan==null:
		island_builder.set_busy(false,"范围或尺寸不合适，请调整后再试。")
		return
	var message: String=preload("res://layout/island_construction.gd").bridge_issue(plan)
	if message.is_empty():
		var probe:=preload("res://scenes/environment/courtyard.gd").new()
		probe.plan=plan;probe.layout_probe=true;probe.process_mode=Node.PROCESS_MODE_DISABLED
		add_child(probe)
		var obstacles: Dictionary=probe.layout_obstacles.duplicate(true)
		obstacles.merge(decoration_layout.ground_footprints())
		var space=preload("res://scenes/environment/animal_space.gd")
		if not plan.construction.trellis.is_empty():
			var trellis: PackedVector2Array=space.footprint(probe.get_node("EntranceTrellis"),plan.ground_height-.02,plan.ground_height+3.2)
			if not Geometry2D.clip_polygons(trellis,plan.plateau()).is_empty(): message="菜架的立柱需要全部落在平地上。"
			for key: String in obstacles:
				if key=="EntranceTrellis" or key.begins_with("stone") or key.begins_with("@Node"): continue
				if not Geometry2D.intersect_polygons(trellis,obstacles[key]).is_empty():
					print("CONSTRUCTION_REJECT stage=trellis object="+key)
					message="菜架碰到了旁边的物件，请调整长宽。";break
		var area: Array=plan.construction.ducks.area
		if not area.is_empty() and int(plan.construction.ducks.count)>0:
			if not Geometry2D.intersect_polygons(preload("res://layout/island_construction.gd").rectangle(area),plan.rim).is_empty(): message="请为鸭群保留水面，或先调整它们的活动区域。"
		var east: PackedVector2Array=space.footprint(probe.get_node("EastBank"),plan.ground_height-.04,plan.ground_height+.02)
		if not Geometry2D.intersect_polygons(plan.plateau(),east).is_empty(): message="添地碰到了对岸，请留出水道。"
		var issues: Array[String]=preload("res://layout/courtyard_circulation.gd").field_placement_issues(plan,obstacles)
		if not issues.is_empty(): message="这里会碰到田地，请缩小范围或调整位置。"
		if message.is_empty():
			var routes:=preload("res://layout/courtyard_circulation.gd").new()
			routes.build(plan,obstacles)
			if not routes.issues.is_empty(): message="这里会挡住通路，请为屋前、田边和桥头留出空间。"
		remove_child(probe);probe.free()
	if not message.is_empty():
		island_builder.set_busy(false,message);return
	var candidate:=FarmState.new();candidate.restore_snapshot(farm_state.snapshot())
	var result: Dictionary=candidate.apply_layout(snapshot,clock.call())
	if not result.ok:
		island_builder.set_busy(false,"已有作物需要保留，请调整范围。");return
	var saved: Dictionary=store.save(candidate.snapshot(),decoration_state.snapshot())
	if not saved.ok:
		island_builder.set_busy(false,"未能保存，岛屿保持原样。可再次确认重试，或取消调整。");return
	previous_layout={} if undo else farm_state.snapshot().layout
	farm_state=candidate
	island_builder.set_busy(true,"已保存，正在更新小岛…")
	_reload_saved_scene()

func _begin_courtyard_edit() -> void:
	if not _loaded or _save_failed or _layout_active(): return
	_return_overview()
	hud.hide_time_preview()
	camera.cancel_zoom()
	courtyard_edit.begin($Environment,farm_state,decoration_layout.ground_footprints(),previous_layout)
	_refresh_hud()

func _apply_courtyard(snapshot: Dictionary, undo: bool) -> void:
	if not _layout_active() or courtyard_edit.editor.busy: return
	var candidate:=FarmState.new()
	candidate.restore_snapshot(farm_state.snapshot())
	var result: Dictionary=candidate.apply_layout(snapshot,clock.call())
	if not result.ok:
		courtyard_edit.editor.set_busy(false,"将移除的田格里还有作物，请先收获，或保留这些田格。")
		return
	courtyard_edit.editor.set_busy(true,"正在整理小院…")
	await get_tree().process_frame
	await get_tree().process_frame
	if _exiting: return
	# Commit to disk before replacing either the authoritative state or its scene.
	# A failed write leaves the old island/crops intact and the draft retryable.
	var saved: Dictionary=store.save(candidate.snapshot(),decoration_state.snapshot())
	if not saved.ok:
		courtyard_edit.editor.set_busy(false,"未能保存，本次整理还没有生效。可以重试，或取消保留原来的小院。")
		return
	previous_layout={} if undo else farm_state.snapshot().layout
	farm_state=candidate
	_reload_saved_scene()


func _begin_decoration() -> void:
	if not _loaded or _save_failed or decoration_layout == null or _layout_active():
		return
	if decoration_layout.active:
		decoration_layout.finish_mode()
		return
	_return_overview()
	decoration_layout.begin_mode()
	farm_audio.play_ui()


func _on_decoration_mode_changed(active: bool) -> void:
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	selected_field = -1
	selected_cell = ""
	farm.select_field(-1)
	farm.select_cell(-1, "")
	if focus_detail != null:
		focus_detail.set_focus()
	camera.set_decoration_framing(active)
	_refresh_hud()


func _refresh_lanterns() -> void:
	if atmosphere != null and decoration_layout != null:
		atmosphere.set_lantern_anchors(decoration_layout.lantern_anchors())


func _input(event: InputEvent) -> void:
	if desktop_wallpaper != null and (desktop_wallpaper.active or desktop_wallpaper.busy): return
	if island_builder!=null and island_builder.active:
		island_builder.observe(event);return
	if field_menu != null and field_menu.active:
		if (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index!=MOUSE_BUTTON_LEFT):
			field_menu.dismiss()
			_cancel_input()
			get_viewport().set_input_as_handled()
		return
	if garden_album!=null and garden_album.active:
		garden_album.cancel_key(event)
		return
	if _animal_active():
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):
			animal_panel.dismiss();get_viewport().set_input_as_handled()
		return
	if _basket_active():
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):
			if harvest_book.viewing: harvest_book.end_view()
			else: harvest_book.dismiss()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		_pointer_position = event.position
	if not _loaded or _save_failed:
		return
	if _layout_active():
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT):
			courtyard_edit.editor.cancel()
			get_viewport().set_input_as_handled()
		return
	if camera_tuning != null and camera_tuning.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			camera_tuning.hide()
			get_viewport().set_input_as_handled()
		return
	if game_menu != null and game_menu.visible:
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			if decoration_layout.active and not decoration_layout.selected_item.is_empty():
				decoration_layout.cancel_preview()
			else:
				_request_menu_close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and OS.is_debug_build():
		_toggle_free_view()
		get_viewport().set_input_as_handled()
		return
	if camera.free_view:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_return_overview()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and (not event.pressed or event.canceled):
			camera.end_free_drag(event.button_index)
		return
	if decoration_layout != null and decoration_layout.active:
		decoration_layout.observe_input(event)
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			if decoration_layout.selected_item.is_empty():
				decoration_layout.finish_mode()
			else:
				decoration_layout.cancel_preview()
			get_viewport().set_input_as_handled()
		return
	if selected_tool == "sow" and event is InputEventMouseButton and event.pressed and not event.canceled and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not hud.is_time_preview_open():
		var ids: Array[String] = Crops.crop_ids()
		_select_crop(ids[posmod(ids.find(selected_crop) + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), ids.size())])
		get_viewport().set_input_as_handled()
		return
	# Cancellation sees even GUI-consumed releases; world gestures start only in unhandled input.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel_or_return()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_or_return()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _press_position != Vector2.INF:
		_press_dragged = _press_dragged or event.position.distance_to(_press_position) > 7.0
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = false
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var hovered := get_viewport().gui_get_hovered_control()
			if event.canceled:
				_cancel_input()
			elif hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				_cancel_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if desktop_wallpaper != null and (desktop_wallpaper.active or desktop_wallpaper.busy): return
	if island_builder!=null and island_builder.active:
		island_builder.handle(event);return
	if field_menu != null and field_menu.active: return
	if garden_album!=null and garden_album.active: return
	if _animal_active(): return
	if _basket_active(): return
	if _layout_active(): return
	if camera_tuning != null and camera_tuning.visible:
		return
	if not _loaded or _save_failed or (game_menu != null and game_menu.visible):
		return
	if camera.free_view:
		camera.free_input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and not event.canceled and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_cancel_input()
		if decoration_layout != null:
			decoration_layout.cancel_pointer_gesture()
		camera.zoom((-0.8 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8) * event.factor)
		get_viewport().set_input_as_handled()
		return
	if decoration_layout != null and decoration_layout.active:
		decoration_layout.handle_input(event)
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.double_click or event.canceled:
					_cancel_input()
				elif event.pressed:
					_tool_press = {}
					_press_position = event.position
					_press_dragged = _dragging
					_picks.append({"down": true, "position": event.position, "dragged": _dragging,
						"action_allowed": not camera.is_transitioning(), "selection": selected_field})
				elif _press_position != Vector2.INF:
					_picks.append({"down": false, "position": event.position, "dragged": _press_dragged,
						"action_allowed": not camera.is_transitioning()})
					_press_position = Vector2.INF
			MOUSE_BUTTON_MIDDLE:
				_cancel_input()
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		camera.drag(event.relative, event.shift_pressed)


func _physics_process(_delta: float) -> void:
	if desktop_wallpaper != null and (desktop_wallpaper.active or desktop_wallpaper.busy): return
	if field_menu != null and field_menu.active:
		$Environment/DoorTools.set_hover("")
		if not _tools_available(): field_menu.dismiss()
		_cancel_input()
		return
	if garden_album!=null and garden_album.active:
		_cancel_input()
		return
	if _animal_active():
		animal_panel.set_activity($Environment/CourtyardAnimals.interaction.status(animal_panel.animal_id))
		_cancel_input()
		return
	_update_hover()
	if _layout_active() or _basket_active() or camera.free_view or (game_menu != null and game_menu.visible):
		_cancel_input()
		return
	# Space queries belong to the physics boundary. Each gesture carries its admission
	# state so a click made in flight can never become an action after the tween ends.
	var picks: Array[Dictionary] = _picks
	_picks = []
	for pick: Dictionary in picks:
		if selected_tool.is_empty() or $Environment/DoorTools.may_hit(camera,pick.position):
			var animal: String=_animal_at(pick.position) if selected_tool.is_empty() else ""
			var entry: String=_scene_entry_at(pick.position) if animal.is_empty() else ""
			if not selected_tool.is_empty() and not entry.begins_with("tool_"): entry=""
			if pick.down:
				_pressed_animal=animal
				_pressed_entry=entry
			elif not _pressed_animal.is_empty() or not _pressed_entry.is_empty():
				var same_animal: bool=not _pressed_animal.is_empty() and animal==_pressed_animal
				var same_entry: bool=not _pressed_entry.is_empty() and entry==_pressed_entry
				_pressed_animal=""
				_pressed_entry=""
				if not pick.dragged and pick.action_allowed and _press_context.get("action_allowed",false):
					if same_animal: _open_animal(animal)
					elif same_entry: _open_scene_entry(entry)
				_pressed_field=-1;_pressed_cell="";_press_context={}
				continue
		var hit: Dictionary = _farm_hit(pick.position)
		var index: int = hit.get("field", -1)
		var cell_id: String = hit.get("cell", "")
		if pick.down:
			_pressed_field = index
			_pressed_cell = cell_id
			_press_context = pick
		else:
			if not pick.dragged and index >= 0 and index == _pressed_field and cell_id == _pressed_cell:
				if pick.action_allowed and _press_context.get("action_allowed", false) and not camera.is_transitioning():
					if not selected_tool.is_empty() and not cell_id.is_empty():
						selected_field = index
						selected_cell = cell_id
						_apply_tool()
					elif not cell_id.is_empty():
						_present_field_menu(index,cell_id,pick.position)
					elif index != selected_field or not camera.focused:
						_focus_field(index)
					else:
						_select_cell(cell_id)
			_pressed_field = -1
			_pressed_cell = ""
			_press_context = {}


func _notification(what: int) -> void:
	if _exiting:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_request_exit()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_MOUSE_EXIT:
		if field_menu != null: field_menu.dismiss()
		if garden_album!=null and garden_album.active: camera.cancel_free_gesture()
		if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and animal_panel!=null: animal_panel.dismiss()
		_pointer_position = Vector2(-100, -100)
		_cancel_input()
		if _layout_active(): courtyard_edit.editor.chart.cancel_drag()
		if is_instance_valid(camera):
			camera.cancel_free_gesture()
			camera.cancel_zoom()
		selected_tool = ""
		selected_palette = ""
		if decoration_layout != null and decoration_layout.active:
			if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
				decoration_layout.finish_mode()
			else:
				decoration_layout.cancel_preview()
		if is_node_ready():
			_refresh_hud()
			if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _loaded and not _save_failed:
				settle_farm()
				_save_farm()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN and is_node_ready():
		settle_farm()


func _field_at(screen_point: Vector2) -> int:
	return int(_farm_hit(screen_point).get("field", -1))


func _cell_at(screen_point: Vector2, field_index: int) -> String:
	var hit: Dictionary = _farm_hit(screen_point)
	return str(hit.get("cell", "")) if hit.get("field", -1) == field_index else ""


func _farm_hit(screen_point: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(screen_point)
	var end := origin + camera.project_ray_normal(screen_point) * 120.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var index: int = int(hit.collider.get_meta("field_index", -1))
	if index < 0:
		return {}
	# Only the actual top soil plane can select a cell; bed sides still focus its field.
	var cell_id: String = farm.cell_at(index, hit.position) if camera.focused and index == selected_field and hit.normal.y > 0.9 else ""
	return {"field": index, "cell": cell_id}


func _focus_field(index: int) -> void:
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	selected_field = index
	selected_cell = ""
	farm.select_field(index)
	farm.select_cell(-1, "")
	focus_detail.set_focus(farm.fields[index])
	camera.focus_field(farm.fields[index].global_position,farm.fields[index].get_meta("field_size"))
	_refresh_hud()


func _select_cell(cell_id: String) -> void:
	if selected_field < 0 or (not cell_id.is_empty() and not farm.cell_ids(selected_field).has(cell_id)):
		return
	_cancel_input()
	selected_cell = cell_id
	farm.select_cell(selected_field, cell_id)
	_refresh_hud()


func _tools_available() -> bool:
	return _loaded and not _save_failed and not _exiting and not _layout_active() and not _basket_active() and not _animal_active() and not (camera_tuning != null and camera_tuning.visible) and not camera.free_view and not camera.is_transitioning() and not (game_menu != null and game_menu.visible) and not (decoration_layout != null and decoration_layout.active)


func _start_tool_press(tool: String) -> void:
	var dragging: bool = _dragging
	_cancel_input()
	if not dragging and _tools_available():
		_tool_press = {"tool": tool}


func _finish_tool_press(tool: String) -> void:
	var admitted: bool = _tool_press.get("tool", "") == tool
	_tool_press = {}
	if admitted:
		_select_tool(tool)


func _can_work_cell() -> bool:
	return _tools_available() and camera.focused and selected_field >= 0 and not selected_cell.is_empty()


func _open_palette(palette: String) -> void:
	if not _tools_available() or palette not in ["sow", "tools"]:
		return
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	_menu_target = {}
	if palette == "sow": field_menu.present_seeds(_pointer_position)
	else: field_menu.present_tools(_pointer_position)
	farm_audio.play_ui()
	_refresh_hud()


func _select_tool(tool: String) -> void:
	_cancel_input()
	if not _tools_available() or tool not in ["sow", "water", "harvest", "weed", "till"]:
		return
	selected_tool = "" if selected_tool == tool else tool
	selected_palette = ""
	_refresh_hud()


func _select_crop(crop_id: String) -> void:
	if not _tools_available() or not Crops.crop_ids().has(crop_id):
		return
	_cancel_input()
	camera.cancel_zoom()
	selected_crop = crop_id
	selected_tool = "sow"
	selected_palette = ""
	farm_audio.play_ui()
	_refresh_hud()


func _cancel_tool() -> void:
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	_refresh_hud()


func _update_hover() -> void:
	if tool_cursor == null:
		return
	var ui: Control = get_viewport().gui_get_hovered_control()
	var blocked: bool = not _tools_available() or _dragging or (ui != null and ui.mouse_filter != Control.MOUSE_FILTER_IGNORE) or not get_viewport().get_visible_rect().has_point(_pointer_position)
	var door_tools: Node3D = $Environment/DoorTools
	var tool_hit: String = ""
	# Test the three tiny bounds first; only perform scene occlusion when nearby.
	if not blocked and door_tools.may_hit(camera,_pointer_position):
		tool_hit = _scene_entry_at(_pointer_position).trim_prefix("tool_")
	door_tools.set_hover(tool_hit)
	var hit: Dictionary = {} if blocked else _farm_hit(_pointer_position)
	var index: int = hit.get("field", -1)
	var cell_id: String = hit.get("cell", "")
	if index != hover_field or cell_id != hover_cell:
		hover_field = index
		hover_cell = cell_id
		farm.select_cell(index, cell_id)
		farm.select_field(index if index >= 0 and cell_id.is_empty() else selected_field)
		_refresh_hud()
	tool_cursor.show_tool("" if blocked else selected_tool, selected_crop)


func _present_field_menu(index: int, cell_id: String, point: Vector2) -> void:
	if not _tools_available() or not camera.focused or index != selected_field or cell_id.is_empty(): return
	_cancel_input()
	selected_field = index
	selected_cell = cell_id
	_menu_target = {"field":index,"cell":cell_id}
	farm.select_cell(index,cell_id)
	field_menu.present(point,farm_state.get_cell(farm.field_id(index),cell_id))
	_refresh_hud()


func _field_menu_action(tool: String, crop: String) -> void:
	var target: Dictionary = _menu_target
	_menu_target = {}
	if not _tools_available(): return
	if not crop.is_empty(): selected_crop = crop
	if target.is_empty():
		if tool == "sow": _select_crop(crop)
		else: _select_tool(tool)
		return
	if not camera.focused or target.field != selected_field: return
	selected_field = target.field
	selected_cell = target.cell
	selected_tool = tool
	_apply_tool()
	# A soil-menu action is one-shot; a prop equips a tool for repeated use.
	_cancel_tool()


func _apply_tool() -> void:
	if not _can_work_cell() or selected_tool.is_empty():
		return
	var field_id: String = farm.field_id(selected_field)
	var now: float = clock.call()
	var candidate:=FarmState.new()
	candidate.restore_snapshot(farm_state.snapshot())
	var result: Dictionary
	match selected_tool:
		"sow": result = candidate.sow(field_id, selected_cell, selected_crop, now)
		"water": result = candidate.water(field_id, selected_cell, now)
		"harvest": result = candidate.harvest(field_id, selected_cell, now)
		"weed", "till": result = candidate.tidy(selected_tool,field_id,selected_cell,now)
		_: return
	if result.ok:
		var decorations:=DecorationState.new()
		decorations.restore_snapshot(decoration_state.snapshot())
		decorations.unlock(candidate.snapshot().harvested)
		var saved: Dictionary=store.save(candidate.snapshot(),decorations.snapshot())
		if not saved.ok:
			_save_failed=true
			_cancel_tool()
			hud.show_storage_issue(saved.kind,true)
			return
		farm_state.restore_snapshot(candidate.snapshot())
		decoration_state.restore_snapshot(decorations.snapshot())
		farm_audio.play_action(selected_tool, result)
		refresh_farm()
		farm_changed.emit(result)


func _cancel_or_return() -> void:
	_cancel_input()
	if not selected_tool.is_empty() or not selected_palette.is_empty():
		_cancel_tool()
	elif not selected_cell.is_empty():
		_select_cell("")
	else:
		_return_overview()


func _return_overview() -> void:
	if camera_tuning != null:
		camera_tuning.hide()
	if camera.free_view:
		camera.set_free_view(false)
		hud.show_free_view(false)
	if decoration_layout != null and decoration_layout.active:
		decoration_layout.finish_mode()
	_cancel_input()
	selected_tool = ""
	selected_palette = ""
	selected_field = -1
	selected_cell = ""
	farm.select_field(-1)
	farm.select_cell(-1, "")
	focus_detail.set_focus()
	camera.return_overview()
	_refresh_hud()


func _reset_view() -> void:
	_return_overview()
	camera.reset_view()
	_refresh_hud()


func _toggle_free_view() -> void:
	if not OS.is_debug_build() or not _loaded or _save_failed or (game_menu != null and game_menu.visible):
		return
	var enabled: bool = not camera.free_view
	_return_overview()
	if enabled:
		camera.set_free_view(true)
		hud.show_free_view(true)


func _toggle_camera_tuning() -> void:
	if camera_tuning == null or not _loaded or _save_failed or (game_menu != null and game_menu.visible):
		return
	if camera_tuning.visible:
		camera_tuning.hide()
		return
	_return_overview()
	hud.hide_time_preview()
	camera_tuning.present(focus_detail.get_settings())


func _cancel_input(cancel_tool_press: bool = true) -> void:
	_pressed_animal=""
	_pressed_entry=""
	if cancel_tool_press:
		_tool_press = {}
	_dragging = false
	_press_position = Vector2.INF
	_press_dragged = true
	_pressed_field = -1
	_pressed_cell = ""
	_press_context = {}
	_picks.clear()


func _setup_settings() -> void:
	if settings_store == null:
		settings_store = SettingsStore.new()
	var loaded: Dictionary = settings_store.load_settings()
	settings_values = loaded.settings
	if OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview"):
		# Development startup overrides the old window preference for this session.
		settings_values.fullscreen = true
	if not loaded.ok:
		_settings_issue = {
			"corrupt": "设置文件无法读取，已使用默认设置；原件保留。保存设置时会先留存原件。",
			"unsupported": "设置来自较新版本，本次使用默认设置；原件保留，暂时不能覆盖。",
		}.get(loaded.kind, "设置暂时无法读取，本次使用默认设置；农场进度不受影响。")
	game_menu = GameMenu.new()
	game_menu.name = "GameMenu"
	add_child(game_menu)
	game_menu.settings_changed.connect(_change_settings)
	game_menu.save_requested.connect(_save_settings)
	game_menu.close_requested.connect(_request_menu_close)
	game_menu.quit_requested.connect(_request_exit)
	game_menu.wallpaper_requested.connect(_enter_wallpaper)
	_apply_settings()
	hud.show_settings_issue(not _settings_issue.is_empty())


func _apply_settings() -> void:
	farm_audio.set_volumes(settings_values.master, settings_values.music, settings_values.effects)
	focus_detail.set_quality(settings_values.quality)
	focus_detail.set_depth_of_field(settings_values.dof_enabled, focus_detail.get_settings().dof_strength)
	# Headless validation has no OS window; preference validation remains identical.
	if DisplayServer.get_name() != "headless" and not (desktop_wallpaper != null and (desktop_wallpaper.active or desktop_wallpaper.busy)):
		var window: Window = get_window()
		var desired: Window.Mode = Window.MODE_FULLSCREEN if settings_values.fullscreen else Window.MODE_WINDOWED
		if settings_values.fullscreen and OS.has_feature("editor") and OS.get_cmdline_user_args().has("--dev-preview"):
			desired = Window.MODE_EXCLUSIVE_FULLSCREEN
		if window.mode != desired:
			_cancel_input()
			window.mode = desired
			if not settings_values.fullscreen:
				window.borderless = false


func _open_menu() -> void:
	if game_menu == null or not _loaded or _save_failed:
		return
	_cancel_input()
	if camera_tuning != null:
		camera_tuning.hide()
	hud.hide_time_preview()
	camera.free_input_enabled = false
	camera.cancel_free_gesture()
	camera.cancel_zoom()
	decoration_layout.cancel_pointer_gesture()
	selected_tool = ""
	selected_palette = ""
	_allow_leave_settings = false
	_refresh_hud()
	game_menu.present(settings_values, _settings_issue)
	farm_audio.play_ui()


func _enter_wallpaper() -> void:
	if desktop_wallpaper == null or desktop_wallpaper.active or desktop_wallpaper.busy: return
	if not _loaded or _save_failed or _layout_active() or (garden_album != null and garden_album.active): return
	if (_settings_dirty or not _settings_issue.is_empty()) and not _save_settings(): return
	settle_farm()
	if not _save_farm(): return
	_wallpaper_issue = ""
	_cancel_input()
	_cancel_tool()
	camera.cancel_free_gesture()
	camera.cancel_zoom()
	game_menu.set_status("正在进入桌面壁纸；双击托盘图标即可返回农场。")
	desktop_wallpaper.enter()


func _wallpaper_changed(enabled: bool) -> void:
	_cancel_input()
	window_activity.set_wallpaper(enabled)
	camera.free_input_enabled = not enabled
	get_viewport().gui_disable_input = enabled
	if enabled:
		game_menu.dismiss()
		hud.hide()
	else:
		hud.show()
		_refresh_hud()
		settle_farm()
		if not _wallpaper_issue.is_empty():
			game_menu.present(settings_values, _wallpaper_issue)


func _change_settings(value: Dictionary) -> void:
	if not SettingsStore.valid_settings(value):
		return
	settings_values = value.duplicate(true)
	_settings_dirty = true
	_allow_leave_settings = false
	_apply_settings()
	hud.show_settings_issue(true)


func _save_settings() -> bool:
	var result: Dictionary = settings_store.save(settings_values)
	if result.ok:
		_settings_dirty = false
		_settings_issue = ""
		_allow_leave_settings = false
		game_menu.set_status("设置已保存。")
	else:
		_settings_issue = "设置未能保存，本次调整仍然有效。可重试保存；农场进度不受影响。"
		if result.kind in ["unsupported", "unsupported_pending"]:
			_settings_issue = "设置来自较新版本，未能保存；原件保留，本次调整只在当前窗口有效。"
		_allow_leave_settings = true
		game_menu.set_status(_settings_issue, true)
	hud.show_settings_issue(not result.ok)
	return result.ok


func _request_menu_close() -> void:
	_cancel_input()
	decoration_layout.cancel_pointer_gesture()
	if (_settings_dirty or not _settings_issue.is_empty()) and not _allow_leave_settings:
		if not _save_settings():
			return
	game_menu.dismiss()
	_allow_leave_settings = false
	camera.free_input_enabled = true
	_refresh_hud()
	hud.get_node("Layout/ViewControls/Settings").grab_focus()


func _report_preview_ready() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("DEV_PREVIEW_READY screen=%d mode=%d size=%s" % [DisplayServer.window_get_current_screen(), get_window().mode, DisplayServer.window_get_size()])
