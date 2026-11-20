extends "res://scripts/rook_procedural_pose.gd"

const SHOULDER_TURN_DELAY := 0.025
const HIP_TURN_DELAY := 0.065

var turn_load := 0.0
var _look_yaw := 0.0
var _shoulder_yaw := 0.0
var _turn_target := 0.0
var _turn_elapsed := HIP_TURN_DELAY

var wing_spread := 0.0
var _left_wing := -1
var _right_wing := -1


func _ready() -> void:
	super()
	_left_wing = get_skeleton().find_bone("Wing.L")
	_right_wing = get_skeleton().find_bone("Wing.R")


func advance_heading(current: float, target: float, opposing_speed: float, grounded: bool, braced: bool, delta: float) -> float:
	# A change of intent starts with the gaze. The torso winds up before the
	# pelvis turns over the support leg, even when reversing from a sprint.
	if absf(angle_difference(_turn_target, target)) > deg_to_rad(35.0):
		_turn_elapsed = 0.0
		_turn_target = target
	var error := angle_difference(current, target)
	var step := 0.0
	if not braced and (not grounded or _turn_elapsed >= HIP_TURN_DELAY):
		step = pivot_step(error, opposing_speed, delta)
	var remaining := error - step
	_look_yaw = lerpf(_look_yaw, clampf(remaining, -0.68, 0.68), 1.0 - exp(-30.0 * delta))
	if _turn_elapsed >= SHOULDER_TURN_DELAY or not grounded:
		_shoulder_yaw = lerpf(_shoulder_yaw, clampf(remaining * 0.50, -0.34, 0.34), 1.0 - exp(-20.0 * delta))
	turn_chest_offset = _shoulder_yaw
	# Head already inherits the spine rotation.
	turn_head_offset = _look_yaw - _shoulder_yaw
	_turn_elapsed += delta
	var load := smoothstep(0.12, 1.1, absf(error)) * 0.10 if grounded and not braced else 0.0
	turn_load = lerpf(turn_load, load, 1.0 - exp(-20.0 * delta))
	return step


func _process_modification_with_delta(delta: float) -> void:
	super(delta)
	if wing_spread <= 0.0:
		return
	var rig := get_skeleton()
	var axis := (rig.global_basis * Vector3.FORWARD).normalized()
	_rotate_world(rig, _left_wing, axis, wing_spread)
	_rotate_world(rig, _right_wing, axis, -wing_spread)
