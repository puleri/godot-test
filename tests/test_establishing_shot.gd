extends SceneTree
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440,900)
	for skip in [true,false]:
		var level = load("res://Levels/MidnightExchange.tscn").instantiate()
		level.establishing_shot_duration = 30.0 if skip else 0.2
		root.add_child(level)
		current_scene = level
		await level.ready_for_play
		var shot = level._establishing_shot
		_check(paused and shot.active and level.player.interaction_locked,"Shot pauses gameplay and locks player")
		_check(root.get_camera_3d() == shot._camera,"Dedicated perspective camera takes control")
		_check(not level._hud_layer.visible and level._dialogue == null,"Shot precedes dialogue and hides HUD")
		var start: Vector3 = level.guards[0].position
		await create_timer(0.06,true).timeout
		_check(level.guards[0].position == start and level.elapsed == 0,"Patrol and clock do not advance")
		var backdrop = level.get_node("HarborBackdrop")
		_check(backdrop.get_node("Buildings") is MultiMeshInstance3D and backdrop.find_children("*","CollisionObject3D",true,false).is_empty(),"Backdrop is batched decorative geometry without collision")
		if skip:
			if OS.get_cmdline_user_args().has("--preview"):
				shot._timeline.pause()
				for progress in [0.0,1.0]:
					shot._frame(progress)
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("/tmp/midnight-establishing-%d.png" % int(progress))
			var event := InputEventKey.new()
			event.physical_keycode = KEY_SPACE
			event.pressed = true
			Input.parse_input_event(event)
			await process_frame
			event = InputEventKey.new()
			event.physical_keycode = KEY_SPACE
			Input.parse_input_event(event)
		else:
			await create_timer(0.3,true).timeout
		_check(level._establishing_shot == null and level._dialogue.active,"Skip or natural completion opens dialogue")
		_check(paused and root.get_camera_3d() == level.get_node("LevelCamera"),"Dialogue remains paused on gameplay camera")
		_check(level._dialogue.line_index == 0 and level._dialogue._revealing,"Skip input does not advance dialogue")
		paused = false
		level.queue_free()
		await process_frame
	print("ESTABLISHING SHOT: %d failures" % failures)
	quit(1 if failures else 0)

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
	else:
		print("PASS: " + description)
