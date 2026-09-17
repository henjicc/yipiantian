extends Node3D
## Distant matte cards share a horizontal stage. Its yaw follows the current
## camera pose in the same frame, keeping the painted waterline level on orbit.
const SHADER = preload("res://scenes/environment/backdrop.gdshader")
const ROOT := "res://art/environment/backdrop/layers-v1/"
var material: ShaderMaterial

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("far_mountains", load(ROOT + "far-mountains.png"))
	material.set_shader_parameter("mid_hills", load(ROOT + "mid-hills.png"))
	material.set_shader_parameter("near_bank", load(ROOT + "near-bank.png"))
	# Keep the diorama's elevated view, but never let orbiting roll its horizon.
	basis = Basis(Vector3.UP, deg_to_rad(25.0)) * Basis(Vector3.RIGHT, deg_to_rad(-28.0))
	position = Vector3(0, 0.85, 0)
	process_priority = 1 # After the camera, before the focus band and drawing.
	_card("SkyAndDistantWater", 0, Vector3(0, 0, -460), Vector2(1200, 700))
	for index: int in 3:
		_card("FarMountains%d" % index, 1, Vector3((index-1)*145, 80+index%2*4, -380), Vector2(160, 160.0/3.0))
	for index: int in 5:
		_card("MiddleHills%d" % index, 2, Vector3((index-2)*99, 55+index%2*2, -310), Vector2(110, 110.0/3.0))
	for index: int in 7:
		_card("VillageBank%d" % index, 3, Vector3((index-3)*48.6, 45.5, -240), Vector2(54, 18))
	_card("ValleyMist", 4, Vector3(0, 48, -270), Vector2(500, 24))

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var yaw: float = atan2(camera.global_basis.z.x, camera.global_basis.z.z)
	# Match the authored overview, not temporary focus/free-camera tilts. Otherwise
	# lowering the overview pushes the entire painted mountain band out of frame.
	var pitch: float = camera.overview_view.y if camera is FarmCamera else 28.0
	basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(-pitch))

func _card(label: String, layer: int, at: Vector3, size: Vector2) -> void:
	var card := MeshInstance3D.new()
	card.name = label
	var quad := QuadMesh.new()
	quad.size = size
	card.mesh = quad
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.position = at
	add_child(card)
	card.set_instance_shader_parameter("landscape_layer", layer)
