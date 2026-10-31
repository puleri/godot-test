extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.play_establishing_shot = false
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	var dialogue = level._dialogue
	_check(paused and level.player.interaction_locked and dialogue.active, "Opening pauses gameplay and locks Rook")
	var start: Vector3 = level.player.position
	var guard_start: Vector3 = level.guards[0].position
	for frame in 20:
		await process_frame
	_check(level.player.position == start and level.guards[0].position == guard_start and level.elapsed == 0.0, "Player, patrols and encounter clock remain paused")
	_check(dialogue.lines.size() == 4, "All four lines are present")
	for index in 4:
		_check(dialogue._body.text == level.OPENING_DIALOGUE[index].text and dialogue._speaker.text == level.OPENING_DIALOGUE[index].speaker, "Exact speaker and text for line %d" % index)
		await _space()
		_check(dialogue.line_index == index and not dialogue._revealing, "First Space reveals without skipping")
		if OS.get_cmdline_user_args().has("--preview"):
			await create_timer(0.35, true).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/midnight-dialogue-%d.png" % index)
		if index == 0 and OS.get_cmdline_user_args().has("--preview"):
			root.size = Vector2i(960, 600)
			await create_timer(0.2, true).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/midnight-dialogue-small.png")
			root.size = Vector2i(1440, 900)
			await process_frame
		await _space()
	if OS.get_cmdline_user_args().has("--preview"):
		root.size = Vector2i(960, 600)
	await create_timer(0.25, true).timeout
	_check(not paused and not level.player.interaction_locked, "Final Space closes dialogue and restores play")
	_check(level._hud_layer.visible and level._objective.is_visible_in_tree(), "Gameplay HUD returns after dialogue")
	_check(level.stage == 0 and not level.finished, "Dialogue preserves the encounter objectives")
	# The closing Space must not leak into the jump action.
	_check(absf(level.player.velocity.y) < 1.0, "Closing Space does not make Rook jump")
	level.queue_free()
	await process_frame
	print("OPENING DIALOGUE: %d failures" % failures)
	quit(1 if failures else 0)

func _space() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	Input.parse_input_event(event)
	await process_frame

func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
