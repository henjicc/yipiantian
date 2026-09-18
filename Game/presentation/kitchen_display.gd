extends Node3D
## Existing supports stay put; only their food contents reflect durable kitchen state.
const Kitchen=preload("res://farm/kitchen.gd")
const Assets=preload("res://scenes/environment/courtyard_assets.gd")
const SURFACE=preload("res://scenes/environment/courtyard_surface.gdshader")
var _anchors: Dictionary={}
var _contents: Dictionary={}
var _ids: Dictionary={}
var _originals: Dictionary={}
var _environment: Node3D

func configure(environment: Node3D) -> void:
	_environment=environment
	var living: Node3D=environment.get_node("LivingDetails")
	var rack: Node3D=living.get_node("SidePorchDryingRack")
	var table: Node3D=living.get_node("PorchHarvestTable")
	var jars: Node3D=living.get_node("YardJarCluster")
	for entry: Array in [["stove",rack,Vector3(.25,1.102,-.04)],
		["rack",rack,Vector3(-.25,1.105,-.04)],
		["jar",jars,Vector3.ZERO],["table",table,Vector3(.03,.705,0)]]:
		var anchor:=Node3D.new()
		anchor.name=entry[0]
		add_child(anchor)
		anchor.global_transform=entry[1].global_transform*Transform3D(Basis.IDENTITY,entry[2])
		_anchors[entry[0]]=anchor
	_originals.table=table.get_node("Slices")
	_originals.jar=jars.get_node("PickleBase")
	# Each tray is named once when built; only the top-left food is replaceable.
	_originals.rack=rack.get_node("DryingContents")

func refresh(state: Dictionary) -> void:
	for station: String in Kitchen.STATIONS:
		var job: Dictionary=state.jobs[station]
		_set_food(station,"" if job.is_empty() else Kitchen.RECIPES[job.recipe].asset)
	_set_food("table","" if state.display.is_empty() else Kitchen.RECIPES[state.display].asset)
	for station: String in _originals: _originals[station].visible=_ids.get(station,"").is_empty()

func _set_food(station: String, id: String) -> void:
	if _ids.get(station,"")==id: return
	_ids[station]=id
	if _contents.has(station):
		_contents[station].queue_free()
		_contents.erase(station)
	if id.is_empty(): return
	var model: Node3D
	if id=="slices":
		model=Assets.instantiate_asset(id)
		model.scale=Vector3.ONE*.78
	else:
		model=load("res://art/environment/kitchen/%s.glb"%id).instantiate()
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			for surface: int in mesh.mesh.get_surface_count():
				var source: StandardMaterial3D=mesh.get_active_material(surface)
				var material:=ShaderMaterial.new()
				material.shader=SURFACE
				material.set_shader_parameter("painted_color",source.albedo_texture)
				material.set_shader_parameter("tint",source.albedo_color)
				mesh.set_surface_override_material(surface,material)
	_contents[station]=model
	_anchors[station].add_child(model)
	# A short settling motion marks a real, already-saved change. No rewards here.
	var rest: Vector3=model.scale
	model.scale=rest*.94
	model.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(model,"scale",rest,.35)

func viewpoint(station: String) -> Dictionary:
	var anchor: Node3D=_anchors[station]
	return {"subject":anchor,"point":anchor.global_position+Vector3.UP*.18,
		"view":Vector3(22,34,7.5 if station in ["stove","rack"] else 5.5)}
