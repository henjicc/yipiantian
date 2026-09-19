extends Node3D
## Four species in shared mesh batches. Saved poses are never rerolled on redraw.
const Plants=preload("res://layout/plantings.gd")
const Wind=preload("res://presentation/plant_wind.gd")
const Marsh=preload("res://scenes/environment/marsh_plants.gd")
static var _sources: Dictionary={}
var _batches: Dictionary={}
var _poses: Dictionary={}
var low_detail: bool=false

static func source(kind: String, tier: String) -> Dictionary:
	var key: String=kind+"_"+tier
	if _sources.has(key): return _sources[key]
	var path: String="res://art/environment/lotus/lotus_%s.glb"%tier if kind=="lotus" else Marsh.ROOT+key+".glb"
	var root: Node3D=load(path).instantiate()
	var geometry: MeshInstance3D=root.find_children("*","MeshInstance3D",true,false)[0]
	var material: Material
	if kind=="lotus":
		var wind:=Wind.new();wind.apply(root,"lotus");material=geometry.get_active_material(0)
	else:
		material=ShaderMaterial.new();material.shader=Marsh.SURFACE
		material.set_shader_parameter("painted_color",geometry.get_active_material(0).albedo_texture)
		material.set_shader_parameter("floating",kind=="trapa")
	_sources[key]={"mesh":geometry.mesh,"material":material}
	root.free();return _sources[key]

func update(entries: Array) -> void:
	for kind: String in Plants.KINDS:
		var poses: Array[Transform3D]=[]
		for entry: Dictionary in entries:
			if entry.kind==kind: poses.append(Plants.pose(entry))
		if _poses.get(kind,[])==poses: continue
		_poses[kind]=poses
		for tier: String in ["high","low"]:
			var key: String=kind+"_"+tier
			if not _batches.has(key):
				if poses.is_empty(): continue
				var data: Dictionary=source(kind,tier)
				var batch:=MultiMeshInstance3D.new();batch.name=key
				batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=data.mesh
				batch.material_override=data.material;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;batch.extra_cull_margin=.15
				add_child(batch);_batches[key]=batch
				if kind=="lotus":
					var bounds: AABB=data.mesh.get_aabb();var center: Vector3=bounds.get_center()
					batch.set_instance_shader_parameter("wind_bounds",Vector4(bounds.position.y,bounds.size.y,center.x,center.z))
					batch.set_instance_shader_parameter("wind_motion",Wind.PROFILES.lotus)
			var batch: MultiMeshInstance3D=_batches[key]
			batch.multimesh.instance_count=poses.size()
			for i: int in poses.size(): batch.multimesh.set_instance_transform(i,poses[i])
	set_low_detail(low_detail)

func set_low_detail(value: bool) -> void:
	low_detail=value
	for key: String in _batches: _batches[key].visible=key.ends_with("_low")==value
