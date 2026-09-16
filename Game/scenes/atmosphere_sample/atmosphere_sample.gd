extends Node3D
## Independent asset inspection; the complete environment is integrated by 3.3.

const Crops = preload("res://scenes/crop_sample/crop_sample.gd")
const Atmosphere = preload("res://atmosphere/day_night.gd")
const Audio = preload("res://audio/farm_audio.gd")
const Activity = preload("res://atmosphere/window_activity.gd")
var crops: Node3D
var atmosphere: Node
var audio: Node
var activity: Node
var water: MeshInstance3D
var lantern_anchor: Marker3D


func _ready() -> void:
	crops = Crops.new()
	add_child(crops)
	water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50, 50)
	water.mesh = plane
	water.position.y = -0.04
	add_child(water)
	lantern_anchor = Marker3D.new()
	lantern_anchor.position = Vector3(-1.1, 0.75, 0.0)
	add_child(lantern_anchor)
	var world: WorldEnvironment
	for child in crops.get_children():
		if child is WorldEnvironment:
			world = child
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.configure(crops.sun, world, water)
	var anchors: Array[Node3D] = [lantern_anchor]
	atmosphere.set_lantern_anchors(anchors)
	audio = Audio.new()
	add_child(audio)
	atmosphere.night_weight_changed.connect(audio.set_night_weight)
	audio.set_night_weight(atmosphere.get_night_weight())
	activity = Activity.new()
	activity.foreground_changed.connect(audio.set_foreground)
	add_child(activity)
	audio.set_foreground(activity.is_foreground())
