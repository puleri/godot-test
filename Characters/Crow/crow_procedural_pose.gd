extends "res://scripts/rook_procedural_pose.gd"

var wing_spread := 0.0
var _left_wing := -1
var _right_wing := -1


func _ready() -> void:
	super()
	_left_wing = get_skeleton().find_bone("Wing.L")
	_right_wing = get_skeleton().find_bone("Wing.R")


func _process_modification_with_delta(delta: float) -> void:
	super(delta)
	if wing_spread <= 0.0:
		return
	var rig := get_skeleton()
	var axis := (rig.global_basis * Vector3.FORWARD).normalized()
	_rotate_world(rig, _left_wing, axis, wing_spread)
	_rotate_world(rig, _right_wing, axis, -wing_spread)
