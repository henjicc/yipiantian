extends RefCounted
## Metric assets produced by CourtyardLife/prepare.py, never cloud URLs at runtime.
const SURFACE = preload("res://scenes/environment/courtyard_surface.gdshader")
static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}

static func instantiate_asset(id: String, tier: String = "high") -> Node3D:
	var path := "res://art/environment/courtyard_life/%s_%s.glb" % [id,tier]
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var root: Node3D = _scenes[path].instantiate()
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		mesh.lod_bias = 1.0
		for surface: int in mesh.mesh.get_surface_count():
			var original: StandardMaterial3D = mesh.get_active_material(surface)
			var key: int = original.get_instance_id()
			if not _materials.has(key):
				var material := ShaderMaterial.new()
				material.shader = SURFACE
				material.set_shader_parameter("painted_color",original.albedo_texture)
				material.set_shader_parameter("tint",original.albedo_color)
				_materials[key] = material
			mesh.set_surface_override_material(surface,_materials[key])
	return root

static func place(parent: Node3D, id: String, at: Vector3, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	var root: Node3D = instantiate_asset(id)
	root.name = id.to_pascal_case()
	root.position = at
	root.rotation.y = deg_to_rad(yaw)
	root.scale = Vector3.ONE * size
	parent.add_child(root)
	return root
