extends SceneTree
var failures := 0
var checks := 0
var level: Node3D
func _initialize() -> void:
	_run.call_deferred()
func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
	print("PASS " if condition else "FAIL ",message)
func _run() -> void:
	create_timer(300).timeout.connect(func(): push_error("Night city test timeout"); quit(1))
	level = load("res://Levels/NocturneCity.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	level.set_process(false)
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	_check(level.get_meta("footprint").x*level.get_meta("footprint").y == 20*32*34,"City footprint is exactly twenty times Midnight Exchange")
	_check(level.get_node("Districts").get_child_count() == 9,"Nine named canal districts are saved")
	_check(level.guards.size() == 15,"Fifteen real Hound and Mouse watchmen have patrol routes")
	_check(level.get_node("Bells").get_child_count() == 9,"Every district has a distraction bell")
	var region: NavigationRegion3D = level.get_node("NavigationRegion3D")
	_check(region.navigation_mesh.get_polygon_count() > 100,"Navigation is baked into the saved scene")
	var map := region.get_navigation_map()
	var start := NavigationServer3D.map_get_closest_point(map,level.player.position)
	for marker in level.get_node("Districts").get_children():
		_check(_reachable(map,start,marker.position),"Street route reaches "+str(marker.get_meta("title")))
	for station in level.get_node("Stations").get_children():
		_check(_reachable(map,start,station.position),"A walking route reaches seal "+station.title)
	for guard in level.guards:
		var route_ok := true
		for marker in guard._points:
			var closest := NavigationServer3D.map_get_closest_point(map,marker.global_position)
			if Vector2(closest.x-marker.global_position.x,closest.z-marker.global_position.z).length() > 0.8 or absf(closest.y-marker.global_position.y) > 0.8:
				route_ok = false
		_check(route_ok,str(guard.name)+" patrol corners rest on the navigation surface")
	# Every guard must physically complete its own circuit, including roof bridges.
	var visited: Array[Dictionary] = []
	for guard in level.guards:
		visited.append({})
		guard.process_mode = Node.PROCESS_MODE_INHERIT
		guard._player = null
		guard.set_physics_process(true)
	for frame in 6500:
		await physics_frame
		for i in level.guards.size():
			var guard = level.guards[i]
			for j in guard._points.size():
				if guard.position.distance_to(guard._points[j].global_position) < 0.45:
					visited[i][j] = true
	for i in level.guards.size():
		var guard = level.guards[i]
		if visited[i].size() != guard._points.size():
			print("PATROL_DETAIL ",guard.name," visited ",visited[i]," at ",guard.position," target ",guard._target_index," velocity ",guard.velocity)
		_check(visited[i].size() == guard._points.size(), str(guard.name)+" physically completes every patrol leg")
		guard.set_physics_process(false)
		guard._player = level.player
	# Distant characters sleep with their animation branches; nearby watch stays awake.
	level.player.position = Vector3(0,0.49,64)
	level._update_activity()
	_check(level.guards[-1].process_mode == Node.PROCESS_MODE_DISABLED and level.guards[2].process_mode == Node.PROCESS_MODE_INHERIT,"Guard activity follows the player's district")
	var map_key := InputEventKey.new()
	map_key.physical_keycode = KEY_M
	map_key.pressed = true
	level._input(map_key)
	_check(level.map_open and level.player.interaction_locked and level.guards[2].process_mode == Node.PROCESS_MODE_DISABLED,"The atlas pauses Rook and watch simulation")
	level._input(map_key)
	_check(not level.map_open and not level.player.interaction_locked,"Closing the atlas resumes play")
	# The main canals contain water and no invisible ground collision.
	var hit := level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(28,10,12),Vector3(28,-4,12),1))
	_check(hit.is_empty(),"Canal gaps have no hidden floor")
	level.player.position = Vector3(0,0.49,64)
	# Start in the central island to physically exercise both stair ramps.
	level.player.position = Vector3(21,0.49,18)
	level.player.velocity = Vector3.ZERO
	var stairs_ok := await _walk_to(Vector3(21,3,10),false) and await _walk_to(Vector3(21,6,2),false)
	_check(stairs_ok and level.player.position.y > 6.2,"Rook physically climbs both flights to +6m")
	var upper_ok := await _walk_to(Vector3(21,6,-10),false) and await _walk_to(Vector3(17,6,-10),false) and await _walk_to(Vector3(17,6,-12),false) and await _walk_to(Vector3(-12,6,-12),false)
	_check(upper_ok,"Rook crosses the rooftop bridge between buildings")
	level.player.position = Vector3(-10,6.49,-1.5)
	level.player.velocity = Vector3(0,7,5)
	var jumped_gap := false
	for frame in 75:
		level.player.velocity.z = 5
		level.player.velocity.y -= 24.0/60
		level.player.move_and_slide()
		await physics_frame
		if level.player.position.z > 1.1 and level.player.is_on_floor() and level.player.position.y > 6.2:
			jumped_gap = true
			break
	_check(jumped_gap,"Rook physically jumps the 1.8m broken rooftop crossing")
	level.player.position = Vector3(0,0.49,48)
	level.player.velocity = Vector3.ZERO
	var bridge_ok := await _walk_to(Vector3(56,0,48),false)
	_check(bridge_ok,"Rook physically crosses a district canal bridge")
	for guard in level.guards:
		guard.player_visible = false
		guard.guard_state = StealthGuard.GuardState.PATROL
	var station = level.get_node("Stations").get_child(0)
	level.player.position = station.position + Vector3.UP*0.49
	level._update_interaction(1,true)
	_check(station.progress > 0 and not station.completed,"Seals require a sustained interaction")
	level._update_interaction(0.1,false)
	_check(station.progress == 0,"Interrupted interactions reset")
	for objective in level.get_node("Stations").get_children():
		level.player.position = objective.position + Vector3.UP*0.49
		level._update_interaction(2.2,true)
	_check(level.collected == 5,"All five seals can be recovered across elevations")
	level.checkpoint = Vector3(-56,0.49,48)
	level.player.position = Vector3(28,-5,12)
	level.recover_from_fall()
	_check(level.player.position == level.checkpoint and level.collected == 5,"Falls restore the safe checkpoint and preserve recovered seals")
	level.player.position = Vector3(0,0.49,64)
	level.guards[0].guard_state = StealthGuard.GuardState.CHASE
	level.try_extract()
	_check(not level.finished,"Extraction requires escaping pursuit")
	level.guards[0].guard_state = StealthGuard.GuardState.PATROL
	level.try_extract()
	_check(level.finished and level.won and level.player.interaction_locked,"Returning to the quay completes the night")
	print("NIGHT_CITY_TESTS ",checks-failures,"/",checks)
	level.free()
	quit(1 if failures else 0)
func _reachable(map: RID, start: Vector3, target: Vector3) -> bool:
	var end := NavigationServer3D.map_get_closest_point(map,target)
	if absf(end.y-target.y) > 0.8 or Vector2(end.x-target.x,end.z-target.z).length() > 1:
		return false
	var path := NavigationServer3D.map_get_path(map,start,end,true)
	return not path.is_empty() and path[-1].distance_to(end)<0.1
func _walk_to(target: Vector3, jump: bool) -> bool:
	var player = level.player
	for frame in 1600:
		var offset: Vector3 = target-player.position
		offset.y = 0
		if offset.length() < 0.3:
			player.velocity = Vector3.ZERO
			return true
		player.velocity.x = offset.normalized().x*4.0
		player.velocity.z = offset.normalized().z*4.0
		player.velocity.y = -1 if player.is_on_floor() else player.velocity.y-24.0/60
		if jump and player.is_on_floor():
			player.velocity.y = 7
		player.move_and_slide()
		await physics_frame
	push_error("Walk blocked at %s toward %s" % [player.position,target])
	return false
