extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _capture(path: String) -> void:
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("Saved ", path)


func _settle(player: Node3D, at: Vector3) -> void:
	player.position = at
	for frame in 150:
		player._update_phase_camera()
		await process_frame


func _run() -> void:
	var level = load("res://Levels/LamplightStore.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
		guard._update_feedback(0)
	var storm = level.get_node("StormFlashLight")
	storm.stop_flashing()
	storm.visible = true
	storm.light_energy = 0.65
	RenderingServer.global_shader_parameter_set("storm_rim_suppression", 1.0)
	await _settle(level.player, Vector3(0, 0.49, 8))
	await _capture("/private/tmp/lamplight-exterior.png")
	await _settle(level.player, Vector3(0, 0.49, -5))
	await _capture("/private/tmp/lamplight-interior.png")
	var tracker = level.guards[1]
	tracker.awareness = 0.35
	tracker._change_state(StealthGuard.GuardState.SUSPICIOUS)
	tracker._update_feedback(0)
	await _capture("/private/tmp/lamplight-suspicious.png")
	tracker.awareness = 1
	tracker._change_state(StealthGuard.GuardState.CHASE)
	tracker._update_feedback(0)
	await _capture("/private/tmp/lamplight-alerted.png")
	tracker._change_state(StealthGuard.GuardState.PATROL)
	tracker.awareness = 0
	tracker._update_feedback(0)
	level.set_store_lights(false)
	await _capture("/private/tmp/lamplight-dark.png")
	level.set_store_lights(true)
	level.player.position = level.get_node("HideSpot").position
	level.interact()
	await _settle(level.player, level.get_node("HideSpot").position)
	await _capture("/private/tmp/lamplight-hide.png")
	level.player.set_peeking(true)
	await _capture("/private/tmp/lamplight-peek.png")
	level.queue_free()
	await process_frame
	quit()
