extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1440,900)
	var level = load("res://Levels/NocturneCity.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	level.set_process(false)
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	for spec in [["arrival",Vector3(0,0.49,60),19.5],["rooftops",Vector3(12,6.49,-12),24],["canal",Vector3(28,0.49,0),27],["street",Vector3(10,0.49,-16),19.5],["city",Vector3(0,0,0),180]]:
		level.player.position = spec[1]
		level._update_activity()
		level.player._focus = spec[1]
		level.player.follow_size = spec[2]
		level.player._update_phase_camera()
		level._process(0)
		if spec[0] == "city":
			level._hud.hide()
			var camera: Camera3D = level.get_node("LevelCamera")
			camera.position = Vector3(112,155,150)
			camera.look_at(Vector3(0,0,-8))
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/nocturne-"+spec[0]+".png")
	level._hud.show()
	level._atlas.show()
	level._atlas.queue_redraw()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/nocturne-atlas.png")
	print("NIGHT_CITY_PREVIEWS_SAVED")
	level.free()
	quit()
