extends SceneTree
## Tests imported Rook poses and real movement, collision, jump and toggle behavior.

var checks := 0
var failures := 0
var _sample: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Procedural motion checks timed out"); quit(1))
	for path in ["res://scenes/Player_v2.tscn", "res://scenes/Player.tscn"]:
		await _check_imported_rig(path)
	_check_springs()
	await _check_movement()
	await _check_preview()
	print("PROCEDURAL ANIMATION CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)


func _capture_pose(skeleton: Skeleton3D) -> void:
	_sample = {}
	for name in ["Spine", "Bone.027", "Bone.032", "Bone.033", "Bone.034", "Bone.035"]:
		_sample[name] = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name))


func _check_imported_rig(path: String) -> void:
	var player = load(path).instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.rotation.y = 0.7
	player.animation_tree.active = false
	player.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var modifier = player.procedural_pose
	var skeleton: Skeleton3D = modifier.get_skeleton()
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	modifier.modification_processed.connect(_capture_pose.bind(skeleton))
	_check(modifier._legs.size() == 2 and modifier._spine >= 0 and modifier._hips >= 0, "%s resolves both leg chains and independent roots" % path.get_file())
	var collider: Transform3D = player.get_node("CollisionShape3D").global_transform
	for clip in ["Skeleton|Idle", "Skeleton|Walk_v2", "Skeleton|Jump"]:
		player.animation_player.play(clip)
		player.animation_player.advance(0.2)
		modifier.reset_motion()
		skeleton.advance(1.0 / 60)
		await modifier.modification_processed
		await process_frame
		var base := _sample.duplicate()
		modifier.world_lean = Vector3(0.07, 0, -0.025)
		modifier.compression = 0.8
		skeleton.advance(1.0 / 60)
		await modifier.modification_processed
		await process_frame
		var posed := _sample.duplicate()
		for foot in ["Bone.034", "Bone.035"]:
			var before: Transform3D = base[foot]
			var after: Transform3D = posed[foot]
			var angle_error := before.basis.orthonormalized().get_rotation_quaternion().angle_to(after.basis.orthonormalized().get_rotation_quaternion())
			_check(before.origin.distance_to(after.origin) < 0.0001 and angle_error < 0.001 and before.basis.get_scale().distance_to(after.basis.get_scale()) < 0.001, "%s %s keeps %s at its animated ankle pose" % [path.get_file(), clip, foot])
		_check(posed.Spine.origin.y < base.Spine.origin.y and posed["Bone.027"].origin.y < base["Bone.027"].origin.y, "%s %s compresses torso and hips in world-down direction" % [path.get_file(), clip])
		_check(not posed["Bone.032"].basis.is_equal_approx(base["Bone.032"].basis), "%s %s bends the knee to absorb landing" % [path.get_file(), clip])
		for frame in 120:
			skeleton.advance(1.0 / 60)
			await modifier.modification_processed
			await process_frame
		_check(_sample.Spine.is_equal_approx(posed.Spine), "%s %s procedural offsets never accumulate" % [path.get_file(), clip])
		player.procedural_animation_enabled = false
		skeleton.advance(1.0 / 60)
		await modifier.modification_processed
		await process_frame
		_check(_sample.Spine.is_equal_approx(base.Spine) and _sample["Bone.034"].is_equal_approx(base["Bone.034"]), "%s %s toggle restores the authored pose" % [path.get_file(), clip])
	_check(player.get_node("CollisionShape3D").global_transform.is_equal_approx(collider), "%s bone modifiers leave the collision transform unchanged" % path.get_file())
	player.free()


func _check_springs() -> void:
	for fps in [30, 60, 120]:
		var modifier = load("res://scripts/rook_procedural_pose.gd").new()
		var delta: float = 1.0 / fps
		modifier.update_motion(delta, Vector3.ZERO, true, 0, 2, 28)
		var peak := 0.0
		for frame in fps:
			modifier.update_motion(delta, Vector3(2, 0, 0), true, 8.0 if frame == 0 else 0.0, 2, 28)
			peak = maxf(peak, modifier.compression)
		_check(peak > 0.65 and peak <= 0.81 and modifier.compression < 0.0001, "Landing spring is bounded and recovers at %d FPS" % fps)
		for frame in fps:
			modifier.update_motion(delta, Vector3.ZERO, true, 0, 2, 28)
		_check(modifier.world_lean.length() < 0.0001, "Braking lean settles upright at %d FPS" % fps)
		modifier.update_motion(delta, Vector3.ZERO, true, 8, 2, 28)
		modifier.update_motion(delta, Vector3.ZERO, false, 0, 2, 28)
		_check(modifier.compression == 0.0, "A new jump cancels landing compression at %d FPS" % fps)
		modifier.free()


func _check_movement() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.2, 100)
	floor_shape.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.5, 5, 20)
	wall_shape.shape = wall_box
	wall.position = Vector3(3, 2.5, 0)
	wall.add_child(wall_shape)
	world.add_child(wall)
	var player = load("res://scenes/Player_v2.tscn").instantiate()
	player.position.y = 0.55
	player.side_plane_z = -2
	world.add_child(player)
	var original = load("res://scenes/Player_v2.tscn").instantiate()
	original.position.y = 0.55
	original.side_plane_z = 2
	original.procedural_animation_enabled = false
	world.add_child(original)
	await _frames(20)
	var separation: Vector3 = original.global_position - player.global_position
	Input.action_press("move_left")
	await _frames(1)
	var yaw := absf(angle_difference(0.0, player.visual_pivot.rotation.y))
	_check(yaw > 0.01 and yaw < PI - 0.01 and is_equal_approx(absf(original.visual_pivot.rotation.y), PI), "Enabled facing eases while disabled facing uses the original snap")
	Input.action_release("move_left")
	await _frames(40)
	_check(absf(angle_difference(player.visual_pivot.rotation.y, PI)) < 0.05, "Turning completes even after movement input is released")
	Input.action_press("move_right")
	var parity := true
	for frame in 180:
		await _frames(1)
		parity = parity and (original.global_position - player.global_position).distance_to(separation) < 0.0001
	_check(parity, "Procedural ON/OFF has identical movement and collision results")
	_check(player.is_on_wall() and absf(player.get_real_velocity().x) < 0.001 and player.procedural_pose.world_lean.length() < 0.0001, "Pushing into a wall settles lean using actual resolved motion")
	Input.action_release("move_right")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(not player.is_on_floor() and player.procedural_pose.compression == 0.0, "Takeoff stays responsive and has no landing compression")
	var landed := false
	for frame in 100:
		await _frames(1)
		if player.is_on_floor():
			landed = player.procedural_pose.compression > 0.0
			break
	_check(landed, "Real jump landing triggers impact-driven compression")
	await _frames(60)
	_check(player.procedural_pose.compression < 0.0001, "Real landing returns to the base pose")
	player.procedural_pose.compression = 0.5
	player.set_interaction_locked(true)
	_check(player.procedural_pose.compression == 0 and player.procedural_pose.world_lean == Vector3.ZERO, "Interaction lock clears procedural motion")
	player.set_interaction_locked(false)
	player.set_barrel_animation_mode_enabled(true)
	Input.action_press("move_left")
	await _frames(10)
	Input.action_release("move_left")
	_check(player.procedural_pose.world_lean == Vector3.ZERO, "Barrel mode suppresses the body pose overlay")
	player.set_barrel_animation_mode_enabled(false)
	# Phase changes must preserve the existing facing handoff.
	player._set_visual_facing_yaw(PI / 2.0)
	player.transition_to_phase_2()
	_check(is_equal_approx(player.rotation.y, PI / 2.0), "Third-person steering uses the logical heading during an unfinished visual turn")
	await _frames(60)
	_check(absf(angle_difference(player.visual_pivot.rotation.y, player.third_person_visual_yaw)) < 0.001, "Third-person transition aligns the visual to the body")
	player.global_position += Vector3(8, 0, 0)
	await _frames(1)
	_check(player.procedural_pose.compression == 0, "Scripted relocation cannot create a landing impulse")
	world.queue_free()
	await process_frame


func _check_preview() -> void:
	var preview = load("res://scenes/ProceduralAnimationTest.tscn").instantiate()
	root.add_child(preview)
	await _frames(2)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_P
	event.pressed = true
	preview.player._input(event)
	_check(not preview.player.procedural_animation_enabled and "OFF" in preview.status.text, "P toggle updates the preview comparison label")
	preview.player._input(event)
	_check(preview.player.procedural_animation_enabled and "ON" in preview.status.text, "P toggle re-enables procedural motion")
	event.physical_keycode = KEY_C
	preview._unhandled_key_input(event)
	await _frames(2)
	_check(preview.player.game_camera.size == 4.0, "C enables a close camera for inspecting the body pose")
	preview._unhandled_key_input(event)
	_check(preview.player.game_camera.size == preview.player.phase_3_static_camera_size, "C restores the staging-room overview")
	preview.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
		await process_frame
