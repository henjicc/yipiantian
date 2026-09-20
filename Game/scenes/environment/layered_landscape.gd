extends Node3D
## Real headlands meet the same lake as the islands. Remote silhouettes live
## in a directional sky, with no dependency on the camera or overview tuning.
const SKY_SHADER = preload("res://scenes/environment/landscape_sky.gdshader")
const LAND_SHADER = preload("res://scenes/environment/pigment.gdshader")
const ROOT := "res://art/environment/backdrop/horizon-v3/"
var material: ShaderMaterial

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("western_ridge", load(ROOT+"west-shoulder.png"))
	material.set_shader_parameter("eastern_ridge", load(ROOT+"east-twin-peaks.png"))
	material.set_shader_parameter("rolling_ridge", load(ROOT+"low-rolling-hills.png"))
	# Open channels between varied peninsulas, rather than a circular wall.
	_headland("WesternHeadland", -112.0, -48.0, 78.0, 34.0, 10.0, 1.3)
	_headland("NorthernHeadland", -40.0, 20.0, 95.0, 43.0, 15.0, 3.9)
	_headland("EasternHeadland", 32.0, 108.0, 85.0, 37.0, 9.0, 6.1)
	_headland("SouthernHeadland", 138.0, 231.0, 95.0, 44.0, 12.0, 8.3)

func _headland(label: String, start: float, end: float, radius: float, depth: float, height: float, seed: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: int in 80:
		for z: int in 18:
			for corner: Vector2 in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
				var u: float = (x+corner.x)/80.0
				var v: float = (z+corner.y)/18.0
				var angle: float = deg_to_rad(lerpf(start,end,u))
				var coast: float = radius + sin(u*13.0+seed)*6.0 + sin(u*31.0+seed)*2.0
				var distance: float = coast+v*depth
				var tip: float = smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.86,1.0,u))
				var ridge: float = 0.55+0.26*sin(u*12.0+seed)+0.16*sin(u*26.0+seed)
				var slope: float = pow(sin(PI*v),1.25)
				var y: float = -0.55 + height*tip*slope*ridge
				y += sin(u*167.0+seed)*sin(v*31.0+seed)*0.22*tip*slope
				surface.set_uv(Vector2(u,v))
				surface.add_vertex(Vector3(sin(angle)*distance,y,-cos(angle)*distance))
	surface.generate_normals()
	surface.index()
	var land := MeshInstance3D.new()
	land.name = label
	land.mesh = surface.commit()
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pigment := ShaderMaterial.new()
	pigment.shader = LAND_SHADER
	pigment.set_shader_parameter("base_color",Color("6b7e70"))
	pigment.set_shader_parameter("wash_scale",0.28)
	pigment.set_shader_parameter("stone_treatment",0.18)
	land.material_override = pigment
	add_child(land)
