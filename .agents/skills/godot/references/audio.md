---
type: Reference
title: "Audio Reference"
description: "@onready var music: AudioStreamPlayer = $Music"
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# Audio Reference

**Verified 2026-06-06** against Godot 4.x. Godot 4 renamed the volume conversion globals to `linear_to_db`/`db_to_linear` (the 3.x `linear2db`/`db2linear` are gone). Re-verify if a newer minor changes them.

## Player types

| Node | Use for |
|---|---|
| `AudioStreamPlayer` | Non-positional: music, UI clicks, narration |
| `AudioStreamPlayer2D` | Positional in 2D: panned and attenuated by distance to the `AudioListener2D`/camera |
| `AudioStreamPlayer3D` | Positional in 3D: full spatialization, attenuation, Doppler |

## Basic playback

```gdscript
@onready var music: AudioStreamPlayer = $Music

func _ready() -> void:
    music.stream = preload("res://assets/audio/theme.ogg")
    music.bus = "Music"
    music.play()                 # play(from_position) to seek
    music.finished.connect(_on_track_done)   # fires on natural end, not on stop()
```
Key properties: `stream`, `playing`, `autoplay`, `volume_db` (offset in dB, 0 = unchanged), `pitch_scale` (also changes tempo), `bus`, `stream_paused` (pause without losing position), `max_polyphony` (concurrent voices on one player; oldest is cut when exceeded).

Import looping music as Ogg Vorbis and enable Loop in the import dock; short SFX as WAV.

## One-shot sound effects

A single player cuts itself off when retriggered. For overlapping SFX either raise `max_polyphony`, or spawn a throwaway player that frees itself:
```gdscript
func play_sfx(stream: AudioStream, bus := "SFX") -> void:
    var p := AudioStreamPlayer.new()
    p.stream = stream
    p.bus = bus
    add_child(p)
    p.finished.connect(p.queue_free)
    p.play()
```
For frequent SFX, pool a handful of players and reuse the idle ones instead of allocating each time.

## Buses and the mixer

Define buses (Master, Music, SFX, UI) in the Audio bottom panel; route each player via its `bus` property. Control them at runtime through `AudioServer`:
```gdscript
var idx := AudioServer.get_bus_index("Music")
AudioServer.set_bus_volume_db(idx, -6.0)
AudioServer.set_bus_mute(idx, true)
AudioServer.set_bus_effect_enabled(idx, 0, false)   # toggle a bus effect (e.g. reverb)
```

## Volume sliders (linear vs dB)

A UI slider is linear (0..1); `volume_db` and bus volume are logarithmic. Convert, do not assign a 0..1 value to dB.
```gdscript
func _on_music_slider_changed(value: float) -> void:   # value in 0..1
    var idx := AudioServer.get_bus_index("Music")
    AudioServer.set_bus_volume_db(idx, linear_to_db(value))

# Reading back for the slider:
slider.value = db_to_linear(AudioServer.get_bus_volume_db(idx))
```
`linear_to_db(0.0)` is `-inf` (silence); guard a slider's zero end by muting the bus instead of passing 0.

## Pausing audio

Audio on a pausable node stops with `get_tree().paused`. To keep music playing through a pause, set the player's `process_mode` to `PROCESS_MODE_ALWAYS` (see [scene-tree.md](scene-tree.md)). To duck or pause a single sound deliberately, use `stream_paused`.

## Pitfalls

- Assigning a 0..1 slider value straight to `volume_db`. dB is logarithmic; use `linear_to_db`.
- Reusing one player for rapid overlapping SFX (each `play()` cancels the last). Pool players or raise `max_polyphony`.
- Expecting `finished` after calling `stop()`. It only fires on natural completion.
- 3.x names `linear2db`/`db2linear`. They no longer exist.
