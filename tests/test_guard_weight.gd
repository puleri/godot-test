extends SceneTree
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
	create_timer(45).timeout.connect(func(): push_error("Guard motion timeout"); quit(1))
	_check_springs()
	var room = load("res://scenes/GuardMotionTest.tscn").instantiate()
	root.add_child(room)
	for guard in room.guards:
		var driver = guard.get_node("AnimationDriver")
		_check(driver.guard_pose != null, str(guard.name) + " has a guard-only pose layer")
		var sk: Skeleton3D = driver.guard_pose.get_skeleton()
		driver.guard_pose.modification_processed.connect(_capture.bind(sk, guard.get_instance_id()))
	var hound = room.guards[0]
	var driver = hound.get_node("AnimationDriver")
	var modifier = driver.guard_pose
	_check(modifier._chains.size() == 4 and modifier.contacts.profiles.size() == 2, "Hound calibrates all four legs and separate walk/run contacts")
	_check(room.guards[1].get_node("AnimationDriver").guard_pose.profile == "mouse", "Mouse uses its actual head, body, hat and baton rig")
	await _frames(60)
	var peak_lean := 0.0
	var peak_accessory := 0.0
	var contact_frames := 0
	var worst_drift := 0.0
	var worst_error := 0.0
	var worst_length_error := 0.0
	var max_mouse_accessory := 0.0
	var segment_lengths := []
	var sk: Skeleton3D = modifier.get_skeleton()
	for chain in modifier._chains:
		segment_lengths.append([sk.get_bone_global_rest(chain.x).origin.distance_to(sk.get_bone_global_rest(chain.y).origin), sk.get_bone_global_rest(chain.y).origin.distance_to(sk.get_bone_global_rest(chain.z).origin)])
	var previous: Dictionary = poses[hound.get_instance_id()].duplicate()
	var planted: Array[bool] = modifier.contacts.planted.duplicate()
	for frame in 720:
		await _frames(1)
		var pose: Dictionary = poses[hound.get_instance_id()]
		peak_lean = maxf(peak_lean, modifier.lean.length())
		peak_accessory = maxf(peak_accessory, modifier.accessory.length())
		max_mouse_accessory = maxf(max_mouse_accessory, room.guards[1].get_node("AnimationDriver").guard_pose.accessory.length())
		for i in modifier._chains.size():
			var chain: Vector3i = modifier._chains[i]
			var measured := [sk.get_bone_global_pose(chain.x).origin.distance_to(sk.get_bone_global_pose(chain.y).origin), sk.get_bone_global_pose(chain.y).origin.distance_to(sk.get_bone_global_pose(chain.z).origin)]
			for j in 2:
				worst_length_error = maxf(worst_length_error, absf(measured[j] - segment_lengths[i][j]))
		for i in 4:
			var name: String = ["Bone.019", "Bone.020", "Bone.021", "Bone.022"][i]
			if modifier.contacts.planted[i] and planted[i] and modifier.contact_strength > 0.99:
				worst_drift = maxf(worst_drift, pose[name].origin.distance_to(previous[name].origin))
				contact_frames += 1
			if modifier.contacts.planted[i] and modifier.contact_strength > 0.99:
				worst_error = maxf(worst_error, pose[name].origin.distance_to(modifier.contacts.anchors[i].origin))
		previous = pose.duplicate()
		planted = modifier.contacts.planted.duplicate()
	_check(contact_frames > 100 and worst_drift < 0.025 and worst_error < 0.035, "Patrol paw contacts stay in world space (drift %.4f, error %.4f)" % [worst_drift, worst_error])
	_check(peak_lean > 0.01 and peak_accessory > 0.01, "Starts, braking and turns drive body and accessory inertia")
	_check(worst_length_error < 0.00001, "Four-leg IK preserves the imported segment lengths")
	_check(max_mouse_accessory > 0.01, "Mouse hat/baton inertia responds on the production guard path")
	_check(driver._guard_gait == "walk" and room.guards[1].get_node("AnimationDriver")._guard_gait == "run", "Patrol uses Hound walk and Mouse run configuration")
	# Hold still and turn the gameplay heading. Only the skeleton is staggered.
	hound.set_physics_process(false)
	hound.velocity = Vector3.ZERO
	for frame in 120:
		driver.set_resolved_motion(0, false, 1.0 / 60)
		driver.update_guard_motion(Vector3.ZERO, hound._last_visual_yaw, false, 1.0 / 60)
		await _frames(1)
	var initial: Dictionary = poses[hound.get_instance_id()].duplicate()
	var collider: Transform3D = hound.get_node("CollisionShape3D").global_transform
	hound._set_visual_yaw(hound._last_visual_yaw + PI / 2)
	driver.update_guard_motion(Vector3.ZERO, hound._last_visual_yaw, false, 1.0 / 60)
	await _frames(1)
	var turned: Dictionary = poses[hound.get_instance_id()]
	var head := _angle(initial.Head.basis, turned.Head.basis)
	var trunk := _angle(initial.Base.basis, turned.Base.basis)
	var hips := _angle(initial.Spine.basis, turned.Spine.basis)
	_check(head > trunk and trunk > hips, "Rendered head leads trunk, then hindquarters (%.3f / %.3f / %.3f)" % [head, trunk, hips])
	_check(hound.get_node("CollisionShape3D").global_transform.is_equal_approx(collider), "Pose changes leave the guard collision transform alone")
	var facing := Vector3.RIGHT.rotated(Vector3.UP, modifier.head_yaw)
	_check(facing.dot(hound.sight_forward()) > 0.999, "Head heading agrees with the detection cone")
	var phase: float = driver._guard_phase
	await _frames(10)
	_check(driver._guard_phase == phase, "Stopped gait never advances on a wall-clock timer")
	# Assert the walk tree actually samples distance, and a chase blends into run.
	var old_phase: float = driver._guard_phase
	driver.update_guard_motion(Vector3(1, 0, 0), hound._last_visual_yaw, false, 1.0 / 60)
	_check(absf(driver._guard_phase - fposmod(old_phase + 1.0 / 60 / modifier.contacts.stride_length, 1.0)) < 0.00001, "Gait phase advances by measured distance / stride")
	for frame in 18:
		driver.set_resolved_motion(2.0, true, 1.0 / 60)
		driver.update_guard_motion(Vector3(2, 0, 0), hound._last_visual_yaw, true, 1.0 / 60)
		await _frames(1)
	_check(driver._guard_gait == "run" and driver._tree.get("parameters/GaitBlend/blend_amount") == 1.0, "Chase smoothly selects the run clip and its contact profile")
	for frame in 120:
		driver.set_resolved_motion(0, false, 1.0 / 60)
		driver.update_guard_motion(Vector3.ZERO, hound._last_visual_yaw, false, 1.0 / 60)
		await _frames(1)
	_check(modifier.lean.length() < 0.0001 and modifier.accessory.length() < 0.0001, "Braking springs return to rest without continued wobble")
	driver.play_alert()
	var released := false
	for frame in 50:
		driver.set_resolved_motion(0, false, 1.0 / 60)
		driver.update_guard_motion(Vector3.ZERO, hound._last_visual_yaw, false, 1.0 / 60)
		released = released or modifier.contact_strength < 0.01
		await _frames(1)
	_check(released, "Alert gestures release paw constraints")
	hound.global_position += Vector3(4, 0, 0)
	driver.update_guard_motion(Vector3.ZERO, hound._last_visual_yaw, false, 1.0 / 60)
	_check(driver._guard_phase == 0 and not modifier.contacts._initialized, "Relocation clears old contact and gait state")
	hound.weighted_motion_enabled = false
	driver.update_guard_motion(Vector3.ZERO, hound._last_visual_yaw, false, 1.0 / 60)
	_check(not modifier._initialized and modifier.lean == Vector3.ZERO, "Disabling motion clears its additive state")
	# Weighted and unweighted guards receive identical patrol/steering decisions.
	var twin = load("res://Characters/Hound/hound_npc.tscn").instantiate()
	twin.set_script(preload("res://scripts/stealth_guard.gd"))
	twin.name = "UnweightedTwin"
	twin.visual_forward_yaw_offset = hound.visual_forward_yaw_offset
	twin.route_path = hound.route_path
	twin.walk_speed = hound.walk_speed
	twin.run_speed = hound.run_speed
	twin.random_seed = hound.random_seed
	twin.pause_min_seconds = hound.pause_min_seconds
	twin.pause_max_seconds = hound.pause_max_seconds
	twin.alert_chance_on_arrival = 0.0
	twin.show_vision = false
	twin.weighted_motion_enabled = false
	twin.position = hound.position
	room.add_child(twin)
	twin.navigation_ready = true
	twin.set_physics_process(false)
	hound.weighted_motion_enabled = true
	hound.velocity = Vector3.ZERO
	twin.velocity = Vector3.ZERO
	hound._target_index = 1
	twin._target_index = 1
	hound._pause_remaining = 0.0
	twin._pause_remaining = 0.0
	twin._heading_yaw = hound._heading_yaw
	twin._set_visual_yaw(hound._last_visual_yaw)
	twin._rng.state = hound._rng.state
	for property in ["_stuck_elapsed", "_stuck_progress", "_last_target_distance", "_state"]:
		twin.set(property, hound.get(property))
	await _frames(2)
	var parity := true
	for frame in 180:
		hound._physics_process(1.0 / 60)
		twin._physics_process(1.0 / 60)
		parity = parity and hound.global_position.distance_to(twin.global_position) < 0.0001 and hound.guard_state == twin.guard_state
		await _frames(1)
	_check(parity, "Weight on/off preserves patrol positions, steering and AI state")
	var ambient = load("res://Characters/Hound/hound_npc.tscn").instantiate()
	ambient.route_path = NodePath("../Route0")
	room.add_child(ambient)
	_check(ambient.get_node("AnimationDriver").guard_pose == null, "Ambient NPCs keep their existing animation pipeline")
	room.free()
	await process_frame
	print("GUARD WEIGHT CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
func _angle(before: Basis, after: Basis) -> float:
	var direction := after * before.inverse() * Vector3.FORWARD
	return absf(atan2(-direction.x, -direction.z))


func _check_springs() -> void:
	for fps in [30, 60, 120]:
		var modifier = load("res://scripts/guard_procedural_pose.gd").new()
		var dt: float = 1.0 / fps
		modifier.update_motion(dt, Vector3.ZERO, 0.0, true, 2, 8, false)
		modifier.update_motion(dt, Vector3(2, 0, 0), PI / 2, true, 2, 8, false)
		_check(modifier.head_yaw > modifier.chest_yaw and modifier.chest_yaw > modifier.pelvis_yaw and modifier.pelvis_yaw > modifier.legs_yaw, "Head → body → hips → legs ordering at %d Hz" % fps)
		var stable := true
		for frame in fps * 2:
			modifier.update_motion(dt, Vector3.ZERO, PI / 2, true, 2, 8, false)
			stable = stable and modifier.lean.is_finite() and modifier.accessory.is_finite() and modifier.accessory.length() <= 0.241
		_check(stable and modifier.lean.length() < 0.0001 and modifier.accessory.length() < 0.0001, "Body/accessory springs stay bounded and settle at %d Hz" % fps)
		modifier.update_motion(dt, Vector3(0, -6, 0), PI / 2, false, 2, 8, false)
		modifier.update_motion(dt, Vector3.ZERO, PI / 2, true, 2, 8, false)
		_check(modifier._landing > 0.0, "Falling triggers impact compression at %d Hz" % fps)
		modifier.reset_motion()
		modifier.update_motion(dt, Vector3.ZERO, PI - 0.01, true, 2, 8, false)
		modifier.update_motion(dt, Vector3.ZERO, -PI + 0.01, true, 2, 8, false)
		_check(absf(modifier.head_yaw - modifier.chest_yaw) < 0.03, "Heading wrap takes the short turn at %d Hz" % fps)
		modifier.free()
