extends "res://tools/export_midnight_workspace.gd"
## Describe the exact saved Godot arrangement without starting gameplay.

const SHIP := preload("res://scripts/last_barrel_ship.gd")

func _initialize() -> void:
	output_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	_export_last_barrel.call_deferred()


func _export_last_barrel() -> void:
	var level: Node3D = load("res://Levels/TheLastBarrel.tscn").instantiate()
	_build_backdrops(level)
	var moon: DirectionalLight3D = level.get_node("Moon")
	var direction: Vector3 = -moon.basis.z
	var environment: Environment = level.find_children("*", "WorldEnvironment", false, false)[0].environment
	var lighting := {
		"direction": [direction.x, -direction.z, direction.y],
		"moon": _rgb(moon.light_color), "energy": moon.light_energy,
		"ambient": _rgb(environment.ambient_light_color), "ambient_energy": environment.ambient_light_energy,
		"sky": _rgb(environment.background_color),
	}
	var markers: Array[Dictionary] = []
	for point in level.get_node("Points").get_children():
		_add_marker(markers, point, "Ship search" if SHIP.POINTS.has(str(point.name)) else "Gameplay")
	for route in level.get_node("Routes").get_children():
		for point in route.get_children():
			_add_marker(markers, point, str(route.name))
	for patch in level.get_node("Ships/Fire").get_children():
		_add_marker(markers, patch, "Fire")
	for path in ["Quay/Office/Door", "Quay/Office/FoldingScreen", "Quay/Office/Bookcase", "Quay/GangwayShutter", "Cargo/SpareBarrel"]:
		_add_marker(markers, level.get_node(path), "Cover and doors")

	var office := level.get_node("Quay/Office")
	_clear_owners(office)
	office.get_parent().remove_child(office)
	level.add_child(office)
	var groups := []
	for spec in [
		["Quay", ["Quay"]],
		["Office", ["Office"]],
		["Merchant", ["Ships/OutboundMerchant"]],
		["Lighter", ["Ships/PotatoLighter"]],
		["Cargo", ["Cargo"]],
		["Cast", ["Player", "Guards", "People"]],
		["Backdrop", ["HarborBackdrop", "HarborWater"]],
	]:
		var visual := Node3D.new()
		visual.name = spec[0]
		var lights := []
		var items: Array[Dictionary] = []
		for path in spec[1]:
			var child := level.get_node_or_null(path) as Node3D
			if child == null:
				continue
			_clear_owners(child)
			child.get_parent().remove_child(child)
			visual.add_child(child)
			if spec[0] in ["Merchant", "Quay", "Office"]:
				_prepare_props(child, child, items, lights, spec[0])
		_expand_batches(visual)
		_remove_helpers(visual)
		_clean(visual)
		for pair in lights:
			var anchor: Node3D = pair[0]
			var light: OmniLight3D = pair[1]
			anchor.replace_by(light)
			anchor.free()
		var stats := {"mesh_count": 0, "surface_count": 0, "bone_count": 0, "clips": [], "ports": []}
		_stats(visual, stats, Transform3D.IDENTITY)
		assert(stats.mesh_count > 0, "Empty Blender group: " + spec[0])
		var gltf := GLTFDocument.new()
		var state := GLTFState.new()
		assert(gltf.append_from_scene(visual, state) == OK)
		assert(gltf.write_to_filesystem(state, output_dir.path_join(spec[0] + ".glb")) == OK)
		groups.append({"name": spec[0], "mesh_count": stats.mesh_count, "items": items})
		print(spec[0], "  ", stats.mesh_count, " meshes")
		visual.free()
	level.free()
	var file := FileAccess.open(output_dir.path_join("layout.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"groups": groups, "markers": markers, "lighting": lighting}, "\t"))
	file.close()
	quit()


func _rgb(tint: Color) -> Array:
	var linear := tint.srgb_to_linear()
	return [linear.r, linear.g, linear.b]


# Keep alternate prop states, the lantern lighting and the clue lettering that
# the generic component-library exporter normally strips from its references.
func _prepare_props(node: Node, group_root: Node, items: Array[Dictionary], lights: Array, group_name: String) -> void:
	for child in node.get_children():
		if not child is Node3D or str(child.name) in ["Ring", "Pulse", "PlayerMarker"]:
			continue
		if group_name != "Merchant" and not child is OmniLight3D:
			_prepare_props(child, group_root, items, lights, group_name)
			continue
		var tag := {"name": str(child.name)}
		if node == group_root and str(child.name) in ["Hull", "FreightDeck", "LowerHold", "SternPassages", "PurserCabin"]:
			tag["section"] = true
		if not child.visible:
			tag["stowed"] = true
			child.show()
		if child is OmniLight3D:
			tag["lantern_energy"] = child.light_energy
		if child is Label3D:
			var ink: Color = child.modulate.srgb_to_linear()
			tag["label"] = {"text": child.text, "size": child.font_size * child.pixel_size,
				"color": [ink.r, ink.g, ink.b, ink.a], "horizontal": child.horizontal_alignment,
				"vertical": child.vertical_alignment}
		if tag.size() > 1:
			tag["id"] = "%sLayout%03d" % [group_name, items.size()]
			items.append(tag)
			child.name = tag.id
		_prepare_props(child, group_root, items, lights, group_name)
		if child is Label3D or child is OmniLight3D:
			var anchor := Node3D.new()
			anchor.name = child.name
			anchor.transform = child.transform
			child.replace_by(anchor)
			if child is OmniLight3D:
				lights.append([anchor, child])
			else:
				child.free()


func _add_marker(markers: Array[Dictionary], node: Node3D, group: String) -> void:
	var at := node.position
	var parent := node.get_parent()
	while parent is Node3D:
		at = parent.transform * at
		parent = parent.get_parent()
	markers.append({"name": str(node.name), "group": group, "position": [at.x, -at.z, at.y]})
