extends SceneTree
## Fixed-camera before/after captures of the real encounter and guard lamps.
## godot --path . --audio-driver Dummy --script tools/preview_comic_lighting.gd

var _capture_dir := "/tmp/comic-lighting-preview"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	root.size = Vector2i(1440, 900)
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.play_opening_dialogue = false
	level.block_print_lighting = false
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.set_process(false)
	level.get_node("StormFlashLight").stop_flashing()
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	for guard in level.guards:
		guard.process_mode = Node.PROCESS_MODE_DISABLED
	level.display_mode = level.DisplayMode.HIDDEN
	level._apply_display_mode()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.0
	level.add_child(camera)
	camera.make_current()
	for guard in [level.guards[0], level.guards[1]]:
		if guard == level.guards[1]:
			guard._set_visual_yaw(PI + guard.visual_forward_yaw_offset)
			guard._sync_sight_light()
		var focus: Vector3 = guard.global_position + guard.sight_forward() * 2.0
		camera.position = focus + Vector3(12, 23, 19)
		camera.look_at(focus)
		for isolated in [false, true]:
			level.get_node("HarborLights").visible = not isolated
			for other_guard in level.guards:
				other_guard.get_node("SightLight").visible = not isolated or other_guard == guard
			await _compare(str(guard.name) + ("-isolated" if isolated else ""))
	level.get_node("HarborLights").show()
	for guard in level.guards:
		guard.get_node("SightLight").show()
	level.player.position = Vector3(-11, 0.49, 3)
	level.player._focus = Vector3(-11, 0.3, 3)
	level.player._update_phase_camera()
	level.player.overview_camera.make_current()
	level.display_mode = level.DisplayMode.STYLED_HUD
	level._apply_display_mode()
	await _compare("player-view")
	level.display_mode = level.DisplayMode.HIDDEN
	level._apply_display_mode()
	camera.make_current()
	camera.position = Vector3(15, 24, 24)
	camera.look_at(Vector3(0, 0, -2))
	camera.size = 32.0
	# Static storm illumination makes the two renders directly comparable.
	var storm: DirectionalLight3D = level.get_node("StormFlashLight")
	storm.light_energy = 0.65
	storm.show()
	RenderingServer.global_shader_parameter_set("storm_rim_suppression", 1.0)
	await _compare("lightning")
	RenderingServer.global_shader_parameter_set("comic_lighting", true)
	for light: Light3D in level.find_children("*", "Light3D", true, false):
		light.hide()
		light.get_parent().remove_child(light)
		light.queue_free()
	for frame in 4:
		await process_frame
	level.queue_free()
	await process_frame
	print("COMIC PREVIEWS: " + _capture_dir)
	quit()


func _compare(name: String) -> void:
	for comic in [false, true]:
		RenderingServer.global_shader_parameter_set("comic_lighting", comic)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_capture_dir.path_join(name + ("-after" if comic else "-before") + ".png"))
