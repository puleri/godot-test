extends CharacterBody3D

const ControllerInput = preload("res://scripts/controller_input.gd")
const ProceduralPose = preload("res://scripts/rook_procedural_pose.gd")
const OutfitMotion = preload("res://Characters/Crow/crow_outfit_motion.gd")

const WALK_SPEED := 1.35
const ACCELERATION := 5.8
const BRAKING := 7.5
const PIVOT_RADIUS := 0.47
const JUMP_SPEED := 3.6
const JUMP_SQUAT_TIME := 0.10
const LANDING_BRACE_TIME := 0.09
const LANDING_BRACE_SPEED := 2.0
const STEP_HEIGHT := 0.16
const STEP_PROBE_DISTANCE := 0.085

@onready var visual: Node3D = $Crow
@onready var animation: AnimationPlayer = $AnimationPlayer

var _pose: ProceduralPose
var _facing := 0.0
var _jump_squat_elapsed := -1.0
var _landing_brace_remaining := 0.0


func _ready() -> void:
	var skeleton: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	_pose = ProceduralPose.new()
	_pose.name = "CrowProceduralPose"
	_pose.pelvis_bone = "Pelvis"
	_pose.head_bone = "Head_2"
	_pose.leg_bones = [
		PackedStringArray(["Thigh.L", "Shin.L", "Foot.L"]),
		PackedStringArray(["Thigh.R", "Shin.R", "Foot.R"]),
	]
	_pose.use_rest_knee_plane = true
	_pose.model_forward = Vector3.FORWARD
	_pose.foot_placement.toe_probe_distance = 0.14
	_pose.cape_motion_enabled = false
	_pose.full_landing_speed = 5.0
	_pose.landing_compression = 0.30
	_pose.landing_response = 18.0
	skeleton.add_child(_pose)
	_pose.configure_locomotion(self, animation, "Idle", "Walk")
	var outfit := OutfitMotion.new()
	outfit.name = "CrowOutfitMotion"
	outfit.satchel_stiffness = 5.0
	outfit.satchel_drag = 0.50
	outfit.influence = 0.72
	skeleton.add_child(outfit)
	animation.play(&"Idle")
	animation.advance(0.0)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var camera := get_viewport().get_camera_3d()
	var camera_basis := camera.global_basis if camera != null else Basis.IDENTITY
	var direction := ControllerInput.camera_relative_direction(input, camera_basis)
	var jumped := _update_jump_squat(delta)
	_move(direction, jumped, delta)


func _update_jump_squat(delta: float) -> bool:
	if not is_on_floor():
		_jump_squat_elapsed = -1.0
		return false
	if _jump_squat_elapsed < 0.0 and Input.is_action_just_pressed("jump"):
		_jump_squat_elapsed = 0.0
	if _jump_squat_elapsed < 0.0:
		return false
	if is_equal_approx(_jump_squat_elapsed, JUMP_SQUAT_TIME):
		_jump_squat_elapsed = -1.0
		return true
	_jump_squat_elapsed = minf(_jump_squat_elapsed + delta, JUMP_SQUAT_TIME)
	return false


func _move(direction: Vector3, jumped: bool, delta: float) -> void:
	var was_grounded := is_on_floor()
	var start := global_transform
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var preparing := _jump_squat_elapsed >= 0.0
	var braced := was_grounded and not jumped and (preparing or _landing_brace_remaining > 0.0)
	# Load both legs before jumping and briefly absorb the landing.
	var yaw_step := 0.0
	if direction.length_squared() > 0.001:
		_facing = atan2(-direction.x, -direction.z)
	var yaw_error := angle_difference(visual.rotation.y, _facing)
	if not braced:
		# A loaded leg first brakes the old stride before the hips can swing around.
		var opposing_speed := maxf(-planar.dot(direction), 0.0) / WALK_SPEED
		yaw_step = ProceduralPose.pivot_step(yaw_error, opposing_speed, delta)
		visual.rotation.y += yaw_step
	var follow := 1.0 - exp(-12.0 * delta)
	_pose.turn_head_offset = lerpf(_pose.turn_head_offset, clampf(yaw_error * 0.42, -0.48, 0.48), follow)
	_pose.turn_chest_offset = lerpf(_pose.turn_chest_offset, clampf(yaw_error * 0.16, -0.17, 0.17), follow)
	# Shed momentum on the old heading before pushing off toward the new one.
	var alignment := smoothstep(0.25, 0.94, cos(yaw_error - yaw_step)) if was_grounded else 1.0
	var desired := direction * WALK_SPEED * alignment
	var rate := BRAKING if planar.dot(desired - planar) < 0.0 else ACCELERATION
	planar = Vector3.ZERO if braced else planar.move_toward(desired, rate * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	velocity += get_gravity() * delta
	if jumped:
		velocity.y = JUMP_SPEED
	var falling_speed := maxf(-velocity.y, 0.0)
	move_and_slide()
	if was_grounded and not jumped and is_on_wall():
		_try_step(start, planar * delta)
	var grounded := is_on_floor()
	var impact := falling_speed if grounded and not was_grounded else 0.0
	_landing_brace_remaining = maxf(_landing_brace_remaining - delta, 0.0)
	if impact >= LANDING_BRACE_SPEED:
		_landing_brace_remaining = LANDING_BRACE_TIME
	if not grounded:
		_jump_squat_elapsed = -1.0
		_landing_brace_remaining = 0.0
	var travel := (global_position - start.origin) / delta
	var speed := minf(Vector2(travel.x, travel.z).length(), WALK_SPEED)
	# A pivot consumes steps even when the capsule hardly translates.
	var yaw_rate := yaw_step / delta if grounded else 0.0
	var gait_speed := _pose.foot_placement.pivot_gait_speed(speed, yaw_rate, PIVOT_RADIUS)
	var walking := grounded and gait_speed > 0.045
	var clip := &"Walk" if walking else &"Idle"
	if not grounded:
		clip = &"Airborne"
	if animation.assigned_animation != clip:
		animation.play(clip, 0.09 if not grounded else 0.14)
	var cycles_per_second := gait_speed / _pose.foot_placement.stride_length
	animation.speed_scale = cycles_per_second * animation.get_animation(&"Walk").length if walking else 1.0
	animation.advance(delta)
	if walking:
		_pose.foot_placement.phase = animation.current_animation_position / animation.current_animation_length
	var turn_load := 0.055 * clampf(absf(yaw_rate) / ProceduralPose.TURN_RATE, 0.0, 1.0)
	_pose.takeoff_squat = maxf(turn_load if grounded else 0.0, 0.19 * smoothstep(0.0, JUMP_SQUAT_TIME, _jump_squat_elapsed))
	_pose.foot_placement.hold_contacts = grounded and (braced or _landing_brace_remaining > 0.0)
	_pose.update_motion(delta, travel, grounded, impact, WALK_SPEED, ACCELERATION)


func _try_step(start: Transform3D, motion: Vector3) -> void:
	# Sweep up, across, and down so the capsule cannot cross walls or ceilings.
	if motion.length_squared() < 0.000001:
		return
	var rise := Vector3.UP * STEP_HEIGHT
	if test_move(start, rise, null, safe_margin):
		return
	var raised := start.translated(rise)
	# Probe past the rounded capsule's first, wall-like contact with the lip.
	motion += motion.normalized() * STEP_PROBE_DISTANCE
	if test_move(raised, motion, null, safe_margin):
		return
	var above_step := raised.translated(motion)
	var contact := KinematicCollision3D.new()
	if not test_move(above_step, -rise, contact, safe_margin):
		return
	if contact.get_normal().dot(Vector3.UP) < cos(floor_max_angle):
		return
	var landing := above_step.origin + contact.get_travel()
	if landing.y - start.origin.y <= safe_margin:
		return
	global_position = landing
	apply_floor_snap()
