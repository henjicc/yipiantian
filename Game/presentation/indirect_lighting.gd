extends Node
## SDFGI receives moving objects but must never bake their changing silhouettes.

var _scene: Node3D
var _environment: Environment
var _occluders: Array[Node] = []


func configure(scene: Node3D, courtyard: Node3D, environment: Environment) -> void:
	_scene = scene
	_environment = environment
	# These structures are immutable within a scene. Courtyard layout changes
	# replace the entire scene and its Environment, rebuilding the GI volume too.
	for part: Node in courtyard.get_children():
		if part.name in ["MainBank", "EastBank", "MainHouse", "PorchDeck", "Kitchen", "EntranceTrellis"] or part.scene_file_path.ends_with("/stone_bridge.glb"):
			_occluders.append(part)
	for node: Node in scene.find_children("*", "GeometryInstance3D", true, false):
		_classify(node)
	# Handles later crop stages, animals, decoration previews and kitchen props.
	# No per-frame walk and no change to gameplay or imported mesh resources.
	get_tree().node_added.connect(_classify)
	_environment.sdfgi_cascades = 4
	_environment.sdfgi_min_cell_size = 0.12
	_environment.sdfgi_energy = 0.50
	_environment.sdfgi_bounce_feedback = 0.20
	_environment.sdfgi_use_occlusion = true
	_environment.sdfgi_read_sky_light = true


func set_enabled(enabled: bool) -> void:
	_environment.sdfgi_enabled = enabled


func _classify(node: Node) -> void:
	if not node is GeometryInstance3D or not _scene.is_ancestor_of(node):
		return
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for structure: Node in _occluders:
		if structure == node or structure.is_ancestor_of(node):
			node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
			return


func _exit_tree() -> void:
	# A layout reload removes the old scene before its queued deletion.
	if get_tree().node_added.is_connected(_classify):
		get_tree().node_added.disconnect(_classify)
	# Release the GI volume while its Environment is still attached to the world.
	_environment.sdfgi_enabled = false
