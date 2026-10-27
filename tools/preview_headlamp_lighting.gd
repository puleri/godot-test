extends SceneTree
## Reproducible legacy/fixed encounter captures without modifying saved scenes.
## godot --path . --script tools/preview_headlamp_lighting.gd -- --capture-dir=/tmp/headlamps

var capture_dir := "/tmp/headlamps"

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size = Vector2i(1440, 900)
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.play_opening_dialogue = false
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
	var materials: Array[ShaderMaterial] = []
	for mesh: MeshInstance3D in level.get_node("NavigationRegion3D/StoneFloor").find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material != null and material.get_shader_parameter("toon_local_lighting") == true and not materials.has(material):
				materials.append(material)
	for guard in [level.guards[0], level.guards[1]]:
		# Face the Hound down its open aisle rather than into the nearby vault wall.
		if guard == level.guards[1]:
			guard._set_visual_yaw(PI + guard.visual_forward_yaw_offset)
			guard._sync_sight_light()
		var camera: Camera3D = level.get_node("LevelCamera")
		var focus: Vector3 = guard.global_position + guard.sight_forward() * 2
		camera.position = focus + Vector3(12, 23, 19)
		camera.look_at(focus)
		for isolated in [false, true]:
			level.get_node("HarborLights").visible = not isolated
			for other_guard in level.guards:
				other_guard.get_node("SightLight").visible = not isolated or other_guard == guard
			for enabled in [false, true]:
				for material in materials:
					material.set_shader_parameter("toon_local_lighting", enabled)
				await _capture(str(guard.name) + ("-isolated" if isolated else "") + ("-after" if enabled else "-before"))
		level.get_node("HarborLights").show()
		for other_guard in level.guards:
			other_guard.get_node("SightLight").show()
	# Include a real player camera view with the styled HUD.
	level.player._update_phase_camera()
	level.display_mode = level.DisplayMode.STYLED_HUD
	level._apply_display_mode()
	await _capture("player-view")
	# Let the renderer detach active light pairs before releasing the scene.
	for light: Light3D in level.find_children("*", "Light3D", true, false):
		light.hide()
	for frame in 4:
		await process_frame
	level.queue_free()
	await process_frame
	quit()


func _capture(name: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))
