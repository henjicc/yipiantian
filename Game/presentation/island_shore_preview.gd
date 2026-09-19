extends Node3D
## A reusable live shore: only changed rocks are instantiated during a stroke.
const Bank=preload("res://layout/bank_geometry.gd")
const Dressing=preload("res://presentation/shore_dressing.gd")
var environment: Node3D
var _surface: MeshInstance3D
var _rocks: Dictionary={}
var _plants: Node3D
var _hidden: Array[Node3D]=[]
var _grass: Node3D
var _fence: Node3D

func configure(courtyard: Node3D) -> void:
	environment=courtyard
	for child: Node in environment.get_children():
		if child is Node3D and (child.name=="MainBank" or child.has_meta("shore_stone") or child.name in ["NewShorePlants","ExpansionGrass"] or child.has_meta("fence_spans")) and child.visible:
			_hidden.append(child);child.hide()
	_surface=MeshInstance3D.new();_surface.name="LiveBank"
	_surface.material_override=environment.get_node("MainBank").get_child(0).get_active_material(0)
	_surface.set_layer_mask_value(2,true);add_child(_surface)
	_grass=preload("res://scenes/environment/ground_cover.gd").new();_grass.name="ExpansionGrass";add_child(_grass)

func update(plan: RefCounted) -> void:
	# Terrain-only preview keeps the existing paths until a structure edit
	# derives new ones. Grass must obey these same routes before and after save.
	plan.paths=environment.plan.paths.duplicate()
	_surface.mesh=Bank.build(plan.rim,plan.ground_height,plan.bank_width,not plan.construction.land.is_empty())
	var wanted: Dictionary={}
	for entry: Dictionary in Dressing.stones(plan):
		var key: String=var_to_str(entry)
		wanted[key]=true
		if _rocks.has(key): continue
		var rock: Node3D=(load("res://art/environment/modules/"+entry.asset+".glb") as PackedScene).instantiate()
		add_child(rock);rock.position=entry.at;rock.rotation.y=deg_to_rad(entry.yaw);rock.scale=entry.size
		environment._apply_pigment(rock,entry.asset);environment._tint_stone(rock,entry.color)
		_rocks[key]=rock
		rock.set_meta("shore_stone",true)
	for key: String in _rocks.keys():
		if not wanted.has(key): _rocks[key].free();_rocks.erase(key)
	if is_instance_valid(_plants): _plants.free()
	_plants=Dressing.plants(plan);add_child(_plants)
	_grass.update_expansion(plan)
	if is_instance_valid(_fence): _fence.free()
	# Keep only the original garden fences, opening spans touched by the brush.
	var spans: Array[Dictionary]=[]
	for span: Dictionary in environment.plan.garden_fences:
		var touched: bool=false
		for patch: Array in plan.construction.land:
			var area:=Rect2(patch[0],patch[1],patch[2],patch[3]).grow(.8)
			if area.has_point(Vector2(span.a.x,span.a.z)) or area.has_point(Vector2(span.b.x,span.b.z)): touched=true;break
		if not touched: spans.append(span)
	_fence=preload("res://layout/fence_geometry.gd").build(spans,plan.fence_style);add_child(_fence)
	environment.preview_shore_plants(plan)

func accept(plan: RefCounted) -> void:
	var bank: Node3D=environment.get_node("MainBank")
	bank.get_child(0).mesh=_surface.mesh;bank.show()
	bank.remove_meta("navigation_footprints")
	for node: Node3D in _hidden:
		if node==bank: continue
		environment._shore_sources.erase(node);environment._contact_sources.erase(node)
		environment.layout_obstacles.erase(String(node.name))
		node.free()
	_hidden.clear()
	for rock: Node3D in _rocks.values():
		rock.reparent(environment);environment._shore_sources.append(rock)
	_rocks.clear()
	_plants.reparent(environment);_grass.reparent(environment);_fence.reparent(environment)
	environment._contact_sources.append(_fence)
	plan.fences.assign(_fence.get_meta("fence_spans"))
	environment.plan=plan
	environment.refresh_terrain.call_deferred()

func restore() -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if is_instance_valid(environment): environment.preview_shore_plants(environment.plan)
