extends Node3D
## Distant matte cards are anchored to the authored overview, not the live camera.
## Orbit and tilt must both move their projection, just like the nearby islands.
const SHADER = preload("res://scenes/environment/backdrop.gdshader")
const ROOT := "res://art/environment/backdrop/layers-v2/"
var material: ShaderMaterial
var _sky: MeshInstance3D

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("far_mountains", load(ROOT + "far-west.png"))
	material.set_shader_parameter("mid_hills", load(ROOT + "far-east.png"))
	material.set_shader_parameter("near_bank", load(ROOT + "wooded-bank.png"))
	# Keep the diorama's elevated view, but never let orbiting roll its horizon.
	basis = Basis(Vector3.UP, deg_to_rad(25.0)) * Basis(Vector3.RIGHT, deg_to_rad(-28.0))
	position = Vector3(0, 0.85, 0)
	process_priority = 1 # After the camera, before the focus band and drawing.
	_card("SkyAndDistantWater", 0, Vector3(0, 0, -460), Vector2(1200, 700))
	_sky = get_node("SkyAndDistantWater")
	_sky.top_level = true
	# Each alpha silhouette appears once. Different peaks, widths and depths,
	# rather than a repeated/mirrored mountain and village strip.
	_card("WesternRange", 1, Vector3(-102, 105, -400), Vector2(320, 75))
	_card("EasternRange", 2, Vector3(113, 100, -365), Vector2(310, 80))
	_card("WoodedShore", 3, Vector3(0, 63, -275), Vector2(380, 30))
	_card("ValleyMist", 4, Vector3(0, 48, -270), Vector2(500, 24))

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var yaw: float = deg_to_rad(camera.overview_view.x if camera is FarmCamera else 27.5)
	# Match only explicit overview tuning, never transient orbit or photo poses. Otherwise
	# lowering the overview pushes the entire painted mountain band out of frame.
	var pitch: float = camera.overview_view.y if camera is FarmCamera else 28.0
	basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))
	# Only the featureless sky/water fill tracks yaw, so its finite support never
	# exposes a side or clips at the far plane. Painted mountains remain fixed.
	var sky_yaw: float = atan2(camera.global_basis.z.x, camera.global_basis.z.z)
	var sky_basis := Basis(Vector3.UP, sky_yaw) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))
	_sky.global_transform = Transform3D(sky_basis, global_position + sky_basis * Vector3(0, 0, -460))

func _card(label: String, layer: int, at: Vector3, size: Vector2) -> void:
	var card := MeshInstance3D.new()
	card.name = label
	var quad := QuadMesh.new()
	quad.size = size
	if layer in [1, 2, 3]:
		# A gently warped opaque support grid keeps the native alpha artwork;
		# do not deform UVs over time or repeat mountain motifs in a shader.
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for x: int in 24:
			for y: int in 4:
				for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
					var uv := Vector2((x+corner.x)/24.0,(y+corner.y)/4.0)
					var bend: float = sin(uv.x*TAU+layer)*sin(uv.x*PI)*1.8
					surface.set_uv(uv)
					surface.set_normal(Vector3.FORWARD)
					surface.add_vertex(Vector3((uv.x-.5)*size.x,(.5-uv.y)*size.y+bend,0))
		surface.index()
		card.mesh = surface.commit()
	else:
		card.mesh = quad
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.position = at
	add_child(card)
	card.set_instance_shader_parameter("landscape_layer", layer)
