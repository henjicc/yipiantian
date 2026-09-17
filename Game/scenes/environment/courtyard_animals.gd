extends Node3D
## Ambient life only: bounded paths avoid beds, bridge, boat and lily coves.
const Assets = preload("res://scenes/environment/courtyard_assets.gd")
var _swimmers: Array[Dictionary] = []
var _hens: Array[Node3D] = []
var _time: float = 0.0

func _ready() -> void:
	for i: int in 3:
		var bird: Node3D = Assets.place(self,"duck",Vector3.ZERO,0,.88 if i == 2 else 1.0)
		bird.name = "LakeDuck%d" % (i+1)
		_play(bird,"Paddle",float(i)*1.15)
		_swimmers.append({"node":bird,"center":Vector2(-9.15,.90),"radius":Vector2(.95,.58),"phase":i*TAU/3.0,"speed":.075,"draft":.20,"heading_offset":0.0,"wake":_wake(.32)})
	for i: int in 2:
		var bird: Node3D = Assets.place(self,"goose",Vector3.ZERO)
		bird.name = "LakeGoose%d" % (i+1)
		_play(bird,"Paddle",float(i)*1.8)
		_swimmers.append({"node":bird,"center":Vector2(2.9,8.85),"radius":Vector2(1.0,.40),"phase":i*PI,"speed":.065,"draft":.29,"heading_offset":PI,"wake":_wake(.43)})
	for i: int in 2:
		var hen: Node3D = Assets.place(self,"hen",Vector3(-.70+i*.75,.14,4.58),-45+i*130,.88+i*.12)
		hen.name = "YardHen%d" % (i+1)
		_play(hen,"Forage",i*1.9)
		_hens.append(hen)
	_update_swimmers()

func _play(root: Node3D, keyword: String, phase: float) -> void:
	for player: AnimationPlayer in root.find_children("*","AnimationPlayer",true,false):
		for id: StringName in player.get_animation_list():
			if String(id).contains(keyword):
				player.get_animation(id).loop_mode = Animation.LOOP_LINEAR
				player.play(id)
				player.seek(phase,true)

func _wake(radius: float) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in 2:
		var r: float = radius + ring*.15
		for i: int in 30:
			var a: float = lerpf(-1.35,1.35,i/30.0)
			var b: float = lerpf(-1.35,1.35,(i+1)/30.0)
			for p: Vector2 in [Vector2(a,r),Vector2(b,r+.007),Vector2(b,r),Vector2(a,r),Vector2(a,r+.007),Vector2(b,r+.007)]:
				surface.set_uv(Vector2(float(ring)/2.0,(p.x+1.35)/2.7))
				surface.add_vertex(Vector3(sin(p.x)*p.y,0,-cos(p.x)*p.y*.6))
	surface.generate_normals()
	var wake := MeshInstance3D.new()
	wake.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://scenes/environment/bird_wake.gdshader")
	wake.material_override = material
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wake)
	return wake

func _process(delta: float) -> void:
	_time += delta
	_update_swimmers()

func _update_swimmers() -> void:
	for entry: Dictionary in _swimmers:
		var phase: float = _time*entry.speed+entry.phase
		var center: Vector2 = entry.center
		var radius: Vector2 = entry.radius
		var bird: Node3D = entry.node
		bird.position = Vector3(center.x+cos(phase)*radius.x,-.25-entry.draft+sin(_time*1.3+entry.phase)*.009,center.y+sin(phase)*radius.y)
		# Imported duck faces +Z, goose -Z (verified from head vertices).
		var heading: float = atan2(-sin(phase)*radius.x,cos(phase)*radius.y)
		bird.rotation.y = heading + entry.heading_offset
		bird.rotation.z = sin(_time*1.1+entry.phase)*.018
		var wake: MeshInstance3D = entry.wake
		wake.position = Vector3(bird.position.x,-.235,bird.position.z)
		wake.rotation.y = heading
