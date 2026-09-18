extends RefCounted
## One shared stroke clock for propulsion and neck motion; no per-frame randomness.
static func cycle(kind: String, time: float) -> float:
	return time * (2.15 if kind=="hen" else .82) * TAU

static func pace(kind: String, time: float) -> float:
	var stroke: float = .5 + .5 * sin(cycle(kind,time))
	if kind=="hen":
		# A short planted hesitation between quick steps, plus longer looking pauses.
		return lerpf(.12,1.0,smoothstep(.23,.76,stroke)) * lerpf(.65,1.0,.5+.5*sin(time*1.17))
	if kind=="duck":
		# Alternate paddle / glide without stopping abruptly on water.
		return lerpf(.43,1.0,stroke*stroke) * lerpf(.76,1.0,.5+.5*sin(time*.57))
	return 1.0
