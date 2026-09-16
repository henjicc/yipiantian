extends RefCounted
## Visual resource mapping only; growth phases and rewards come from FarmState.

const CROP_IDS: Array[String] = ["greens", "radish"]
const STAGES: Array[String] = ["sprout", "young", "mature"]


static func scene_path(crop_id: String, stage: String, low_detail: bool = false) -> String:
	if not CROP_IDS.has(crop_id) or not STAGES.has(stage):
		return ""
	return "res://art/crops/%s/%s_%s%s.glb" % [crop_id, crop_id, stage, "_low" if low_detail else ""]


static func instantiate(crop_id: String, stage: String, low_detail: bool = false) -> Node3D:
	var path: String = scene_path(crop_id, stage, low_detail)
	if path.is_empty():
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


static func planting_depth(crop_id: String, stage: String) -> float:
	# Source origin remains at the root tip; the field owns the soil-surface anchor.
	if crop_id != "radish":
		return 0.0
	match stage:
		"sprout":
			return 0.003
		"young":
			return 0.020
		"mature":
			return 0.060
	return 0.0
