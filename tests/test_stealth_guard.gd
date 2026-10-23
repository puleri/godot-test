extends SceneTree

const STUDY := preload("res://Levels/StealthTraversalTest.tscn")
var _failures := 0
var _checks := 0
var _caught_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(25.0).timeout.connect(func(): push_error("Stealth checks timed out"); quit(1))
	var level := STUDY.instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	# The shared storm cycle is verified with rendered captures. Keep it from
	# starting an asynchronous flash during this deterministic encounter suite.
	level.get_node("StormFlashLight").stop_flashing()
	level.set_process(false)
	var guard := level.get_node("Guard") as StealthGuard
	var player := level.get_node("Player") as CharacterBody3D
	guard.set_physics_process(false)
	player.set_physics_process(false)
	guard.player_caught.connect(func(): _caught_count += 1)
	_check(level.region.navigation_mesh.get_polygon_count() > 0, "Courtyard navigation bakes successfully")

	await _place(guard, player, Vector3(8, 0, 1), Vector3(8, 0.49, -3))
	_check(guard.can_see_player(), "Player in an unobstructed view cone is visible")
	player.global_position = Vector3(8, 0.49, -8)
	await physics_frame
	_check(not guard.can_see_player(), "Player outside sight range is unseen")
	player.global_position = Vector3(8, 0.49, 4)
	await physics_frame
	_check(not guard.can_see_player(), "Player behind the guard is unseen")
	player.global_position = Vector3(11, 0.49, -1)
	await physics_frame
	_check(not guard.can_see_player(), "Player outside the view angle is unseen")
	guard._face_position(guard.global_position + Vector3.RIGHT, 1.0)
	guard._update_feedback(0.0)
	var beam_forward := -guard._sight_light.global_basis.z.normalized()
	_check(beam_forward.dot(guard.sight_forward()) > 0.9999, "Turning keeps the Hound's real spotlight aligned with sight")
	guard.show_vision = false
	guard._update_feedback(0.0)
	_check(guard._sight_light.visible and not guard._vision_instance.visible, "Hiding the debug cone keeps the Hound's real light on")

	await _place(guard, player, Vector3(-4, 0, 3.3), Vector3(-4, 0.49, -1))
	_check(not guard.can_see_player(), "Full-height cover blocks visibility")
	guard.guard_state = StealthGuard.GuardState.CHASE
	guard.awareness = 1.0
	guard.capture_distance = 6.0
	guard._physics_process(1.0 / 60.0)
	_check(_caught_count == 0, "Even nearby pursuit cannot capture through cover")
	guard.capture_distance = 0.9

	for fps in [30, 60, 120]:
		guard.guard_state = StealthGuard.GuardState.PATROL
		guard.awareness = 0.0
		guard.player_visible = true
		for frame in range(fps / 2):
			guard._update_awareness(1.0 / fps)
		_check(is_equal_approx(guard.awareness, 0.5 / guard.seconds_to_detect), "Awareness uses elapsed time at %d FPS" % fps)
		_check(guard.guard_state == StealthGuard.GuardState.SUSPICIOUS, "A brief sighting warns before pursuit at %d FPS" % fps)
	guard._update_awareness(guard.seconds_to_detect)
	_check(guard.guard_state == StealthGuard.GuardState.CHASE, "Sustained visibility triggers pursuit")

	await _place(guard, player, Vector3(8, 0, 1), Vector3(8, 0.49, -3))
	guard.guard_state = StealthGuard.GuardState.CHASE
	guard.awareness = 1.0
	guard._physics_process(1.0 / 60.0)
	var remembered := guard.last_seen_position
	player.global_position = Vector3(-9, 0.49, -6)
	for frame in 45:
		await physics_frame
		guard._physics_process(1.0 / 60.0)
	_check(guard.last_seen_position.is_equal_approx(remembered), "Hiding does not reveal the player's new position")
	_check(guard.guard_state == StealthGuard.GuardState.SEARCH, "Lost sight transitions pursuit into a search")
	guard._search_arrived = true
	guard._search_elapsed = 0.0
	guard._search(guard.search_seconds + 0.1)
	_check(guard.guard_state == StealthGuard.GuardState.RETURN, "An unsuccessful search returns to the patrol route")
	guard.global_position = guard._points[guard._target_index].global_position
	guard._return_to_patrol(1.0 / 60.0)
	_check(guard.guard_state == StealthGuard.GuardState.PATROL, "Reaching the route resumes patrol")

	# Exercise actual pathfinding and collision, on opposite sides of EastCover.
	await _place(guard, player, Vector3(6, 0, -1.5), Vector3(-9, 0.49, -6))
	guard._requested_destination = Vector3.INF
	guard._repath_remaining = 0.0
	var destination := Vector3(0, 0.49, -1.5)
	var detour := 0.0
	for frame in 420:
		await physics_frame
		guard._repath_remaining -= 1.0 / 60.0
		guard._apply_gravity(1.0 / 60.0)
		guard._navigate_to(destination, 3.0, 1.0 / 60.0)
		guard.move_and_slide()
		detour = maxf(detour, absf(guard.global_position.z + 1.5))
		if guard._agent.is_navigation_finished():
			break
	_check(detour > 2.5, "Pathfinding takes the guard around the cover wall")
	_check(Vector2(guard.global_position.x, guard.global_position.z + 1.5).length() < 0.7, "Guard can reach the far side of cover")
	_check(guard._agent.is_navigation_finished(), "A remembered player position above the floor has a reachable path endpoint")

	await _place(guard, player, Vector3(8, 0, 1), Vector3(8, 0.49, 0.4))
	guard.guard_state = StealthGuard.GuardState.CHASE
	guard.awareness = 1.0
	guard.active = true
	guard._physics_process(1.0 / 60.0)
	_check(_caught_count == 1 and level.finished, "A pursuing guard can catch a visible nearby player")
	_check(player.interaction_locked, "Capture stops player input")

	# Reload the same scene, as the R key does, and verify objective state resets.
	reload_current_scene()
	await process_frame
	while current_scene == null:
		await process_frame
	level = current_scene
	if not level.guard.navigation_ready:
		await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	level.set_process(false)
	level.guard.set_physics_process(false)
	level.player.set_physics_process(false)
	_check(not level.finished and not level.has_loot and level.guard.awareness == 0.0, "Restart resets the encounter and relic")
	var starting_position: Vector3 = level.player.global_position
	level.player.set_physics_process(true)
	Input.action_press("move_right")
	for frame in 20:
		await physics_frame
	Input.action_release("move_right")
	_check(level.player.global_position.distance_to(starting_position) > 0.4, "Movement input moves the Rook in the study scene")
	for frame in 8:
		await physics_frame
	_check(Vector2(level.player.velocity.x, level.player.velocity.z).length() < 0.01, "Releasing movement stops the Rook")
	level.player.set_physics_process(false)
	level._at_exit = true
	level._try_escape()
	_check(not level.finished, "Extraction requires the relic")
	level._on_objective_entered(level.player)
	level.guard.player_visible = true
	level.guard.guard_state = StealthGuard.GuardState.CHASE
	level._try_escape()
	_check(not level.finished, "Extraction is blocked while visibly pursued")
	level.guard.player_visible = false
	level.guard.guard_state = StealthGuard.GuardState.SEARCH
	level._try_escape()
	_check(level.finished and level.has_loot, "Returning unseen with the relic completes the encounter")

	print("STEALTH CHECKS: %d passed, %d failed" % [_checks - _failures, _failures])
	quit(0 if _failures == 0 else 1)


func _place(guard: StealthGuard, player: CharacterBody3D, guard_position: Vector3, player_position: Vector3) -> void:
	guard.global_position = guard_position
	guard.velocity = Vector3.ZERO
	guard._heading_yaw = 0.0
	guard._set_visual_yaw(guard.visual_forward_yaw_offset)
	player.global_position = player_position
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)
