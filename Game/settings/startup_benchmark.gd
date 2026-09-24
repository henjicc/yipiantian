extends RefCounted
## Short, bounded samples of the actual farm. Never classify unfocused frames.

static func summarize(samples: Array[float]) -> Dictionary:
	if samples.size() < 20: return {"ok": false, "reason": "insufficient"}
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	var median: float = ordered[ordered.size() / 2]
	var p90: float = ordered[mini(ordered.size() - 1, int(ordered.size() * .9))]
	if median <= 0.0 or p90 > median * 2.5:
		return {"ok": false, "reason": "unstable"}
	return {"ok": true, "p90_ms": p90, "samples": ordered.size()}


static func sample(tree: SceneTree, window: Window) -> Dictionary:
	if DisplayServer.get_name() == "headless" or not window.has_focus():
		return {"ok": false, "reason": "unfocused"}
	var size: Vector2i = window.size
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	var samples: Array[float] = []
	while Time.get_ticks_usec() - start < 2500000:
		await tree.process_frame
		var now: int = Time.get_ticks_usec()
		if not window.has_focus() or window.mode == Window.MODE_MINIMIZED or window.size != size:
			return {"ok": false, "reason": "window_changed"}
		if now - start > 4000000:
			return {"ok": false, "reason": "timeout"}
		# Keep compilation and the first second of warm-up outside the sample.
		if previous - start >= 1000000: samples.append(float(now - previous) / 1000.0)
		previous = now
	return summarize(samples)
