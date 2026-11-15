extends SceneTree
var checks := 0
var failures := 0
var level: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60).timeout.connect(func(): push_error("Lamplight checks timed out"); quit(1))
	level = load("res://Levels/LamplightStore.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	var p = level.player
	p.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	var pause_key := InputEventKey.new()
	pause_key.physical_keycode = KEY_P
	pause_key.pressed = true
	level._unhandled_input(pause_key)
	_check(level.guards_paused and not level.guards[0].is_physics_processing(), "Study control pauses guard AI while leaving camera exploration available")
	level._unhandled_input(pause_key)
	_check(not level.guards_paused and level.guards[0].is_physics_processing(), "Study control resumes guard AI")
	for guard in level.guards:
		guard.set_physics_process(false)
	level.get_node("StormFlashLight").stop_flashing()
	var cam: Camera3D = p.overview_camera
	_check(level.get_node("NavigationRegion3D").navigation_mesh.get_polygon_count() > 0, "Saved encounter bakes navigation around real walls and barrels")
	_check(not p.indoors and cam.size > 26 and cam.get_cull_mask_value(19), "Courtyard starts with a wide shot and visible building shell")
	_check(await _walk_to(Vector3(0, 0, -4)), "Rook can physically walk through the archway into the building")
	_check(p.indoors and cam.size < 25 and cam.size > 15.5, "Crossing the threshold eases toward a tighter shot")
	for frame in 100:
		p._update_phase_camera()
	_check(cam.size < 15.6 and not cam.get_cull_mask_value(19), "Interior camera settles and cuts away the roof and near walls")
	var shell_culled := true
	for shell in [level.get_node("WeatherRoof"), level.get_node("NavigationRegion3D/CutawayFacade")]:
		for geometry in shell.find_children("*", "GeometryInstance3D", true, false):
			shell_culled = shell_culled and (geometry.layers & cam.cull_mask) == 0
	_check(shell_culled, "Saved imported roof and facade meshes are actually excluded by the interior camera")
	level._process(0)
	var notification_guard = level.guards[1]
	var bubble = notification_guard._suspicion_bubble
	notification_guard.awareness = 0.2
	notification_guard._change_state(StealthGuard.GuardState.SUSPICIOUS)
	bubble._physics_process(0)
	bubble._process(0)
	_check(bubble._state == 1 and not bubble._occluded and bubble._anchor.visible, "Indoor suspicious notification is visible through the camera's roof cutaway")
	notification_guard._change_state(StealthGuard.GuardState.CHASE)
	bubble._physics_process(0)
	bubble._process(0)
	_check(bubble._state == 2 and bubble._anchor.visible and bubble._art.modulate.is_equal_approx(bubble.CORAL), "Indoor pursuit displays the confirmed alert notification")
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 2
	shape.shape = box
	blocker.add_child(shape)
	var head: Vector3 = notification_guard.position + Vector3.UP * (notification_guard.eye_height + 0.65)
	blocker.position = head.lerp(cam.global_position, 0.12)
	level.add_child(blocker)
	await physics_frame
	await physics_frame
	bubble._physics_process(0)
	_check(bubble._occluded, "A normal solid obstruction still hides the notification")
	blocker.queue_free()
	await physics_frame
	notification_guard._change_state(StealthGuard.GuardState.PATROL)
	notification_guard.awareness = 0
	p.position.z = -2.0
	p._update_phase_camera()
	_check(p.indoors, "Doorway hysteresis keeps the interior shot while standing in the threshold")
	p.position.z = -1.0
	p._update_phase_camera()
	_check(not p.indoors and cam.get_cull_mask_value(19), "Leaving the threshold restores the exterior shell")
	level._process(0)
	_check(bubble.occlusion_exclusions.is_empty(), "Exterior view restores full notification occlusion")
	for frame in 100:
		p._update_phase_camera()
	_check(cam.size > 26.9, "Leaving the store smoothly restores the wide shot")
	var sensor: StealthExposureSensor = p.get_node("ExposureSensor")
	p.position = Vector3(-3, 0.49, -6)
	await physics_frame
	level.set_store_lights(true)
	sensor.refresh()
	var lit: float = sensor.exposure
	level.set_store_lights(false)
	sensor.refresh()
	_check(lit > sensor.exposed_threshold and sensor.exposure < sensor.hidden_threshold, "Switch controls real illumination and recognition exposure")
	var storm: DirectionalLight3D = level.get_node("StormFlashLight")
	storm.visible = true
	storm.light_energy = 1
	p.indoors = true
	p._update_phase_camera()
	sensor.refresh()
	_check(sensor.lightning_exposure == 0, "Camera-hidden roof still blocks indoor lightning exposure")
	p.position = Vector3(0, 0.49, 7)
	await physics_frame
	sensor.refresh()
	_check(sensor.lightning_exposure > 0.5, "The same lightning exposes Rook in the open courtyard")
	storm.visible = false
	p.position = level.get_node("LightSwitch").position
	_check(level.interact() and level.lights_on, "Physical switch interaction restores the store lighting")
	p.position = level.get_node("HideSpot").position + Vector3(0, 0, 1)
	for guard in level.guards:
		guard.player_visible = false
	_check(level.interact() and p.concealed and p.interaction_locked and not p.visual_pivot.visible, "Alcove interaction enters explicit concealment and locks movement")
	var anchor: Vector3 = p.position
	var watch = level.guards[0]
	var tracker = level.guards[1]
	_check(tracker.walk_speed > watch.walk_speed and tracker.run_speed > p.max_walk_speed, "Indoor tracker patrols faster and can outrun normal Rook movement")
	tracker._change_state(StealthGuard.GuardState.PATROL)
	tracker.awareness = 0
	tracker.player_visible = true
	tracker.recognition_strength = 1
	for frame in 27:
		tracker._update_awareness(1.0 / 60)
	_check(tracker.guard_state == StealthGuard.GuardState.SUSPICIOUS and tracker.awareness >= 0.49, "Indoor tracker builds at least half suspicion in 0.45 seconds")
	for frame in 28:
		tracker._update_awareness(1.0 / 60)
	_check(tracker.guard_state == StealthGuard.GuardState.CHASE, "Indoor tracker confirms a clear sighting within 0.9 seconds")
	tracker.player_visible = false
	tracker._change_state(StealthGuard.GuardState.PATROL)
	tracker.awareness = 0
	watch.position = anchor + Vector3(0, -0.49, 2.2)
	watch._set_visual_yaw(watch.visual_forward_yaw_offset)
	watch._sync_sight_light()
	await physics_frame
	sensor.refresh()
	_check(not watch.can_see_player(), "Ordinary watchman cannot recognize a concealed Rook at ordinary range")
	p.set_peeking(true)
	await physics_frame
	sensor.refresh()
	_check(p.peeking and p.visual_pivot.visible and p.position.z > anchor.z and watch.can_see_player(), "Peeking reveals Rook to real guard vision rather than granting immunity")
	p.set_peeking(false)
	_check(not p.peeking and p.position.is_equal_approx(anchor) and not watch.can_see_player(), "Ending peek returns to the concealed anchor")
	level.set_store_lights(false)
	watch.position = Vector3(5, 0, 4)
	tracker.position = anchor + Vector3(0, -0.49, 2.0)
	await physics_frame
	sensor.refresh()
	_check(tracker.can_see_player() and sensor.exposure < sensor.hidden_threshold, "Tracker can sense a concealed Rook nearby in darkness")
	tracker.position = anchor + Vector3(0, -0.49, 4)
	await physics_frame
	_check(not tracker.can_see_player(), "Tracker concealment exception is bounded by its close-sense radius")
	tracker.position = Vector3(-4, 0, -12)
	await physics_frame
	_check(not tracker.can_see_player(), "Solid alcove wall blocks tracker sensing")
	_check(level.interact() and not p.concealed and not p.interaction_locked, "Leaving concealment restores movement")
	p.position = level.get_node("HideSpot").position
	watch.player_visible = true
	_check(not level.interact() and not p.concealed, "Witnessed entry cannot erase a guard's confirmed sighting")
	watch.player_visible = false
	p.position = level.get_node("Ledger").position
	_check(level.interact() and level.ledger_taken and not level.get_node("Ledger").visible, "Ledger is collected through the encounter interaction")
	p.position = level.get_node("ExitMarker").position
	level._process(0)
	_check(level.escaped and not level.caught, "Returning the ledger to the courtyard completes the encounter")
	level.escaped = false
	tracker.active = true
	p.position = Vector3(3, 0.49, -9)
	tracker.position = Vector3(3, 0, -13)
	tracker.velocity = Vector3.ZERO
	tracker._heading_yaw = PI
	tracker._set_visual_yaw(PI + tracker.visual_forward_yaw_offset)
	tracker._change_state(StealthGuard.GuardState.CHASE)
	tracker.awareness = 1
	level.set_store_lights(true)
	await physics_frame
	sensor.refresh()
	var pursuit_start: Vector3 = tracker.position
	for frame in 30:
		await physics_frame
		tracker._physics_process(1.0 / 60)
	_check(tracker.position.distance_to(pursuit_start) > 0.7 and Vector2(tracker.velocity.x, tracker.velocity.z).length() > 3.2, "Real tracker pursuit accelerates beyond its former speed within half a second")
	p.enter_hide(anchor)
	tracker.position = anchor + Vector3(0, -0.49, 0.6)
	tracker.guard_state = StealthGuard.GuardState.CHASE
	tracker.awareness = 1
	await physics_frame
	tracker._physics_process(1.0 / 60)
	_check(level.caught and p.interaction_locked and not level.interact(), "Real tracker contact captures concealed Rook and ends interactions")
	print("LAMPLIGHT CHECKS: %d passed, %d failed" % [checks - failures, failures])
	level.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _walk_to(target: Vector3) -> bool:
	for frame in 600:
		await physics_frame
		var offset: Vector3 = target - level.player.position
		offset.y = 0
		if offset.length() < 0.3:
			level.player.velocity = Vector3.ZERO
			return true
		level.player.velocity = offset.normalized() * 4.2
		level.player.velocity.y = -2
		level.player.move_and_slide()
		level.player._update_phase_camera()
	return false


func _check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
