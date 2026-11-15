extends SceneTree

func _initialize() -> void:
	var builder = preload("res://scripts/stealth_systems_lab_builder.gd").new()
	var level = builder.build_lab()
	var result: Error = builder.kit.save_scene(level, "res://Levels/StealthSystemsLab.tscn")
	level.free()
	print("Saved StealthSystemsLab: ", error_string(result))
	quit(0 if result == OK else 1)
