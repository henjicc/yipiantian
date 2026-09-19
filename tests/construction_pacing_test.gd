extends "res://../tests/construction_life_test.gd"
## Real wall-clock waits and real earned food; no inventory fixtures or time jumps.

func harvest_opening_crop() -> void:
	await tap(cell_point(2,"cell_06"));await create_timer(1).timeout
	await tap(cell_point(2,"cell_06"))
	if not scene.field_menu.active: expect(false,"Opening harvest menu is reachable");return
	var petal: Control=scene.field_menu.cards.get_node("harvest")
	await tap(petal.global_position+petal.center)

func wait_for_food(button: Control,deadline: float) -> void:
	while button.disabled:
		await create_timer(.2).timeout
		if Time.get_unix_time_from_system()>deadline+2:
			expect(false,"Ready action enables at the advertised time");return

func _run() -> void:
	root.size=Vector2i(1600,900)
	var exchange: bool=OS.get_cmdline_user_args().has("--exchange")
	folder=ProjectSettings.globalize_path("res://../.local/verification/construction-pacing-%d"%Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(folder);print("EVIDENCE "+folder," route=", "exchange" if exchange else "direct")
	scene=load("res://scenes/main.tscn").instantiate();scene.name="FarmExperience"
	scene.store=Store.new(folder.path_join("farm"));scene.settings_store=Settings.new(folder.path_join("settings"))
	scene.clock=func() -> float: return Time.get_unix_time_from_system()
	root.add_child(scene);current_scene=scene;await frames(8)
	scene.atmosphere.set_preview_hour(11)
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	await choose_tool("lantern")
	expect(scene.island_builder._status.text.contains("0/16") and scene.island_builder._status.text.contains("0/3"),"Locked object shows current baskets and varieties")
	await choose_tool("drying_rack")
	expect(scene.island_builder._status.text.contains("0/1") and scene.island_builder._status.text.contains("厨房"),"First construction reward names its next activity")
	await shot("01-unlock-progress")
	await click(scene.island_builder._panel.find_child("Finish",true,false));await create_timer(1).timeout
	await open_kitchen()
	expect(page_button("FirstMealHarvest")!=null,"Empty pantry gives an actionable return to the field")
	await click(page_button("FirstMealHarvest"));await frames()
	await harvest_opening_crop()
	expect(scene.farm_state.snapshot().inventory.greens==1,"Real opening harvest supplies the complete first-meal cost")
	await open_kitchen()
	if exchange:
		await click(scene.harvest_book._tabs.neighbors)
		var amount: SpinBox=page_button("Amount_greens")
		await click(amount)
		amount.value=1 # Real quantity control; remaining actions use pointer input.
		await click(page_button("Share"));await click(scene.harvest_book._tabs.kitchen)
		expect(page_button("FirstMealGift")!=null,"Sending the initial crop does not strand the reward path")
		await click(page_button("FirstMealGift"));await click(page_button("Gift_radish"))
		await click(scene.harvest_book._tabs.kitchen)
		expect(page_button("FirstMealCook").text.contains("白萝卜1篮") and page_button("FirstMealCook").text.contains("35秒"),"Reply ingredient offers a usable short recipe without requiring more planting")
	else:
		expect(page_button("FirstMealCook").text.contains("青菜1篮") and page_button("FirstMealCook").text.contains("20秒"),"First recipe action clearly names ingredient cost and wait")
	await shot("02-next-recipe")
	await click(page_button("FirstMealCook"))
	var job: Dictionary=scene.farm_state.snapshot().kitchen.jobs.stove
	expect(not job.is_empty() and page_button("FirstMealCollect").disabled,"Meal starts once; collection cannot skip the real wait")
	if job.is_empty(): await finish();return
	var inventory: Dictionary=scene.farm_state.snapshot().inventory
	expect(preload("res://farm/crop_catalog.gd").total_harvested(inventory)==0,"No spare food is needed to continue building")
	scene.harvest_book.dismiss();await frames()
	await click(scene.hud.get_node("Layout/BuildIsland"));await create_timer(1).timeout
	await drag(Vector3(0,.13,6),Vector3(0,.13,8.5))
	await drag(Vector3(0,.13,8.5),Vector3(2.5,.13,8.5))
	await click(scene.island_builder._confirm);await frames()
	expect(scene.courtyard_plan.land_bounds().end.y>=8.5 and scene.farm_state.snapshot().inventory==inventory,"Actual land expansion remains free while food cooks")
	await choose_tool("bench")
	await tap(scene.camera.unproject_position(Vector3(0,.13,7.5)))
	await click(scene.island_builder._panel.find_child("Finish",true,false));await create_timer(1).timeout
	expect(scene.decoration_layout._instances.has("bench") and scene.farm_state.snapshot().inventory==inventory,"Free furniture placement also works with an empty pantry")
	expect(scene.farm_state.snapshot().kitchen.jobs.stove==job,"Building does not reset or charge the running recipe")
	await open_kitchen()
	await click(scene.harvest_book._tabs.journal)
	var collect: Control=page_button("FirstMealCollect")
	expect(collect!=null,"Journal also provides the pending next step")
	if collect==null: await finish();return
	await wait_for_food(collect,job.finish_utc)
	expect(page_button("RackProgress").text.contains("可收起"),"Real-time progress updates on journal page")
	await shot("03-ready-during-building")
	await click(collect)
	expect(page_button("FirstMealShare")!=null,"Completed dish offers explicit sharing action")
	await click(page_button("FirstMealShare"))
	expect(scene.decoration_state.snapshot().drying_rack.unlocked and page_button("BuildDryingRack")!=null,"One real harvest and actual wait unlock usable construction")
	print("PACING_REAL_SECONDS ",Time.get_unix_time_from_system()-job.start_utc," recipe_seconds=",job.finish_utc-job.start_utc)
	await click(page_button("BuildDryingRack"));await create_timer(1).timeout
	# Select clear supported ground, respecting the rocks on the freshly drawn bank.
	var rack_site: bool=false
	for position: Vector3 in [Vector3(1.5,.13,8),Vector3(.5,.13,8.5),Vector3(2,.13,8),Vector3(.5,.13,8)]:
		var point: Vector2=scene.camera.unproject_position(position)
		if not root.get_visible_rect().has_point(point): continue
		await tap(point)
		var decor: Node=scene.decoration_layout
		if decor.has_preview() and decor.placement_issue(decor._preview,"drying_rack",decor.preview_slot).is_empty(): rack_site=true;break
	expect(rack_site,"Expanded ground contains a clear supported site for the reward")
	await shot("04-rack-preview")
	print("RACK_SITE ",scene.decoration_layout.preview_position," ",scene.decoration_layout._message)
	await click(scene.island_builder._panel.find_child("Finish",true,false));await create_timer(1).timeout
	expect(scene.decoration_layout._instances.has("drying_rack") and scene.farm_state.snapshot().inventory==inventory,"Earned rack needs no extra payment or additional crop cycle")
	if not scene.decoration_layout._instances.has("drying_rack"):
		print("RACK_REFUSAL ",scene.decoration_layout._message);await shot("failure-rack");await finish();return
	root.size=Vector2i(960,640);await frames();await open_kitchen();await shot("04-small-earned-kitchen")
	expect(page_button("RackProgress")==null and root.get_visible_rect().encloses(scene.harvest_book._paper.get_global_rect()),"Completed goal clears itself and small-window kitchen remains usable")
	await finish()
