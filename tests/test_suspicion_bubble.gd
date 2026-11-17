extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.play_opening_dialogue = false
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.set_process(false)
	level.get_node("StormFlashLight").stop_flashing()
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	level.display_mode = level.DisplayMode.STYLED_HUD
	level._apply_display_mode()
	for guard in [level.guards[0], level.guards[1]]:
		var camera: Camera3D = level.get_node("LevelCamera")
		var focus: Vector3 = guard.position + Vector3.UP * 0.4
		camera.position = focus + Vector3(12, 23, 19)
		camera.look_at(focus)
		var bubble = guard._suspicion_bubble
		_check(bubble._state == 0 and not bubble._anchor.visible, "Patrolling guard has no bubble")
		bubble.show_audio_alert()
		_check(bubble._audio_art.visible, "Heard sound displays artwork at the guard")
		bubble.set_enabled(false)
		_check(not bubble._audio_art.visible, "Hidden display mode hides audio artwork")
		bubble.set_enabled(true)
		bubble._audio_remaining = 0.01
		bubble._process(0.02)
		_check(not bubble._audio_art.visible, "Audio artwork expires")
		guard.awareness = 0.1
		guard._change_state(StealthGuard.GuardState.SUSPICIOUS)
		var entrance: Tween = bubble._motion
		await create_timer(0.3).timeout
		_check(bubble._state == 1 and bubble._anchor.visible and bubble._anchor.scale.is_equal_approx(Vector2.ONE), "Suspicion pops in and settles")
		guard._change_state(StealthGuard.GuardState.SUSPICIOUS)
		_check(bubble._motion == entrance, "Repeated suspicion does not restart entrance")
		guard.player_visible = false
		guard.awareness = 0.2
		await process_frame
		_check(bubble._motion == entrance and bubble._anchor.visible, "Brief lost sight keeps the bubble steady")
		await _capture(guard.name + "-suspicious")
		guard.awareness = 1.0
		guard._change_state(StealthGuard.GuardState.CHASE)
		await create_timer(0.09).timeout
		_check(bubble._anchor.scale.x > 1.1, "Confirmed detection punches the bubble larger")
		await create_timer(0.25).timeout
		_check(bubble._state == 2 and bubble._art.modulate.is_equal_approx(bubble.CORAL), "Confirmed detection settles to coral")
		await _capture(guard.name + "-detected")
		guard.awareness = 0.2
		guard._change_state(StealthGuard.GuardState.SEARCH)
		await process_frame
		_check(bubble._state == 1, "Residual suspicion remains visible during search")
		guard.awareness = 0.0
		await create_timer(0.25).timeout
		_check(bubble._state == 0 and not bubble._anchor.visible, "Cleared suspicion shrinks and fades away")
		guard._change_state(StealthGuard.GuardState.SUSPICIOUS)
		await create_timer(0.3).timeout
		level.display_mode = level.DisplayMode.HIDDEN
		level._apply_display_mode()
		_check(not bubble._anchor.visible, "Hidden display mode immediately hides bubble")
		level.display_mode = level.DisplayMode.STYLED_HUD
		level._apply_display_mode()
		await process_frame
		_check(bubble._anchor.visible, "Styled HUD restores guard bubble")
		var wall := StaticBody3D.new()
		wall.position = camera.global_position.lerp(guard.global_position + Vector3.UP * (guard.eye_height + 0.65), 0.5)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3.ONE * 3.0
		collision.shape = shape
		wall.add_child(collision)
		level.add_child(wall)
		await physics_frame
		await physics_frame
		await process_frame
		_check(not bubble._anchor.visible, "Level geometry occludes the bubble")
		wall.queue_free()
		await physics_frame
		await physics_frame
		await process_frame
		_check(bubble._anchor.visible, "Bubble returns when the camera has a clear view")
		guard.awareness = 0.0
		guard._change_state(StealthGuard.GuardState.PATROL)
		await create_timer(0.25).timeout
	print("SUSPICION BUBBLE: %d checks, %d failures" % [checks, failures])
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--preview"):
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/bubble-" + name + ".png")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error(description)
