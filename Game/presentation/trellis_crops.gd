extends Node3D
## Crop display and root picking; time, occupancy and yield belong to FarmState.
const Slots=preload("res://layout/trellis_slots.gd")
const Construction=preload("res://layout/island_construction.gd")
const Vines=preload("res://presentation/trellis_vine.gd")
const INDEX: int=1000000
var body:=StaticBody3D.new()
var crops:=Node3D.new()
var _roots: Dictionary={}
var _keys: Dictionary={}
var _patches: Dictionary={}
var _visual_plan: RefCounted
var _layout_key: Array=[]
var _selected: String=""
var _focused: bool=false
var preview_plan: RefCounted

func _ready() -> void:
	body.name="TrellisPlanting";body.collision_layer=1;body.collision_mask=0
	body.set_meta("field_index",INDEX);body.set_meta("field_id",Slots.FIELD_ID)
	add_child(body);crops.name="Crops";body.add_child(crops)

func show_state(plan: RefCounted, field: Dictionary) -> bool:
	_visual_plan=preview_plan if preview_plan!=null else plan
	var dimensions: Vector3=Construction.trellis_size(_visual_plan)
	var key: Array=Construction.trellis_parameters(_visual_plan)
	var changed: bool=key!=_layout_key
	body.transform=Construction.trellis_pose(_visual_plan)
	body.set_meta("field_size",Vector2(dimensions.y+.8,dimensions.x+.4))
	var positions: Dictionary=Slots.slots(_visual_plan)
	# Invalid shrinking previews still show the occupied roots; committing is blocked.
	var original: Dictionary=Slots.slots(plan)
	for id: String in field.cells:
		if not positions.has(id) and not field.cells[id].crop_id.is_empty(): positions[id]=original[id]
	if changed:
		for patch: Node3D in _patches.values(): patch.free()
		_patches.clear()
		for child: Node in body.get_children():
			if child is CollisionShape3D: child.free()
		for id: String in positions:
			var patch:=MeshInstance3D.new();var surface:=SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i: int in 24:
				for offset: Vector2 in [Vector2.ZERO,Vector2.from_angle(TAU*(i+1)/24.0)*.15,Vector2.from_angle(TAU*i/24.0)*.15]:
					var point: Vector3=positions[id]+Vector3(offset.x*.6,0,offset.y)
					point.y=Slots.soil_height(point,dimensions)+.002
					surface.add_vertex(point)
			surface.generate_normals();patch.mesh=surface.commit()
			var material:=StandardMaterial3D.new();material.albedo_color=Color("68523a");material.roughness=1
			patch.material_override=material;body.add_child(patch);_patches[id]=patch
			var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.38,.08,.48)
			collision.shape=shape;collision.position=positions[id];body.add_child(collision)
		_layout_key=key
	for id: String in _roots.keys():
		if not positions.has(id) or field.cells.get(id,{}).get("crop_id","").is_empty():
			_roots[id].free();_roots.erase(id);_keys.erase(id)
	for id: String in positions:
		var cell: Dictionary=field.cells.get(id,{"stage":"empty","crop_id":""})
		if cell.crop_id.is_empty(): continue
		var visual_key: Array=[cell.stage,dimensions.y,dimensions.z,id.begins_with("left")]
		if _keys.get(id)!=visual_key:
			if _roots.has(id): _roots[id].free()
			var plant: Node3D=Vines.build(cell.stage,dimensions,id.begins_with("left"))
			for node: Node in plant.get_children():
				if node is StaticBody3D:
					node.set_meta("field_index",INDEX);node.set_meta("trellis_cell",id)
			plant.name=id;plant.set_meta("crop_id",cell.crop_id);plant.set_meta("stage_key",cell.stage)
			crops.add_child(plant);_roots[id]=plant;_keys[id]=visual_key;changed=true
		_roots[id].position=positions[id]
	for id: String in _patches:
		var material: StandardMaterial3D=_patches[id].material_override
		material.albedo_color=Color("493e2e") if field.cells.get(id,{}).get("watered",false) else Color("68523a")
	select(_selected,_focused)
	return changed

func select(id: String, focused: bool) -> void:
	_selected=id;_focused=focused
	for key: String in _patches:
		var material: StandardMaterial3D=_patches[key].material_override
		material.emission_enabled=focused or key==id
		material.emission=Color("9a844d")
		material.emission_energy_multiplier=.55 if key==id else .28

func cell_at(world: Vector3) -> String:
	var local: Vector3=body.to_local(world)
	var positions: Dictionary=Slots.slots(_visual_plan)
	for id: String in positions:
		var p: Vector3=positions[id]
		if absf(local.x-p.x)<=.2 and absf(local.z-p.z)<=.25: return id
	return ""
