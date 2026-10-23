extends SceneTree
## Exports visual references without entering gameplay scenes into the tree.
## Used by build_component_library.py; never writes to the original resources.

var output_dir := "/tmp/rook-component-library"
var records: Array = []
var converted_materials: Dictionary = {}


func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		output_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	call_deferred("_export_all")


func _export_all() -> void:
	var harbor := "res://Mesh/Harboretum-Mesh/"
	for pair in [
		["Stone tile / single", "stone_tile_block.tscn"],
		["Stone tile / four", "stone_tile_block_4.tscn"],
		["Stone tile / nine", "stone_tile_block_9.tscn"],
		["Cobblestone / seven", "cobble_stone_7.tscn"],
		["Harbor wall / four", "habor_wall_4.tscn"],
		["Harbor archway", "habor_archway.tscn"],
		["Stone railing", "stone_railing.tscn"],
		["Stone railing / corner", "stone_railing_corner.tscn"],
		["Wood planks", "wood_planks.tscn"],
		["Wood walkway supports", "wood_walk_legs.tscn"],
	]:
		_export(pair[0], "01 Architecture", harbor + pair[1])
	for pair in [["Short grass block", "short_grass_block.tscn"], ["Tall grass block", "tall_grass_block.tscn"], ["Grass tuft / one", "grass_tuft_01.tscn"]]:
		_export(pair[0], "02 Vegetation", harbor + pair[1])
	# Additional original variations have no material wrapper in the project.
	for pair in [["Cobblestone / single", "CobbleStone.fbx", "01 Architecture"], ["Harbor wall / single", "HaborWall-1.fbx", "01 Architecture"], ["Grass tuft / two", "GrassTuft02.fbx", "02 Vegetation"]]:
		_export(pair[0], pair[2], harbor + pair[1], "Original model; no Godot material wrapper exists.")
	for pair in [["Barrel / interactive visual", "Objects/Newbarrel.tscn"], ["Barrel / cargo", "Modules/Props/CargoBarrel.tscn"], ["Coin", "Mesh/Treasure/coin.tscn"], ["Cargo seal", "Modules/Gameplay/CargoSeal.tscn"], ["Pressure plate", "Objects/PressurePlate.tscn"], ["Prototype arch", "Objects/ArchTest.tscn"]]:
		_export(pair[0], "03 Props and gameplay", "res://" + pair[1])
	_export_door()
	_export("Bronze bell / rigged", "03 Props and gameplay", "res://Mesh/Bell/bell.tscn", "Native editable source, three bones, Ring and RingLoop actions. Game scale 0.6.", {"native_source": "Mesh/Bell/source/bell_rigged.blend", "native_root": "BellRig", "native_scale": 0.6})
	_export("Storefront", "04 Buildings", "res://Mesh/Storefront/storefront.tscn", "Current game model with separate editable mesh parts and original PBR materials. The authoring .blend differs from the exported game mesh; this library follows the game geometry. Godot uses a separate runtime toon palette.")
	_export("Rook / player", "05 Characters", "res://scenes/Player_v2.tscn", "Includes the player wrapper's actual scale and visual offset; rig and animation clips retained.")
	_export_player_two()
	_export("Hound / current", "05 Characters", "res://Characters/Hound/hound_npc.tscn", "NPC wrapper scale and offset; rig and animation clips retained.")
	_export("Mouse / current", "05 Characters", "res://Characters/Mouse/mouse_npc.tscn", "NPC wrapper scale and offset; rig and animation clips retained.")
	for name in ["Straight", "Corner", "TJunction", "Staircase", "Bridge"]:
		_export(name, "06 Connector modules", "res://Modules/Connectors/" + name + ".tscn", "Connection empties retained. Godot -Z outward becomes Blender +Y outward; 6 m ports.")
	for name in ["HarborHall", "HarborStorehouse"]:
		_export(name, "07 Room modules", "res://Modules/Rooms/" + name + ".tscn", "Connection empties retained; walking surface at local Z = 0 in Blender.")
	for pair in [["Entryway / original", "Build-EntryWay.tscn"], ["Entryway / v2", "Build-EntryWay_v2.tscn"]]:
		_export(pair[0], "08 Assemblies", harbor + pair[1])
	for pair in [["Rook / earlier", "Rook/Rook_v2.tscn"], ["Hound / v1", "Characters/Hound/Hound_v1.tscn"], ["Mouse / v1", "Characters/Mouse/Mouse_v1.tscn"]]:
		_export(pair[0], "09 Earlier versions", "res://" + pair[1], "Earlier source version at its scene scale; kept for reference.")
	# Authored primitive props that currently live inside levels rather than files.
	var exchange: Node = load("res://Levels/MidnightExchange.tscn").instantiate()
	for name in ["Manifest", "Crank"]:
		var node: Node3D = exchange.get_node("Stations/" + name).duplicate()
		node.transform = Transform3D.IDENTITY
		_export_node(name + " station", "03 Props and gameplay", "res://Levels/MidnightExchange.tscn#Stations/" + name, node, "Visual assembly extracted from the saved level; gameplay scripts excluded.", {})
	exchange.free()
	# Builder extracts just this saved subtree to avoid Main_v2's missing door OBJ.
	var chessboard: PackedScene = load(output_dir.path_join("chessboard.tscn"))
	_export_node("Chessboard", "03 Props and gameplay", "res://scenes/Main_v2.tscn#ChessboardTrigger/Board", chessboard.instantiate(), "Original 4 x 4 visual tiles; trigger and glow excluded.", {})
	var file := FileAccess.open(output_dir.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("COMPONENT_EXPORT_OK ", records.size(), " components")
	quit()


func _export(title: String, category: String, source: String, notes := "", extra := {}) -> void:
	var packed = load(source)
	assert(packed is PackedScene, "Cannot load " + source)
	_export_node(title, category, source, packed.instantiate(), notes, extra)


func _export_node(title: String, category: String, source: String, node: Node, notes: String, extra: Dictionary) -> void:
	_clear_owners(node)
	_clean(node)
	var stats := {"mesh_count": 0, "surface_count": 0, "bone_count": 0, "clips": [], "ports": []}
	_stats(node, stats, Transform3D.IDENTITY)
	assert(stats.mesh_count > 0, "Empty component: " + title)
	var slug := title.to_lower().replace(" / ", "_").replace(" ", "_")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_scene(node, state) == OK, "Export failed: " + title)
	assert(doc.write_to_filesystem(state, output_dir.path_join(slug + ".glb")) == OK)
	var record := {"name": title, "category": category, "source": source, "notes": notes, "slug": slug, "stats": stats}
	record.merge(extra)
	records.append(record)
	print("EXPORTED ", title, " meshes=", stats.mesh_count, " bones=", stats.bone_count)
	node.free()


func _clear_owners(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owners(child)


func _clean(node: Node) -> void:
	# Detached instances never run _ready; remove behavior and nonvisual nodes.
	if node.get_script():
		node.set_script(null)
	for child in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D or child is Camera3D or child is Light3D or child is Label3D or child is AudioStreamPlayer or child is AudioStreamPlayer3D or child is AnimationTree:
			# StaticBody/Area roots can contain visual geometry (e.g. cargo seal).
			if child is CollisionObject3D:
				var replacement := Node3D.new()
				replacement.name = child.name
				replacement.transform = child.transform
				node.remove_child(child)
				node.add_child(replacement)
				for grandchild in child.get_children():
					child.remove_child(grandchild)
					replacement.add_child(grandchild)
				child.free()
				_clean(replacement)
			else:
				child.free()
			continue
		if child is CSGShape3D or str(child.name).to_lower().contains("previewground") or (child is Node3D and not child.visible):
			child.free()
			continue
		_clean(child)
	if node is MeshInstance3D and node.mesh:
		for index in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(index)
			if material is ShaderMaterial:
				node.set_surface_override_material(index, _pbr(material))
		if node.material_override is ShaderMaterial:
			node.material_override = _pbr(node.material_override)


func _pbr(material: ShaderMaterial) -> StandardMaterial3D:
	if converted_materials.has(material):
		return converted_materials[material]
	var converted := StandardMaterial3D.new()
	converted.resource_name = material.resource_name if not material.resource_name.is_empty() else material.resource_path.get_file().get_basename()
	var color = material.get_shader_parameter("albedo_color")
	converted.albedo_color = color if color is Color else Color(0.25, 0.3, 0.4)
	converted.roughness = 0.85
	converted.cull_mode = BaseMaterial3D.CULL_DISABLED
	converted_materials[material] = converted
	return converted


func _stats(node: Node, stats: Dictionary, parent_transform: Transform3D) -> void:
	var xform := parent_transform
	if node is Node3D:
		xform *= node.transform
	if node is MeshInstance3D and node.mesh:
		stats.mesh_count += 1
		stats.surface_count += node.mesh.get_surface_count()
		var box: AABB = xform * node.mesh.get_aabb()
		if not stats.has("bounds_min"):
			stats.bounds_min = [box.position.x, box.position.y, box.position.z]
			stats.bounds_max = [box.end.x, box.end.y, box.end.z]
		else:
			for axis in 3:
				stats.bounds_min[axis] = min(stats.bounds_min[axis], box.position[axis])
				stats.bounds_max[axis] = max(stats.bounds_max[axis], box.end[axis])
	if node is Skeleton3D:
		stats.bone_count += node.get_bone_count()
	if node is AnimationPlayer:
		for clip in node.get_animation_list():
			stats.clips.append(clip)
	if node is Marker3D and node.has_meta("level_connection"):
		stats.ports.append({"name": str(node.name), "position": [xform.origin.x, xform.origin.y, xform.origin.z], "width": node.get_meta("width", 6.0)})
	for child in node.get_children():
		_stats(child, stats, xform)


func _export_player_two() -> void:
	var player: Node = load("res://scenes/Player_v2.tscn").instantiate()
	var previous: Node3D = player.get_node("VisualPivot/Rook_v2")
	var model: Node3D = load("res://Rook/v2/Rook_v2-PlayerTwo.tscn").instantiate()
	model.transform = previous.transform
	previous.get_parent().add_child(model)
	previous.free()
	_export_node("Rook / player two", "05 Characters", "res://Rook/v2/Rook_v2-PlayerTwo.tscn", player, "Light material variant placed in the current player wrapper for comparable size.", {})


func _export_door() -> void:
	# Recover the exact original mesh from the existing web release, never invent it.
	var mesh_path := output_dir.path_join("recovered_door.mesh")
	assert(FileAccess.file_exists(mesh_path), "Builder must recover door mesh first")
	var door := Node3D.new()
	door.name = "Door01"
	var hinge := Node3D.new()
	hinge.name = "HingePivot"
	door.add_child(hinge)
	var visual := MeshInstance3D.new()
	visual.name = "DoorTest"
	visual.mesh = load(mesh_path)
	visual.scale = Vector3.ONE * 0.75
	visual.position.y = 0.25477302
	visual.set_surface_override_material(0, load("res://Materials/GreyToon.tres"))
	visual.set_surface_override_material(1, load("res://Materials/BlackToon.tres"))
	hinge.add_child(visual)
	_export_node("Door / hinged", "03 Props and gameplay", "res://Objects/Door01.tscn", door, "Exact original mesh recovered from web/index.pck because Objects/Door_test.obj is absent; transforms/materials match Door01.tscn.", {})
