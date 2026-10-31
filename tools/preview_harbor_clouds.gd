extends SceneTree
## Render a fixed-camera comparison to verify motion while gameplay is paused.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440,900)
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.establishing_shot_duration = 30.0
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level._establishing_shot._timeline.pause()
	await create_timer(0.5,true).timeout
	await RenderingServer.frame_post_draw
	var first := root.get_texture().get_image()
	first.save_png("/tmp/midnight-clouds-0.png")
	await create_timer(4.0,true).timeout
	await RenderingServer.frame_post_draw
	var last := root.get_texture().get_image()
	last.save_png("/tmp/midnight-clouds-4.png")
	var changed := 0
	# Sample sky only, excluding water and buildings. Camera remains fixed.
	for y in range(20,320,3):
		for x in range(20,1420,3):
			var a := first.get_pixel(x,y)
			var b := last.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.012:
				changed += 1
	var passed: bool = changed > 1000 and paused and level.elapsed == 0.0
	print("CLOUD MOTION: %s; %d sky samples changed with camera and gameplay paused" % ["PASS" if passed else "FAIL",changed])
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if passed else 1)
