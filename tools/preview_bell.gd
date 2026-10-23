extends SceneTree
## Capture the actual Godot import at rest, during ringing and during the loop.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	var preview = load("res://scenes/BellPreview.tscn").instantiate()
	root.add_child(preview)
	current_scene = preview
	var bell = preview.get_node("Bell")
	bell.stop_ringing()
	for pose in [["rest", "Ring", 0.0], ["ring", "Ring", 1.4], ["loop", "RingLoop", 0.4]]:
		bell.animation_player.play(pose[1])
		bell.animation_player.seek(pose[2], true)
		bell.animation_player.pause()
		for frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/bell-godot-" + pose[0] + ".png")
	quit()
