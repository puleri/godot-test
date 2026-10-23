extends SceneTree

func _initialize() -> void:
	var builder = preload("res://scripts/harbor_night_shift_builder.gd").new()
	for spec in [["HarborHall", 12, 12], ["HarborStorehouse", 14, 12]]:
		var room = builder.build_room(spec[0], spec[1], spec[2])
		var result: Error = builder.kit.save_scene(room, "res://Modules/Rooms/%s.tscn" % spec[0])
		room.free()
		if result != OK:
			push_error("Room save failed: " + error_string(result))
			quit(1)
			return
	var level = builder.build_level()
	var result: Error = builder.kit.save_scene(level, "res://Levels/HarborNightShift.tscn")
	level.free()
	print("Saved HarborNightShift: ", error_string(result))
	quit(0 if result == OK else 1)
