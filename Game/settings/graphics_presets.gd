extends RefCounted
## Presets expand into independent preferences; their name is derived, never a
## second source of rendering state. Hardware recommendations are conservative.

const ORDER: Array[String] = ["high", "standard", "low"]
const TITLES: Array[String] = ["高画质", "中画质", "低画质"]
const KEYS: Array[String] = ["quality", "shadows", "lighting", "antialiasing", "resolution", "fsr", "dof_enabled"]


static func values(tier: String, output_height: int, fsr_supported: bool = true) -> Dictionary:
	var result: Dictionary = {
		"quality": tier, "shadows": tier, "lighting": tier,
		"antialiasing": "4x" if tier == "high" else ("2x" if tier == "standard" else "off"),
		"resolution": "1440" if tier == "high" else ("1080" if tier == "standard" else "720"),
		"fsr": "off", "dof_enabled": tier != "low",
	}
	# FSR scales from the output, not from the manual resolution cap. Only use it
	# when its actual pixel height fits this tier's budget (including 4K screens).
	if fsr_supported:
		if tier == "standard" and output_height > 1080 and output_height <= 1620:
			result.fsr = "quality"
		elif tier == "low" and output_height > 1080 and output_height <= 1440:
			result.fsr = "performance"
	return result


static func matching(settings: Dictionary, height: int, supported: bool = true) -> int:
	for index: int in ORDER.size():
		var preset: Dictionary = values(ORDER[index], height, supported)
		var matches: bool = true
		for key: String in KEYS:
			if settings.get(key) != preset[key]: matches = false; break
		if matches: return index
	return 3


static func recommend(device_type: int, memory_bytes: int, processors: int, pixels: int) -> String:
	if memory_bytes <= 0 or memory_bytes < 8 * 1024 * 1024 * 1024 or processors < 4:
		return "low"
	if device_type != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU or pixels > 3840 * 2160:
		return "low"
	# High is recommended only after a successful real-scene sample. Adapter
	# names and VRAM capacity alone are not performance measurements.
	return "standard"
