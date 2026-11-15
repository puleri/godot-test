extends SkeletonModifier3D
## Guard-only motion after the authored pose. No AI, collider or lamp transforms.
const PawContacts = preload("res://scripts/guard_paw_contacts.gd")
var contacts := PawContacts.new()
var body: CharacterBody3D
var profile := ""
var enabled := true
var motion_strength := 1.0
var contact_strength := 1.0
var phase := 0.0
var head_yaw := 0.0
var chest_yaw := 0.0
var pelvis_yaw := 0.0
var legs_yaw := 0.0
var lean := Vector3.ZERO
var accessory := Vector3.ZERO
var _lean_velocity := Vector3.ZERO
var _accessory_velocity := Vector3.ZERO
var _previous_velocity := Vector3.ZERO
var _previous_yaw := 0.0
var _heading := 0.0
var _initialized := false
var _grounded := false
var _speed := 0.0
var _time := 0.0
var _seed_phase := 0.0
var _contact_drop := 0.0
var _weight_shift := Vector3.ZERO
var _base := -1
var _head := -1
var _legs_root := -1
var _rear := -1
var _tail := -1
var _hat := -1
var _baton := -1
var _chains: Array[Vector3i] = []
var _height := 0.5
var _landing := 0.0
var _landing_velocity := 0.0
var _was_grounded := false
var _fall_speed := 0.0
var _stance_yaw := 0.0
var _stationary := true
var _pivoting := false
# Small stationary glances use the neck and chest, rather than shuffling paws.
const STANDING_LOOK_LIMIT := deg_to_rad(75.0)
const STANDING_CHEST_FOLLOW := 0.22


func configure(actor: CharacterBody3D, player: AnimationPlayer, idle: String, walk: String, run: String) -> bool:
	body = actor
	var skeleton := get_skeleton()
	_base = skeleton.find_bone("Base")
	_head = skeleton.find_bone("Head")
	if skeleton.find_bone("Paw-FR") >= 0:
		profile = "hound"
		_legs_root = skeleton.find_bone("Bone.005")
		_rear = skeleton.find_bone("Spine")
		_tail = skeleton.find_bone("TailBase")
		for names in [["Bone.011", "Bone.015", "Bone.019"], ["Bone.012", "Bone.016", "Bone.020"], ["Bone.013", "Bone.017", "Bone.021"], ["Bone.014", "Bone.018", "Bone.022"]]:
			_chains.append(Vector3i(skeleton.find_bone(names[0]), skeleton.find_bone(names[1]), skeleton.find_bone(names[2])))
		contacts.configure(skeleton, _chains, actor, player.get_animation(idle), {"walk": player.get_animation(walk), "run": player.get_animation(run)})
		_height = contacts.leg_length
	elif skeleton.find_bone("Baton") >= 0:
		profile = "mouse"
		_legs_root = skeleton.find_bone("Bone.004")
		_hat = skeleton.find_bone("Hat")
		_baton = skeleton.find_bone("Baton")
	else:
		return false
	_seed_phase = fposmod(float(actor.random_seed if actor.random_seed != 0 else hash(actor.get_path())) * 0.6180339, TAU)
	reset_motion()
	return _base >= 0 and _head >= 0


func reset_motion() -> void:
	contacts.reset()
	_initialized = false
	lean = Vector3.ZERO
	_lean_velocity = Vector3.ZERO
	accessory = Vector3.ZERO
	_accessory_velocity = Vector3.ZERO
	_previous_velocity = Vector3.ZERO
	_contact_drop = 0.0
	_weight_shift = Vector3.ZERO
	_speed = 0.0
	_grounded = false
	_time = 0.0
	_landing = 0.0
	_landing_velocity = 0.0
	_was_grounded = false
	_fall_speed = 0.0
	_stationary = true
	_pivoting = false


func update_motion(delta: float, resolved: Vector3, heading: float, grounded: bool, max_speed: float, acceleration: float, suppressed: bool) -> void:
	if not enabled or suppressed:
		reset_motion()
		return
	var velocity := Vector3(resolved.x, 0, resolved.z)
	if not _initialized:
		head_yaw = heading
		chest_yaw = heading
		pelvis_yaw = heading
		legs_yaw = heading
		_previous_yaw = heading
		_stance_yaw = heading
		_previous_velocity = velocity
		_initialized = true
	var actual_acceleration := (velocity - _previous_velocity) / maxf(delta, 0.0001)
	_previous_velocity = velocity
	_heading = heading
	if grounded and not _was_grounded:
		_landing_velocity += clampf(_fall_speed / 8.0, 0.0, 1.0) * 22.0 * exp(1.0)
	_fall_speed = maxf(_fall_speed, -resolved.y) if not grounded else 0.0
	_was_grounded = grounded
	var landing_impulse := _landing_velocity + 22.0 * _landing
	_landing = (_landing + landing_impulse * delta) * exp(-22.0 * delta)
	_landing_velocity = (_landing_velocity - 22.0 * landing_impulse * delta) * exp(-22.0 * delta)
	if not grounded:
		_landing = 0.0
		_landing_velocity = 0.0
	_grounded = grounded
	_speed = velocity.length()
	_time += delta
	# The head agrees with the gameplay sight cone. The trunk and hindquarters
	# catch up afterward; collision steering and detection never inherit this lag.
	head_yaw += angle_difference(head_yaw, heading)
	if _stationary and _speed > 0.06:
		_stationary = false
	elif not _stationary and _speed < 0.025:
		_stationary = true
		_stance_yaw = legs_yaw
		_pivoting = false
	var chest_target := head_yaw
	if _stationary:
		var glance := angle_difference(_stance_yaw, head_yaw)
		if absf(glance) > STANDING_LOOK_LIMIT:
			_pivoting = true
		if _pivoting and absf(angle_difference(legs_yaw, head_yaw)) < 0.05:
			_pivoting = false
			_stance_yaw = legs_yaw
			glance = angle_difference(_stance_yaw, head_yaw)
		if not _pivoting:
			chest_target = _stance_yaw + glance * STANDING_CHEST_FOLLOW
	chest_yaw = lerpf(chest_yaw, chest_target, 1.0 - exp(-delta / 0.07))
	var hips_target := chest_yaw if not _stationary or _pivoting else _stance_yaw
	pelvis_yaw = lerpf(pelvis_yaw, hips_target, 1.0 - exp(-delta / 0.085))
	var legs_target := pelvis_yaw if not _stationary or _pivoting else _stance_yaw
	legs_yaw = lerpf(legs_yaw, legs_target, 1.0 - exp(-delta / 0.055))
	var turning_speed := angle_difference(_previous_yaw, heading) / maxf(delta, 0.0001)
	_previous_yaw = heading
	var target := (actual_acceleration / maxf(acceleration, 0.1) + velocity / maxf(max_speed, 0.1) * 0.15).limit_length() * deg_to_rad(5.0)
	if not grounded:
		target = Vector3.ZERO
	var omega := 18.0
	var offset := lean - target
	var impulse := _lean_velocity + offset * omega
	var decay := exp(-omega * delta)
	lean = target + (offset + impulse * delta) * decay
	_lean_velocity = (_lean_velocity - impulse * omega * delta) * decay
	var inertia := (-actual_acceleration / maxf(acceleration, 0.1)).limit_length().cross(Vector3.UP) * 0.12
	inertia += Vector3.UP * clampf(-turning_speed * 0.035, -0.18, 0.18)
	# A slower accessory spring gives hats, batons and tails a short recovery.
	omega = 10.0
	offset = accessory - inertia
	impulse = _accessory_velocity + offset * omega
	decay = exp(-omega * delta)
	accessory = (inertia + (offset + impulse * delta) * decay).limit_length(0.24)
	_accessory_velocity = (_accessory_velocity - impulse * omega * delta) * decay


func _rotate(skeleton: Skeleton3D, bone: int, world_axis: Vector3, angle: float) -> void:
	if bone < 0 or absf(angle) < 0.000001:
		return
	var pose := skeleton.get_bone_global_pose(bone)
	pose.basis = Basis((skeleton.global_basis.inverse() * world_axis).normalized(), angle * motion_strength) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)


func _process_modification_with_delta(delta: float) -> void:
	if not enabled or not _initialized or motion_strength <= 0.0:
		return
	var skeleton := get_skeleton()
	var chest_offset := clampf(chest_yaw - head_yaw, -1.1, 1.1)
	var leg_offset := clampf(legs_yaw - head_yaw, -2.5, 2.5)
	_rotate(skeleton, _base, Vector3.UP, chest_offset)
	_rotate(skeleton, _head, Vector3.UP, -chest_offset)
	_rotate(skeleton, _legs_root, Vector3.UP, leg_offset)
	_rotate(skeleton, _rear, Vector3.UP, clampf(pelvis_yaw - legs_yaw, -0.3, 0.3))
	var feet: Array[Transform3D] = []
	for chain in _chains:
		feet.append(skeleton.get_bone_global_pose(chain.z))
	var targets := feet
	if profile == "hound":
		contacts.phase = phase
		contacts.grounded = _grounded and contact_strength > 0.01
		contacts.speed = _speed
		var front_frame := Transform3D(Basis(Vector3.UP, leg_offset * motion_strength) * skeleton.global_basis, skeleton.global_position)
		var rear_frame := Transform3D(Basis(Vector3.UP, (leg_offset + clampf(pelvis_yaw - legs_yaw, -0.3, 0.3)) * motion_strength) * skeleton.global_basis, skeleton.global_position)
		var frames: Array[Transform3D] = [front_frame, front_frame, rear_frame, rear_frame]
		targets = contacts.solve_targets(skeleton, feet, delta, frames)
		for i in targets.size():
			targets[i] = feet[i].interpolate_with(targets[i], contact_strength * minf(motion_strength, 1.0))
	if lean.length_squared() > 0.00000001:
		_rotate(skeleton, _base, Vector3.UP.cross(lean.normalized()), lean.length())
		_rotate(skeleton, _legs_root, Vector3.UP.cross(lean.normalized()), lean.length() * 0.65)
	if accessory.length_squared() > 0.00000001:
		_rotate(skeleton, _tail, accessory.normalized(), accessory.length())
		_rotate(skeleton, _baton, accessory.normalized(), accessory.length())
		_rotate(skeleton, _hat, accessory.normalized(), accessory.length() * 0.65)
	_rotate(skeleton, _hat, Vector3.UP, chest_offset * 0.7)
	# Small independent breathing phases keep a line of idle guards from posing
	# in lockstep. Both body roots share the translation; paws keep their ground.
	var breathe := sin(_time * 1.6 + _seed_phase) * _height * 0.007 * (1.0 - clampf(_speed, 0, 1))
	var world_shift := Vector3.UP * (breathe - _landing * _height * 0.12) - lean * _height * 0.14
	if profile == "hound" and _grounded:
		_weight_shift = _weight_shift.lerp(contacts.weight_shift, 1.0 - exp(-16.0 * delta))
		world_shift += _weight_shift
	var displacement := skeleton.global_basis.inverse() * world_shift
	var required_drop := 0.0
	for i in _chains.size():
		if not contacts.planted[i]:
			continue
		var chain := _chains[i]
		var hip := skeleton.get_bone_global_pose(chain.x).origin + displacement
		var knee := skeleton.get_bone_global_pose(chain.y).origin + displacement
		var ankle := skeleton.get_bone_global_pose(chain.z).origin + displacement
		var reach := (hip.distance_to(knee) + knee.distance_to(ankle)) * 0.985
		var down := (skeleton.global_basis.inverse() * Vector3.DOWN).normalized()
		var difference := targets[i].origin - hip
		var vertical := difference.dot(down)
		required_drop = maxf(required_drop, vertical - sqrt(maxf(reach * reach - maxf(difference.length_squared() - vertical * vertical, 0), 0)))
	_contact_drop = minf(maxf(required_drop, lerpf(_contact_drop, required_drop, 1.0 - exp(-18.0 * delta))), _height / skeleton.global_basis.x.length() * 0.50)
	displacement += (skeleton.global_basis.inverse() * Vector3.DOWN).normalized() * _contact_drop
	for bone in [_base, _legs_root, _hat]:
		if bone >= 0:
			var pose := skeleton.get_bone_global_pose(bone)
			pose.origin += displacement * motion_strength
			skeleton.set_bone_global_pose(bone, pose)
	for i in _chains.size():
		_solve_leg(skeleton, _chains[i], targets[i], skeleton.get_bone_global_pose(_chains[i].y).origin)


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
