extends SceneTree
const Courtyard = preload("res://scenes/environment/courtyard.gd")

func _initialize() -> void:
	var yard := Courtyard.new()
	var a: Node3D = yard._make_styled_path_stone(Vector3.ZERO, {"shape":1,"yaw":0.0,"tint":Color("93907e")*.90})
	var b: Node3D = yard._make_styled_path_stone(Vector3.ONE, {"shape":1,"yaw":0.0,"tint":Color("93907e")*1.08})
	var first: MeshInstance3D = a.find_children("*","MeshInstance3D",true,false)[0]
	var second: MeshInstance3D = b.find_children("*","MeshInstance3D",true,false)[0]
	assert(first.get_active_material(0) == second.get_active_material(0), "Repeated stones share their draw material")
	assert(first.get_instance_shader_parameter("stone_color") == Color("93907e")*.90)
	assert(second.get_instance_shader_parameter("stone_color") == Color("93907e")*1.08, "A new stone keeps its own tint")
	yard._tint_stone(a, Color("726f5d"))
	assert(second.get_instance_shader_parameter("stone_color") == Color("93907e")*1.08, "Tinting one stone cannot recolor another")
	var copy: Node3D = b.duplicate(0)
	assert(copy.find_children("*","MeshInstance3D",true,false)[0].get_instance_shader_parameter("stone_color") == Color("93907e")*1.08, "Construction copies retain instance color")
	a.free(); b.free(); copy.free(); yard.free()
	print("COURTYARD_MATERIALS_PASS shared drawing, independent tints and construction copies")
	quit()
