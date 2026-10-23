extends SceneTree
## Verify real storm pulses, shared guard lamps and Rook noise.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Awareness integration timed out"); quit(1))
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	var storm = level.get_node("StormFlashLight")
	storm.stop_flashing()
	var sensor: StealthExposureSensor = level.exposure_sensor
	for guard in level.guards:
		guard.set_physics_process(false)
	var coverage := {"HIDDEN": 0, "DIM": 0, "EXPOSED": 0}
	var map: RID = level.region.get_navigation_map()
	var spawn: Vector3 = level.player.position
	for x in range(-14, 15, 2):
		for z in range(-15, 16, 2):
			var at := Vector3(x, 0, z)
			var surface := NavigationServer3D.map_get_closest_point(map, at)
			if Vector2(surface.x - x, surface.z - z).length() > 0.5:
				continue
			level.player.position = at + Vector3.UP * 0.49
			sensor.refresh()
			coverage[sensor.exposure_name()] += 1
	level.player.position = spawn
	_check(coverage["HIDDEN"] > 5 and coverage["EXPOSED"] > 5, "The authored night layout contains both deep-shadow routes and exposed areas")
	print("NIGHT COVERAGE: ", coverage)
	for guard in level.guards:
		guard.has_lamp = false
		guard._sync_sight_light()
	for light in level.get_node("HarborLights").find_children("*", "Light3D", true, false):
		light.visible = false
	level.player.set_physics_process(false)
	var hound = level.get_node("Guards/CrankHound")
	var mouse = level.get_node("Guards/SortingMouse")
	hound.position = Vector3(5, 0, -1)
	hound._set_visual_yaw(hound.visual_forward_yaw_offset)
	level.player.position = Vector3(5, 0.49, -5)
	await physics_frame
	sensor.refresh()
	_check(not hound.can_see_player() and sensor.exposure_name() == "HIDDEN", "Saved scene hides stationary Rook outside all light")
	# A second guard's lamp must be available to the first guard's vision.
	mouse.position = Vector3(5, 0, -9)
	mouse.has_lamp = true
	mouse._set_visual_yaw(PI + mouse.visual_forward_yaw_offset)
	mouse._sync_sight_light()
	await physics_frame
	sensor.refresh()
	_check(hound.can_see_player() and sensor.exposure >= sensor.exposed_threshold, "A mouse's lamp can reveal Rook to a Hound with its own lamp off")
	mouse.has_lamp = false
	mouse._sync_sight_light()
	# Use the real tween-driven storm, rather than setting a test multiplier.
	storm.trigger_flash(1.0)
	var revealed := false
	var highest := 0.0
	for frame in 180:
		await physics_frame
		sensor.refresh()
		highest = maxf(highest, sensor.lightning_exposure)
		if hound.can_see_player():
			revealed = true
	_check(revealed and highest > 0.3, "A real storm pulse reveals Rook without changing the Hound's view cone")
	storm.stop_flashing()
	await physics_frame
	sensor.refresh()
	_check(sensor.exposure_name() == "HIDDEN" and not hound.can_see_player(), "Stopping the storm immediately restores shadow protection")
	# Exercise real character movement; manually moving a node cannot emit footsteps.
	for guard in level.guards:
		guard.active = false
	level.player.position = Vector3(0, 0.49, 14)
	level.player.velocity = Vector3.ZERO
	var noise: Array = []
	level.player.noise_emitted.connect(func(at: Vector3, radius: float, kind: String): noise.append([at, radius, kind]))
	level.player.set_physics_process(true)
	Input.action_press("move_right")
	for frame in 55:
		await physics_frame
	Input.action_release("move_right")
	level.player.set_physics_process(false)
	_check(noise.any(func(event): return event[2] == "FOOTSTEPS" and is_equal_approx(event[1], 5.0)), "Walking Rook emits real footstep events at the configured radius")
	var count := noise.size()
	level.player.set_physics_process(true)
	for frame in 25:
		await physics_frame
	count = noise.size()
	for frame in 45:
		await physics_frame
	_check(noise.size() == count, "Stationary Rook emits no repeated footstep events")
	# The physical Shift key must quiet the same production footstep path.
	var shift := InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	shift.pressed = true
	Input.parse_input_event(shift)
	Input.action_press("move_right")
	for frame in 100:
		await physics_frame
	Input.action_release("move_right")
	shift.pressed = false
	Input.parse_input_event(shift)
	_check(noise.any(func(event): return event[2] == "FOOTSTEPS" and is_equal_approx(event[1], 1.6)), "Shift movement emits quieter footsteps through the production input path")
	level.player.set_physics_process(false)
	# Give a real landing enough airtime to produce a noise event.
	level.player.position = Vector3(0, 3, 14)
	level.player.velocity = Vector3.ZERO
	level.player.set_physics_process(true)
	for frame in 120:
		await physics_frame
	_check(noise.any(func(event): return event[2] == "LANDING" and is_equal_approx(event[1], 7.5)), "Landing emits a separate louder noise event")
	print("AWARENESS INTEGRATION: %d passed, %d failed" % [checks - failures, failures])
	level.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
