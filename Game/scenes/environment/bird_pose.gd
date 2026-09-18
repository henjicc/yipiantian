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
var root: Node3D
var ground: Callable
var neck_chain: Array[int] = []
var neck_limits: Array[float] = []
var beak_rest: Vector3
var beak_bindings: Array[Dictionary] = []

func configure(bird: Node3D, kind: String) -> void:
	root = bird
	species = kind
	for player: AnimationPlayer in bird.find_children("*", "AnimationPlayer", true, false): player.stop()
	skeleton = bird.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.reset_bone_poses()
	for i: int in skeleton.get_bone_count(): rests.append(skeleton.get_bone_global_rest(i))
	head = skeleton.find_bone("tripo__Head_0")
	for label: String in ["Spine_0", "Spine_1", "Spine_2", "Spine_3", "Head_0", "Head_1", "Head_2"]:
		var bone: int = skeleton.find_bone("tripo__" + label)
		if bone >= 0:
			neck_chain.append(bone)
			neck_limits.append(.38 if label == "Spine_0" else (.65 if label.begins_with("Spine") else .95))
	# Skinned vertices include inverse bind transforms: mesh.to_global(vertex)
	# alone double-applies the normalization retained on the imported skeleton.
	var threshold: float = root.to_local(skeleton.to_global(rests[head].origin)).y
	var forward: float = -1.0 if species == "goose" else 1.0
	var farthest: float = -INF
	for mesh: MeshInstance3D in bird.find_children("*", "MeshInstance3D", true, false):
		var skin: Skin = mesh.skin
		var bindings: Array[int] = []
		for i: int in skin.get_bind_count(): bindings.append(skeleton.find_bone(skin.get_bind_name(i)))
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var influences: int = arrays[Mesh.ARRAY_BONES].size() / vertices.size()
			for vertex_index: int in vertices.size():
				var point := Vector3.ZERO
				var vertex_bindings: Array[Dictionary] = []
				for j: int in influences:
					var offset: int = vertex_index * influences + j
					var weight: float = arrays[Mesh.ARRAY_WEIGHTS][offset]
					if weight <= 0: continue
					var bind: int = arrays[Mesh.ARRAY_BONES][offset]
					var local: Vector3 = skin.get_bind_pose(bind) * vertices[vertex_index]
					point += (rests[bindings[bind]] * local) * weight
					vertex_bindings.append({"bone": bindings[bind], "local": local, "weight": weight})
				point = root.to_local(skeleton.to_global(point))
				if point.y > threshold and point.z * forward > farthest:
					farthest = point.z * forward
					beak_rest = point
					beak_bindings = vertex_bindings
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
	var turn: float = sin(time * .7) * .10
	if action in ["probe", "peck"]:
		var amount: float = smoothstep(.08, .82, .5 + .5 * sin(time * (3.6 if species == "hen" else 1.9))) * action_mix
		var forward: Vector3 = root.global_basis.orthonormalized() * Vector3(0, 0, sign_forward)
		var contact: Vector3 = root.global_position + forward * (.14 if species == "hen" else .24)
		contact.y = ground.call(Vector2(contact.x, contact.z)) + .015 if species == "hen" else -.257
		_neck_reach(skeleton.to_local(root.to_global(beak_rest).lerp(contact, amount)), true)
	elif action == "preen":
		var size: float = 1.0 if species == "hen" else (1.25 if species == "duck" else 1.9)
		var shoulder := Vector3(.095 * size, .23 * size + .008 * sin(time * 4.5), -.01 * sign_forward)
		_neck_reach(skeleton.to_local(root.to_global(beak_rest.lerp(shoulder, action_mix))), false)
	else:
		if action == "observe": turn = sin(time * 1.6) * .55
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

func beak_world_position() -> Vector3:
	return skeleton.to_global(_beak_position())

func support_height() -> float:
	# Lower the pelvis to the lower supporting foot on stone/grass boundaries.
	# Sampling only under the body can leave a short leg reaching into thin air.
	var height: float=ground.call(Vector2(root.global_position.x,root.global_position.z))
	for i: int in legs.size():
		var cycle: float=fposmod(phase+i*.5,1.0)
		if cycle>=.55 and motion>.01: continue
		var along: float=lerpf(.0605,-.0605,cycle/.55)*motion
		var foot: Vector3=skeleton.to_global(rests[legs[i].foot].origin)
		foot+=root.global_basis.orthonormalized()*Vector3(0,0,along)
		height=minf(height,float(ground.call(Vector2(foot.x,foot.z))))
	return height

func _beak_position() -> Vector3:
	var point := Vector3.ZERO
	for binding: Dictionary in beak_bindings:
		point += (skeleton.get_bone_global_pose(binding.bone) * binding.local) * binding.weight
	return point

func _neck_reach(target: Vector3, sagittal: bool) -> void:
	# CCD is restricted to the authored neck chain; the body and feet stay planted.
	# Clamp total joint displacement from rest rather than accumulating unbounded turns.
	var rotations: Array[Quaternion] = []
	for bone: int in neck_chain: rotations.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
	for iteration: int in 7:
		for index: int in range(neck_chain.size() - 1, -1, -1):
			var bone: int = neck_chain[index]
			var joint: Transform3D = skeleton.get_bone_global_pose(bone)
			var tip: Vector3 = _beak_position()
			var from: Vector3 = (tip - joint.origin).normalized()
			var to: Vector3 = (target - joint.origin).normalized()
			var delta: Quaternion
			if sagittal:
				delta = Quaternion(Vector3.RIGHT, atan2(from.y * to.z - from.z * to.y, from.y * to.y + from.z * to.z))
			else: delta = Quaternion(from, to)
			var parent: int = skeleton.get_bone_parent(bone)
			var parent_basis: Basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized()
			var local: Quaternion = (parent_basis.inverse() * Basis(delta) * joint.basis.orthonormalized()).get_rotation_quaternion()
			var relative: Quaternion = (rotations[index].inverse() * local).normalized()
			if relative.w < 0: relative = -relative
			var angle: float = relative.get_angle()
			if angle > neck_limits[index]: relative = Quaternion.IDENTITY.slerp(relative, neck_limits[index] / angle)
			skeleton.set_bone_pose_rotation(bone, (rotations[index] * relative).normalized())

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
