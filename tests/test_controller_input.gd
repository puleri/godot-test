extends SceneTree
## Exercise actual joypad events through InputMap and paused opening UI.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Input.use_accumulated_input = false
	create_timer(60).timeout.connect(func(): quit(1))
	_check(_key(KEY_SHIFT).is_action("quiet_walk"), "Shift retains quiet walking")
	_check(_key(KEY_TAB).is_action("toggle_vision"), "Tab retains vision toggle")
	_check(_key(KEY_ENTER).is_action("dialogue_advance"), "Enter retains dialogue advance")
	_check(_key(KEY_KP_ENTER).is_action("dialogue_advance"), "Keypad Enter retains dialogue advance")
	for pair in [[JOY_BUTTON_A, "jump"], [JOY_BUTTON_B, "interact"], [JOY_BUTTON_Y, "secondary_action"], [JOY_BUTTON_LEFT_SHOULDER, "quiet_walk"], [JOY_BUTTON_BACK, "toggle_map"], [JOY_BUTTON_LEFT_STICK, "toggle_vision"], [JOY_BUTTON_RIGHT_SHOULDER, "sprint"]]:
		var event := _button(pair[0], true)
		_check(event.is_action_pressed(pair[1]), "Joypad maps to " + pair[1])
		Input.parse_input_event(event)
		_check(Input.is_action_pressed(pair[1]), "Held joypad activates " + pair[1])
		Input.parse_input_event(_button(pair[0], false))
		_check(not Input.is_action_pressed(pair[1]), "Release clears " + pair[1])
	for pair in [[JOY_AXIS_LEFT_X, 0.1], [JOY_AXIS_LEFT_X, 0.6], [JOY_AXIS_LEFT_Y, -1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis = pair[0]
		event.axis_value = pair[1]
		Input.parse_input_event(event)
		var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if pair[1] == 0.1:
			_check(movement.is_zero_approx(), "Small stick drift stays inside deadzone")
		elif pair[1] == 0.6:
			_check(movement.x > 0 and movement.x < 1, "Stick preserves partial movement strength")
		else:
			_check(movement.y < -0.99, "Up on stick moves forward")
		var neutral := InputEventJoypadMotion.new()
		neutral.axis = pair[0]
		Input.parse_input_event(neutral)
	Input.parse_input_event(_button(JOY_BUTTON_DPAD_LEFT, true))
	_check(Input.get_axis("move_left", "move_right") == -1, "D-pad moves left")
	Input.parse_input_event(_button(JOY_BUTTON_DPAD_LEFT, false))
	await _check_free_movement()
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.establishing_shot_duration = 30.0
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	_check(paused and level._establishing_shot.active, "Opening cinematic is paused")
	await _tap(JOY_BUTTON_A)
	_check(level._dialogue != null and level._dialogue.active, "Cross skips cinematic into dialogue")
	_check(level._dialogue.line_index == 0 and level._dialogue._revealing, "Cinematic skip does not also advance dialogue")
	for index in 4:
		await _tap(JOY_BUTTON_A)
		_check(not level._dialogue._revealing and level._dialogue.line_index == index, "Cross reveals dialogue line %d" % index)
		await _tap(JOY_BUTTON_A)
	await create_timer(0.25, true).timeout
	_check(not paused and not level.player.interaction_locked, "Cross finishes dialogue and restores movement")
	_check(absf(level.player.velocity.y) < 1, "Closing dialogue does not leak a jump")
	var mode: int = level.display_mode
	await _tap(JOY_BUTTON_LEFT_STICK)
	_check(level.display_mode != mode, "L3 cycles gameplay HUD and vision")
	var pause_menu = root.get_node("ControllerPause")
	await _tap(JOY_BUTTON_START)
	_check(paused and pause_menu.active, "Options pauses gameplay and opens the controller guide")
	await _tap(JOY_BUTTON_A)
	await create_timer(0.2, true).timeout
	_check(not paused and not pause_menu.active, "Cross resumes from pause")
	_check(absf(level.player.velocity.y) < 1, "Resume press does not leak a jump")
	level.player.set_physics_process(false)
	Input.parse_input_event(_button(JOY_BUTTON_LEFT_SHOULDER, true))
	Input.parse_input_event(_button(JOY_BUTTON_DPAD_RIGHT, true))
	for frame in 30:
		level.player.handle_phase_1_movement(1.0 / 60)
	var quiet_speed: float = Vector2(level.player.velocity.x, level.player.velocity.z).length()
	Input.parse_input_event(_button(JOY_BUTTON_LEFT_SHOULDER, false))
	for frame in 30:
		level.player.handle_phase_1_movement(1.0 / 60)
	var normal_speed: float = Vector2(level.player.velocity.x, level.player.velocity.z).length()
	Input.parse_input_event(_button(JOY_BUTTON_RIGHT_SHOULDER, true))
	for frame in 40:
		level.player.handle_phase_1_movement(1.0 / 60)
	var run_speed: float = Vector2(level.player.velocity.x, level.player.velocity.z).length()
	_check(is_equal_approx(run_speed, normal_speed * 1.5), "R1 runs at 150 percent of normal speed")
	Input.parse_input_event(_button(JOY_BUTTON_RIGHT_SHOULDER, false))

	_check(quiet_speed > 0 and quiet_speed < normal_speed * 0.7, "L1 reduces actual player movement speed")
	Input.parse_input_event(_button(JOY_BUTTON_DPAD_RIGHT, false))
	level.set_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
		guard.position = Vector3(100, 0, 100)
		guard.guard_state = StealthGuard.GuardState.PATROL
	var station = level.get_node("Stations").get_child(0)
	level.player.position = station.position
	Input.parse_input_event(_button(JOY_BUTTON_B, true))
	level._update_interaction(0.1)
	_check(station.progress > 0, "Holding Circle advances an actual objective")
	Input.parse_input_event(_button(JOY_BUTTON_B, false))
	level._update_interaction(0.1)
	_check(station.progress == 0, "Releasing Circle interrupts objective work")
	level.queue_free()
	await process_frame
	print("CONTROLLER INPUT: %d failures" % failures)
	quit(1 if failures else 0)

func _tap(button: JoyButton) -> void:
	Input.parse_input_event(_button(button, true))
	await process_frame
	Input.parse_input_event(_button(button, false))
	await process_frame

func _button(button: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _check_free_movement() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var camera := Camera3D.new()
	fixture.add_child(camera)
	for script_path in ["res://scripts/player_controller.gd", "res://scripts/player_controller_SideScroll.gd"]:
		var player = load("res://scenes/Player_v2.tscn").instantiate()
		player.set_script(load(script_path))
		fixture.add_child(player)
		player.set_physics_process(false)
		camera.make_current()
		var directions_ok := true
		var facing_ok := true
		var speed_ok := true
		for yaw in [0.0, 0.7, 1.66, -2.2]:
			camera.rotation = Vector3(-0.55, yaw, 0)
			var right := Vector3(cos(yaw), 0, -sin(yaw))
			var back := Vector3(sin(yaw), 0, cos(yaw))
			for phase in [0, 1]:
				player.current_phase = phase
				player.rotation.y = 0.43
				for angle in range(0, 360, 5):
					var stick := Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle)))
					_stick(stick)
					var expected := right * stick.x + back * stick.y
					var direction: Vector3 = player.handle_phase_1_movement(0.1) if phase == 0 else player.handle_phase_2_movement(0.1)
					directions_ok = directions_ok and player.controller_movement_active and direction.distance_to(expected) < 0.001
					for step in 10:
						if phase == 0: player.handle_phase_1_movement(0.1)
						else: player.handle_phase_2_movement(0.1)
					speed_ok = speed_ok and absf(Vector2(player.velocity.x, player.velocity.z).length() - player.max_walk_speed) < 0.001
					player._update_facing(direction)
					if player.has_method("_update_visual_turn"): player._update_visual_turn(1.0)
					var facing: Vector3 = player.visual_pivot.global_basis.x
					facing_ok = facing_ok and facing.normalized().dot(expected.normalized()) > 0.99
		_check(directions_ok, "360-degree movement follows the active camera in both phases: " + script_path.get_file())
		_check(speed_ok, "Diagonal and arbitrary angles retain equal speed: " + script_path.get_file())
		_check(facing_ok, "Rook faces the exact travel direction: " + script_path.get_file())
		_stick(Vector2(0.3, -0.6))
		var partial: Vector3 = player.handle_phase_1_movement(0.1)
		_check(partial.x != 0 and partial.z != 0 and partial.length() < 1, "Partial diagonal stick tilt retains both axes and analog strength")
		_stick(Vector2.ZERO)
		player.velocity = Vector3(2, 0, 2)
		player.handle_phase_1_movement(0.01)
		_check(player.velocity.x > 0 and player.velocity.z > 0, "Releasing the stick brakes both axes without snapping to cardinal")
		for step in 30: player.handle_phase_1_movement(0.1)
		_check(player.velocity.length() < 0.001, "Stick release comes to rest")
		var key := _key(KEY_D)
		Input.parse_input_event(key)
		_check(not player.controller_movement_active, "Keyboard movement restores the existing keyboard controls")
		key = _key(KEY_D)
		key.pressed = false
		Input.parse_input_event(key)
		_stick(Vector2(0.15, -0.15))
		_check(player.controller_movement_active and player.handle_phase_1_movement(0.1).length() > 0, "A gentle diagonal crosses the radial deadzone without cardinal activation")
		_stick(Vector2.ZERO)
		player.queue_free()
		await process_frame
	fixture.queue_free()
	await process_frame

func _stick(value: Vector2) -> void:
	for pair in [[JOY_AXIS_LEFT_X, value.x], [JOY_AXIS_LEFT_Y, value.y]]:
		var event := InputEventJoypadMotion.new()
		event.axis = pair[0]
		event.axis_value = pair[1]
		Input.parse_input_event(event)
