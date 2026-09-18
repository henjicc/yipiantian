extends RefCounted
## Visual resource mapping only; growth phases and rewards come from FarmState.

const CROP_IDS: Array[String] = ["greens", "radish", "spinach", "lettuce", "chrysanthemum", "coriander", "celery", "mustard", "tatsoi", "carrot", "scallion", "garlic"]
const ROOT_RADII := {
	"spinach": Vector2(0.03835, 0.11000),
	"lettuce": Vector2(0.11000, 0.11000),
	"chrysanthemum": Vector2(0.08778, 0.11000),
	"coriander": Vector2(0.02333, 0.02220),
	"celery": Vector2(0.04430, 0.04709),
	"mustard": Vector2(0.04806, 0.03768),
	"tatsoi": Vector2(0.11000, 0.11000),
	"carrot": Vector2(0.05847, 0.11000),
	"scallion": Vector2(0.11000, 0.03975),
	"garlic": Vector2(0.04260, 0.03028),
}
const STAGES: Array[String] = ["sprout", "young", "mature"]
const P2_STAGE_CROPS: Array[String] = ["spinach"]


static func preserves_painted_color(crop_id: String, stage: String) -> bool:
	return P2_STAGE_CROPS.has(crop_id) or (crop_id == "greens" and stage == "mature")


static func wind_profile(crop_id: String) -> String:
	return crop_id if crop_id in ["greens", "radish", "spinach"] else "autumn_crop"


static func scene_path(crop_id: String, stage: String, low_detail: bool = false) -> String:
	if not CROP_IDS.has(crop_id) or not STAGES.has(stage):
		return ""
	return "res://art/crops/%s/%s_%s%s.glb" % [crop_id, crop_id, stage, "_low" if low_detail and crop_id in ["greens", "radish"] else ""]


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
	if crop_id == "greens":
		return {"sprout": .001, "young": .009, "mature": .021}.get(stage, 0.0)
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


static func soil_radius(crop_id: String, stage: String) -> Vector2:
	if crop_id == "spinach":
		return {"sprout": Vector2(.009,.009), "young": Vector2(.0114,.0106), "mature": Vector2(.0263,.0219)}.get(stage, Vector2(.0263,.0219))
	if ROOT_RADII.has(crop_id):
		return Vector2(.015,.015) if stage == "sprout" else ROOT_RADII[crop_id] * (.54 if stage == "young" else 1.0)
	# Audited at the soil contact slice of each imported stage, not canopy bounds.
	if crop_id == "greens":
		return {"sprout": Vector2(.018,.022), "young": Vector2(.055,.058), "mature": Vector2(.11,.10)}.get(stage,Vector2(.075,.06))
	return {"sprout": Vector2(.014,.018), "young": Vector2(.024,.025), "mature": Vector2(.055,.055)}.get(stage,Vector2(.052,.05))
