extends SceneTree
## Regressions for continuous left/right glances, not just single large turns.
var checks := 0
var failures := 0
var poses: Dictionary = {}
func _initialize() -> void:
	_run.call_deferred()
func _check(condition: bool, message: String) -> void:
	checks += 1
	print("PASS: " if condition else "FAIL: ", message)
	if not condition:
		failures += 1
		push_error(message)
func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
func _capture(skeleton: Skeleton3D, id: int) -> void:
	var pose := {}
	for i in skeleton.get_bone_count():
		pose[skeleton.get_bone_name(i)] = skeleton.global_transform * skeleton.get_bone_global_pose(i)
	poses[id] = pose
func _run() -> void:
	for fps in [30, 60, 120]:
		var modifier = load("res://scripts/guard_procedural_pose.gd").new()
		var dt: float = 1.0 / fps
		modifier.update_motion(dt, Vector3.ZERO, PI - 0.05, true, 2, 8, false)
		var base: float = modifier.legs_yaw
		var worst_foot_turn := 0.0
		var worst_chest_turn := 0.0
		for frame in fps * 6:
			var heading := base + sin(frame * dt * 1.8) * 1.1
			modifier.update_motion(dt, Vector3.ZERO, wrapf(heading, -PI, PI), true, 2, 8, false)
			worst_foot_turn = maxf(worst_foot_turn, absf(modifier.legs_yaw - base))
			worst_chest_turn = maxf(worst_chest_turn, absf(modifier.chest_yaw - base))
		_check(worst_foot_turn < 0.001 and worst_chest_turn < 0.3, "Standing scans keep the lower body planted across heading wrap at %d Hz" % fps)
		modifier.update_motion(dt, Vector3.ZERO, base + PI / 2.0, true, 2, 8, false)
		for frame in fps * 2:
			modifier.update_motion(dt, Vector3.ZERO, base + PI / 2.0, true, 2, 8, false)
		_check(absf(angle_difference(modifier.legs_yaw, base + PI / 2.0)) < 0.05, "A larger stationary turn still completes a full pivot at %d Hz" % fps)
		modifier.free()
	var room = load("res://scenes/GuardMotionTest.tscn").instantiate()
	root.add_child(room)
	for guard in room.guards:
		guard.set_physics_process(false)
		guard._pause_remaining = 100.0
		var modifier = guard.get_node("AnimationDriver").guard_pose
		modifier.modification_processed.connect(_capture.bind(modifier.get_skeleton(), guard.get_instance_id()))
	for frame in 120:
		for guard in room.guards:
			guard._physics_process(1.0 / 60)
		await _frames(1)
	for guard in room.guards:
		guard.guard_state = StealthGuard.GuardState.SEARCH
		guard._search_arrived = true
		guard._search_elapsed = 0.0
		guard._search_yaw = guard._heading_yaw
		guard.search_seconds = 100.0
	var hound = room.guards[0]
	var previous: Dictionary = poses[hound.get_instance_id()].duplicate()
	var worst_dip := 0.0
	var worst_ankle := 0.0
	var worst_knee := 0.0
	var worst_head_step := 0.0
	var head_range := Vector2(INF, -INF)
	var idle_pivots := 0
	for frame in 720:
		for guard in room.guards:
			guard._physics_process(1.0 / 60)
		await _frames(1)
		var current: Dictionary = poses[hound.get_instance_id()]
		worst_dip = maxf(worst_dip, absf(current.Base.origin.y - previous.Base.origin.y))
		worst_head_step = maxf(worst_head_step, _angle(previous.Head.basis, current.Head.basis))
		for name in ["Bone.019", "Bone.020", "Bone.021", "Bone.022"]:
			worst_ankle = maxf(worst_ankle, current[name].origin.distance_to(previous[name].origin))
		for name in ["Bone.015", "Bone.016", "Bone.017", "Bone.018"]:
			worst_knee = maxf(worst_knee, _angle(previous[name].basis, current[name].basis))
		var modifier = hound.get_node("AnimationDriver").guard_pose
		head_range.x = minf(head_range.x, modifier.head_yaw)
		head_range.y = maxf(head_range.y, modifier.head_yaw)
		if frame > 60 and modifier.contacts._settling >= 0:
			idle_pivots += 1
		previous = current.duplicate()
	_check(head_range.y - head_range.x > 2.0 and worst_head_step < 0.05, "Search still looks fully left/right with a continuous head trajectory")
	_check(worst_dip < 0.005, "No scan-induced body drop (largest frame step %.6fm)" % worst_dip)
	_check(worst_ankle < 0.005 and idle_pivots == 0, "Look-around preserves paw contacts instead of repeated recovery steps (%.6fm)" % worst_ankle)
	_check(worst_knee < 0.05, "Knees stay continuous during stationary scanning")
	var mouse = room.guards[1]
	var mouse_pose = mouse.get_node("AnimationDriver").guard_pose
	_check(absf(mouse_pose.pelvis_yaw - mouse_pose._stance_yaw) < 0.001 and absf(mouse_pose.head_yaw - mouse._last_visual_yaw) < 0.001, "Mouse scanning also holds its body stance and agrees with sight")
	room.free()
	await process_frame
	print("GUARD SCAN CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
func _angle(before: Basis, after: Basis) -> float:
	return before.orthonormalized().get_rotation_quaternion().angle_to(after.orthonormalized().get_rotation_quaternion())
