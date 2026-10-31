extends "res://tools/export_component_library.gd"
## Export detached visual references; gameplay never runs and sources stay unchanged.

func _initialize() -> void:
	output_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	call_deferred("_export_workspace")

func _export_workspace() -> void:
	var level: Node3D = load("res://Levels/MidnightExchange.tscn").instantiate()
	# Tool-generated backdrop children do not exist until each instance builds.
	_build_backdrops(level)
	var manifest := {"source": "res://Levels/MidnightExchange.tscn", "groups": []}
	for spec in [
		["LevelGeometry", ["NavigationRegion3D", "Details", "Stations", "Bells", "Boat_v1", "NorthQuayWarehouse"]],
		["Characters", ["Player", "Guards"]],
		["HarborBackdrop", ["HarborBackdrop"]],
	]:
		var visual := Node3D.new()
		visual.name = spec[0]
		for child_name in spec[1]:
			var child := level.get_node_or_null(NodePath(child_name))
			if child:
				_clear_owners(child)
				level.remove_child(child)
				visual.add_child(child)
		_expand_batches(visual)
		_clear_owners(visual)
		_clean(visual)
		_remove_helpers(visual)
		var stats := {"mesh_count": 0, "surface_count": 0, "bone_count": 0, "clips": [], "ports": []}
		_stats(visual, stats, Transform3D.IDENTITY)
		assert(stats.mesh_count > 0)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_scene(visual, state) == OK)
		assert(document.write_to_filesystem(state, output_dir.path_join(spec[0]+".glb")) == OK)
		manifest.groups.append({"name": spec[0], "stats": stats})
		print("WORKSPACE_GROUP ", spec[0], " meshes=", stats.mesh_count)
		visual.free()
	level.free()
	FileAccess.open(output_dir.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("MIDNIGHT_WORKSPACE_EXPORTED")
	quit()

func _build_backdrops(node: Node) -> void:
	for child in node.get_children():
		_build_backdrops(child)
	if node.get_script() == preload("res://scripts/harbor_backdrop.gd"):
		node._ready()

func _expand_batches(node: Node) -> void:
	for child in node.get_children():
		if child is MultiMeshInstance3D and child.multimesh:
			var group := Node3D.new()
			group.name = child.name
			group.transform = child.transform
			node.remove_child(child)
			node.add_child(group)
			for i in child.multimesh.instance_count:
				var mesh := MeshInstance3D.new()
				mesh.name = "%s_%03d" % [child.name,i]
				mesh.mesh = child.multimesh.mesh
				mesh.material_override = child.material_override
				mesh.transform = child.multimesh.get_instance_transform(i)
				group.add_child(mesh)
			child.free()
		else:
			_expand_batches(child)

func _remove_helpers(node: Node) -> void:
	for child in node.get_children():
		if child is AnimationPlayer or child is WorldEnvironment or child is CanvasLayer or str(child.name) in ["Ring", "Pulse", "PlayerMarker"]:
			child.free()
		else:
			_remove_helpers(child)
