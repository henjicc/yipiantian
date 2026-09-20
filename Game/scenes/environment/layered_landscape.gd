extends Node3D
## Real headlands meet the same lake as the islands. Remote silhouettes live
## in a directional sky, with no dependency on the camera or overview tuning.
const SKY_SHADER = preload("res://scenes/environment/landscape_sky.gdshader")
const LAND_SHADER = preload("res://scenes/environment/pigment.gdshader")
const HILL_SHADER = preload("res://scenes/environment/painted_hill.gdshader")
const ROOT := "res://art/environment/backdrop/horizon-v3/"
var material: ShaderMaterial
var _hill_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("western_ridge", load(ROOT+"west-shoulder.png"))
	material.set_shader_parameter("eastern_ridge", load(ROOT+"east-twin-peaks.png"))
	material.set_shader_parameter("rolling_ridge", load(ROOT+"low-rolling-hills.png"))
	# Open channels between varied peninsulas, rather than a circular wall.
	_headland("WesternHeadland", -112.0, -48.0, 78.0, 34.0, 1.5, 1.3)
	_headland("NorthernHeadland", -40.0, 20.0, 95.0, 43.0, 1.8, 3.9)
	_headland("EasternHeadland", 32.0, 108.0, 85.0, 37.0, 1.4, 6.1)
	_headland("SouthernHeadland", 138.0, 231.0, 95.0, 44.0, 1.7, 8.3)
	_hill("SinglePeak", "single-peak", -48.0, 142.0, 42.0, Rect2(0.006,0.115,0.988,0.800))
	_hill("TwinHills", "twin-hills", -6.0, 125.0, 65.0, Rect2(0.010,0.326,0.980,0.423))
	_hill("WoodedKnoll", "wooded-knoll", -28.0, 100.0, 38.0, Rect2(0.012,0.268,0.976,0.502))
	# Each new silhouette appears once. Staggered radii leave multiple readable
	# layers at both ends of the player's bounded overview orbit.
	var expanded: Array = [
		[-108.0,170.0,57.0,Rect2(.0085,.1807,.9824,.6572)],
		[-83.0,145.0,52.0,Rect2(.0280,.2373,.9544,.6006)],
		[-65.0,205.0,48.0,Rect2(.0286,.1318,.9453,.7715)],
		[-88.0,108.0,44.0,Rect2(.0137,.3477,.9727,.4258)],
		[-31.0,220.0,62.0,Rect2(.0150,.1172,.9701,.7754)],
		[14.0,185.0,62.0,Rect2(.0072,.1992,.9883,.6426)],
		[35.0,115.0,44.0,Rect2(.0150,.2402,.9740,.5850)],
		[58.0,180.0,54.0,Rect2(.0273,.1201,.9453,.7891)],
		[-4.0,240.0,56.0,Rect2(.0195,.2285,.9609,.6133)],
		[-56.0,100.0,33.0,Rect2(.0111,.2637,.9785,.5342)],
	]
	for index: int in expanded.size():
		var placement: Array = expanded[index]
		_hill("ExpandedHill%02d"%index,"hill-%02d"%(index+1),placement[0],placement[1],placement[2],placement[3],"expanded-v5")
	material.changed.connect(_sync_hill_palette)

func _sync_hill_palette() -> void:
	for hill: ShaderMaterial in _hill_materials:
		hill.set_shader_parameter("atmosphere_tint",material.get_shader_parameter("atmosphere_tint"))
		hill.set_shader_parameter("horizon_color",material.get_shader_parameter("sky_horizon"))

func _hill(label: String, asset: String, heading: float, radius: float, width: float, crop: Rect2, collection: String = "individual-v4") -> void:
	# A fixed cylindrical segment faces the lake, not the moving camera.
	# Curvature and transparent ends avoid a hard rectangular side at orbit limits.
	var texture: Texture2D = load("res://art/environment/backdrop/"+collection+"/"+asset+".png")
	var height: float = width * texture.get_height()*crop.size.y/(texture.get_width()*crop.size.x)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x: int in 40:
		for corner: Vector2 in [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(1,0)]:
			var u: float = (x+corner.x)/40.0
			var angle: float = deg_to_rad(heading)+(u-.5)*width/radius
			surface.set_uv(crop.position+Vector2(u,1.0-corner.y)*crop.size)
			surface.add_vertex(Vector3(sin(angle)*radius,-.5+corner.y*height,-cos(angle)*radius))
	surface.generate_normals()
	var hill := MeshInstance3D.new()
	hill.name = label
	hill.mesh = surface.commit()
	hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var painted := ShaderMaterial.new()
	painted.shader = HILL_SHADER
	painted.set_shader_parameter("pigment",texture)
	hill.material_override = painted
	_hill_materials.append(painted)
	add_child(hill)

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
