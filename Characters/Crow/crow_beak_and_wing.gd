extends SkeletonModifier3D
## Per-character performance layered after locomotion. Positions are world space.
signal contacts_updated(bill: Vector3, wing: Vector3)

var speech_openness := 0.0
var working := false
var brace_target := Vector3.ZERO
var sweep := 0.0
var _head: int
var _jaw: int
var _grip: int
var _shoulder: int
var _wrist: int
var _tip: int

func _ready() -> void:
	var rig := get_skeleton()
	_head = rig.find_bone("Head_2")
	_jaw = rig.find_bone("LowerBeak")
	_grip = rig.find_bone("PickGrip")
	_shoulder = rig.find_bone("Wing.R")
	_wrist = rig.find_bone("WingWrist.R")
	_tip = rig.find_bone("WingContact.R")

func _process_modification_with_delta(_delta: float) -> void:
	var rig := get_skeleton()
	var opening := 0.22 if working else clampf(speech_openness, 0, 1)
	if opening > 0:
		_rotate(rig, _jaw, Quaternion(Vector3.RIGHT, deg_to_rad(-25 * opening)))
	if not working:
		return
	_rotate(rig, _head, Quaternion(Vector3.RIGHT, deg_to_rad(14 + sweep * 8)))
	var root := rig.get_bone_global_pose(_shoulder).origin
	var elbow := rig.get_bone_global_pose(_wrist).origin
	var tip := rig.get_bone_global_pose(_tip).origin
	var upper := root.distance_to(elbow)
	var outer := elbow.distance_to(tip)
	var reach := rig.to_local(brace_target) - root
	var axis := reach.normalized()
	var span := clampf(reach.length(), absf(upper - outer) + 0.001, upper + outer - 0.001)
	var along := (upper * upper - outer * outer + span * span) / (2 * span)
	# Keep the elbow on the outside of the coat as the primaries meet the pad.
	var bend := Vector3.RIGHT.slide(axis).normalized()
	var joint := root + along * axis + sqrt(maxf(0, upper * upper - along * along)) * bend
	_rotate(rig, _shoulder, Quaternion((elbow-root).normalized(), (joint-root).normalized()))
	elbow = rig.get_bone_global_pose(_wrist).origin
	tip = rig.get_bone_global_pose(_tip).origin
	_rotate(rig, _wrist, Quaternion((tip-elbow).normalized(), (root+axis*span-elbow).normalized()))
	contacts_updated.emit(rig.to_global(rig.get_bone_global_pose(_grip).origin),
		rig.to_global(rig.get_bone_global_pose(_tip).origin))

func _rotate(rig: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(rotation) * pose.basis
	rig.set_bone_global_pose(bone, pose)
