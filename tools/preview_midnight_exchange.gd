extends SceneTree
## Save four gameplay views plus shadow/lightning comparisons in /tmp.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 900)
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	for guard in level.guards:
		guard.set_physics_process(false)
	level.player.set_physics_process(false)
	for spec in [["entry", Vector3(0, 0.49, 14)], ["sorting", Vector3(-11, 0.49, 3)], ["crank", Vector3(11.5, 0.49, 3.5)], ["vault", Vector3(0, 0.49, -13)]]:
		level.player.position = spec[1]
		level.player._focus = Vector3(spec[1].x, 0.3, spec[1].z)
		level.player._update_phase_camera()
		for frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/midnight-" + spec[0] + ".png")
	level.player.position = Vector3(-4, 0.49, -1)
	level.player._focus = Vector3(-4, 0.3, -1)
	level.player._update_phase_camera()
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/midnight-shadow.png")
	level.get_node("StormFlashLight").trigger_flash(1.0)
	for frame in 180:
		await physics_frame
		if level.exposure_sensor.lightning_exposure > 0.3:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/midnight-lightning.png")
			break
	level.get_node("StormFlashLight").stop_flashing()
	level.queue_free()
	await process_frame
	quit()
