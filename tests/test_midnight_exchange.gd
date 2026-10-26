extends SceneTree
## Integration checks against the saved collision world and running guard AI.

var checks := 0
var failures := 0
var level: Node3D

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(100).timeout.connect(func(): push_error("Exchange tests timed out"); quit(1))
	level = load("res://Levels/MidnightExchange.tscn").instantiate()
	var test_coin = load("res://Mesh/Treasure/coin.tscn").instantiate()
	test_coin.position = Vector3(0, 100, 0)
	level.add_child(test_coin)
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	level.set_process(false)
	var player = level.player
	player.set_physics_process(false)
	_check(_display_matches(true, false), "The encounter starts with HUD only")
	await _press_tab()
	_check(_display_matches(true, true), "Tab shows the HUD and every guard's vision")
	await _press_tab()
	_check(_display_matches(false, true), "Tab hides all screen/world UI while keeping guard vision")
	await _press_tab()
	_check(_display_matches(false, false), "Tab hides all HUD, labels, markers and guard vision")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_TAB
	echo.pressed = true
	echo.echo = true
	Input.parse_input_event(echo)
	await process_frame
	_check(_display_matches(false, false), "Holding Tab does not skip display modes")
	await _press_tab()
	_check(level.display_mode == level.DisplayMode.STYLED_HUD and level._styled_hud.visible and _display_matches(false, false), "Tab selects Styled HUD without world labels or vision")
	var styled_eye = level._styled_hud.get_node("Control/EyeAnchor/AlertEye")
	_check(styled_eye.is_visible_in_tree() and level._styled_hud.get_node("Control/CoinIcon/CoinCount").is_visible_in_tree(), "Styled HUD shows the suspicion eye and coin counter")
	test_coin.collected()
	test_coin.collected()
	_check(level._styled_hud.coins_collected == 1 and level._styled_hud.coin_count.text == "x 01", "Styled counter tracks real coin pickups exactly once")
	await _press_tab()
	_check(level._styled_hud.coins_collected == 1, "Coin count survives changing HUD options")
	_check(_display_matches(true, false) and not level._styled_hud.visible, "Tab wraps to HUD only and key release does not advance it")
	_check(player.position.distance_to(Vector3(0, 0.49, 14)) < 0.1, "Rook starts inside the protected exit court")
	_check(level.guards.size() == 3 and level.get_node("Guards/SortingMouse/VisualPivot/Model").scene_file_path.contains("mouse_v2"), "Saved encounter includes two real mouse models and one Hound")
	_check(level.region.navigation_mesh.get_polygon_count() > 0, "Saved geometry bakes a navigation surface")
	var map: RID = level.region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map, player.position)
	for target in [Vector3(-12, 0, 0), Vector3(12, 0, 0), Vector3(0, 0, -14)]:
		var end := NavigationServer3D.map_get_closest_point(map, target)
		var path := NavigationServer3D.map_get_path(map, start, end, true)
		_check(not path.is_empty() and path[-1].distance_to(end) < 0.1, "Navigation connects the exit to %s" % target)
	var reference = load("res://Levels/Demo_A2.tscn").instantiate()
	var lamp = level.get_node("HarborLights/ExchangeLamp_01")
	_check(lamp.light_energy == reference.get_node("SpotLight3D").light_energy and lamp.spot_range == reference.get_node("SpotLight3D").spot_range, "Fixed lamps retain Demo_A2 energy and range")
	_check(level.get_node("StormFlashLight").get_script() == reference.get_node("StormFlashLight").get_script(), "Demo_A2 lightning and audio script are reused")
	reference.free()
	var visited := [{}, {}, {}]
	for frame in 2600:
		await physics_frame
		for i in level.guards.size():
			var guard = level.guards[i]
			for j in guard._points.size():
				if guard.position.distance_to(guard._points[j].position) < 0.4:
					visited[i][j] = true
	for i in 3:
		_check(visited[i].size() == 4, "%s completes its four-corner patrol" % level.guards[i].name)
		level.guards[i].set_physics_process(false)
	var mouse = level.guards[0]
	var hound = level.guards[1]
	_check(mouse.field_of_view_degrees > hound.field_of_view_degrees and mouse.sight_range < hound.sight_range and mouse.seconds_to_detect < hound.seconds_to_detect, "Mice have wider, shorter sight and faster detection than the Hound")
	mouse.position = Vector3(-7, 0, 2)
	mouse._set_visual_yaw(PI / 2 + mouse.visual_forward_yaw_offset)
	player.position = Vector3(-11, 0.49, 2)
	await physics_frame
	_check(not mouse.can_see_player(), "The sorting screen blocks a mouse's real sight ray")
	player.position = Vector3(-7.8, 0.49, 2)
	await physics_frame
	_check(mouse.can_see_player(), "The mouse detects an exposed Rook in its beam")
	mouse._pause_remaining = 1.6
	mouse._update_feedback(0.016)
	_check(mouse._state_label.text.contains("MOVES IN"), "Guard pauses expose readable countdowns")
	# Physical walk through both wings and both vault doors, with threats paused.
	player.position = Vector3(0, 0.49, 14)
	var stops := [Vector3(-6, 0, 13), Vector3(-6, 0, 6), Vector3(-12, 0, 6), Vector3(-12, 0, 0), Vector3(-12, 0, 6), Vector3(-5, 0, 8), Vector3(5, 0, 8), Vector3(12, 0, 6), Vector3(12, 0, 0), Vector3(5, 0, 0), Vector3(5, 0, -6), Vector3(4, 0, -14), Vector3(0, 0, -14), Vector3(-5, 0, -14), Vector3(-5, 0, -6), Vector3(-5, 0, 8), Vector3(-6, 0, 13), Vector3(0, 0, 14)]
	var walked := true
	for stop in stops:
		if not await _walk_to(stop):
			walked = false
			push_error("Blocked toward %s from %s" % [stop, player.position])
			break
	_check(walked, "Rook physically walks the complete two-wing loop, both vault doors and return route")
	var stations = level.get_node("Stations").get_children()
	for guard in level.guards:
		guard.player_visible = false
		guard.guard_state = StealthGuard.GuardState.PATROL
	player.position = stations[2].position + Vector3.UP * 0.49
	level._update_interaction(4.0, true)
	_check(level.stage == 0 and not stations[2].completed, "The vault requires the manifest and crank first")
	player.position = stations[0].position + Vector3.UP * 0.49
	level._update_interaction(1.0, true)
	_check(stations[0].progress > 0 and level.stage == 0, "Work takes time rather than collecting on contact")
	level._update_interaction(0.1, false)
	_check(stations[0].progress == 0, "Releasing E resets interrupted work")
	mouse.player_visible = true
	level._update_interaction(3.0, true)
	_check(level.stage == 0, "A guard's sight blocks objective work")
	mouse.player_visible = false
	level._update_interaction(2.0, true)
	_check(level.stage == 1 and stations[0].completed, "A full clear interaction copies the manifest")
	player.position = stations[1].position + Vector3.UP * 0.49
	hound.position = Vector3(14, 0, 2)
	level._update_interaction(3.0, true)
	_check(level.stage == 1 and not stations[1].guard_is_clear(), "The Hound's normal circuit prevents working the crank")
	# The real Hound must hear the bell and navigate around the crank screen.
	player.position = Vector3(5, 0.49, 6)
	hound.position = Vector3(14, 0, 2)
	hound.velocity = Vector3.ZERO
	_check(level.ring_nearest_bell() and hound.investigating_noise, "Q at the east bell draws the Hound from its post")
	_check(not level.ring_nearest_bell(), "Bell cooldown prevents noise spam")
	hound.set_physics_process(true)
	var kited := await _walk_to(Vector3(5, 0, 0)) and await _walk_to(Vector3(12, 0, 0))
	for frame in 240:
		await physics_frame
		level._update_interaction(1.0 / 60.0, true)
		if level.stage == 2 or level.finished:
			break
	_check(kited and level.stage == 2 and not level.finished, "Rook physically kites the live Hound around the screen and works the crank in time")
	var reached := false
	for frame in 900:
		await physics_frame
		if hound._search_arrived and hound.position.distance_to(Vector3(5, 0, 6)) < 0.8:
			reached = true
			break
	_check(reached, "Lured Hound navigates around solid cover to the bell")
	_check(stations[1].guard_is_clear(), "The bell creates a real opening at the crank")
	hound.set_physics_process(false)
	for guard in level.guards:
		guard.player_visible = false
		guard.guard_state = StealthGuard.GuardState.SEARCH
	player.position = stations[2].position + Vector3.UP * 0.49
	level._update_interaction(2.7, true)
	_check(level.stage == 3, "The vault interaction recovers the night seal")
	player.position = level.get_node("Extraction").position + Vector3.UP * 0.49
	mouse.guard_state = StealthGuard.GuardState.CHASE
	level.try_extract()
	_check(not level.finished, "Extraction is blocked by ongoing pursuit")
	mouse.guard_state = StealthGuard.GuardState.SEARCH
	for i in 3:
		await _press_tab()
	level.try_extract()
	_check(level.finished and player.interaction_locked, "All three stages and a clear exit complete the encounter")
	_check(level._result.visible and not level._result.is_visible_in_tree(), "Finishing in hidden mode keeps the result UI hidden")
	await _press_tab()
	_check(level._result.is_visible_in_tree() and level._styled_hud.visible and _display_matches(false, false), "Styled HUD reveals the result after the run has finished")
	_check(not styled_eye.is_processing(), "Completion freezes the styled eye too")
	await _press_tab()
	_check(level._result.is_visible_in_tree() and _display_matches(true, false), "Standard HUD also retains the result")
	_check(not hound.active and not mouse.active, "Completion stops every guard")
	var camera: Camera3D = level.get_node("LevelCamera")
	var before := camera.position
	player.position.x += 3
	for frame in 60:
		player._update_phase_camera()
	_check(camera.position.distance_to(before) > 1 and is_equal_approx(camera.size, 9.4), "The camera follows Rook at a zoom tighter than Demo_A2")
	level.queue_free()
	await process_frame
	# A fresh run must reset the ordered stations and bell cooldown.
	level = load("res://Levels/MidnightExchange.tscn").instantiate()
	root.add_child(level)
	await level.ready_for_play
	_check(level.stage == 0 and level.bell_cooldown == 0 and not level.finished, "Restart restores objectives, bells and active play")
	_check(_display_matches(true, false) and not level._styled_hud.visible and level._styled_hud.coins_collected == 0, "Restart restores default HUD and resets styled coins")
	level.set_process(false)
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	mouse = level.guards[0]
	mouse.position = Vector3(-12, 0, 0)
	mouse._set_visual_yaw(mouse.visual_forward_yaw_offset)
	mouse.guard_state = StealthGuard.GuardState.CHASE
	mouse.awareness = 1.0
	level.player.position = Vector3(-12, 0.49, -0.35)
	await physics_frame
	mouse._physics_process(1.0 / 60.0)
	_check(level.finished and level.player.interaction_locked, "A real mouse guard catches Rook and locks movement")
	print("MIDNIGHT EXCHANGE CHECKS: %d passed, %d failed" % [checks - failures, failures])
	level.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _press_tab() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_TAB
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_TAB
	Input.parse_input_event(event)
	await process_frame


func _display_matches(hud_visible: bool, vision_visible: bool) -> bool:
	if level._objective.is_visible_in_tree() != hud_visible:
		return false
	for label in level.find_children("*", "Label3D", true, false):
		if label.is_visible_in_tree() != hud_visible:
			return false
	for marker_name in ["Ring", "Pulse", "PlayerMarker"]:
		for marker in level.find_children(marker_name, "MeshInstance3D", true, false):
			if (marker.layers != 0) != hud_visible:
				return false
	for guard in level.guards:
		if guard.show_vision != vision_visible or guard._vision_instance.visible != vision_visible:
			return false
		if guard._last_seen_marker.visible != (vision_visible and guard.guard_state == StealthGuard.GuardState.SEARCH):
			return false
	return true


func _walk_to(destination: Vector3) -> bool:
	for frame in 450:
		await physics_frame
		var offset := destination - level.player.position as Vector3
		offset.y = 0
		if offset.length() < 0.18:
			level.player.velocity = Vector3.ZERO
			return level.player.position.y > 0.3 and level.player.position.y < 0.8
		level.player.velocity = offset.normalized() * 4.2
		level.player.velocity.y = -2
		level.player.move_and_slide()
	return false


func _check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
