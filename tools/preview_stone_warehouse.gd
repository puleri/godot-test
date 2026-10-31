extends SceneTree
## Render a close view, its actual level placement, and the existing opening shot.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 1000)
	var studio := Node3D.new()
	root.add_child(studio)
	var warehouse: Node3D = load("res://Modules/Buildings/StoneWarehouse.tscn").instantiate()
	studio.add_child(warehouse)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("1b2632")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a4b6cc")
	world.environment.ambient_light_energy = 0.45
	studio.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42,-32,0)
	key.light_color = Color("e4e3dc")
	key.light_energy = 0.8
	key.shadow_enabled = true
	studio.add_child(key)
	var camera := Camera3D.new()
	studio.add_child(camera)
	camera.position = Vector3(13,10,18)
	camera.look_at(Vector3(0,2.7,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.5
	camera.make_current()
	await _save("res://docs/images/stone-warehouse.png")
	studio.queue_free()
	await process_frame
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.play_opening_dialogue = false
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
	level.display_mode = level.DisplayMode.HIDDEN
	level._apply_display_mode()
	var view := Camera3D.new()
	level.add_child(view)
	view.position = Vector3(9,13,-5)
	view.look_at(Vector3(-7,2.7,-24))
	view.fov = 55
	view.make_current()
	await _save("/tmp/midnight-warehouse-night.png")
	# Neutral inspection fill is temporary and never enters the saved level.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-42,-32,0)
	fill.light_color = Color("96aecd")
	fill.light_energy = 0.4
	level.add_child(fill)
	await _save("/tmp/midnight-warehouse-placement.png")
	view.queue_free()
	fill.queue_free()
	await process_frame
	var shot = preload("res://scripts/exchange_establishing_shot.gd").new()
	level.add_child(shot)
	shot.duration = 30
	shot.start(level)
	shot._timeline.pause()
	shot._frame(1.0)
	await _save("/tmp/midnight-warehouse-establishing.png")
	shot.finish()
	paused = false
	level.queue_free()
	await process_frame
	print("STONE_WAREHOUSE_PREVIEWS_SAVED")
	quit()


func _save(path: String) -> void:
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
