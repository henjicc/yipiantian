extends RefCounted
## Bounded vertex motion for the project's opaque, two-sided plant materials.
## Runtime surface overrides retain imported textures and the original Mesh/LOD arrays.

const WIND_SHADER = preload("res://presentation/plant_wind.gdshader")
const PROFILES := {
	"tree": Vector4(0.042, 0.42, 1.0, 0.008),
	"osmanthus": Vector4(0.14, 0.20, 0.0, 0.025),
	"bamboo": Vector4(0.026, 0.16, 0.0, 0.007),
	"flowers": Vector4(0.012, 0.18, 0.0, 0.003),
	"lotus": Vector4(0.035, 0.15, 0.0, 0.012),
	"grass": Vector4(0.018, 0.08, 0.0, 0.003),
	"greens": Vector4(0.005, 0.20, 0.0, 0.0015),
	"autumn_crop": Vector4(0.005, 0.20, 0.0, 0.0015),
	"radish": Vector4(0.005, 0.42, 0.0, 0.0015),
	"trellis": Vector4(0.010, 0.08, 0.0, 0.003),
	"flowerpot": Vector4(0.010, 0.42, 0.0, 0.003),
}
# Meshes with authored wind weights (COLOR_0: r bend, g flutter, b phase) and their
# crown bend amplitude in metres. Kinds absent here keep the bounds-based mask even
# when an unrelated vertex colour layer exists.
const AUTHORED_BEND := {
	"osmanthus": 0.07,
	"greens": 0.006,
}
var _materials: Dictionary = {}


func apply(root: Node3D, kind: String) -> void:
	assert(PROFILES.has(kind), "Unknown plant wind profile")
	_apply_node(root, kind)


func _apply_node(node: Node, kind: String) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh: MeshInstance3D = node
		var bounds: AABB = mesh.mesh.get_aabb()
		var centre: Vector3 = bounds.get_center()
		var motion: Vector4 = PROFILES[kind]
		# Sprouts receive the same relative restraint as the larger mature plants.
		if kind in ["greens", "radish", "autumn_crop"]:
			motion.x = minf(motion.x, bounds.size.y * 0.025)
			motion.w = minf(motion.w, bounds.size.y * 0.008)
		for surface: int in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(surface)
			var painted: ShaderMaterial = _convert(source)
			if painted != null:
				mesh.set_surface_override_material(surface, painted)
		# Programmatic grass uses material_override, which wins over surface overrides.
		if mesh.material_override != null:
			mesh.material_override = _convert(mesh.material_override)
		mesh.set_instance_shader_parameter("wind_bounds", Vector4(bounds.position.y, bounds.size.y, centre.x, centre.z))
		mesh.set_instance_shader_parameter("wind_motion", motion)
		var authored := AUTHORED_BEND.has(kind) and _has_vertex_colors(mesh.mesh)
		mesh.set_instance_shader_parameter("wind_authored", 1.0 if authored else 0.0)
		mesh.set_instance_shader_parameter("wind_authored_bend", AUTHORED_BEND.get(kind, 0.07))
		mesh.set_instance_shader_parameter("leaf_paint_strength", 0.0 if kind == "autumn_crop" else 1.0)
		mesh.set_instance_shader_parameter("wind_leaf_texture_mask", 1.0 if kind == "trellis" else 0.0)
		mesh.extra_cull_margin = maxf(mesh.extra_cull_margin, 0.22 if kind == "osmanthus" else motion.x + motion.w)
		mesh.set_meta("plant_wind_kind", kind)
	for child: Node in node.get_children():
		_apply_node(child, kind)


func _has_vertex_colors(mesh: Mesh) -> bool:
	for surface: int in mesh.get_surface_count():
		if mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR] != null:
			return true
	return false


func _convert(source: Material) -> ShaderMaterial:
	if source is ShaderMaterial and source.shader == WIND_SHADER:
		return source
	if source == null:
		return null
	var key: int = source.get_instance_id()
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = WIND_SHADER
	if source is StandardMaterial3D:
		# Audited GLBs have opaque albedo texture + scalar PBR, without normal maps.
		# Fail visibly for a newly introduced material feature, rather than stripping it.
		assert(source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not source.normal_enabled)
		material.set_shader_parameter("base_color", source.albedo_color)
		material.set_shader_parameter("color_texture", source.albedo_texture)
		material.set_shader_parameter("textured", source.albedo_texture != null)
		material.set_shader_parameter("base_roughness", source.roughness)
		material.set_shader_parameter("base_specular", source.metallic_specular)
		material.set_shader_parameter("base_metallic", source.metallic)
		material.set_shader_parameter("uv_scale", source.uv1_scale)
		material.set_shader_parameter("uv_offset", source.uv1_offset)
	elif source is ShaderMaterial and source.shader.resource_path == "res://scenes/environment/courtyard_surface.gdshader":
		material.set_shader_parameter("base_color",source.get_shader_parameter("tint"))
		material.set_shader_parameter("color_texture",source.get_shader_parameter("painted_color"))
		material.set_shader_parameter("textured",true)
		material.set_shader_parameter("base_roughness",.95)
		material.set_shader_parameter("base_specular",.08)
	elif source is ShaderMaterial and source.shader.resource_path == "res://scenes/environment/pigment.gdshader":
		material.set_shader_parameter("base_color", source.get_shader_parameter("base_color"))
		material.set_shader_parameter("wash_scale", source.get_shader_parameter("wash_scale"))
		material.set_shader_parameter("pigment", true)
		material.set_shader_parameter("base_roughness", 0.98)
	else:
		push_error("Unsupported plant material: " + source.resource_path)
		return null
	_materials[key] = material
	return material
