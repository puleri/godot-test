extends SceneTree

func _initialize() -> void:
	var builder = preload("res://scripts/lamplight_store_builder.gd").new()
	var level = builder.build_store()
	var result: Error = builder.kit.save_scene(level, "res://Levels/LamplightStore.tscn")
	level.free()
	print("Saved LamplightStore: ", error_string(result))
	quit(0 if result == OK else 1)
