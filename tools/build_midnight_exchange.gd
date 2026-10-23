extends SceneTree

func _initialize() -> void:
	var builder = preload("res://scripts/midnight_exchange_builder.gd").new()
	var level = builder.build_exchange()
	var result: Error = builder.kit.save_scene(level, "res://Levels/MidnightExchange.tscn")
	level.free()
	print("Saved MidnightExchange: ", error_string(result))
	quit(0 if result == OK else 1)
