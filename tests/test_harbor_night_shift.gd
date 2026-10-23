extends SceneTree
## Integration checks on the saved level: patrols, joined navigation and a full job.

const LEVEL = preload("res://Levels/HarborNightShift.tscn")
var _failures := 0
var _checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0).timeout.connect(func(): push_error("Harbor checks timed out"); quit(1))
	var level = LEVEL.instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	level.set_process(false)
	var player: CharacterBody3D = level.player
	player.set_physics_process(false)
	_check(level.region.navigation_mesh.get_polygon_count() > 0, "Saved harbor geometry bakes a navigation mesh")
	_check(level.guards.size() == 2 and level.get_node("CargoSeals").get_child_count() == 3, "Encounter contains two patrols and three objectives")
	var storm = level.get_node("StormFlashLight")
	_check(storm.get_script() == load("res://scripts/storm_flash_light.gd") and storm.thunder_sounds.size() == 3 and storm.storm_ambience != null, "Demo_A2 storm script and all audio assets are reused")
	for guard in level.guards:
		_check(guard._sight_light != null and guard._sight_light.shadow_enabled, "%s retains its shadow-casting sight light after scene packing" % guard.name)
		_check(is_equal_approx(guard._sight_light.spot_angle * 2, guard.field_of_view_degrees), "%s light matches detection angle" % guard.name)
	var map: RID = level.region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, Vector3(0, 0, 17))
	for target in [Vector3(-20.5, 0, -20), Vector3(20.5, 0, -20), Vector3(4, 0, -17)]:
		var destination := NavigationServer3D.map_get_closest_point(map, target)
		var path := NavigationServer3D.map_get_path(map, start, destination, true)
		_check(not path.is_empty() and path[-1].distance_to(destination) < 0.1, "Navigation connects the entrance to %s" % target)
	# Exercise both real patrols with the player safely at the entrance.
	var visited := [{}, {}]
	for frame in 2400:
		await physics_frame
		for i in level.guards.size():
			var guard: StealthGuard = level.guards[i]
			for j in guard._points.size():
				if guard.global_position.distance_to(guard._points[j].global_position) < 0.4:
					visited[i][j] = true
	for i in level.guards.size():
		_check(visited[i].size() == 4, "%s reaches all four patrol corners without getting stuck" % level.guards[i].name)
		level.guards[i].set_physics_process(false)
	# The screen must hide a player, even during a flash; light is visual feedback.
	var guard: StealthGuard = level.guards[0]
	guard.global_position = Vector3(0, 0, 3)
	guard._heading_yaw = 0.0
	guard._set_visual_yaw(guard.visual_forward_yaw_offset)
	player.global_position = Vector3(0, 0.49, -3)
	await physics_frame
	_check(not guard.can_see_player(), "Reusable harbor screen blocks real guard sight")
	storm.visible = true
	storm.light_energy = 1.0
	_check(not guard.can_see_player(), "Lightning does not reveal a player through a wall")
	storm.stop_flashing()
	player.global_position = Vector3(0, 0.49, 2)
	await physics_frame
	_check(guard.can_see_player(), "An unobstructed player inside the beam is visible")
	# Confirm this level's baked paths route around its art-backed cover.
	guard._requested_destination = Vector3.INF
	guard._repath_remaining = 0.0
	var detour := 0.0
	var destination := Vector3(0, 0.49, -3)
	for frame in 500:
		await physics_frame
		guard._repath_remaining -= 1.0 / 60.0
		guard._apply_gravity(1.0 / 60.0)
		guard._navigate_to(destination, 3.4, 1.0 / 60.0)
		guard.move_and_slide()
		detour = maxf(detour, absf(guard.global_position.x))
		if guard._agent.is_navigation_finished():
			break
	_check(detour > 2.5 and Vector2(guard.position.x, guard.position.z + 3).length() < 0.7, "A pursuing guard navigates around the customs screen")
	for hound in level.guards:
		hound.active = false
		hound.player_visible = false
		hound.guard_state = StealthGuard.GuardState.PATROL
	var seals: Array[Node] = level.get_node("CargoSeals").get_children()
	seals[0].recover(guard)
	_check(level.recovered_seals.is_empty(), "Hounds cannot collect cargo seals")
	level._at_exit = true
	level._try_extract()
	_check(not level.finished, "Extraction requires all three cargo seals")
	level._at_exit = false
	# Walk the actual collision world, triggering all pickups along a full loop.
	player.global_position = Vector3(0, 0.49, 17)
	player.velocity = Vector3.ZERO
	var stops := [
		Vector3(0, 0, 3), Vector3(-3.2, 0, 2), Vector3(-3.2, 0, -3.5),
		Vector3(-4, 0, -3.5), Vector3(-10, 0, 0), Vector3(-17, 0, 0),
		Vector3(-17, 0, -10), Vector3(-14, 0, -14), Vector3(-13.5, 0, -18.5),
		Vector3(-20.5, 0, -20), Vector3(-14.5, 0, -19), Vector3(-12, 0, -18.5),
		Vector3(-10, 0, -17), Vector3(-5, 0, -17), Vector3(4, 0, -17),
		Vector3(11, 0, -17), Vector3(14, 0, -14), Vector3(21, 0, -14),
		Vector3(21, 0, -20),
	]
	var walked := true
	for stop in stops:
		if not await _walk_to(player, stop):
			walked = false
			push_error("Walking blocked toward %s; player at %s" % [stop, player.position])
			break
	_check(walked, "Player can walk the joined modules and tide bridge to all objectives")
	_check(level.recovered_seals.size() == 3, "Walking over the objectives triggers all three saved pickup areas")
	seals[0].recover(player)
	_check(level.recovered_seals.size() == 3, "Recovered objectives cannot be counted twice")
	level._at_exit = true
	level.guards[1].player_visible = true
	level._try_extract()
	_check(not level.finished, "Either guard's confirmed sight blocks extraction")
	level.guards[1].player_visible = false
	level.guards[1].guard_state = StealthGuard.GuardState.CHASE
	level._try_extract()
	_check(not level.finished, "Ongoing pursuit blocks extraction even between sightings")
	level.guards[1].guard_state = StealthGuard.GuardState.SEARCH
	level._at_exit = false
	var returned := walked
	if walked:
		for stop in [Vector3(21, 0, -14), Vector3(17, 0, -11), Vector3(17, 0, 0), Vector3(10, 0, 0), Vector3(3.3, 0, 2.3), Vector3(0, 0, 3), Vector3(0, 0, 17)]:
			if not await _walk_to(player, stop):
				returned = false
				push_error("Return blocked toward %s; player at %s" % [stop, player.position])
				break
	_check(returned and level.finished, "Walking the other arcade home completes the job at extraction")
	_check(player.interaction_locked and not level.guards[0].active and not level.guards[1].active, "Mission completion stops both patrols and player input")
	# Restart uses the same saved scene and resets every objective and guard.
	reload_current_scene()
	await process_frame
	while current_scene == null:
		await process_frame
	level = current_scene
	if not level.guards[0].navigation_ready:
		await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	for hound in level.guards:
		hound.set_physics_process(false)
	_check(not level.finished and level.recovered_seals.is_empty() and level.guards[0].active and level.guards[1].active, "Restart restores the complete two-guard encounter")
	var camera: Camera3D = level.get_node("LevelCamera")
	level.player.toggle_map()
	_check(is_equal_approx(camera.size, 58), "Overview shows the entire loop")
	level.player.toggle_map()
	_check(is_equal_approx(camera.size, 21), "Returning from overview restores the playable camera")
	var before: Vector3 = level.player.position
	Input.action_press("move_up")
	for frame in 20:
		await physics_frame
	Input.action_release("move_up")
	_check(level.player.position.distance_to(before) > 0.5, "Camera-relative movement works in the saved level")
	level.player.set_physics_process(false)
	guard = level.guards[1]
	guard.global_position = Vector3(21, 0, -15)
	guard.velocity = Vector3.ZERO
	guard._heading_yaw = 0.0
	guard._set_visual_yaw(guard.visual_forward_yaw_offset)
	guard.guard_state = StealthGuard.GuardState.CHASE
	guard.awareness = 1.0
	level.player.global_position = Vector3(21, 0.49, -15.6)
	await physics_frame
	guard._physics_process(1.0 / 60.0)
	_check(level.finished and level.player.interaction_locked, "The archive Hound's capture signal ends the encounter")
	_check(not level.guards[0].active and not level.guards[1].active, "Capture stops both guards")
	print("HARBOR CHECKS: %d passed, %d failed" % [_checks - _failures, _failures])
	level.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _walk_to(player: CharacterBody3D, destination: Vector3) -> bool:
	for frame in 700:
		await physics_frame
		var offset := destination - player.global_position
		offset.y = 0
		if offset.length() < 0.18:
			player.velocity = Vector3.ZERO
			return player.global_position.y > 0.3 and player.global_position.y < 0.8
		player.velocity = offset.normalized() * 4.2
		player.velocity.y = -2.0
		player.move_and_slide()
	return false


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
