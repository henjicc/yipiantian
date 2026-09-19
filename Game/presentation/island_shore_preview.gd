extends Node3D
## A reusable live shore: only changed rocks are instantiated during a stroke.
const Bank=preload("res://layout/bank_geometry.gd")
const Dressing=preload("res://presentation/shore_dressing.gd")
var environment: Node3D
var _surface: MeshInstance3D
var _rocks: Dictionary={}
var _plants: Node3D
var _hidden: Array[Node3D]=[]

func configure(courtyard: Node3D) -> void:
	environment=courtyard
	for child: Node in environment.get_children():
		if child is Node3D and (child.name=="MainBank" or child.has_meta("shore_stone") or child.name=="NewShorePlants") and child.visible:
			_hidden.append(child);child.hide()
	_surface=MeshInstance3D.new();_surface.name="LiveBank"
	_surface.material_override=environment.get_node("MainBank").get_child(0).get_active_material(0)
	_surface.set_layer_mask_value(2,true);add_child(_surface)

func update(plan: RefCounted) -> void:
	_surface.mesh=Bank.build(plan.rim,plan.ground_height,plan.bank_width,true)
	var wanted: Dictionary={}
	for entry: Dictionary in Dressing.stones(plan):
		var key: String=var_to_str(entry)
		wanted[key]=true
		if _rocks.has(key): continue
		var rock: Node3D=(load("res://art/environment/modules/"+entry.asset+".glb") as PackedScene).instantiate()
		add_child(rock);rock.position=entry.at;rock.rotation.y=deg_to_rad(entry.yaw);rock.scale=entry.size
		environment._apply_pigment(rock,entry.asset);environment._tint_stone(rock,entry.color)
		_rocks[key]=rock
	for key: String in _rocks.keys():
		if not wanted.has(key): _rocks[key].free();_rocks.erase(key)
	if is_instance_valid(_plants): _plants.free()
	_plants=Dressing.plants(plan);add_child(_plants)
	environment.preview_shore_plants(plan)

func restore() -> void:
	for node: Node3D in _hidden:
		if is_instance_valid(node): node.show()
	_hidden.clear()
	if is_instance_valid(environment): environment.preview_shore_plants(environment.plan)
