extends SceneTree
## Drive the playable route through the scene's real input and physics.
## godot --headless --fixed-fps 60 --script res://tests/test_tidewatch.gd

var level: Node3D
var player: CharacterBody3D
var failed := false


func _initialize() -> void:
	call_deferred("run")


func tick(frames: int) -> void:
	for i in frames:
		await physics_frame


func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		print("FAIL ", message, " at ", player.position)
		failed = true


func key(code: Key) -> void:
	var button := InputEventKey.new()
	button.physical_keycode = code
	button.pressed = true
	Input.parse_input_event(button)
	await tick(2)
	button = InputEventKey.new()
	button.physical_keycode = code
	Input.parse_input_event(button)
	await tick(2)


func go(to: float, frames := 210) -> void:
	Input.action_press("move_right")
	for i in frames:
		if player.position.x >= to or level.caught:
			break
		await tick(1)
	Input.action_release("move_right")
	await tick(6)
	check(player.position.x >= to and not level.caught, "walk to x %.2f" % to)


func jump_to(to: float) -> void:
	Input.action_press("move_right")
	await tick(2)
	Input.action_press("jump")
	await tick(2)
	Input.action_release("jump")
	for i in 65:
		if player.position.x >= to or level.caught:
			break
		await tick(1)
	Input.action_release("move_right")
	await tick(12)
	check(player.position.x >= to and player.is_on_floor() and not level.caught, "jump to x %.2f" % to)


func lean_open(index: int) -> void:
	var door: Node3D = level.dock.doors[index]
	Input.action_press("move_right")
	for i in 30:
		if player.leaning:
			break
		await tick(1)
	var contact_x := player.position.x
	await tick(10)
	check(player.leaning and not door.opened and door.progress > 0, "walking into shutter %d starts a peek" % index)
	check(absf(player.position.x - contact_x) < 0.1, "Rook plants his feet during the peek")
	Input.action_release("move_right")
	await tick(18)
	check(not player.leaning and not door.opened and is_zero_approx(door.progress), "releasing movement closes the cracked shutter")
	Input.action_press("move_right")
	for i in 60:
		if player.position.x > door.position.x + 0.2:
			break
		await tick(1)
	Input.action_release("move_right")
	await tick(2)
	check(door.opened and player.position.x > door.position.x, "continued movement opens and crosses shutter %d" % index)


func click_lamp(index: int) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = level.camera.unproject_position(level.dock.lamps[index].position)
	click.pressed = true
	root.push_input(click, true)
	await tick(2)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)


func run() -> void:
	change_scene_to_file("res://Levels/Tidewatch.tscn")
	await scene_changed
	level = current_scene
	player = level.player
	await tick(25)
	var guards := level.get_node("Guards").get_children()
	check(player.is_on_floor(), "Rook is grounded")
	check(is_equal_approx(player.max_walk_speed, 4.2) and is_equal_approx(guards[0].run_speed, 4.6) and is_equal_approx(guards[0].walk_speed, 0.8), "shared movement values")
	check(NavigationServer3D.map_get_path(guards[0]._agent.get_navigation_map(), Vector3(11, 0, 0), Vector3(6.35, 0, 0), true).size() > 1, "guard has connected navigation")
	await go(0.64)
	await click_lamp(0)
	await tick(22)
	check(level.dock.lamps[0].collision_layer == 8, "shutter occludes actual mouse shot")
	await key(KEY_E)
	check(not level.lever_pulled, "cannot use winch remotely")
	await lean_open(0)
	await key(KEY_F)
	await tick(22)
	check(level.dock.lamps[0].collision_layer == 0, "slingshot breaks warehouse lamp")
	await go(2.4)
	await jump_to(3.55)
	check(player.position.y > 1.1, "Rook lands on the step")
	await go(3.91)
	await jump_to(5.65)
	check(player.position.y > 2.20, "Rook lands on the catwalk")
	await key(KEY_F)
	await tick(25)
	check(level.dock.lamps[1].collision_layer == 0, "second warehouse lamp breaks")
	await go(16.85)
	await lean_open(1)
	var pump = guards[1]
	await click_lamp(2)
	await tick(22)
	check(level.dock.lamps[2].collision_layer == 0, "mouse aim breaks pump lamp")
	check(pump.guard_state == StealthGuard.GuardState.SEARCH, "Hound searches after breaking glass")
	for i in 320:
		if pump.position.z < -1.42:
			break
		await tick(1)
	check(pump.position.z < -1.42, "investigation clears side-scrolling lane")
	Input.action_press("quiet_walk")
	await go(22.42)
	Input.action_release("quiet_walk")
	await go(23.69)
	await jump_to(25.6)
	await go(26.64)
	await key(KEY_F)
	await tick(20)
	await key(KEY_E)
	check(level.lever_pulled and level.dock.escape_gate.opened, "winch raises floodgate")
	await go(35.6)
	check(level.escaped, "arrival at east quay clears scene")
	await key(KEY_R)
	check(current_scene != level and not current_scene.escaped and not current_scene.dock.doors[0].opened, "restart resets encounter")
	level = current_scene
	player = level.player
	player.position = Vector3(6.25, 2.3, 0.0)
	await tick(15)
	check(level.sensor.exposure >= level.sensor.exposed_threshold, "lit catwalk exposes Rook")
	await click_lamp(0)
	await tick(24)
	check(level.sensor.exposure <= level.sensor.hidden_threshold, "breaking the lamp immediately restores shadow")
	player.position = level.get_node("Guards/PumpWatch").position + Vector3(0.25, 0.49, 0)
	await tick(130)
	check(level.caught and player.interaction_locked, "close contact triggers capture and locks movement")
	# Fixed FPS can run the whole encounter faster than the audio thread drains.
	await create_timer(0.2, true, false, true).timeout
	unload_current_scene()
	await tick(10)
	quit(int(failed))
