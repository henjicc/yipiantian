extends RefCounted
const HEN_STRIDE: float = .16

static func hen_pace(phase: float) -> float:
	var step: float = fposmod(phase * 2.0, 1.0)
	# Brief hesitation at foot exchange; a nonzero floor lets distance advance.
	return lerpf(.24, 1.0, smoothstep(.0, .12, step) * (1.0 - smoothstep(.82, 1.0, step)))

static func hen_head_offset(phase: float) -> float:
	var step: float = fposmod(phase * 2.0, 1.0)
	# Quick thrust, then cancel body translation for the remaining step.
	return HEN_STRIDE * .5 * (smoothstep(0.0, .26, step) - step - .33)
## Waterfowl retain their time-driven paddle/glide rhythm.
static func cycle(_kind: String, time: float) -> float:
	return time * .82 * TAU

static func pace(kind: String, time: float) -> float:
	var stroke: float = .5 + .5 * sin(cycle(kind,time))
	if kind=="duck":
		# Alternate paddle / glide without stopping abruptly on water.
		return lerpf(.43,1.0,stroke*stroke) * lerpf(.76,1.0,.5+.5*sin(time*.57))
	return 1.0
