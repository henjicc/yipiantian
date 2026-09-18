extends SceneTree
const State=preload("res://farm/farm_state.gd")
const Store=preload("res://farm/farm_store.gd")
var scene: Node
var folder: String
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok: failures+=1;push_error(label)
func click(control: Control) -> void:
	var point: Vector2=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	await physics_frame;await process_frame
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
		await physics_frame;await process_frame
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join(label+".png"))
func choose(id: String) -> void:
	await click(scene.harvest_book._content.find_child(id,true,false))
	await create_timer(.3).timeout
func open_season() -> void:
	scene._open_basket();await create_timer(.25).timeout
	await click(scene.harvest_book._tabs.season)
func run() -> void:
	folder=ProjectSettings.globalize_path("res://../.local/verification/season-%d"%Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	var state:=State.new(1000);var invalid: Dictionary=state.snapshot();invalid.season="storm"
	check(not state.restore_snapshot(invalid),"Unknown season rejected atomically")
	check(state.snapshot().season=="daily" and not state.set_season("winter"),"Safe initial season, no undeclared themes")
	scene=load("res://scenes/main.tscn").instantiate();scene.store=Store.new(folder.path_join("farm"));scene.settings_store=load("res://settings/settings_store.gd").new(folder.path_join("settings"));scene.clock=func() -> float: return 1000
	root.add_child(scene);await process_frame
	while not scene.get_node("Environment/CourtyardAnimals").ready_for_motion: await process_frame
	scene.atmosphere.set_preview_hour(14);await create_timer(.4).timeout
	var original: Dictionary=scene.farm_state.snapshot()
	var daily_energy: float=scene.get_node("DirectionalLight3D").light_energy
	var presentation: Node=scene.seasonal_courtyard
	check(presentation._ordinary_bundles.size()==4,"All four original hanging bundles identified")
	await shot("daily")
	await open_season();await shot("choices")
	await choose("drying")
	check(scene.farm_state.snapshot().season=="drying" and presentation._autumn.visible,"Real choice publishes autumn props after save")
	for bundle: Node3D in presentation._ordinary_bundles: check(not bundle.visible,"Original food not doubled")
	check(scene.farm_audio._season.stream.loop and scene.farm_audio._season.has_stream_playback(),"Autumn ambience started, including when focus-paused")
	scene.farm_audio.set_foreground(true)
	scene.farm_audio._season.seek(47.85);await create_timer(.4).timeout
	check(scene.farm_audio._season.playing and scene.farm_audio._season.get_playback_position()<1.0,"Autumn sound actually loops across its end")
	scene.harvest_book.dismiss();await shot("drying")
	await open_season()
	var pending: String=scene.store.directory.path_join(Store.PENDING);DirAccess.make_dir_absolute(pending)
	await choose("after_rain")
	check(scene._save_failed and scene.farm_state.snapshot().season=="drying" and not presentation._wet.visible,"Write failure retains committed mood and props")
	DirAccess.remove_absolute(pending);scene._retry_storage();await create_timer(.2).timeout
	await open_season();await choose("after_rain")
	check(scene.farm_state.snapshot().season=="after_rain" and presentation._wet.visible,"Rain retry commits normally")
	check(presentation._wet.get_child_count()>0 and presentation._wet.get_child_count()<=8,"Wet ground follows derived paths within budget")
	check(not presentation._ground_materials.is_empty(),"Ground and stone materials receive rain wash")
	for material: ShaderMaterial in presentation._ground_materials: check(material.get_shader_parameter("rain_dampness")==1.0,"Rain wash reaches every admitted material")
	for cover: Node3D in presentation._rain_covers: check(cover.visible,"Rain shelters visible")
	for wet: Decal in presentation._wet.get_children(): check(wet.cull_mask==2,"Wet decals exclude actors and crops")
	check(scene.get_node("DirectionalLight3D").light_energy<daily_energy*.8,"Theme lighting survives clock updates")
	check(scene.farm_audio._season.stream.loop,"Rain sound loops")
	scene.farm_audio.set_foreground(false);check(scene.farm_audio._season.stream_paused,"Rain sound pauses on background")
	scene.harvest_book.dismiss();await shot("after-rain")
	scene.camera.view_neighbor(Vector3(0,.3,.5),Vector3(25,48,11));await create_timer(1.1).timeout
	await shot("wet-paths-close")
	scene.camera.view_neighbor(Vector3(.1,.4,4.65),Vector3(24,35,9));await create_timer(1.1).timeout
	await shot("shelter-close")
	scene.atmosphere.set_preview_hour(21);await create_timer(.3).timeout;await shot("rain-night")
	var loaded: Dictionary=Store.new(scene.store.directory).load_state()
	check(loaded.ok and loaded.farm.season=="after_rain","Saved theme reads back")
	var restored:=State.new();check(restored.restore_snapshot(loaded.farm),"Theme schema restores")
	restored.settle(1000+86400*90)
	check(restored.snapshot().season=="after_rain","No date lock or absence reset")
	var current: Dictionary=scene.farm_state.snapshot()
	# Real animal companionship can legitimately be observed during these views.
	for key: String in ["fields","harvested","inventory","neighbors","layout","kitchen","animals"]:
		check(current[key]==original[key],"Theme switches preserve "+key)
	scene.camera.return_overview();await create_timer(1).timeout
	await open_season();await choose("daily")
	check(not presentation._wet.visible and not presentation._autumn.visible,"Returning to daily removes special effects")
	for material: ShaderMaterial in presentation._ground_materials: check(material.get_shader_parameter("rain_dampness")==0.0,"Daily restores dry stone and earth")
	for bundle: Node3D in presentation._ordinary_bundles: check(bundle.visible,"Every original bundle restored")
	check(scene.farm_audio._season.stream==null,"Daily removes seasonal audio")
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(960,600);await create_timer(.4).timeout
	await shot("minimum")
	check(scene.harvest_book._paper.get_global_rect().end.x<=root.get_visible_rect().end.x,"New tab and choices fit minimum view")
	scene.farm_audio.shutdown();await create_timer(.15).timeout
	print("SEASON_SCENE failures=",failures," evidence=",folder)
	scene.queue_free();await process_frame;quit(0 if failures==0 else 1)
