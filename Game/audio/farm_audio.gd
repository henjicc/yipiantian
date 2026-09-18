extends Node
## One controller owns the game's buses; settings stay separate from focus mute.

const MUSIC = preload("res://art/audio/courtyard_theme.ogg")
const DAY = preload("res://art/audio/ambience_day.ogg")
const NIGHT = preload("res://art/audio/ambience_night.ogg")
const SEASONS = {
	"drying": preload("res://art/audio/season_drying.ogg"),
	"after_rain": preload("res://art/audio/season_after_rain.ogg"),
}
const ACTIONS: Dictionary = {
	"sow": preload("res://art/audio/sow.wav"),
	"water": preload("res://art/audio/water.wav"),
	"harvest": preload("res://art/audio/harvest.wav"),
	"weed": preload("res://art/audio/harvest.wav"),
	"till": preload("res://art/audio/sow.wav"),
}
const UI = preload("res://art/audio/ui.wav")
const BUS_MASTER: StringName = &"FarmMaster"
const BUS_MUSIC: StringName = &"FarmMusic"
const BUS_EFFECTS: StringName = &"FarmEffects"
const BUS_AMBIENT: StringName = &"FarmAmbient"

var _volumes: Dictionary = {"master": 0.8, "music": 0.7, "effects": 0.8}
var _foreground: bool = true
var _music: AudioStreamPlayer
var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _season: AudioStreamPlayer
var _season_id: String = "daily"
var _ui: AudioStreamPlayer
var _actions: Array[AudioStreamPlayer] = []
var _last_action_usec: int = -1000000
var _last_ui_usec: int = -1000000
var _night_weight: float = 0.0
var _shutdown: bool = false


func _ready() -> void:
	if not get_tree().get_nodes_in_group("farm_audio_owner").is_empty():
		push_error("Only one FarmAudio controller may own the game audio buses.")
		queue_free()
		return
	add_to_group("farm_audio_owner")
	_ensure_bus(BUS_MASTER, &"Master")
	_ensure_bus(BUS_MUSIC, BUS_MASTER)
	_ensure_bus(BUS_EFFECTS, BUS_MASTER)
	_ensure_bus(BUS_AMBIENT, BUS_EFFECTS)
	_music = _player("Music", MUSIC, BUS_MUSIC)
	_day = _player("DayAmbience", DAY, BUS_AMBIENT)
	_night = _player("NightAmbience", NIGHT, BUS_AMBIENT)
	_season = _player("SeasonAmbience", null, BUS_AMBIENT)
	_ui = _player("Interface", UI, BUS_EFFECTS)
	for index in 2:
		_actions.append(_player("Action%d" % index, null, BUS_EFFECTS))
	_foreground = get_window().has_focus() and get_window().mode != Window.MODE_MINIMIZED
	set_night_weight(_night_weight)
	_apply_volumes()
	_music.play()
	_day.play()
	_night.play()
	_pause_background_loops()


func set_volumes(master: float, music: float, effects: float) -> bool:
	if not is_finite(master) or not is_finite(music) or not is_finite(effects):
		return false
	_volumes = {"master": clampf(master, 0.0, 1.0), "music": clampf(music, 0.0, 1.0), "effects": clampf(effects, 0.0, 1.0)}
	if is_node_ready():
		_apply_volumes()
	return true


func get_volumes() -> Dictionary:
	return _volumes.duplicate()


func set_foreground(active: bool) -> void:
	if _shutdown:
		return
	_foreground = active
	if not is_node_ready():
		return
	_apply_volumes()
	_pause_background_loops()
	if not active:
		_ui.stop()
		for player in _actions:
			player.stop()


func is_foreground() -> bool:
	return _foreground


func set_night_weight(weight: float) -> void:
	_night_weight = clampf(weight, 0.0, 1.0) if is_finite(weight) else 0.0
	if _day != null:
		_day.volume_linear = cos(_night_weight * PI * 0.5) * (.70 if _season_id=="after_rain" else 1.0)
		_night.volume_linear = sin(_night_weight * PI * 0.5)
	if _season != null:
		_season.volume_linear = 1.0 if _season_id=="after_rain" else lerpf(1.0,.3,_night_weight)

func set_season(id: String) -> void:
	if _shutdown or _season==null or id==_season_id: return
	_season_id=id
	_season.stop()
	_season.stream=SEASONS.get(id)
	if _season.stream!=null: _season.play()
	set_night_weight(_night_weight)
	_pause_background_loops()


func play_action(tool: String, result: Dictionary) -> bool:
	if not result.get("ok", false) or not ACTIONS.has(tool) or not _can_hear_effects():
		return false
	var now: int = Time.get_ticks_usec()
	if now - _last_action_usec < 160000:
		return false
	for player in _actions:
		if not player.playing:
			player.stream = ACTIONS[tool]
			player.play()
			_last_action_usec = now
			return true
	return false


func play_ui() -> bool:
	var now: int = Time.get_ticks_usec()
	if not _can_hear_effects() or _ui.playing or now - _last_ui_usec < 100000:
		return false
	_ui.play()
	_last_ui_usec = now
	return true


func _can_hear_effects() -> bool:
	return not _shutdown and is_node_ready() and _foreground and _volumes.master > 0.0 and _volumes.effects > 0.0


func shutdown() -> void:
	if _shutdown:
		return
	_shutdown = true
	# AudioServer retires stopped playback on a later mix. The scene's final exit
	# keeps the engine running briefly after this, instead of stopping at teardown.
	for player: AudioStreamPlayer in [_music, _day, _night, _season, _ui] + _actions:
		if is_instance_valid(player):
			player.stop()
			player.stream = null


func _pause_background_loops() -> void:
	for player in [_music, _day, _night, _season]:
		player.stream_paused = not _foreground


func _apply_volumes() -> void:
	_set_bus(BUS_MASTER, _volumes.master, not _foreground)
	_set_bus(BUS_MUSIC, _volumes.music, false)
	_set_bus(BUS_EFFECTS, _volumes.effects, false)


func _set_bus(bus: StringName, volume: float, extra_mute: bool) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume == 0.0 or extra_mute)


func _ensure_bus(bus: StringName, destination: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, destination)


func _player(label: String, stream: AudioStream, bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = label
	player.stream = stream
	player.bus = bus
	add_child(player)
	return player
