extends RefCounted
## Reuses the courtyard's opaque curved meadow blades; one mesh per grassy cell.
const Cover=preload("res://scenes/environment/ground_cover.gd")
const Soil=preload("res://presentation/tilled_soil.gd")
static func build(center: Vector3, span: Vector2, half_extent: Vector2, seed_value: int, cut: bool = false) -> MeshInstance3D:
	var cover:=Cover.new()
	cover._rng.seed=seed_value
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in 38:
		var p:=Vector2(cover._rng.randf_range(-.46,.46)*span.x,cover._rng.randf_range(-.46,.46)*span.y)
		var height: float=cover._rng.randf_range(.12,.26)
		cover._tuft(surface,Vector3(p.x,Soil.height_at(p+Vector2(center.x,center.z),half_extent,span.y)-.003,p.y),height*(.18 if cut else 1.0),5)
	cover.free()
	var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.name="UnclearedGrass"
	mesh.material_override=ShaderMaterial.new();mesh.material_override.shader=Cover.SHADER
	if cut:
		mesh.name="CutStubble"
	mesh.set_meta("ground","rough" if cut else "weedy")
	mesh.extra_cull_margin=.04
	mesh.position=center
	return mesh
