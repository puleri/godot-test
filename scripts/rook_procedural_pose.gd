extends SkeletonModifier3D
## Additive Rook pose, evaluated after the authored AnimationTree pose.
## Bone names describe the imported Rook rig; no imported resources are changed.

const FootPlacement = preload("res://scripts/rook_foot_placement.gd")

var foot_placement := FootPlacement.new()
var foot_planting_enabled := true
var cape_motion_enabled := true
var cape_strength := 1.0
var turn_head_offset := 0.0
var turn_pelvis_offset := 0.0
var turn_chest_offset := 0.0
var head_yaw := 0.0
var pelvis_yaw := 0.0
var legs_yaw := 0.0
var _turn_initialized := false
var _previous_chest_yaw := 0.0
var _turn_speed := 0.0
var _head := -1
var _cape: Array[int] = []
var cape_angles: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _cape_velocity: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _grounded := false
var _speed := 0.0
var _body_shift := Vector3.ZERO
var _contact_drop := 0.0
var max_lean_degrees := 7.0
var lean_response := 20.0
var landing_response := 26.0
var landing_compression := 0.12
var full_landing_speed := 10.0

var world_lean := Vector3.ZERO
var compression := 0.0
var _lean_velocity := Vector3.ZERO
var _compression_velocity := 0.0
var _previous_velocity := Vector3.ZERO
var _motion_initialized := false
var _spine := -1
var _hips := -1
var _legs: Array[Vector3i] = []
var _leg_length := 0.0


func _ready() -> void:
	var skeleton := get_skeleton()
	_spine = skeleton.find_bone("Spine")
	_hips = skeleton.find_bone("Bone.027")
	_head = skeleton.find_bone("Head")
	for name in ["Cape_1", "Cape_2", "CapeEnd"]:
		var bone := skeleton.find_bone(name)
		if bone >= 0:
			_cape.append(bone)
	for names in [["Bone.030", "Bone.032", "Bone.034"], ["Bone.031", "Bone.033", "Bone.035"]]:
		var chain := Vector3i(skeleton.find_bone(names[0]), skeleton.find_bone(names[1]), skeleton.find_bone(names[2]))
		if chain.x >= 0 and chain.y >= 0 and chain.z >= 0:
			_legs.append(chain)
	if not _legs.is_empty():
		var chain := _legs[0]
		_leg_length = skeleton.get_bone_global_rest(chain.x).origin.distance_to(skeleton.get_bone_global_rest(chain.y).origin)
		_leg_length += skeleton.get_bone_global_rest(chain.y).origin.distance_to(skeleton.get_bone_global_rest(chain.z).origin)
	if _spine < 0 or _hips < 0 or _legs.size() != 2:
		push_warning("Rook procedural pose needs the Spine, hip and two leg chains; unsupported bones will be left alone.")


func configure_locomotion(player: CharacterBody3D, animation_player: AnimationPlayer, idle: String, walk: String) -> void:
	if _legs.size() == 2 and not idle.is_empty() and not walk.is_empty():
		foot_placement.configure(get_skeleton(), _legs, player, animation_player.get_animation(idle), animation_player.get_animation(walk))


func reset_motion() -> void:
	foot_placement.reset()
	_turn_initialized = false
	turn_head_offset = 0.0
	turn_pelvis_offset = 0.0
	turn_chest_offset = 0.0
	_turn_speed = 0.0
	_grounded = false
	_body_shift = Vector3.ZERO
	_contact_drop = 0.0
	for i in 3:
		cape_angles[i] = Vector3.ZERO
		_cape_velocity[i] = Vector3.ZERO
	world_lean = Vector3.ZERO
	_lean_velocity = Vector3.ZERO
	compression = 0.0
	_compression_velocity = 0.0
	_previous_velocity = Vector3.ZERO
	_motion_initialized = false


func update_turn(delta: float, target: float, current: float, response: float) -> float:
	if not _turn_initialized:
		head_yaw = current
		pelvis_yaw = current
		legs_yaw = current
		_previous_chest_yaw = current
		_turn_initialized = true
	# Each follower chases the preceding part, rather than the requested heading.
	# Use one unwrapped heading so reversals consistently take the same arc.
	var desired := head_yaw + angle_difference(head_yaw, target)
	head_yaw = lerpf(head_yaw, desired, 1.0 - exp(-delta / maxf(response * 0.45, 0.005)))
	pelvis_yaw = lerpf(pelvis_yaw, head_yaw, 1.0 - exp(-delta / maxf(response * 1.1, 0.005)))
	legs_yaw = lerpf(legs_yaw, pelvis_yaw, 1.0 - exp(-delta / maxf(response * 1.7, 0.005)))
	turn_pelvis_offset = clampf(pelvis_yaw - legs_yaw, -deg_to_rad(32), deg_to_rad(32))
	turn_chest_offset = turn_pelvis_offset + clampf(head_yaw - pelvis_yaw, -deg_to_rad(20), deg_to_rad(20)) * 0.35
	turn_head_offset = clampf(head_yaw - legs_yaw - turn_chest_offset, -deg_to_rad(55), deg_to_rad(55))
	var chest_yaw := legs_yaw + turn_chest_offset
	_turn_speed = (chest_yaw - _previous_chest_yaw) / maxf(delta, 0.0001)
	_previous_chest_yaw = chest_yaw
	return legs_yaw


func update_motion(delta: float, resolved_velocity: Vector3, grounded: bool, impact_speed: float, max_speed: float, acceleration: float) -> void:
	if delta <= 0.0:
		return
	var planar_velocity := Vector3(resolved_velocity.x, 0.0, resolved_velocity.z)
	var planar_acceleration := Vector3.ZERO
	if _motion_initialized:
		planar_acceleration = (planar_velocity - _previous_velocity) / delta
	_previous_velocity = planar_velocity
	_motion_initialized = true
	_grounded = grounded
	_speed = planar_velocity.length()
	var target := Vector3.ZERO
	if grounded:
		# A little forward intent at speed, with most of the weight in starts/stops.
		target = planar_acceleration / maxf(acceleration, 0.01)
		target += planar_velocity / maxf(max_speed, 0.01) * 0.18
		target = target.limit_length() * deg_to_rad(max_lean_degrees)
	# Exact critically damped springs remain stable at different frame rates.
	var omega := maxf(lean_response, 0.01)
	var offset := world_lean - target
	var impulse := _lean_velocity + offset * omega
	var decay := exp(-omega * delta)
	world_lean = target + (offset + impulse * delta) * decay
	_lean_velocity = (_lean_velocity - impulse * omega * delta) * decay

	omega = maxf(landing_response, 0.01)
	if impact_speed > 0.0:
		var strength := clampf(impact_speed / maxf(full_landing_speed, 0.01), 0.0, 1.0)
		# This impulse peaks at 'strength' after 1 / omega seconds.
		_compression_velocity += strength * exp(1.0) * omega
	var landing_impulse := _compression_velocity + omega * compression
	decay = exp(-omega * delta)
	compression = clampf((compression + landing_impulse * delta) * decay, 0.0, 1.0)
	_compression_velocity = (_compression_velocity - omega * landing_impulse * delta) * decay
	if not grounded:
		compression = 0.0
		_compression_velocity = 0.0

	if cape_motion_enabled:
		var drag := (-planar_acceleration / maxf(acceleration, 0.01)).limit_length() * 0.22
		drag -= planar_velocity / maxf(max_speed, 0.01) * 0.12
		var cape_target := drag.cross(Vector3.UP) + Vector3.UP * clampf(-_turn_speed * 0.025, -0.16, 0.16)
		if impact_speed > 0.0 and get_skeleton() != null:
			var forward := (get_skeleton().get_parent() as Node3D).global_basis.x.normalized()
			cape_target += forward.cross(Vector3.UP) * minf(impact_speed / full_landing_speed, 1.0) * 0.15
		for i in 3:
			var follow := cape_target if i == 0 else cape_angles[i - 1] * 0.85
			var omega_cape := 14.0 - i * 2.5
			# Analytic underdamped spring: one restrained overshoot, stable at 30–120 Hz.
			var damping := 0.72
			var frequency := omega_cape * sqrt(1.0 - damping * damping)
			var offset_cape := cape_angles[i] - follow
			var sine_term := (_cape_velocity[i] + offset_cape * damping * omega_cape) / frequency
			var envelope := exp(-damping * omega_cape * delta)
			var wave := offset_cape * cos(frequency * delta) + sine_term * sin(frequency * delta)
			cape_angles[i] = follow + wave * envelope
			_cape_velocity[i] = (sine_term * frequency * cos(frequency * delta) - offset_cape * frequency * sin(frequency * delta) - wave * damping * omega_cape) * envelope
			cape_angles[i] = cape_angles[i].limit_length(deg_to_rad(16))
	else:
		for i in 3:
			cape_angles[i] = Vector3.ZERO
			_cape_velocity[i] = Vector3.ZERO


func _rotate_world(skeleton: Skeleton3D, bone: int, world_axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.000001:
		return
	var pose := skeleton.get_bone_global_pose(bone)
	var axis := (skeleton.global_basis.inverse() * world_axis).normalized()
	pose.basis = Basis(axis, angle) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _spine < 0 or _hips < 0 or _legs.size() != 2:
		return
	# Capture contacts before the independent upper-body and pelvis rotations.
	var feet: Array[Transform3D] = []
	for chain in _legs:
		feet.append(skeleton.get_bone_global_pose(chain.z))
	foot_placement.enabled = foot_planting_enabled
	foot_placement.grounded = _grounded
	foot_placement.speed = _speed
	feet = foot_placement.solve_targets(skeleton, feet, delta)

	_rotate_world(skeleton, _hips, Vector3.UP, turn_pelvis_offset)
	_rotate_world(skeleton, _spine, Vector3.UP, turn_chest_offset)
	_rotate_world(skeleton, _head, Vector3.UP, turn_head_offset)
	if world_lean.length_squared() > 0.00000001:
		_rotate_world(skeleton, _spine, Vector3.UP.cross(world_lean.normalized()), world_lean.length())
	# The cape shoulder stays attached; delay increases down the three free bones.
	if cape_motion_enabled:
		for i in _cape.size():
			var rotation_vector := cape_angles[i] * cape_strength
			if rotation_vector.length_squared() > 0.00000001:
				_rotate_world(skeleton, _cape[i], rotation_vector.normalized(), rotation_vector.length())

	var inverse := skeleton.global_basis.inverse()
	var displacement := (inverse * Vector3.DOWN).normalized() * _leg_length * landing_compression * compression
	if _grounded and foot_planting_enabled:
		var desired_shift := foot_placement.weight_shift
		# Small inertial translation as well as lean, with a soft supporting knee.
		var world_leg_length := (skeleton.global_basis * Vector3.ONE.normalized() * _leg_length).length()
		desired_shift -= world_lean * world_leg_length * 0.18
		_body_shift = _body_shift.lerp(desired_shift, 1.0 - exp(-18.0 * delta))
		displacement += inverse * (_body_shift + Vector3.DOWN * world_leg_length * 0.035 * clampf(_speed / world_leg_length, 0.0, 1.0))
	# Lower the pelvis just enough for the support ankle to remain reachable.
	var correction := 0.0
	for i in _legs.size():
		if not foot_placement.planted[i]:
			continue
		var chain := _legs[i]
		var hip := skeleton.get_bone_global_pose(chain.x).origin + displacement
		var upper := hip.distance_to(skeleton.get_bone_global_pose(chain.y).origin + displacement)
		var lower := skeleton.get_bone_global_pose(chain.y).origin.distance_to(skeleton.get_bone_global_pose(chain.z).origin)
		var down := (inverse * Vector3.DOWN).normalized()
		var difference := feet[i].origin - hip
		var vertical := difference.dot(down)
		var horizontal_squared := maxf(difference.length_squared() - vertical * vertical, 0.0)
		var reach := (upper + lower) * 0.985
		correction = maxf(correction, vertical - sqrt(maxf(reach * reach - horizontal_squared, 0.0)))
	_contact_drop = maxf(correction, lerpf(_contact_drop, correction, 1.0 - exp(-18.0 * delta)))
	_contact_drop = minf(_contact_drop, _leg_length * 0.28)
	displacement += (inverse * Vector3.DOWN).normalized() * _contact_drop
	for bone in [_spine, _hips]:
		var pose := skeleton.get_bone_global_pose(bone)
		pose.origin += displacement
		skeleton.set_bone_global_pose(bone, pose)
	for i in _legs.size():
		# Follow the pelvis with the knee plane, while the sole keeps its contact.
		var knee := skeleton.get_bone_global_pose(_legs[i].y).origin
		_solve_leg(skeleton, _legs[i], feet[i], knee)


func _solve_leg(skeleton: Skeleton3D, chain: Vector3i, foot: Transform3D, previous_knee: Vector3) -> void:
	var hip := skeleton.get_bone_global_pose(chain.x).origin
	var knee := skeleton.get_bone_global_pose(chain.y).origin
	var ankle := skeleton.get_bone_global_pose(chain.z).origin
	var upper := hip.distance_to(knee)
	var lower := knee.distance_to(ankle)
	var to_foot := foot.origin - hip
	if upper <= 0.0 or lower <= 0.0 or to_foot.length_squared() < 1e-14:
		return
	var direction := to_foot.normalized()
	var distance := clampf(to_foot.length(), absf(upper - lower) + 1e-8, upper + lower - 1e-8)
	# Preserve the clip's knee plane; fall back to Rook's +X forward if straight.
	var bend := previous_knee - hip
	bend -= direction * bend.dot(direction)
	if bend.length_squared() < 1e-12:
		var model := skeleton.get_parent() as Node3D
		bend = skeleton.global_basis.inverse() * model.global_basis.x.normalized()
		bend -= direction * bend.dot(direction)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	var target_knee := hip + direction * along + bend.normalized() * height
	_rotate_bone_to(skeleton, chain.x, chain.y, target_knee)
	_rotate_bone_to(skeleton, chain.y, chain.z, foot.origin)
	# Preserve ankle orientation after the parents have rotated.
	var ankle_pose := skeleton.get_bone_global_pose(chain.z)
	ankle_pose.basis = foot.basis
	skeleton.set_bone_global_pose(chain.z, ankle_pose)


func _rotate_bone_to(skeleton: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var current := skeleton.get_bone_global_pose(child).origin - pose.origin
	var desired := target - pose.origin
	if current.length_squared() < 1e-14 or desired.length_squared() < 1e-14:
		return
	pose.basis = Basis(Quaternion(current.normalized(), desired.normalized())) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)
