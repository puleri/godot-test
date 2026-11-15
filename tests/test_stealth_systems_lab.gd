extends SceneTree

var _checks := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90).timeout.connect(func(): push_error("Lab checks timed out"); quit(1))
	var level = load("res://Levels/StealthSystemsLab.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	_check(level.region.navigation_mesh.get_polygon_count() > 0, "Showcase collision bakes navigation")
	_check(level.guards.size() == 5, "Saved scene contains all five demonstration guards")
	_check(level.player.overview_camera != null, "Saved player uses the lab camera")
	var from := Vector3(-26, 0, 3)
	var receipts: Array[Dictionary] = level.emit_noise(from, 12, "PULSE")
	_check(receipts[0].result.audible and not receipts[0].result.direct, "Open-door listener hears around the wall")
	_check(receipts[0].result.distance > from.distance_to(receipts[0].guard.position), "Sound spends distance along its route")
	_check(not receipts[1].result.audible and is_inf(receipts[1].result.distance), "Sealed enclosure has no acoustic route")
	_check(not level.acoustics.route(from, receipts[0].guard.position, 9).audible, "A geometrically close listener can be outside the routed sound budget")
	_check(level.completed[0], "Open-versus-sealed comparison marks the first demonstration")
	level.set_door(false)
	await physics_frame
	await physics_frame
	receipts = level.emit_noise(from, 12, "PULSE")
	_check(not receipts[0].result.audible and not receipts[1].result.audible, "Closing the physical door blocks the remaining short route")
	level.set_door(true)
	await physics_frame
	await physics_frame
	_check(level.acoustics.route(from, level.guards[0].position, 12).audible, "Reopening the door restores hearing")
	level.select_bay(1)
	# Disable visual recognition only inside these deterministic hearing/motor
	# checks; the final capture check restores a real player reference.
	for guard in level.guards:
		guard._player = null
	receipts = level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	_check(receipts[0].result.audible and receipts[1].result.audible, "Both squad members physically hear the distraction")
	var leader: Node3D = level.leader
	var sentry: Node3D = level.guards[3]
	_check(leader == level.guards[2] and sentry.duty == "SENTRY", "Nearest listener investigates while the other holds its exit")
	var sentry_home: Vector3 = sentry.position
	var glance := Vector3.ZERO
	var scan_start := Vector3.ZERO
	for frame in 150:
		await physics_frame
		leader._physics_process(1.0 / 60)
		sentry._physics_process(1.0 / 60)
		if frame == 44:
			glance = sentry.sight_forward()
		if frame == 100:
			scan_start = sentry.sight_forward()
	_check(leader.position.distance_to(leader.home) > 1.5, "Investigator actually walks toward the distraction")
	_check(sentry.position.distance_to(sentry_home) > 0.3 and sentry.position.distance_to(sentry_home) < 1.6, "Sentry autonomously starts its watch patrol while the investigator moves")
	_check(glance.dot((Vector3(-4, 0, 3) - sentry_home).normalized()) > 0.9, "Sentry first turns visibly toward the disturbance")
	_check(scan_start.distance_to(glance) > 0.1, "Sentry changes heading to walk its watch route")
	_check((-sentry._sight_light.global_basis.z).dot(sentry.sight_forward()) > 0.96, "Real lamp direction follows the sentry's scanning vision")
	var remembered: Vector3 = leader.investigation_target
	level.emit_noise(Vector3(4, 0, 3), 12, "FOOTSTEPS")
	_check(leader.investigation_target.is_equal_approx(remembered), "Repeated footsteps do not continuously home an investigating guard")
	leader.guard_state = StealthGuard.GuardState.CHASE
	level.emit_noise(Vector3(2, 0, 3), 12, "CHIME")
	_check(leader.guard_state == StealthGuard.GuardState.CHASE, "A sound does not override confirmed pursuit")
	level.select_bay(1)
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	var first_investigator: Node3D = level.leader
	for frame in 150:
		await physics_frame
		first_investigator._physics_process(1.0 / 60)
		sentry._physics_process(1.0 / 60)
	var scan_elapsed: float = sentry._sentry_elapsed
	level.emit_noise(Vector3(-3.5, 0, 3), 12, "PULSE")
	_check(sentry.duty == "SENTRY" and is_equal_approx(sentry._sentry_elapsed, scan_elapsed), "Same-source repeat during cooldown does not pin the sentry's gaze")
	for frame in 60:
		await physics_frame
		sentry._physics_process(1.0 / 60)
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	_check(sentry._sentry_elapsed == 0 and sentry.duty == "SENTRY", "Same-source sound can prompt another glance after cooldown")
	var first_target: Vector3 = first_investigator.investigation_target
	level.emit_noise(Vector3(-1.5, 0, 3), 12, "FOOTSTEPS")
	_check(sentry.duty == "SENTRY" and sentry._sentry_incident.is_equal_approx(Vector3(-1.5, 0, 3)), "Same-incident footsteps update the sentry glance without starting another investigation")
	for frame in 45:
		await physics_frame
		sentry._physics_process(1.0 / 60)
	_check(sentry.sight_forward().dot((Vector3(-1.5, 0, 3) - sentry.position).normalized()) > 0.9, "New sound briefly turns the moving sentry toward its source")
	var heard_at: Vector3 = sentry.last_heard_position
	scan_elapsed = sentry._sentry_elapsed
	level.emit_noise(Vector3(4, 0, -4), 0.1, "PULSE")
	_check(sentry.last_heard_position.is_equal_approx(heard_at) and is_equal_approx(sentry._sentry_elapsed, scan_elapsed), "Inaudible event cannot turn the sentry or replace its sound memory")
	_check(sentry.covered_incident.is_equal_approx(first_target), "Glancing at later sounds preserves the incident covered for takeover")
	level.emit_noise(Vector3(4, 0, 3), 12, "PULSE")
	_check(sentry.duty == "INVESTIGATOR" and sentry.investigation_target.is_equal_approx(Vector3(4, 0, 3)), "Separate distraction assigns the available sentry its own investigation")
	_check(first_investigator.investigation_target.is_equal_approx(first_target) and first_investigator.duty == "INVESTIGATOR", "Second incident preserves the first investigator's assignment")
	sentry._search_elapsed = 1
	level.emit_noise(Vector3(4.3, 0, 3), 12, "CHIME")
	_check(sentry._search_elapsed == 1 and sentry.investigation_target.is_equal_approx(Vector3(4, 0, 3)), "Repeated distraction extends an existing incident without restarting its search")
	for frame in 150:
		await physics_frame
		sentry._physics_process(1.0 / 60)
	_check(sentry.position.distance_to(sentry_home) > 1, "Second investigator physically approaches the separate disturbance")
	first_investigator.guard_state = StealthGuard.GuardState.PATROL
	level._update_squad()
	_check(level.leader == sentry and sentry.duty == "INVESTIGATOR", "Completing the first incident does not cancel the second investigation")
	sentry.guard_state = StealthGuard.GuardState.PATROL
	level._update_squad()
	_check(level.leader == null and sentry.duty == "PATROL", "Both incident assignments clear after independent completion")
	level.select_bay(1)
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	var partner: Node3D = level.leader
	var partner_target: Vector3 = partner.investigation_target
	# Let the sentry run through the engine's real physics scheduling without
	# another test pulse. Keep the partner occupied to expose duty locks.
	sentry.set_physics_process(true)
	var reversals := 0
	var previous_index: int = sentry._watch_index
	var min_z: float = sentry.position.z
	var max_z: float = sentry.position.z
	for frame in 720:
		await physics_frame
		min_z = minf(min_z, sentry.position.z)
		max_z = maxf(max_z, sentry.position.z)
		if sentry._watch_index != previous_index:
			reversals += 1
			previous_index = sentry._watch_index
	_check(max_z - min_z > 1.2 and reversals >= 2, "Sentry autonomously walks and reverses its watch route without another sound")
	_check(sentry.duty == "SENTRY" and partner.guard_state == StealthGuard.GuardState.SEARCH, "Watch patrol continues while the partner remains occupied")
	var emitted_steps: Array[Vector3] = []
	var capture_step := func(at: Vector3, _radius: float, kind: String):
		if kind == "FOOTSTEPS":
			emitted_steps.append(at)
	level.player.noise_emitted.connect(capture_step)
	level.player.jump_to(Vector3(4, 0.49, 1))
	level.player._step_distance = 0
	level.player._air_time = 0
	level.player.set_physics_process(true)
	Input.action_press("move_right")
	for frame in 40:
		await physics_frame
	Input.action_release("move_right")
	level.player.set_physics_process(false)
	sentry.set_physics_process(false)
	level.player.noise_emitted.disconnect(capture_step)
	_check(not emitted_steps.is_empty(), "Actual player movement emits footsteps through the connected noise signal")
	_check(sentry.duty == "INVESTIGATOR" and sentry.guard_state == StealthGuard.GuardState.SEARCH, "Real footsteps draw the sentry into investigation without pressing E")
	var heard_real_step := false
	for step_at in emitted_steps:
		heard_real_step = heard_real_step or Vector2(step_at.x - sentry.investigation_target.x, step_at.z - sentry.investigation_target.z).length() < 0.05
	_check(heard_real_step and partner.investigation_target.is_equal_approx(partner_target), "Footstep investigation uses a real emitted location and preserves the partner's assignment")
	level.select_bay(1)
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	sentry.guard_state = StealthGuard.GuardState.CHASE
	sentry.player_visible = true
	var chase_heading: float = sentry._sentry_elapsed
	level.emit_noise(Vector3(4, 0, 3), 12, "PULSE")
	_check(sentry.guard_state == StealthGuard.GuardState.CHASE and is_equal_approx(sentry._sentry_elapsed, chase_heading), "Separate audio cannot reassign or turn a sentry in confirmed pursuit")
	level.select_bay(1)
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	var old_leader: Node3D = level.leader
	var shared_incident: Vector3 = old_leader.investigation_target
	level.emit_noise(Vector3(-1.5, 0, 3), 12, "FOOTSTEPS")
	_check(level.disable_investigator(), "Bay shortcut can mark the investigator unavailable")
	_check(level.leader == sentry and sentry.guard_state == StealthGuard.GuardState.SEARCH and sentry.investigation_target.is_equal_approx(shared_incident), "Sentry takes over the remembered incident when its partner is unavailable")
	_check(not old_leader.active and not old_leader.has_lamp, "Unavailable partner stops acting and switches off its lamp")
	for frame in 150:
		await physics_frame
		sentry._physics_process(1.0 / 60)
	_check(sentry.position.distance_to(sentry_home) > 1, "Replacement investigator physically leaves the sentry post")
	level.select_bay(1)
	_check(old_leader.active and old_leader.has_lamp and sentry.duty == "PATROL", "Bay reset restores partner, lamp and duties")
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	sentry.guard_state = StealthGuard.GuardState.CHASE
	level.disable_investigator()
	_check(level.leader == null and sentry.guard_state == StealthGuard.GuardState.CHASE, "Takeover never diverts a sentry already pursuing Rook")
	sentry.guard_state = StealthGuard.GuardState.PATROL
	level._update_squad()
	_check(level.leader == sentry and sentry.investigation_target.is_equal_approx(shared_incident), "Deferred takeover remains pending until the sentry is available")
	level.select_bay(1)
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	level.leader.guard_state = StealthGuard.GuardState.PATROL
	level._update_squad()
	_check(level.leader == null and sentry.duty == "PATROL", "Completed investigation releases the sentry from its watch")
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	sentry._player = level.player
	sentry.awareness = 1
	level.player.position = sentry.position + Vector3(0, 0.49, -0.6)
	await physics_frame
	sentry._physics_process(1.0 / 60)
	_check(sentry.guard_state == StealthGuard.GuardState.CHASE and level.player.interaction_locked, "Sentry can detect and capture Rook while assigned to hold an exit")
	level._update_squad()
	_check(level.player.interaction_locked and not sentry.active, "Capture ends the encounter without starting a takeover")
	sentry._player = null
	level.select_bay(2)
	var watcher: Node3D = level.guards[4]
	_check(not level.trigger_chime(), "Remote trigger requires an armed chime")
	_check(level.place_chime(), "Player can place the reusable chime")
	_check(watcher.guard_state == StealthGuard.GuardState.PATROL, "Placement preview does not alert a guard")
	var incident: Vector3 = level.get_node("RemoteChime").position
	level.player.jump_to(Vector3(22, 0.49, -3))
	_check(level.trigger_chime(), "Chime can be triggered after the player leaves it")
	_check(watcher.investigation_target.is_equal_approx(incident), "Guard investigates the chime rather than the player's new position")
	_check(not level.trigger_chime() and not level.place_chime(), "One activation and a cooldown prevent repeatedly pinning a guard")
	var reached := false
	var returned := false
	for frame in 2400:
		await physics_frame
		watcher._physics_process(1.0 / 60)
		reached = reached or watcher.visited_search_points >= 2
		if reached and watcher.guard_state == StealthGuard.GuardState.PATROL:
			returned = true
			break
	_check(watcher.search_points.size() >= 2, "Incident produces reachable area search points")
	_check(reached, "Guard physically visits multiple search locations")
	_check(returned, "Bounded area search finishes and rejoins the home route")
	_check(watcher.investigation_target.is_equal_approx(incident), "Area search does not track the hidden player")
	level.select_bay(2)
	watcher._player = level.player
	watcher.guard_state = StealthGuard.GuardState.CHASE
	watcher.awareness = 1
	level.player.position = watcher.position + Vector3(0, 0.49, -0.6)
	await physics_frame
	watcher._physics_process(1.0 / 60)
	_check(level.player.interaction_locked, "Real guard contact captures the player in the lab")
	level.select_bay(2)
	_check(not level.player.interaction_locked and watcher.active and watcher.awareness == 0, "Selecting a bay resets capture and guard memory")
	level.player.map_view = true
	level.player._update_phase_camera()
	_check(is_equal_approx(level.player.overview_camera.size, 67), "Overview frames all three demonstrations")
	level.player.map_view = false
	level.player._update_phase_camera()
	level.player.set_physics_process(true)
	var start: Vector3 = level.player.position
	Input.action_press("move_right")
	for frame in 18:
		await physics_frame
	Input.action_release("move_right")
	_check(level.player.position.distance_to(start) > 0.5, "Camera-relative movement works in the saved scene")
	print("SYSTEMS LAB CHECKS: %d passed, %d failed" % [_checks - _failed, _failed])
	level.queue_free()
	await process_frame
	quit(0 if _failed == 0 else 1)


func _check(ok: bool, text: String) -> void:
	_checks += 1
	if ok:
		print("PASS: " + text)
	else:
		_failed += 1
		push_error("FAIL: " + text)
