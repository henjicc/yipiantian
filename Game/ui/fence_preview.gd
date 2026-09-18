extends TextureRect
## Render the actual fence once per choice, with no permanent secondary render loop.
const Fence = preload("res://layout/fence_geometry.gd")
var _viewport: SubViewport
var _fence: Node3D
var _style: String = ""

func _ready() -> void:
	custom_minimum_size=Vector2(260,105)
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_viewport=SubViewport.new()
	_viewport.name="FenceView"
	_viewport.size=Vector2i(600,210)
	_viewport.own_world_3d=true
	_viewport.transparent_bg=true
	_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d=Viewport.MSAA_2X
	add_child(_viewport)
	texture=_viewport.get_texture()
	var camera:=Camera3D.new()
	_viewport.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.35
	camera.position=Vector3(1.8,1.5,3)
	camera.look_at(Vector3(.65,.40,0))
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-30,0)
	_viewport.add_child(light)
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color("f4ecd9")
	world.environment.ambient_light_energy=.7
	_viewport.add_child(world)

func show_style(style: String) -> void:
	if _style==style: return
	_style=style
	if _fence!=null: _fence.free()
	var spans: Array[Dictionary]=[{"a":Vector3.ZERO,"b":Vector3(1.3,0,0),"height":1.0}]
	_fence=Fence.build(spans,style)
	_viewport.add_child(_fence)
	_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
