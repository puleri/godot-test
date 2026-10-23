extends SceneTree
## Behavior checks for contact, staggered turns, distance gait and accessory inertia.

var checks := 0
var failures := 0
var _pose: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame

func _capture(skeleton: Skeleton3D) -> void:
	_pose = {}
	for name in ["Spine", "Head", "Bone.027", "Bone.030", "Bone.032", "Bone.034", "Bone.031", "Bone.033", "Bone.035", "Cape_1", "Cape_2", "CapeEnd"]:
		_pose[name] = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name))

func _run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Rook weight checks timed out"); quit(1))
	_check_turns_and_springs()
	for path in ["res://scenes/Player_v2.tscn", "res://scenes/Player.tscn"]:
		await _check_contacts(path)
	await _check_demo()
	print("ROOK WEIGHT CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)

func _check_turns_and_springs() -> void:
	for fps in [30, 60, 120]:
		var modifier = load("res://scripts/rook_procedural_pose.gd").new()
		var dt: float = 1.0 / fps
		modifier.update_turn(dt, 0.0, 0.0, 0.055)
		modifier.update_turn(dt, PI / 2.0, 0.0, 0.055)
		_check(modifier.head_yaw > modifier.pelvis_yaw and modifier.pelvis_yaw > modifier.legs_yaw and modifier.legs_yaw > 0.0, "Head leads pelvis, then legs at %d FPS" % fps)
		var safe := true
		for frame in fps * 2:
			modifier.update_turn(dt, PI, modifier.legs_yaw, 0.055)
			modifier.update_motion(dt, Vector3(2, 0, 0) if frame < fps / 2 else Vector3.ZERO, true, 0, 2, 28)
			for bend in modifier.cape_angles:
				safe = safe and bend.is_finite() and bend.length() <= deg_to_rad(16.01)
		_check(absf(angle_difference(modifier.legs_yaw, PI)) < 0.0001 and absf(modifier.turn_head_offset) < 0.0001, "A half-turn finishes without permanent twist at %d FPS" % fps)
		_check(safe and modifier.cape_angles[2].length() < 0.0001, "Cape stays bounded and settles after braking at %d FPS" % fps)
		modifier.reset_motion()
		modifier.update_turn(dt, -PI + 0.02, PI - 0.02, 0.055)
		_check(absf(modifier.legs_yaw - (PI - 0.02)) < 0.04, "Heading wrap takes the short arc at %d FPS" % fps)
		modifier.reset_motion()
		_check(modifier.cape_angles[0] == Vector3.ZERO and modifier.turn_head_offset == 0 and not modifier.foot_placement._initialized, "Reset clears cape, heading and contact state at %d FPS" % fps)
		modifier.free()

func _check_contacts(path: String) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := AnimatableBody3D.new()
	floor_body.sync_to_physics = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.2, 100)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.1
	world.add_child(floor_body)
	var player = load(path).instantiate()
	player.position.y = 0.7
	world.add_child(player)
	var modifier = player.procedural_pose
	var skeleton: Skeleton3D = modifier.get_skeleton()
	modifier.modification_processed.connect(_capture.bind(skeleton))
	await _frames(60)
	var label := path.get_file()
	_check(modifier.foot_placement.stride_length > 0.5 and modifier._cape.size() == 3 and modifier._head >= 0, label + " calibrates stride and resolves cape/head bones")
	# Verify the animation really samples our phase, not merely the counter.
	player.set_physics_process(false)
	modifier.active = false
	player.animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.state_machine_playback = player.animation_tree.get("parameters/playback")
	player.state_machine_playback.start("Ground")
	player.walk_blend_amount = 1.0
	player._walk_cycle_phase = 0.1
	player._update_animation_tree(1.0, false)
	player.animation_tree.advance(1.0 / 60)
	var first_gait := skeleton.get_bone_global_pose(skeleton.find_bone("Bone.034"))
	player._walk_cycle_phase = 0.4
	player._update_animation_tree(1.0, false)
	player.animation_tree.advance(1.0 / 60)
	var second_gait := skeleton.get_bone_global_pose(skeleton.find_bone("Bone.034"))
	_check((skeleton.global_basis * (first_gait.origin - second_gait.origin)).length() > 0.03, label + " AnimationTree samples different authored poses at distance phases")
	modifier.active = true
	player.animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	player.state_machine_playback = player.animation_tree.get("parameters/playback")
	player.state_machine_playback.start("Ground")
	player.current_animation_state = "Ground"
	player.reset_procedural_motion()
	player.set_physics_process(true)
	await _frames(60)
	var stationary_phase: float = player._walk_cycle_phase
	await _frames(15)
	_check(is_equal_approx(stationary_phase, player._walk_cycle_phase), label + " walk phase stays still at rest")
	var phase_start: float = player._walk_cycle_phase
	var start: Vector3 = player.global_position
	Input.action_press("move_right")
	var contact_frames := 0
	var worst_drift := 0.0
	var worst_target_error := 0.0
	var worst_length_error := 0.0
	var last_foot: Array[Vector3] = [_pose["Bone.034"].origin, _pose["Bone.035"].origin]
	var last_planted: Array[bool] = modifier.foot_placement.planted.duplicate()
	var worst_jump := 0.0
	var peak_cape := 0.0
	var traveled := 0.0
	var previous: Vector3 = start
	var measured_lengths := []
	for names in [["Bone.030", "Bone.032", "Bone.034"], ["Bone.031", "Bone.033", "Bone.035"]]:
		measured_lengths.append([_pose[names[0]].origin.distance_to(_pose[names[1]].origin), _pose[names[1]].origin.distance_to(_pose[names[2]].origin)])
	for frame in 180:
		await _frames(1)
		var position: Vector3 = player.global_position
		traveled += Vector2(position.x - previous.x, position.z - previous.z).length()
		previous = position
		peak_cape = maxf(peak_cape, modifier.cape_angles[0].length())
		for i in 2:
			var names := ["Bone.030", "Bone.032", "Bone.034"] if i == 0 else ["Bone.031", "Bone.033", "Bone.035"]
			var ankle: Vector3 = _pose[names[2]].origin
			worst_jump = maxf(worst_jump, ankle.distance_to(last_foot[i]))
			if modifier.foot_placement.planted[i] and last_planted[i]:
				worst_drift = maxf(worst_drift, ankle.distance_to(last_foot[i]))
				contact_frames += 1
			if modifier.foot_placement.planted[i]:
				worst_target_error = maxf(worst_target_error, ankle.distance_to(modifier.foot_placement.anchors[i].origin))
			for j in 2:
				var length: float = _pose[names[j]].origin.distance_to(_pose[names[j + 1]].origin)
				worst_length_error = maxf(worst_length_error, absf(length - measured_lengths[i][j]))
			last_foot[i] = ankle
			last_planted[i] = modifier.foot_placement.planted[i]
	Input.action_release("move_right")
	var expected_phase: float = fposmod(phase_start + traveled / modifier.foot_placement.stride_length, 1.0)
	_check(absf(angle_difference(expected_phase * TAU, player._walk_cycle_phase * TAU)) < 0.01, label + " gait phase follows resolved distance")
	_check(contact_frames > 100 and worst_drift < 0.012 and worst_target_error < 0.015, "%s planted contacts hold world position (drift %.4f, error %.4f)" % [label, worst_drift, worst_target_error])
	_check(worst_length_error < 0.0001, "%s IK preserves bone lengths (error %.6f)" % [label, worst_length_error])
	_check(worst_jump < 0.18, "%s swing has no abrupt ankle teleport (max %.3f)" % [label, worst_jump])
	_check(peak_cape > 0.03, label + " cape visibly responds to movement")
	await _frames(120)
	_check(modifier.foot_placement.planted[0] and modifier.foot_placement.planted[1] and modifier.foot_placement._settling == -1, label + " stopping finishes recovery steps and plants both feet")
	_check(modifier.cape_angles[2].length() < 0.0001, label + " cape settles at rest")
	# Turn without translating; the head starts first while the support ankle holds.
	var before: Dictionary = _pose.duplicate()
	player._set_visual_facing_yaw(PI / 2.0)
	await _frames(1)
	var head_rotation := _yaw_change(before.Head.basis, _pose.Head.basis)
	var pelvis_rotation := _yaw_change(before["Bone.027"].basis, _pose["Bone.027"].basis)
	var foot_rotation := _yaw_change(before["Bone.034"].basis, _pose["Bone.034"].basis)
	_check(head_rotation > pelvis_rotation and pelvis_rotation > foot_rotation, "%s rendered bones turn head → pelvis → foot (%.3f / %.3f / %.3f)" % [label, head_rotation, pelvis_rotation, foot_rotation])
	await _frames(120)
	_check(modifier.foot_placement.planted[0] and modifier.foot_placement.planted[1] and absf(modifier.turn_head_offset) < 0.001, label + " pivot steps finish with an untwisted body")
	# Rapid cardinal changes and reversals must not leave a stretched, twisted rig.
	var rapid_drift := 0.0
	var rapid_error := 0.0
	for action in ["move_left", "move_up", "move_right", "move_down", "move_left", "move_right"]:
		Input.action_press(action)
		for frame in 18:
			var before_feet := [_pose["Bone.034"].origin, _pose["Bone.035"].origin]
			var before_planted: Array[bool] = modifier.foot_placement.planted.duplicate()
			await _frames(1)
			for i in 2:
				var ankle: Vector3 = _pose["Bone.034" if i == 0 else "Bone.035"].origin
				if before_planted[i] and modifier.foot_placement.planted[i]:
					rapid_drift = maxf(rapid_drift, ankle.distance_to(before_feet[i]))
				if modifier.foot_placement.planted[i]:
					rapid_error = maxf(rapid_error, ankle.distance_to(modifier.foot_placement.anchors[i].origin))
		Input.action_release(action)
	_check(rapid_drift < 0.025 and rapid_error < 0.035, "%s contacts survive quick turns/reversals (drift %.4f, error %.4f)" % [label, rapid_drift, rapid_error])
	await _frames(120)
	# World-space contacts travel with their supporting platform.
	var foot_before: Vector3 = _pose["Bone.034"].origin
	floor_body.position.x += 0.1
	await _frames(1)
	_check(absf((_pose["Bone.034"].origin - foot_before).x - 0.1) < 0.015, label + " planted foot follows a moving support")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(not modifier.foot_placement._initialized and not modifier.foot_placement.planted[0], label + " takeoff releases foot locks immediately")
	player.procedural_animation_enabled = false
	await _frames(1)
	_check(modifier.cape_angles[0] == Vector3.ZERO and modifier.turn_pelvis_offset == 0.0, label + " disabling motion restores authored cape and body")
	player.procedural_animation_enabled = true
	player.global_position += Vector3(0, 0, 10)
	await _frames(1)
	_check(not modifier.foot_placement._initialized and modifier.compression == 0, label + " relocation discards old contacts and impact")
	world.free()
	await process_frame

func _yaw_change(before: Basis, after: Basis) -> float:
	var direction := after * before.inverse() * Vector3.RIGHT
	return absf(atan2(-direction.z, direction.x))


func _check_demo() -> void:
	var preview = load("res://scenes/ProceduralAnimationTest.tscn").instantiate()
	root.add_child(preview)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_T
	event.pressed = true
	preview._unhandled_key_input(event)
	await _frames(100)
	_check(preview._demo_running and preview._demo_index > 1, "Motion room demo advances its movement sequence")
	preview._unhandled_key_input(event)
	_check(not preview._demo_running and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("jump"), "Stopping the demo releases simulated input")
	preview.free()
	await process_frame
