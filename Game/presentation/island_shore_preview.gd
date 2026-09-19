extends Node3D
## A reusable live shore: only changed rocks are instantiated during a stroke.
const Bank=preload("res://layout/bank_geometry.gd")
const Dressing=preload("res://presentation/shore_dressing.gd")
const Cover=preload("res://scenes/environment/ground_cover.gd")
var environment: Node3D
var _surfaces: Dictionary={}
var _rocks: Dictionary={}
var _original_rocks: Dictionary={}
var _plants: Node3D
var _hidden: Array[Node3D]=[]
var _originals: Array[Node3D]=[]
var _grass: Node3D
var _core: Node3D
var _fence: Node3D
var _held_hens: bool=false
var _last_land: Array=[]
var _plateaus: Array[PackedVector2Array]=[]
var _shown_fences: Array=[]

func configure(courtyard: Node3D) -> void:
	environment=courtyard
	for island: int in 2:
		_last_land.append(environment.plan.land_patches(island).duplicate(true))
		_plateaus.append(environment.plan.plateau(island).duplicate())
	_shown_fences=environment.plan.fences.duplicate(true)
	for child: Node in environment.get_children():
		if child is Node3D and child.name=="NewShorePlants":
			_originals.append(child)
			if child.visible: _hidden.append(child);child.hide()
	_grass=preload("res://scenes/environment/ground_cover.gd").new();_grass.name="ExpansionGrass";add_child(_grass)
	_grass.preview_tiles(environment.get_node("ExpansionGrass"))
	_core=preload("res://scenes/environment/ground_cover.gd").new();add_child(_core)
	_core.preview_tiles(environment.get_node("GroundCover/CoreGrass"))

func update(plan: RefCounted) -> void:
	for stamp: Array in plan.construction.land+plan.construction.east_land:
		if stamp.size()==5 and stamp not in environment.plan.construction.land+environment.plan.construction.east_land:
			environment.get_node("CourtyardAnimals").preview_kind="hen";_held_hens=true;break
	# Terrain-only preview keeps the existing paths until a structure edit
	# derives new ones. Grass must obey these same routes before and after save.
	plan.paths=environment.plan.paths.duplicate()
	for island: int in 2:
		if plan.land_patches(island)==_last_land[island]: continue
		if not _surfaces.has(island):
			var bank: Node3D=environment.get_node("EastBank" if island==1 else "MainBank")
			_originals.append(bank)
			if bank.visible: _hidden.append(bank);bank.hide()
			for child: Node in environment.get_children():
				if child.has_meta("shore_stone") and child.get_meta("shore_island",0)==island:
					_originals.append(child)
					_original_rocks[child.get_meta("shore_key")]=child
					if child.visible: _hidden.append(child);child.hide()
			var surface:=MeshInstance3D.new();surface.name="LiveBank%d"%island
			surface.material_override=bank.get_child(0).get_active_material(0)
			surface.set_layer_mask_value(2,true);add_child(surface);surface.transform=bank.transform
			_surfaces[island]=surface
		_surfaces[island].mesh=Bank.build(plan.island_rim(island),plan.ground_height,plan.bank_width,not plan.land_patches(island).is_empty())
		var wanted: Dictionary={}
		for entry: Dictionary in Dressing.stones(plan,island):
			var key: String=str(island)+var_to_str(entry)
			wanted[key]=true
			if _rocks.has(key): continue
			# Keep prepared geometry, materials and footprint caches for rocks
			# whose placement is unchanged. Originals stay owned by the courtyard
			# until save, so a cancelled stroke can restore them without rebuilding.
			if _original_rocks.has(key):
				var original: Node3D=_original_rocks[key]
				original.visible=original in _hidden
				_rocks[key]=original
				continue
			var rock: Node3D=(load("res://art/environment/modules/"+entry.asset+".glb") as PackedScene).instantiate()
			add_child(rock);rock.position=entry.at;rock.rotation.y=deg_to_rad(entry.yaw);rock.scale=entry.size
			environment._apply_pigment(rock,entry.asset);environment._tint_stone(rock,entry.color)
			_rocks[key]=rock
			rock.set_meta("shore_stone",true);rock.set_meta("shore_island",island)
			rock.set_meta("shore_key",key)
			environment._fit_bridge_stone(rock)
		for key: String in _rocks.keys():
			if _rocks[key].get_meta("shore_island",0)==island and not wanted.has(key):
				if _original_rocks.has(key): _rocks[key].hide()
				else: _rocks[key].free()
				_rocks.erase(key)
	if is_instance_valid(_plants): _plants.free()
	_plants=Dressing.plants(plan);add_child(_plants)
	# Compare actual world-space ground, including the opposite island's pose.
	# Only tiles that gained or lost support can change their deterministic grass.
	var changes: Array[PackedVector2Array]=[]
	for island: int in 2:
		var plateau: PackedVector2Array=plan.plateau(island)
		if plateau!=_plateaus[island]:
			changes.append_array(Geometry2D.clip_polygons(plateau,_plateaus[island]))
			changes.append_array(Geometry2D.clip_polygons(_plateaus[island],plateau))
		_plateaus[island]=plateau.duplicate()
		_last_land[island]=plan.land_patches(island).duplicate(true)
	var changed: Dictionary=Cover.grass_cells(changes)
	if not changed.is_empty():
		_grass.update_tiles(plan,true,changed)
		_core.update_tiles(plan,false,changed)
	_update_fence(plan)
	environment.preview_shore_plants(plan)

func _update_fence(plan: RefCounted) -> void:
	# Keep only the original garden fences, opening spans touched by the brush.
	var spans: Array[Dictionary]=[]
	for span: Dictionary in environment.plan.garden_fences:
		var touched: bool=false
		for patch: Array in plan.construction.land:
			var area:=Rect2(patch[0],patch[1],patch[2],patch[3]).grow(.8)
			if area.has_point(Vector2(span.a.x,span.a.z)) or area.has_point(Vector2(span.b.x,span.b.z)): touched=true;break
		if not touched: spans.append(span)
	if spans==_shown_fences: return
	if is_instance_valid(_fence): _fence.free()
	else:
		for child: Node in environment.get_children():
			if not child.has_meta("fence_spans"): continue
			_originals.append(child)
			if child.visible: _hidden.append(child);child.hide()
	_fence=preload("res://layout/fence_geometry.gd").build(spans,plan.fence_style);add_child(_fence)
	_shown_fences=spans.duplicate(true)

func accept(plan: RefCounted) -> void:
	for island: int in _surfaces:
		var bank: Node3D=environment.get_node("EastBank" if island==1 else "MainBank")
		bank.get_child(0).mesh=_surfaces[island].mesh;bank.show()
		bank.remove_meta("navigation_footprints")
	var retained: Array=_rocks.values()
	for node: Node3D in _originals:
		if node.has_meta("bank_role") or node in retained: continue
		environment._shore_sources.erase(node);environment._contact_sources.erase(node)
		environment.layout_obstacles.erase(String(node.name))
		node.free()
	_hidden.clear()
	_originals.clear()
	_original_rocks.clear()
	for rock: Node3D in _rocks.values():
		if rock.get_parent()!=environment: rock.reparent(environment)
		if rock.visible and rock not in environment._shore_sources: environment._shore_sources.append(rock)
	_rocks.clear()
	_plants.reparent(environment)
	_grass.accept_tiles();_core.accept_tiles()
	if is_instance_valid(_fence):
		_fence.reparent(environment)
		environment._contact_sources.append(_fence)
	plan.fences.assign(_shown_fences)
	environment.plan=plan
	environment.preview_shore_plants(plan,true)
	environment.fit_player_dressing(plan,true)
	if _held_hens: environment.get_node("CourtyardAnimals").preview_kind="";_held_hens=false
	environment.refresh_terrain.call_deferred()

func restore() -> void:
	_grass.restore_tiles();_core.restore_tiles()
	if _held_hens and is_instance_valid(environment): environment.get_node("CourtyardAnimals").preview_kind="";_held_hens=false
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if is_instance_valid(environment): environment.preview_shore_plants(environment.plan)
