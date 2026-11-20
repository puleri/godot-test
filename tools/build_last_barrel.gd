extends SceneTree

func _initialize() -> void:
	var builder = preload("res://scripts/last_barrel_builder.gd").new()
	var level: Node3D = builder.build()
	var result: Error = builder.kit.save_scene(level, "res://Levels/TheLastBarrel.tscn")
	level.free()
	print("Saved The Last Barrel: ", error_string(result))
	quit(0 if result == OK else 1)
