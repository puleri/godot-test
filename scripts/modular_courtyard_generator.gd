@tool
extends Node3D
## Builds editable scene instances. Generation is explicit; playing never rebuilds it.

const TILE = preload("res://Mesh/Harboretum-Mesh/stone_tile_block.tscn")
const WALL = preload("res://Mesh/Harboretum-Mesh/habor_wall_4.tscn")
const ARCH = preload("res://Mesh/Harboretum-Mesh/habor_archway.tscn")
const RAIL = preload("res://Mesh/Harboretum-Mesh/stone_railing.tscn")
const GRASS = preload("res://Mesh/Harboretum-Mesh/grass_tuft_01.tscn")
const BARREL = preload("res://Objects/Newbarrel.tscn")
const CELL := 2.0

@export_category("Layout")
@export var layout_seed: int = 42
@export_range(13, 25, 2) var width_cells: int = 13
@export_range(11, 23, 2) var depth_cells: int = 11
@export_range(0.6, 2.4, 0.3) var terrace_height: float = 1.2
@export_range(2, 6, 1) var approach_length: int = 4
@export_category("Dressing")
@export_range(0.0, 1.0, 0.05) var grass_density: float = 0.4
@export_range(0, 12, 1) var barrel_count: int = 6
@export_tool_button("Generate Courtyard", "GridMap") var generate_action = regenerate

var _bounds_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if not Engine.is_editor_hint():
		var caption := get_node_or_null("HUD/Caption") as Label
		if caption != null:
			var generated := get_node_or_null("Generated")
			var saved_seed := int(generated.get_meta("layout_seed", layout_seed)) if generated != null else layout_seed
			caption.text = "MODULAR COURTYARD  /  SEED %d\nWASD / arrows: move   Space: jump   Tab: camera   R: reset" % saved_seed


func regenerate() -> void:
	# Build off-tree first so the editor only sees a complete replacement.
	var replacement := build_layout()
	var previous := get_node_or_null("Generated")
	if Engine.is_editor_hint() and is_inside_tree():
		# Resolve dynamically so exported games do not depend on editor-only classes.
		var editor = Engine.get_singleton("EditorInterface")
		var history = editor.get_editor_undo_redo()
		history.create_action("Generate modular courtyard", UndoRedo.MERGE_DISABLE, self)
		history.add_do_method(self, "_replace_generated", previous, replacement)
		history.add_undo_method(self, "_replace_generated", replacement, previous)
		history.add_do_reference(replacement)
		if previous != null:
			history.add_undo_reference(previous)
		history.commit_action()
	else:
		_replace_generated(previous, replacement)
		if previous != null:
			previous.free()


func _replace_generated(previous: Node, replacement: Node) -> void:
	if is_instance_valid(previous) and previous.get_parent() == self:
		remove_child(previous)
	if is_instance_valid(replacement):
		add_child(replacement)
		_assign_owners(replacement, self)
	if Engine.is_editor_hint() and is_inside_tree():
		Engine.get_singleton("EditorInterface").mark_scene_as_unsaved()


func _assign_owners(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	# Imported scene children retain their source ownership and material overrides.
	if not node.scene_file_path.is_empty():
		return
	for child in node.get_children():
		_assign_owners(child, scene_root)


func build_layout() -> Node3D:
	_rng.seed = layout_seed
	var layout := Node3D.new()
	layout.name = "Generated"
	layout.set_meta("layout_seed", layout_seed)
	var ground := _group(layout, "Ground")
	var terraces := _group(layout, "Terraces")
	var boundary := _group(layout, "Boundary")
	var dressing := _group(layout, "Dressing")
	var markers := _group(layout, "Markers")
	# Clamp programmatic inputs too; odd dimensions keep the entrance centered.
	var columns := clampi(width_cells, 13, 25) | 1
	var rows := clampi(depth_cells, 11, 23) | 1
	var half_x := columns / 2
	var half_z := rows / 2
	var front := (half_z + 0.5) * CELL
	var back := -front
	var side := (half_x + 0.5) * CELL
	var approach := clampi(approach_length, 2, 6)
	var rise := clampf(terrace_height, 0.6, 2.4)

	for x in range(-half_x, half_x + 1):
		for z in range(-half_z, half_z + 1):
			_floor(ground, "Tile_%d_%d" % [x + half_x, z + half_z], Vector3(x * CELL, 0, z * CELL))
	for z in range(approach):
		for x in range(-1, 2):
			_floor(ground, "Approach_%d_%d" % [x + 1, z], Vector3(x * CELL, 0, front + 1 + z * CELL))

	# Terraces shift along the courtyard with the seed, keeping a clear center aisle.
	for direction in [-1, 1]:
		var center := Vector3(direction * (half_x - 2) * CELL, 0, -_rng.randi_range(1, half_z - 2) * CELL)
		_terrace(terraces, "WestTerrace" if direction < 0 else "EastTerrace", center, rise)

	# A heavy back wall; slimmer railings leave the play space visible to the camera.
	var wall_count := ceili(columns * CELL / 4.0)
	for i in range(wall_count):
		var module := _module(boundary, "BackWall_%02d" % i, WALL,
			Vector3((i - (wall_count - 1) * 0.5) * 4, 0, back - 1))
		_box(module, Vector3(4, _asset_bounds(WALL).size.y, 2), Vector3(0, _asset_bounds(WALL).size.y * 0.5, 0))
	for z in range(-half_z, half_z + 1):
		for direction in [-1, 1]:
			_railing(boundary, Vector3(direction * side, 0, z * CELL), PI * 0.5)
	for x in range(-half_x, half_x + 1):
		if absi(x) > 1:
			_railing(boundary, Vector3(x * CELL, 0, front))
	for z in range(approach):
		for direction in [-1, 1]:
			_railing(boundary, Vector3(direction * 3, 0, front + 1 + z * CELL), PI * 0.5)
	var entrance := _module(boundary, "EntranceArch", ARCH, Vector3(0, 0, front))
	# Concave collision preserves the opening, unlike a box around the whole arch.
	_mesh_collision(entrance.get_node("Model"), entrance)

	# Small clusters along the edges leave the entrance, stairs and central aisle clear.
	for x in range(-half_x, half_x + 1):
		for z in range(1, half_z):
			if absi(x) < 3 or _rng.randf() > grass_density:
				continue
			for tuft in range(_rng.randi_range(2, 4)):
				var at := Vector3(x * CELL + _rng.randf_range(-0.65, 0.65), 0.01, z * CELL + _rng.randf_range(-0.65, 0.65))
				_module(dressing, "Grass_%03d" % dressing.get_child_count(), GRASS, at, _rng.randf_range(0, TAU))
	# Unique candidate positions keep props apart and away from the terrace stairs.
	var slots: Array[Vector3] = []
	for x in range(-half_x + 1, half_x):
		if absi(x) >= 2:
			slots.append(Vector3(x * CELL, 0, (half_z - 1) * CELL))
	for i in range(mini(clampi(barrel_count, 0, 12), slots.size())):
		var slot := _rng.randi_range(0, slots.size() - 1)
		var barrel := _module(dressing, "Barrel_%02d" % i, BARREL, slots.pop_at(slot), _rng.randf_range(0, TAU))
		# Reuse its art as a static prop; the existing interactive barrel adds runtime bodies.
		barrel.get_node("Model").set_script(null)
		var shape := CylinderShape3D.new()
		shape.radius = 0.34
		shape.height = _asset_bounds(BARREL).size.y
		_shape(barrel, shape, Vector3(0, shape.height * 0.5, 0))

	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 0.9, front + (approach - 1) * CELL)
	markers.add_child(spawn)
	var focus := Marker3D.new()
	focus.name = "CameraFocus"
	focus.position = Vector3(0, 0, approach * 0.6)
	markers.add_child(focus)
	var connections := _group(layout, "Connections")
	var entrance_connection := Marker3D.new()
	entrance_connection.name = "Entrance"
	entrance_connection.position = Vector3(0, 0, front + approach * CELL)
	entrance_connection.rotation.y = PI
	entrance_connection.gizmo_extents = 1.5
	entrance_connection.set_meta("level_connection", true)
	entrance_connection.set_meta("width", 6.0)
	entrance_connection.set_meta("grid", CELL)
	connections.add_child(entrance_connection)
	layout.set_meta("camera_size", maxf(columns * CELL * 1.25, (rows + approach) * CELL * 1.15))
	return layout


func _terrace(parent: Node, title: String, at: Vector3, rise: float) -> void:
	var terrace := _group(parent, title)
	terrace.position = at
	for x in range(-1, 2):
		for z in range(-1, 2):
			_floor(terrace, "Tile_%d_%d" % [x + 1, z + 1], Vector3(x * CELL, rise, z * CELL), Vector3(CELL, rise + 1.9, CELL))
	for i in range(-1, 2):
		_railing(terrace, Vector3(i * CELL, rise, -3))
		_railing(terrace, Vector3(-3, rise, i * CELL), PI * 0.5)
		_railing(terrace, Vector3(3, rise, i * CELL), PI * 0.5)
		if i != 0:
			_railing(terrace, Vector3(i * CELL, rise, 3))
	var steps := ceili(rise / 0.3)
	for i in range(steps):
		var height := rise * (i + 1) / steps
		var tread := Vector3(CELL, height, 0.55)
		var step := _floor(terrace, "Step_%02d" % i, Vector3(0, height, 3 + (steps - i - 0.5) * 0.55), tread)
		step.get_node("Collision").free()
	# A ramp under the stair art lets CharacterBody3D walk up without a step solver.
	var ramp := ConvexPolygonShape3D.new()
	var length := steps * 0.55
	ramp.points = PackedVector3Array([
		Vector3(-1, -0.05, 3), Vector3(1, -0.05, 3),
		Vector3(-1, -0.05, 3 + length), Vector3(1, -0.05, 3 + length),
		Vector3(-1, rise, 3), Vector3(1, rise, 3),
		Vector3(-1, 0, 3 + length), Vector3(1, 0, 3 + length),
	])
	var stairs := _group(terrace, "StairRamp")
	_shape(stairs, ramp)
	var arrival := Marker3D.new()
	arrival.name = "TerraceArrival"
	arrival.position = Vector3(0, rise, 0)
	terrace.add_child(arrival)


func _floor(parent: Node, title: String, at: Vector3, dimensions := Vector3(2, 1.9, 2)) -> Node3D:
	var module := _module(parent, title, TILE, at, 0, dimensions, true)
	_box(module, dimensions, Vector3(0, -dimensions.y * 0.5, 0))
	return module


func _railing(parent: Node, at: Vector3, yaw: float = 0) -> void:
	var module := _module(parent, "Railing_%03d" % parent.get_child_count(), RAIL, at, yaw)
	_box(module, Vector3(CELL, 1.05, 0.3), Vector3(0, 0.525, 0))


func _module(parent: Node, title: String, asset: PackedScene, at: Vector3,
		yaw: float = 0, dimensions := Vector3.ZERO, align_top: bool = false) -> Node3D:
	var module := _group(parent, title)
	module.position = at
	module.rotation.y = yaw
	var model := asset.instantiate() as Node3D
	model.name = "Model"
	module.add_child(model)
	var bounds := _asset_bounds(asset)
	# Normalize source origins without changing source scenes or scaling physics bodies.
	var source_transform := model.transform
	var adjustment := Transform3D.IDENTITY
	if dimensions != Vector3.ZERO:
		adjustment.basis = Basis.from_scale(dimensions / bounds.size)
	var adjusted := adjustment * bounds
	adjustment.origin = Vector3(-adjusted.get_center().x,
		-adjusted.end.y if align_top else -adjusted.position.y, -adjusted.get_center().z)
	model.transform = adjustment * source_transform
	return module


func _group(parent: Node, title: String) -> Node3D:
	var group := Node3D.new()
	group.name = title
	parent.add_child(group)
	return group


func _box(parent: Node, dimensions: Vector3, at: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = dimensions
	_shape(parent, shape, at)


func _shape(parent: Node, shape: Shape3D, at := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	parent.add_child(body)
	var collider := CollisionShape3D.new()
	collider.name = "Shape"
	collider.shape = shape
	collider.position = at
	body.add_child(collider)


func _mesh_collision(node: Node, module: Node3D, accumulated := Transform3D.IDENTITY) -> void:
	if node is Node3D:
		accumulated = accumulated * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var body := StaticBody3D.new()
		body.name = "ArchCollision"
		module.add_child(body)
		var collider := CollisionShape3D.new()
		collider.name = "Shape"
		collider.shape = node.mesh.create_trimesh_shape()
		collider.transform = accumulated
		body.add_child(collider)
	for child in node.get_children():
		_mesh_collision(child, module, accumulated)


func _asset_bounds(asset: PackedScene) -> AABB:
	if not _bounds_cache.has(asset.resource_path):
		var model := asset.instantiate() as Node3D
		var boxes: Array[AABB] = []
		_collect_bounds(model, Transform3D.IDENTITY, boxes)
		var bounds := boxes[0]
		for i in range(1, boxes.size()):
			bounds = bounds.merge(boxes[i])
		_bounds_cache[asset.resource_path] = bounds
		model.free()
	return _bounds_cache[asset.resource_path]


func _collect_bounds(node: Node, accumulated: Transform3D, boxes: Array[AABB]) -> void:
	if node is Node3D:
		accumulated = accumulated * node.transform
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(accumulated * node.get_aabb())
	for child in node.get_children():
		_collect_bounds(child, accumulated, boxes)
