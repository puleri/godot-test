extends RefCounted
## World-space ankle contacts over the authored gait. All distances scale with the rig.

var enabled := true
var stride_length := 1.0
var phase := 0.0
var grounded := false
var speed := 0.0
var weight_shift := Vector3.ZERO
var planted: Array[bool] = [false, false]
var anchors: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var feet: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _idle: Array[Transform3D] = []
var _front: Array[Transform3D] = []
var _contact_phase: Array[float] = [0.25, 0.75]
var _swing_from: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _was_stance: Array[bool] = [false, false]
var _early_swing: Array[bool] = [false, false]
var _last_cycle: Array[float] = [0.0, 0.0]
var _contact_valid: Array[bool] = [false, false]
var _swing_start_cycle: Array[float] = [0.52, 0.52]
var _settling := -1
var _settle_time := 0.0
var _settle_duration := 0.16
var _initialized := false
var _was_moving := false
var _body: CharacterBody3D
var _leg_length := 1.0
var _clearance: Array[float] = [0.03, 0.03]
var _support: Array[Node3D] = [null, null]
var _last_support: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]


func configure(skeleton: Skeleton3D, legs: Array[Vector3i], player: CharacterBody3D, idle: Animation, walk: Animation) -> void:
	_body = player
	var original: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		original.append(skeleton.get_bone_pose(bone))
	_sample(skeleton, idle, 0.0)
	for chain in legs:
		_idle.append(skeleton.get_bone_global_pose(chain.z))
		_front.append(skeleton.get_bone_global_pose(chain.z))
	_leg_length = (skeleton.global_basis * (skeleton.get_bone_global_pose(legs[0].x).origin - skeleton.get_bone_global_pose(legs[0].y).origin)).length()
	_leg_length += (skeleton.global_basis * (skeleton.get_bone_global_pose(legs[0].y).origin - skeleton.get_bone_global_pose(legs[0].z).origin)).length()
	# Preserve the ankle's authored clearance above the collision capsule's sole.
	var bottom := 0.0
	for shape in player.find_children("*", "CollisionShape3D", true, false):
		if shape.shape is CapsuleShape3D:
			bottom = shape.global_position.y - shape.shape.height * shape.global_basis.y.length() * 0.5 - player.global_position.y
	for i in 2:
		_clearance[i] = clampf((skeleton.global_transform * _idle[i].origin).y - player.global_position.y - bottom, _leg_length * 0.025, _leg_length * 0.12)
	var model := skeleton.get_parent() as Node3D
	var forward := (skeleton.global_basis.inverse() * model.global_basis.x).normalized()
	var minimum := [INF, INF]
	var maximum := [-INF, -INF]
	for frame in 96:
		var sample_phase := float(frame) / 96.0
		_sample(skeleton, walk, walk.length * sample_phase)
		for i in 2:
			var pose := skeleton.get_bone_global_pose(legs[i].z)
			var along := pose.origin.dot(forward)
			minimum[i] = minf(minimum[i], along)
			if along > maximum[i]:
				maximum[i] = along
				_contact_phase[i] = sample_phase
				_front[i] = pose
	for i in 2:
		_front[i].basis = _idle[i].basis
	stride_length = minf(_leg_length * 2.0, maxf(((maximum[0] - minimum[0]) + (maximum[1] - minimum[1])) * (skeleton.global_basis * forward).length(), _leg_length))
	for bone in original.size():
		skeleton.set_bone_pose(bone, original[bone])
	reset()


func reset() -> void:
	_initialized = false
	_was_moving = false
	_settling = -1
	_settle_time = 0.0
	grounded = false
	weight_shift = Vector3.ZERO
	for i in 2:
		planted[i] = false
		_was_stance[i] = false
		_early_swing[i] = false
		_contact_valid[i] = false
		_support[i] = null


func solve_targets(skeleton: Skeleton3D, authored: Array[Transform3D], delta: float) -> Array[Transform3D]:
	if not enabled or not grounded or _idle.size() != 2:
		reset()
		return authored
	var moving := speed > _leg_length * 0.035
	if not _initialized:
		for i in 2:
			feet[i] = skeleton.global_transform * authored[i]
			anchors[i] = _on_ground(feet[i], i, true)
			feet[i] = anchors[i]
			_swing_from[i] = feet[i]
		_initialized = true
	for i in 2:
		_follow_support(i)
	if moving:
		_settling = -1
		for i in 2:
			var cycle := fposmod(phase - _contact_phase[i], 1.0)
			if cycle < _last_cycle[i]:
				_early_swing[i] = false
			_last_cycle[i] = cycle
			# An abrupt start/reversal may reach the stance limit before the usual
			# toe-off. Start a continuous swing here; never drag a locked ankle.
			var separation := feet[i].origin - _body.global_position
			separation.y = 0.0
			if _was_stance[i] and separation.length() > _leg_length * 0.66:
				_early_swing[i] = true
			var stance := cycle < 0.52 and not _early_swing[i]
			if stance:
				if not _was_stance[i] or not _contact_valid[i]:
					anchors[i] = _on_ground(feet[i], i, true)
				feet[i] = anchors[i] if _contact_valid[i] else skeleton.global_transform * authored[i]
			else:
				if _was_stance[i] or not _was_moving:
					_swing_from[i] = feet[i]
					_swing_start_cycle[i] = cycle
				var progress := clampf((cycle - _swing_start_cycle[i]) / maxf(1.0 - _swing_start_cycle[i], 0.01), 0.0, 1.0)
				var target := _on_ground(skeleton.global_transform * _front[i], i)
				feet[i] = _swing_from[i].interpolate_with(target, smoothstep(0.0, 1.0, progress))
				feet[i].origin.y += sin(progress * PI) * _leg_length * 0.15
			planted[i] = stance and _contact_valid[i]
			_was_stance[i] = stance
	else:
		# Complete the swing, then recover the trailing foot. Also supplies small
		# alternating pivot steps when turning in place, instead of twisting soles.
		var desired: Array[Transform3D] = []
		for i in 2:
			desired.append(_on_ground(skeleton.global_transform * _idle[i], i))
		if _was_moving:
			for i in 2:
				if not planted[i]:
					_settling = i
					_swing_from[i] = feet[i]
					_settle_time = 0.0
		if _settling < 0:
			var worst := 0.0
			for i in 2:
				var error := feet[i].origin.distance_to(desired[i].origin) / _leg_length
				error += feet[i].basis.orthonormalized().get_rotation_quaternion().angle_to(desired[i].basis.orthonormalized().get_rotation_quaternion()) * 0.16
				if error > maxf(worst, 0.045):
					worst = error
					_settling = i
			if _settling >= 0:
				_swing_from[_settling] = feet[_settling]
				_settle_time = 0.0
		for i in 2:
			planted[i] = i != _settling and _contact_valid[i]
			_was_stance[i] = false
			_early_swing[i] = false
			if i != _settling:
				feet[i] = anchors[i]
		if _settling >= 0:
			var i := _settling
			_settle_time += delta
			var progress := clampf(_settle_time / _settle_duration, 0.0, 1.0)
			feet[i] = _swing_from[i].interpolate_with(desired[i], smoothstep(0.0, 1.0, progress))
			feet[i].origin.y += sin(progress * PI) * _leg_length * 0.085
			if progress >= 1.0:
				anchors[i] = _on_ground(feet[i], i, true)
				feet[i] = anchors[i]
				planted[i] = _contact_valid[i]
				_settling = -1
	_was_moving = moving
	var support_center := Vector3.ZERO
	var count := 0.0
	for i in 2:
		if planted[i]:
			support_center += feet[i].origin
			count += 1.0
	var shift := Vector3.ZERO
	if count > 0.0 and moving:
		shift = support_center / count - _body.global_position
		shift.y = 0.0
		shift = shift.limit_length(_leg_length * 0.045)
	weight_shift = weight_shift.lerp(shift, 1.0 - exp(-16.0 * delta))
	var result: Array[Transform3D] = []
	for foot in feet:
		result.append(skeleton.global_transform.affine_inverse() * foot)
	return result


func _on_ground(pose: Transform3D, index: int, bind_contact: bool = false) -> Transform3D:
	# No contact across a ledge: leave the proposed animation target in place.
	var query := PhysicsRayQueryParameters3D.create(pose.origin + Vector3.UP * _leg_length * 0.6, pose.origin - Vector3.UP * _leg_length * 0.65, _body.collision_mask, [_body.get_rid()])
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y >= cos(_body.floor_max_angle):
		pose.origin.y = hit.position.y + _clearance[index]
		if bind_contact:
			_contact_valid[index] = true
			_support[index] = hit.collider as Node3D
			if _support[index] != null:
				_last_support[index] = _support[index].global_transform
	elif bind_contact:
		_contact_valid[index] = false
		_support[index] = null
	return pose


func _follow_support(index: int) -> void:
	if is_instance_valid(_support[index]):
		var transform := _support[index].global_transform
		var change := transform * _last_support[index].affine_inverse()
		anchors[index] = change * anchors[index]
		feet[index] = change * feet[index]
		_swing_from[index] = change * _swing_from[index]
		_last_support[index] = transform


func _sample(skeleton: Skeleton3D, animation: Animation, time: float) -> void:
	# Imported clips can omit immutable tracks. Never carry idle offsets into walk.
	skeleton.reset_bone_poses()
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if path.get_subname_count() != 1:
			continue
		var bone := skeleton.find_bone(path.get_subname(0))
		if bone < 0:
			continue
		match animation.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, animation.position_track_interpolate(track, time))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track, time))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, animation.scale_track_interpolate(track, time))
