extends SceneTree
## Real-renderer captures; no changes are saved to the scene.


func _initialize() -> void:
	_run.call_deferred()


func _capture(path: String) -> void:
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("Saved ", path)


func _run() -> void:
	var level = load("res://Levels/StealthSystemsLab.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	var storm = level.get_node("StormFlashLight")
	storm.stop_flashing()
	level.toggle_inspection_light()
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	level.emit_noise(Vector3(-26, 0, 3), 12, "PULSE")
	await _capture("/private/tmp/systems-lab-door.png")
	level.player.map_view = true
	level.player._update_phase_camera()
	storm.visible = true
	storm.light_energy = 0.9
	RenderingServer.global_shader_parameter_set("storm_rim_suppression", 1.0)
	await _capture("/private/tmp/systems-lab-overview.png")
	storm.light_energy = 0.65
	level.player.map_view = false
	level.select_bay(1)
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	await _capture("/private/tmp/systems-lab-team.png")
	var sentry = level.guards[3]
	sentry._player = null
	for frame in 45:
		await physics_frame
		sentry._physics_process(1.0 / 60)
	await _capture("/private/tmp/systems-lab-sentry-glance.png")
	for frame in 135:
		await physics_frame
		sentry._physics_process(1.0 / 60)
	await _capture("/private/tmp/systems-lab-sentry-scan.png")
	level.disable_investigator()
	await _capture("/private/tmp/systems-lab-takeover.png")
	level.select_bay(1)
	for guard in level.guards:
		if guard.bay == 1:
			guard._player = null
	level.emit_noise(Vector3(-4, 0, 3), 12, "PULSE")
	for frame in 210:
		await physics_frame
		level.guards[2]._physics_process(1.0 / 60)
		sentry._physics_process(1.0 / 60)
	await _capture("/private/tmp/systems-lab-watch-patrol.png")
	level.emit_noise(Vector3(4, 0, 0), 5, "FOOTSTEPS")
	for frame in 45:
		await physics_frame
		sentry._physics_process(1.0 / 60)
	await _capture("/private/tmp/systems-lab-new-sound.png")
	level.emit_noise(Vector3(4, 0, 0), 12, "PULSE")
	for frame in 90:
		await physics_frame
		level.guards[2]._physics_process(1.0 / 60)
		sentry._physics_process(1.0 / 60)
	await _capture("/private/tmp/systems-lab-two-incidents.png")
	level.select_bay(2)
	level.place_chime()
	level.player.jump_to(Vector3(22, 0.49, 3))
	level.trigger_chime()
	await _capture("/private/tmp/systems-lab-chime.png")
	level.queue_free()
	await process_frame
	quit()
