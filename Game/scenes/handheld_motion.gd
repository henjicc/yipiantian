extends RefCounted
## Session-only authoring parameters; no contribution enters the saved camera pose.
const FIELDS: Array = [
	["frequency", "频率", .05, 2.0, .05, .35],
	["amplitude", "总幅度", 0.0, 3.0, .05, 1.0],
	["x", "X 左右位移", 0.0, 2.0, .05, 1.0],
	["y", "Y 上下位移", 0.0, 2.0, .05, .65],
	["z", "Z 前后位移", 0.0, 2.0, .05, .4],
	["pitch", "俯仰", 0.0, 2.0, .05, .4],
	["yaw", "偏航", 0.0, 2.0, .05, .5],
	["roll", "侧倾", 0.0, 2.0, .05, .3],
	["detail", "细微抖动", 0.0, .5, .01, .08],
	["inertia", "惯性", .05, 1.0, .05, .25],
]
var parameters: Dictionary = {}
var offset := Vector3.ZERO
var angles := Vector3.ZERO
var _phase: float = randf() * 1000.0
var _noise := FastNoiseLite.new()

func _init() -> void:
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	_noise.frequency = 1.0
	reset()

func reset() -> void:
	for field: Array in FIELDS: parameters[field[0]] = field[5]

func advance(delta: float) -> void:
	_phase += delta * parameters.frequency
	var drift := Vector3(_sample(13), _sample(47), _sample(83))
	var response: float = 1.0 - exp(-delta / parameters.inertia)
	offset = offset.lerp(drift * Vector3(parameters.x, parameters.y, parameters.z) * parameters.amplitude, response)
	# Small correlated rotations resemble a hand correcting its aim, while a
	# separate faster layer supplies fine movement without frame-random jitter.
	var turn := Vector3(-drift.y, drift.x, _sample(131))
	angles = angles.lerp(turn * Vector3(parameters.pitch, parameters.yaw, parameters.roll) * deg_to_rad(.35) * parameters.amplitude, response)

func _sample(channel: float) -> float:
	return _noise.get_noise_2d(_phase, channel) * .9 + sin(_phase * 2.3 + channel) * .1 + _noise.get_noise_2d(_phase * 7.0, channel + 211.0) * parameters.detail
