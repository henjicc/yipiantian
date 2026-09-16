extends RefCounted
## Design definitions only. Every returned dictionary is an independent value.

const WATER_PROGRESS: float = 0.2
const YOUNG_PROGRESS: float = 0.35


static func crop_ids() -> Array[String]:
	return ["greens", "radish"]


static func definition(crop_id: String) -> Dictionary:
	match crop_id:
		"greens":
			return {"id": "greens", "name": "青菜", "duration_seconds": 1800.0}
		"radish":
			return {"id": "radish", "name": "白萝卜", "duration_seconds": 5400.0}
	return {}
