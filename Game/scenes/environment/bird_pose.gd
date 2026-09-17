extends RefCounted
## Tripo rest rig retained. Local procedural poses replace the old unrelated idle loop.
var skeleton: Skeleton3D
var species: String
var phase: float = 0.0
var motion: float = 0.0
var action_mix: float = 0.0
var action: String = "rest"
var rests: Array[Transform3D] = []
var legs: Array[Dictionary] = []
var head: int
var neck: int
var root: Node3D
var ground: Callable

func configure(bird: Node3D, kind: String) -> void:
	root = bird
	species = kind
	for player: AnimationPlayer in bird.find_children("*", "AnimationPlayer", true, false): player.stop()
	skeleton = bird.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.reset_bone_poses()
	for i: int in skeleton.get_bone_count(): rests.append(skeleton.get_bone_global_rest(i))
	head = skeleton.find_bone("tripo__Head_0")
	neck = skeleton.find_bone("tripo__Spine_2")
	for side: String in ["Left", "Right"]:
		var knee: int = skeleton.find_bone("tripo__0_%s_Limb_0" % side)
		var foot: int = skeleton.find_bone("tripo__0_%s_Limb_1" % side)
		legs.append({"hip": skeleton.get_bone_parent(knee), "knee": knee, "foot": foot})

func update(delta: float, distance: float, speed: float, behavior: String, time: float) -> void:
	motion = move_toward(motion, clampf(speed / (.23 if species == "hen" else .3), 0.0, 1.0), delta * 4.0)
	phase += distance / (.22 if species == "hen" else .5)
	if behavior != action:
		action_mix = move_toward(action_mix, 0.0, delta * 3.0)
		if action_mix == 0.0: action = behavior
	else: action_mix = move_toward(action_mix, 1.0, delta * 2.0)
	skeleton.reset_bone_poses()
	var sign_forward: float = -1.0 if species == "goose" else 1.0
	var dip: float = 0.0
	var turn: float = sin(time * .7) * .10
	if action in ["probe", "peck"]:
		dip = (.5 + .5 * sin(time * (4.8 if species == "hen" else 2.2))) * (1.05 if species == "hen" else 1.35)
	elif action == "preen":
		dip = .45 + .10 * sin(time * 3.0)
		turn = 1.35 + .10 * sin(time * 2.0)
	elif action == "observe": turn = sin(time * 1.6) * .55
	_rotate(neck, Vector3.RIGHT, dip * .6 * sign_forward * action_mix)
	_rotate(head, Vector3.RIGHT, dip * .4 * sign_forward * action_mix)
	_rotate(head, Vector3.UP, turn * action_mix)
	for i: int in legs.size():
		var leg: Dictionary = legs[i]
		if species == "hen":
			var cycle: float = fposmod(phase + i * .5, 1.0)
			# 55% planted stance: backwards travel exactly matches body distance.
			var stride: float = .22 * .55
			var along: float = lerpf(stride * .5, -stride * .5, cycle / .55) if cycle < .55 else lerpf(-stride * .5, stride * .5, smoothstep(.55, 1.0, cycle))
			var lift: float = 0.0 if cycle < .55 else sin((cycle - .55) / .45 * PI) * .038
			var offset := Vector3(0, lift, along) * motion
			var local_offset: Vector3 = skeleton.global_basis.inverse() * root.global_basis.orthonormalized() * offset
			var target: Vector3 = skeleton.to_global(rests[leg.foot].origin + local_offset)
			var standing: Vector3 = root.to_local(skeleton.to_global(rests[leg.foot].origin))
			target.y = ground.call(Vector2(target.x, target.z)) + standing.y * root.scale.y + lift * motion
			_solve_leg(leg, skeleton.to_local(target))
		else:
			_rotate(leg.knee, Vector3.RIGHT, sin(phase * TAU + i * PI) * .42 * motion * sign_forward)

func _rotate(bone: int, axis: Vector3, angle: float) -> void:
	if bone < 0: return
	var basis: Basis = skeleton.get_bone_global_pose(bone).basis.orthonormalized()
	var local_axis: Vector3 = basis.inverse() * axis
	skeleton.set_bone_pose_rotation(bone, (skeleton.get_bone_pose_rotation(bone) * Quaternion(local_axis.normalized(), angle)).normalized())

func _global_rotation(bone: int, rotation: Basis) -> void:
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * rotation).get_rotation_quaternion().normalized())

func _solve_leg(leg: Dictionary, target: Vector3) -> void:
	var hip: Vector3 = rests[leg.hip].origin
	var knee: Vector3 = rests[leg.knee].origin
	var foot: Vector3 = rests[leg.foot].origin
	var upper: float = hip.distance_to(knee)
	var lower: float = knee.distance_to(foot)
	var direction: Vector3 = (target - hip).normalized()
	var reach: float = clampf(hip.distance_to(target), absf(upper - lower) + .001, upper + lower - .001)
	var plane: Vector3 = (knee - hip) - direction * (knee - hip).dot(direction)
	if plane.length_squared() < .000001: plane = Vector3.FORWARD
	var along: float = (upper * upper + reach * reach - lower * lower) / (2.0 * reach)
	var desired_knee: Vector3 = hip + direction * along + plane.normalized() * sqrt(maxf(0.0, upper * upper - along * along))
	var upper_rotation := Basis(Quaternion((knee - hip).normalized(), (desired_knee - hip).normalized()))
	_global_rotation(leg.hip, upper_rotation * rests[leg.hip].basis)
	var lower_rotation := Basis(Quaternion((foot - knee).normalized(), (target - desired_knee).normalized()))
	_global_rotation(leg.knee, lower_rotation * rests[leg.knee].basis)
	_global_rotation(leg.foot, rests[leg.foot].basis)
