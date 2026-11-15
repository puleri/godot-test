extends SceneTree
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# The dummy renderer discards MultiMesh GPU buffers when serializing resources.
	if DisplayServer.get_name() == "headless":
		push_error("Use the real renderer to build this saved MultiMesh scene (omit --headless).")
		quit(1)
		return
	var builder = preload("res://scripts/night_city_builder.gd").new()
	var level: Node3D = builder.build_city()
	if level.get_script() == null:
		push_error("City controller did not compile")
		quit(1)
		return
	# Only static construction enters the live world; actors retain authored state.
	var region: NavigationRegion3D = level.get_node("NavigationRegion3D")
	level.remove_child(region)
	region.owner = null
	root.add_child(region)
	region.bake_navigation_mesh(false)
	await physics_frame
	root.remove_child(region)
	level.add_child(region)
	level.move_child(region,0)
	builder._own_additions(level,level)
	var error: Error = builder.kit.save_scene(level,"res://Levels/NocturneCity.tscn")
	print("NIGHT_CITY_SAVED ",error_string(error)," / nav polygons ",region.navigation_mesh.get_polygon_count())
	level.free()
	quit(0 if error == OK else 1)
