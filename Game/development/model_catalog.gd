extends RefCounted
## Review provenance follows ArtSource records, never inferred from mesh appearance.
const NAMES := {"greens":"青菜","radish":"白萝卜","tatsoi":"塌菜","mustard":"芥菜","garlic":"蒜苗","lettuce":"生菜","spinach":"菠菜","chrysanthemum":"茼蒿／菊花","carrot":"胡萝卜","celery":"芹菜","coriander":"香菜","scallion":"小葱","tree":"庭院树","osmanthus":"桂花","bamboo":"竹子","flowers":"野花","lotus":"荷花","house":"民居","boat":"木船","trellis":"藤架","jar":"陶罐","lantern":"灯笼","flowerpot":"花盆","duck":"鸭","goose":"鹅","hen":"鸡","kitchen":"厨房","pepper":"辣椒","pomelo":"柚子","radish_bundle":"萝卜束","slices":"菜干","seedling":"秧苗","willow":"柳树","cattail":"香蒲","reed":"芦苇","trapa":"菱叶","canal_courts":"水巷院落","bamboo_inlet":"竹湾","mulberry_court":"桑树小院","rice_hamlet":"稻田村落","willow_meadow":"柳岸","cottage":"农家小院","stir_fry":"清炒时蔬","root_soup":"菜根汤","pickled_greens":"腌菜罐","climbing_trellis":"攀爬竹架","bamboo_fence":"竹篱","east_bank_v2":"东岸坡","entrance_canopy":"入口棚","field_frame":"田框","island_bank":"旧岛岸","island_bank_v2":"岛岸","side_wing":"厢房","stone_bridge":"石桥","veranda":"廊台"}

static func scan(path: String = "res://") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for file: String in ResourceLoader.list_directory(path):
		if file.ends_with("/") and not file.begins_with("."):
			result.append_array(scan(path.path_join(file.trim_suffix("/"))))
		elif file.get_extension() in ["glb","gltf","obj","fbx"]:
			result.append(describe(path.path_join(file)))
	return result

static func describe(path: String) -> Dictionary:
	var key := path.get_file().get_basename()
	var suffix := ""
	for ending: String in ["_low","_high","_mature","_young","_sprout"]:
		if key.ends_with(ending):
			key = key.trim_suffix(ending)
			suffix = {"_low":" · 低档","_high":" · 高档","_mature":" · 成熟","_young":" · 幼株","_sprout":" · 幼芽"}[ending] + suffix
	var name: String = NAMES.get(key,key)
	if key.begins_with("stone_") and key.trim_prefix("stone_").is_valid_int(): name = "岸石 " + key.trim_prefix("stone_")
	var category := "环境"
	if "/crops/" in path: category = "作物"
	elif "/decorations/" in path: category = "摆件"
	elif "/modules/" in path: category = "建筑模块"
	elif "/courtyard_life/" in path: category = "院落生活"
	elif "/archipelago/" in path or "/islets/" in path: category = "远景与水生"
	elif not path.begins_with("res://art/"): category = "小样"
	var source := "来源／版本未记录"
	var evidence := ""
	if path.begins_with("res://art/"):
		source = "Tripo · H3.1 / v3.1-20260211"
		evidence = "ArtSource/Environment/README.md"
		if "/crops/" in path:
			evidence = "ArtSource/Crops/Autumn2026/README.md"
			if key in ["greens","radish"]:
				evidence = "ArtSource/Crops/Greens/README.md" if key == "greens" else "ArtSource/Crops/Radish/README.md"
			elif "_sprout" in path: source = "Blender · 程序建模（幼芽）"
			# Adopted P2 stage exports match P2Stages20260919 byte-for-byte.
			# Garlic sprout/young were not replaced; retain their original provenance.
			var p2_stage := key in ["greens","radish","tatsoi","mustard","lettuce","spinach","chrysanthemum","carrot","celery","coriander","scallion"] or (key == "garlic" and "_mature" in path)
			if p2_stage:
				source = "Tripo · P2.0 / P2-20260801"
				evidence = "ArtSource/Crops/P2Stages20260919/README.md"
				if key == "greens" and "_mature" in path:
					evidence = "ArtSource/Crops/Greens/README.md"
		elif "/lotus/" in path:
			source = "Tripo · P2.0 / P2-20260801"
			evidence = "ArtSource/Environment/Lotus/README.md"
		elif "/modules/" in path:
			source = "Blender · 程序建模"
			evidence = "ArtSource/Environment/Modules/README.md"
			if key.begins_with("stone_") and key.trim_prefix("stone_").is_valid_int():
				source = "Tripo · H3.1 / v3.1-20260211"
				evidence = "ArtSource/Environment/Rocks/README.md"
			elif key.ends_with("_v2"): evidence = "ArtSource/Environment/Banks/README.md"
		else:
			for group: String in ["courtyard_life","archipelago","islets","kitchen","osmanthus","house"]:
				if ("/"+group+"/") in path:
					evidence = "ArtSource/Environment/" + {"courtyard_life":"CourtyardLife","archipelago":"Archipelago","islets":"Islets","kitchen":"Kitchen","osmanthus":"Trees","house":"House"}[group] + "/README.md"
	if path in ["res://art/environment/courtyard_life/lantern_high.glb", "res://art/environment/courtyard_life/lantern_low.glb", "res://art/decorations/lantern/lantern_high.glb", "res://art/decorations/lantern/lantern_low.glb"]:
		source = "Tripo · P2.0 / P2-20260801"
		evidence = "ArtSource/Decorations/Lantern/P2_20260923_r01/asset-audit.json"
	if "/greens_pbr/" in path:
		name = "青菜 · PBR候选"
		source = "Tripo · P2.0 / P2-20260801"
		evidence = "ArtSource/Crops/Greens/README.md · v3.5重贴图"
	return {"path":path,"name":name+suffix,"category":category,"source":source,"evidence":evidence}
