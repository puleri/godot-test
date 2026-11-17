extends "res://tools/export_component_library.gd"
## Snapshot all six manually operated props without running the encounter.
func _initialize() -> void:
	output_dir = "/tmp/exchange-interactables"
	DirAccess.make_dir_recursive_absolute(output_dir)
	call_deferred("_export_props")

func _export_props() -> void:
	var level: Node3D = load("res://Levels/MidnightExchange.tscn").instantiate()
	for station in level.get_node("Stations").get_children():
		station.prepare_visuals()
	for group in ["Stations", "Bells"]:
		for item in level.get_node(group).get_children():
			var visual: Node3D = item.get_node("Visual").duplicate()
			var wrapper := Node3D.new()
			wrapper.name = item.name
			wrapper.add_child(visual)
			_export_node(str(item.name), "Interactables", "Levels/MidnightExchange.tscn#" + group + "/" + str(item.name), wrapper, "Editable visual at local origin, actual game scale. Moving parts retained.", {})
	level.free()
	FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE).store_string(JSON.stringify(records, "\t"))
	quit()
