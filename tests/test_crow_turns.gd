extends SceneTree
## Exercise the playable controller and inspect the final IK pose after each turn.

const COURSE = preload("res://Characters/Crow/CrowLocomotionTest.tscn")

var _player: CharacterBody3D
var _rig: Skeleton3D
var _legs: Array[Vector3i] = []
var _minimum_side := INF
var _minimum_bend := INF
var _maximum_twist := 0.0
var _maximum_plant_error := 0.0
var _support_samples := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var course := COURSE.instantiate()
	root.add_child(course)
	_player = course.get_node("CrowPlayer")
	_player.position = Vector3(6, 0, 6)
	_rig = _player.find_children("*", "Skeleton3D")[0]
	for side in ["L", "R"]:
		_legs.append(Vector3i(_rig.find_bone("Thigh." + side), _rig.find_bone("Shin." + side), _rig.find_bone("Foot." + side)))
	_rig.skeleton_updated.connect(_sample)
	for tick in 40:
		await physics_frame
	# Vary the point in the stride where the player snaps the stick across.
	var actions := ["move_down", "move_up", "move_down", "move_left", "move_right", "move_left", "move_right"]
	var durations := [82, 93, 75, 64, 8, 19, 101]
	for index in actions.size():
		Input.action_press(actions[index])
		for tick in durations[index]:
			await physics_frame
		Input.action_release(actions[index])
	print("Crow turns: %d support samples, lateral clearance %.3f m, rear hock bend %.3f m, foot twist %.1f degrees, plant error %.4f m" % [
		_support_samples, _minimum_side, _minimum_bend, _maximum_twist, _maximum_plant_error])
	quit(0 if _support_samples > 300 and _minimum_side > 0.0 and _minimum_bend > 0.01 and _maximum_twist < 55.0 and _maximum_plant_error < 0.003 else 1)


func _sample() -> void:
	if not _player.is_on_floor():
		return
	var placement = _rig.get_node("CrowProceduralPose").foot_placement
	for i in _legs.size():
		var chain := _legs[i]
		var hip := _rig.get_bone_global_pose(chain.x).origin
		var knee := _rig.get_bone_global_pose(chain.y).origin
		var ankle := _rig.get_bone_global_pose(chain.z)
		_minimum_side = minf(_minimum_side, ankle.origin.x * (-1.0 if i == 0 else 1.0))
		var bend := (knee - hip).slide((ankle.origin - hip).normalized())
		_minimum_bend = minf(_minimum_bend, bend.z)
		var toe := ankle.basis.y
		var rest := _rig.get_bone_global_rest(chain.z).basis.y
		var twist := angle_difference(atan2(rest.x, rest.z), atan2(toe.x, toe.z))
		_maximum_twist = maxf(_maximum_twist, absf(rad_to_deg(twist)))
		if placement.planted[i]:
			_support_samples += 1
			var actual := _rig.global_transform * ankle.origin
			_maximum_plant_error = maxf(_maximum_plant_error, actual.distance_to(placement.anchors[i].origin))
