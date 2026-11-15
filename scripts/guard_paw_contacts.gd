extends RefCounted
## Four-paw contacts for the Hound rig; gait profiles are sampled per instance.

var enabled := true
var stride_length := 1.0
var phase := 0.0
var grounded := false
var speed := 0.0
var weight_shift := Vector3.ZERO
var planted: Array[bool] = [false, false, false, false]
var anchors: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]
var feet: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]
var _idle: Array[Transform3D] = []
var _front: Array[Transform3D] = []
var _contact_phase: Array[float] = [0.25, 0.75, 0.0, 0.5]
var _swing_from: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]
var _was_stance: Array[bool] = [false, false, false, false]
var _early_swing: Array[bool] = [false, false, false, false]
var _last_cycle: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _contact_valid: Array[bool] = [false, false, false, false]
var _swing_start_cycle: Array[float] = [0.52, 0.52, 0.52, 0.52]
var _settling := -1
var _settle_time := 0.0
var _settle_duration := 0.09
var _initialized := false
var _was_moving := false
var _body: CharacterBody3D
var _leg_length := 1.0
var _clearance: Array[float] = [0.04, 0.04, 0.04, 0.04]
var _support: Array[Node3D] = [null, null, null, null]
var _last_support: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]


var _sockets: Array[Vector3] = []
var profiles: Dictionary = {}
var current_gait := ""
var leg_length: float:
	get: return _leg_length


func configure(skeleton: Skeleton3D, legs: Array[Vector3i], body: CharacterBody3D, idle: Animation, gaits: Dictionary) -> void:
	_body = body
	var original: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		original.append(skeleton.get_bone_pose(bone))
	_sample(skeleton, idle, 0.0)
	for i in 4:
		var chain := legs[i]
		_idle.append(skeleton.get_bone_global_pose(chain.z))
		_sockets.append(skeleton.get_bone_global_pose(chain.x).origin)
		var paw := skeleton.get_bone_global_pose(skeleton.get_bone_children(chain.z)[0])
		_clearance[i] = maxf((skeleton.global_basis * (_idle[i].origin - paw.origin)).y, 0.015) + 0.012
	_leg_length = (skeleton.global_basis * (skeleton.get_bone_global_pose(legs[0].x).origin - skeleton.get_bone_global_pose(legs[0].y).origin)).length()
	_leg_length += (skeleton.global_basis * (skeleton.get_bone_global_pose(legs[0].y).origin - skeleton.get_bone_global_pose(legs[0].z).origin)).length()
	var model := skeleton.get_parent() as Node3D
	var forward := (skeleton.global_basis.inverse() * model.global_basis.x).normalized()
	for gait in gaits:
		var clip: Animation = gaits[gait]
		# Hound Walk contains two repeated strides; Run contains one gallop.
		var period := 0.5 if gait == "walk" else 1.0
		var minimum := [INF, INF, INF, INF]
		var maximum := [-INF, -INF, -INF, -INF]
		var phases: Array[float] = [0.0, 0.0, 0.0, 0.0]
		var front: Array[Transform3D] = _idle.duplicate()
		for frame in 96:
			var sample_phase := float(frame) / 96.0
			_sample(skeleton, clip, clip.length * period * sample_phase)
			for i in 4:
				var pose := skeleton.get_bone_global_pose(legs[i].z)
				var along := pose.origin.dot(forward)
				minimum[i] = minf(minimum[i], along)
				if along > maximum[i]:
					maximum[i] = along
					phases[i] = sample_phase
					front[i] = pose
		var travel := 0.0
		for i in 4:
			travel += maximum[i] - minimum[i]
			front[i].basis = _idle[i].basis
		profiles[gait] = {"phases": phases, "front": front, "stride": clampf(travel * 0.5 * (skeleton.global_basis * forward).length(), _leg_length * 1.8, _leg_length * 3.2), "period": period}
	for bone in original.size():
		skeleton.set_bone_pose(bone, original[bone])
	set_gait("walk")


func set_gait(gait: String) -> void:
	if gait == current_gait or not profiles.has(gait):
		return
	current_gait = gait
	_contact_phase = profiles[gait].phases.duplicate()
	_front = profiles[gait].front.duplicate()
	stride_length = profiles[gait].stride
	reset()


func reset() -> void:
	_initialized = false
	_was_moving = false
	_settling = -1
	_settle_time = 0.0
	grounded = false
	weight_shift = Vector3.ZERO
	for i in 4:
		planted[i] = false
		_was_stance[i] = false
		_early_swing[i] = false
		_contact_valid[i] = false
		_support[i] = null


func solve_targets(skeleton: Skeleton3D, authored: Array[Transform3D], delta: float, placement_frames: Array[Transform3D]) -> Array[Transform3D]:
	if not enabled or not grounded or _idle.size() != 4:
		reset()
		return authored
	var moving := speed > _leg_length * 0.035
	if not _initialized:
		for i in 4:
			feet[i] = skeleton.global_transform * authored[i]
			anchors[i] = _on_ground(feet[i], i, true)
			feet[i] = anchors[i]
			_swing_from[i] = feet[i]
		_initialized = true
	for i in 4:
		_follow_support(i)
	if moving:
		_settling = -1
		for i in 4:
			var cycle := fposmod(phase - _contact_phase[i], 1.0)
			if cycle < _last_cycle[i]:
				_early_swing[i] = false
			_last_cycle[i] = cycle
			# An abrupt start/reversal may reach the stance limit before the usual
			# toe-off. Start a continuous swing here; never drag a locked ankle.
			var separation := feet[i].origin - placement_frames[i] * _sockets[i]
			separation.y = 0.0
			if _was_stance[i] and separation.length() > _leg_length * 0.72:
				_early_swing[i] = true
			var stance := cycle < (0.44 if current_gait == "run" else 0.60) and not _early_swing[i]
			if stance:
				if not _was_stance[i] or not _contact_valid[i]:
					anchors[i] = _on_ground(feet[i], i, true)
				feet[i] = anchors[i] if _contact_valid[i] else skeleton.global_transform * authored[i]
			else:
				if _was_stance[i] or not _was_moving:
					_swing_from[i] = feet[i]
					_swing_start_cycle[i] = cycle
				var progress := clampf((cycle - _swing_start_cycle[i]) / maxf(1.0 - _swing_start_cycle[i], 0.01), 0.0, 1.0)
				var target := _on_ground(placement_frames[i] * _front[i], i)
				feet[i] = _swing_from[i].interpolate_with(target, smoothstep(0.0, 1.0, progress))
				feet[i].origin.y += sin(progress * PI) * _leg_length * 0.18
			planted[i] = stance and _contact_valid[i]
			_was_stance[i] = stance
	else:
		# Complete the swing, then recover the trailing foot. Also supplies small
		# alternating pivot steps when turning in place, instead of twisting soles.
		var desired: Array[Transform3D] = []
		for i in 4:
			desired.append(_on_ground(placement_frames[i] * _idle[i], i))
		if _was_moving:
			for i in 4:
				if not planted[i] and _settling < 0:
					_settling = i
					_swing_from[i] = feet[i]
					_swing_from[(i + 2) % 4] = feet[(i + 2) % 4]
					_settle_time = 0.0
		if _settling < 0:
			var worst := 0.0
			for i in 4:
				var error := feet[i].origin.distance_to(desired[i].origin) / _leg_length
				error += feet[i].basis.orthonormalized().get_rotation_quaternion().angle_to(desired[i].basis.orthonormalized().get_rotation_quaternion()) * 0.16
				if error > maxf(worst, 0.045):
					worst = error
					_settling = i
			if _settling >= 0:
				_swing_from[_settling] = feet[_settling]
				_swing_from[(_settling + 2) % 4] = feet[(_settling + 2) % 4]
				_settle_time = 0.0
		for i in 4:
			planted[i] = i != _settling and i != (_settling + 2) % 4 and _contact_valid[i] if _settling >= 0 else _contact_valid[i]
			_was_stance[i] = false
			_early_swing[i] = false
			if _settling < 0 or (i != _settling and i != (_settling + 2) % 4):
				feet[i] = anchors[i]
		if _settling >= 0:
			_settle_time += delta
			var progress := clampf(_settle_time / _settle_duration, 0.0, 1.0)
			for i in [_settling, (_settling + 2) % 4]:
				feet[i] = _swing_from[i].interpolate_with(desired[i], smoothstep(0.0, 1.0, progress))
				feet[i].origin.y += sin(progress * PI) * _leg_length * 0.085
				if progress >= 1.0:
					anchors[i] = _on_ground(feet[i], i, true)
					feet[i] = anchors[i]
					planted[i] = _contact_valid[i]
			if progress >= 1.0:
				_settling = -1

	_was_moving = moving
	var support_center := Vector3.ZERO
	var count := 0.0
	for i in 4:
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
