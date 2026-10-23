extends SceneTree
## Rebuild source connector scenes and their assembled demonstration level.

const BUILDER = preload("res://scripts/connector_kit_builder.gd")


func _initialize() -> void:
	var builder = BUILDER.new()
	DirAccess.make_dir_recursive_absolute("res://Modules/Connectors")
	for kind in builder.MODULE_NAMES:
		var module = builder.build_module(kind)
		var path := "res://Modules/Connectors/%s.tscn" % kind
		var result: Error = builder.save_scene(module, path)
		module.free()
		if result != OK:
			push_error("Could not save %s: %s" % [path, error_string(result)])
			quit(1)
			return
		print("Saved ", path)
	var demo = builder.build_demo()
	var result: Error = builder.save_scene(demo, "res://Levels/ConnectorKitDemo.tscn")
	demo.free()
	if result != OK:
		push_error("Could not save demonstration: %s" % error_string(result))
		quit(1)
	else:
		print("Saved res://Levels/ConnectorKitDemo.tscn")
		quit()
