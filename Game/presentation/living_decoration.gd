extends RefCounted
const Living=preload("res://scenes/environment/living_details.gd")
## Reuses the courtyard's rounded bamboo, wicker and ceramic construction.
static func build(living: Living, id: String) -> Node3D:
	var prop:=Node3D.new()
	prop.name=id.to_pascal_case()
	var wood: ShaderMaterial=living._wood
	var bamboo: ShaderMaterial=living._bamboo
	var height: float=.39 if id=="bench" else .58
	var half_x: float=.43 if id=="bench" else .30
	var half_z: float=.17 if id=="bench" else .24
	for x: float in [-half_x*.8,half_x*.8]:
		for z: float in [-half_z*.8,half_z*.8]:
			living._beam(prop,Vector3(x*1.10,.025,z*1.1),Vector3(x,height,z),.026,wood)
		living._beam(prop,Vector3(x,.17,-half_z*.8),Vector3(x,.17,half_z*.8),.018,bamboo)
	for i: int in 5:
		var z: float=lerpf(-half_z,half_z,i/4.0)
		living._beam(prop,Vector3(-half_x,height,z),Vector3(half_x,height,z),.034,bamboo)
	living._beam(prop,Vector3(-half_x*.8,.18,0),Vector3(half_x*.8,.18,0),.019,wood)
	if id=="drying_rack":
		living._tray(prop,Vector3(0,height+.042,0),.265,false)
		var contents:=Node3D.new()
		contents.name="Harvest"
		prop.add_child(contents)
		living.Assets.place(contents,"slices",Vector3(0,height+.076,0),25,1)
		contents.hide()
	elif id=="tea_table":
		var tea:=Node3D.new()
		tea.name="Tea"
		prop.add_child(tea)
		var ceramic: ShaderMaterial=living._paint(Color("a7b1a0"),6)
		var dark: ShaderMaterial=living._paint(Color("635536"),4)
		for at: Vector3 in [Vector3(-.13,height+.037,.095),Vector3(.12,height+.037,.08)]:
			living._lathe(tea,at,[Vector2(.008,0),Vector2(.035,0),Vector2(.063,.075),Vector2(.06,.082),Vector2(.052,.079),Vector2(.025,.015),Vector2(.008,.015)],ceramic,40)
			living._lathe(tea,at+Vector3(0,.058,0),[Vector2(.001,0),Vector2(.050,0)],dark,40)
		var pot:=Vector3(0,height+.037,-.10)
		living._lathe(tea,pot,[Vector2(.006,0),Vector2(.055,0),Vector2(.067,.014),Vector2(.077,.032),Vector2(.082,.055),Vector2(.083,.075),Vector2(.080,.096),Vector2(.071,.117),Vector2(.055,.137),Vector2(.049,.145),Vector2(.009,.145)],ceramic,48)
		living._lathe(tea,pot+Vector3(0,.148,0),[Vector2(.008,0),Vector2(.060,0),Vector2(.035,.018),Vector2(.012,.025),Vector2(.009,.048)],ceramic,40)
		for i: int in 12:
			var a: float=i*PI/12
			var b: float=(i+1)*PI/12
			living._beam(tea,pot+Vector3(-.070-sin(a)*.048,.06+cos(a)*.045,0),pot+Vector3(-.070-sin(b)*.048,.06+cos(b)*.045,0),.010,ceramic)
		living._beam(tea,pot+Vector3(.060,.06,0),pot+Vector3(.135,.125,0),.018,ceramic)
		living._merge_static_group(tea)
		tea.hide()
	living._merge_static_group(prop)
	return prop
