---
type: Reference
title: "Input Reference"
description: "For input *propagation order* (`_input` / `_gui_input` / `_unhandled_input`) and the event-vs-polling decision, see [architecture.md](architecture.md)."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-19T00:00:00Z }
---
# Input Reference

**Verified 2026-06-19** against Godot 4.7. The Input/InputMap API and `physical_keycode`-over-`keycode` guidance are stable across 4.x. 4.7 added `VirtualJoystick`, the `InputEvent.DEVICE_ID_*` constants (a breaking change for code that assumed keyboard/mouse `device == 0`), and `Input.ignore_joypad_on_unfocused_application`. Re-verify enum names if a newer minor changes them.

For input *propagation order* (`_input` / `_gui_input` / `_unhandled_input`) and the event-vs-polling decision, see [architecture.md](architecture.md). This file covers the Input Map, action polling, devices, and runtime remapping.

## Use actions, not raw keys

Define named actions in the Input Map (Project Settings > Input Map, stored in `project.godot`) and bind keys, mouse buttons, and gamepad inputs to each. Code references the action name, so rebinding never touches gameplay code and one action can have many bindings.

## Polling actions (continuous and discrete)

```gdscript
# Continuous (movement, aiming): poll every frame
func _physics_process(_delta: float) -> void:
    var dir := Input.get_vector("left", "right", "up", "down")   # normalized Vector2, deadzoned
    velocity = dir * SPEED
    move_and_slide()

# Discrete (jump, attack): the "just" variants fire for one frame
if Input.is_action_just_pressed("jump"): jump()
if Input.is_action_just_released("charge"): release_shot()

var throttle := Input.get_action_strength("accelerate")   # 0..1 (analog triggers)
var steer := Input.get_axis("steer_left", "steer_right")  # -1..1
```
`get_vector`/`get_axis`/`get_action_strength` read analog inputs and apply the action's deadzone, so they work for both keyboard (0/1) and stick (0..1).

## Event-based handling

For one-shot actions, prefer reacting to events over polling (consume so UI/gameplay do not double-handle):
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        interact()
        get_viewport().set_input_as_handled()
```
Useful `InputEvent` subclasses: `InputEventKey`, `InputEventMouseButton`, `InputEventMouseMotion`, `InputEventJoypadButton`, `InputEventJoypadMotion`, `InputEventScreenTouch`/`ScreenDrag` (mobile).

### Identifying the source device (Godot 4.7)

Every event carries a `device: int`. In 4.7 keyboard and mouse events report dedicated IDs instead of `0`:
```gdscript
func _input(event: InputEvent) -> void:
    if event.device == InputEvent.DEVICE_ID_KEYBOARD:   # 16
        ...
    elif event.device == InputEvent.DEVICE_ID_MOUSE:    # 32
        ...
    # gamepads keep their 0-based slot id; DEVICE_ID_EMULATION is -1
```
**Breaking change:** code that treated `event.device == 0` as "keyboard or mouse" must switch to these constants.

## physical_keycode vs keycode

Bind movement to **`physical_keycode`** (position on the keyboard) so WASD stays in the same place on AZERTY/QWERTZ. Use `keycode` only when the printed letter matters (text shortcuts).
```gdscript
if Input.is_physical_key_pressed(KEY_W): ...
```

## Mouse

```gdscript
Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)   # FPS look; HIDDEN/CONFINED/VISIBLE also
Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)
# Mouse position: get_global_mouse_position() (world) / get_viewport().get_mouse_position() (screen)
```

## Gamepad

```gdscript
for id in Input.get_connected_joypads():
    print(Input.get_joy_name(id))
Input.start_joy_vibration(0, 0.5, 0.8, 0.3)        # device, weak, strong, seconds
```
Prefer named actions (with both keyboard and joypad bindings) over reading raw axes. Set per-action deadzones in the Input Map; `get_vector` honors them.

Set `Input.ignore_joypad_on_unfocused_application = true` (Project Settings > Input Devices > Joypads, off by default) to drop gamepad input, motion sensors, and vibration while the window is unfocused (Godot 4.7).

## VirtualJoystick (touch, Godot 4.7)

`VirtualJoystick` is a built-in on-screen joystick `Control`. It does not expose a live output value; instead it **feeds the Input Map**, so you read it through the same `Input.get_vector()` used for physical sticks. Set its `action_left/right/up/down` (StringName) to your movement actions and pick a `joystick_mode`:

```gdscript
@onready var stick: VirtualJoystick = %VirtualJoystick

func _ready() -> void:
    stick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC   # JOYSTICK_FIXED / JOYSTICK_FOLLOWING

func _physics_process(_delta: float) -> void:
    var dir := Input.get_vector(stick.action_left, stick.action_right,
                                stick.action_up, stick.action_down)
    velocity = dir * SPEED
    move_and_slide()
```
Modes: `JOYSTICK_FIXED` (stays put), `JOYSTICK_DYNAMIC` (appears where touched), `JOYSTICK_FOLLOWING` (base follows the finger). Useful props: `deadzone_ratio`, `clampzone_ratio`, `joystick_size`, `visibility_mode`. Signals: `pressed()`, `released(input_vector)`, `tapped()`, `flicked(input_vector)`, `flick_canceled()`.

## Motion sensors (mobile)

Read gyro and accelerometer for gyro-aiming or tilt controls (4.7 improved mobile sensor support; these getters are long-standing):
```gdscript
var rotation_rate := Input.get_gyroscope()      # Vector3, rad/s around each axis
var tilt := Input.get_accelerometer()           # Vector3, m/s^2 incl. gravity
```

## Runtime remapping

Capture a new binding, then swap it into the action. Persist the result (see [persistence.md](persistence.md)).
```gdscript
func rebind(action: String, event: InputEvent) -> void:
    InputMap.action_erase_events(action)
    InputMap.action_add_event(action, event)

# Capture step (in a "press a key" screen):
func _input(event: InputEvent) -> void:
    if listening and (event is InputEventKey or event is InputEventJoypadButton):
        rebind(pending_action, event)
        listening = false
```
`InputMap.has_action`, `get_actions`, and `action_get_events` round out the API.

## Pitfalls

- Hardcoding keys (`KEY_SPACE`) in gameplay instead of an action. Rebinding and gamepad support then require code edits.
- Binding movement to `keycode`; use `physical_keycode` so layout does not move WASD.
- Reading `is_action_pressed` for a discrete action and firing every frame it is held. Use `is_action_just_pressed`.
- Polling in `_process` for physics-affecting input; poll movement in `_physics_process` (see [physics.md](physics.md)).
