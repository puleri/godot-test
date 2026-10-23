extends SceneTree
## godot --headless --path . --script tools/generate_courtyard.gd -- --seed=42


func _initialize() -> void:
	var level: Node3D = load("res://Levels/ModularCourtyard.tscn").instantiate()
	var output := "res://Levels/ModularCourtyard.tscn"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			level.layout_seed = argument.trim_prefix("--seed=").to_int()
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	level.regenerate()
	var packed := PackedScene.new()
	var result := packed.pack(level)
	if result == OK:
		result = ResourceSaver.save(packed, output)
	level.free()
	if result != OK:
		push_error("Could not save courtyard: %s" % error_string(result))
		quit(1)
	else:
		print("Saved editable courtyard: ", output)
		quit()
