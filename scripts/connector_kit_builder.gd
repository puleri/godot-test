@tool
extends RefCounted
## Source builder for the saved connector scenes; no construction runs during play.

const CONNECTOR = preload("res://scripts/level_connector.gd")
const TILE = preload("res://Mesh/Harboretum-Mesh/stone_tile_block.tscn")
const RAIL = preload("res://Mesh/Harboretum-Mesh/stone_railing.tscn")
const PLANKS = preload("res://Mesh/Harboretum-Mesh/wood_planks.tscn")
const SUPPORT = preload("res://Mesh/Harboretum-Mesh/wood_walk_legs.tscn")
const PLAYER = preload("res://scenes/Player_v2.tscn")
const PLAYTEST_CONTROLLER = preload("res://scripts/courtyard_playtest_player.gd")
const MODULE_NAMES := ["Straight", "Corner", "TJunction", "Staircase", "Bridge"]
var _bounds: Dictionary = {}
var _boxes: Dictionary = {}


func build_demo() -> Node3D:
	var level := Node3D.new()
	level.name = "ConnectorKitDemo"
	var generated := group(level, "Generated")
	generated.set_meta("camera_size", 48.0)
	var modules := group(generated, "Modules")
	var straight := _instance(modules, "Straight", "EntryWalk")
	var junction := _instance(modules, "TJunction", "Junction")
	assert(junction.connect_to("South", straight.get_connection("North")))
	var corner := _instance(modules, "Corner", "Corner")
	assert(corner.connect_to("South", junction.get_connection("West")))
	var bridge := _instance(modules, "Bridge", "Bridge")
	assert(bridge.connect_to("South", corner.get_connection("East")))
	var stairs := _instance(modules, "Staircase", "Staircase")
	assert(stairs.connect_to("South", junction.get_connection("East")))
	var upper_walk := _instance(modules, "Straight", "UpperWalk")
	assert(upper_walk.connect_to("South", stairs.get_connection("North")))
	var start := _plaza(modules, "StartCourt")
	assert(start.connect_to("South", straight.get_connection("South")))
	var lower := _plaza(modules, "LowerCourt")
	assert(lower.connect_to("South", bridge.get_connection("North")))
	var upper := _plaza(modules, "UpperCourt")
	assert(upper.connect_to("South", upper_walk.get_connection("North")))
	var labels := group(generated, "Labels")
	for entry in [
		["START", Vector3(0, 1.9, 4.5)],
		["STRAIGHT", Vector3(0, 1.9, -3.5)],
		["T-JUNCTION", Vector3(0, 1.9, -12)],
		["CORNER", Vector3(-5.5, 1.9, -10)],
		["WOODEN BRIDGE", Vector3(-6, 1.9, -20)],
		["LOWER COURT", Vector3(-6, 1.9, -30)],
		["STAIRCASE / +2m", Vector3(7, 3.8, -11)],
		["UPPER WALK", Vector3(15, 3.9, -11)],
		["UPPER COURT", Vector3(23, 3.9, -11)],
	]:
		var label := Label3D.new()
		label.name = "Label_%02d" % labels.get_child_count()
		label.text = entry[0]
		label.position = entry[1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 44
		label.pixel_size = 0.009
		label.modulate = Color(0.98, 0.86, 0.61)
		label.outline_modulate = Color(0.03, 0.04, 0.05)
		label.outline_size = 8
		labels.add_child(label)
	var markers := group(generated, "Markers")
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 0.9, 3)
	markers.add_child(spawn)
	var focus := Marker3D.new()
	focus.name = "CameraFocus"
	focus.position = Vector3(7, 0, -12)
	markers.add_child(focus)
	_demo_environment(level, focus.position)
	var player := PLAYER.instantiate() as CharacterBody3D
	player.name = "Player"
	player.set_script(PLAYTEST_CONTROLLER)
	player.set("max_walk_speed", 5.0)
	player.floor_snap_length = 0.35
	level.add_child(player)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	level.add_child(hud)
	var caption := Label.new()
	caption.name = "Caption"
	caption.position = Vector2(48, 36)
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_color", Color(0.94, 0.91, 0.82))
	caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption.text = "CONNECTOR KIT  /  6m CONNECTIONS  /  2m GRID\nWASD / arrows: move   Space: jump   Tab: camera   R: reset"
	hud.add_child(caption)
	return level


func _instance(parent: Node, kind: String, title: String) -> Node3D:
	var module: Node3D = load("res://Modules/Connectors/%s.tscn" % kind).instantiate()
	module.name = title
	parent.add_child(module)
	return module


func _plaza(parent: Node, title: String) -> Node3D:
	var plaza := group(parent, title)
	plaza.set_script(CONNECTOR)
	plaza.set("module_label", title)
	var geometry := group(plaza, "Geometry")
	strip(geometry, 0, 6)
	for x in range(-1, 2):
		rail(geometry, Vector3(x * 2, 0, -6), Vector3.RIGHT)
	var connections := group(plaza, "Connections")
	port(connections, "South", Vector3.ZERO, PI)
	return plaza


func _demo_environment(level: Node3D, focus: Vector3) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.065, 0.095, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.74, 0.85)
	environment.ambient_light_energy = 0.65
	world.environment = environment
	level.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -28, 0)
	sun.light_color = Color(1, 0.87, 0.7)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150
	level.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-35, 145, 0)
	fill.light_color = Color(0.55, 0.7, 0.9)
	fill.light_energy = 0.35
	level.add_child(fill)
	var camera := Camera3D.new()
	camera.name = "OverviewCamera"
	camera.position = focus + Vector3(24, 32, 36)
	camera.basis = Basis.looking_at(focus - camera.position)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 48
	camera.far = 200
	camera.current = true
	level.add_child(camera)


func build_module(kind: String) -> Node3D:
	assert(kind in MODULE_NAMES)
	var module := Node3D.new()
	module.set_script(CONNECTOR)
	module.name = kind
	module.module_label = kind
	var geometry := group(module, "Geometry")
	var connections := group(module, "Connections")
	port(connections, "South", Vector3.ZERO, PI)
	match kind:
		"Straight":
			strip(geometry, 0, 8)
			port(connections, "North", Vector3(0, 0, -8))
		"Corner", "TJunction":
			for row in range(3):
				for column in range(-1, 2):
					floor_tile(geometry, Vector3(column * 2, 0, -1 - row * 2))
			for column in range(-1, 2):
				rail(geometry, Vector3(column * 2, 0, -6), Vector3.RIGHT)
			port(connections, "East", Vector3(3, 0, -3), -PI * 0.5)
			if kind == "Corner":
				for row in range(3):
					rail(geometry, Vector3(-3, 0, -1 - row * 2), Vector3.FORWARD)
			else:
				port(connections, "West", Vector3(-3, 0, -3), PI * 0.5)
		"Staircase":
			strip(geometry, 0, 2)
			strip(geometry, -6, 2, 2)
			for step in range(8):
				var height := (step + 1) * 0.25
				for column in range(-1, 2):
					var tread := visual(geometry, TILE, Vector3(column * 2, height, -2.25 - step * 0.5), Vector3(2, height + 1.9, 0.5), true)
					tread.name = "Step_%02d_%d" % [step, column + 1]
			var ramp := ConvexPolygonShape3D.new()
			ramp.points = PackedVector3Array([
				Vector3(-3, -1.9, -2), Vector3(3, -1.9, -2),
				Vector3(-3, -1.9, -6), Vector3(3, -1.9, -6),
				Vector3(-3, 0, -2), Vector3(3, 0, -2),
				Vector3(-3, 2, -6), Vector3(3, 2, -6),
			])
			shape(geometry, ramp)
			for side in [-1, 1]:
				for segment in range(2):
					rail(geometry, Vector3(side * 3, 0.5 + segment, -3 - segment * 2), Vector3(0, 1, -2), sqrt(5.0))
			port(connections, "North", Vector3(0, 2, -8))
		"Bridge":
			strip(geometry, 0, 2)
			strip(geometry, -10, 2)
			for row in range(4):
				for column in range(-1, 2):
					var deck := visual(geometry, PLANKS, Vector3(column * 2, 0, -3 - row * 2), Vector3(2, 0.36, 2), true)
					box(deck, Vector3(2, 0.36, 2), Vector3(0, -0.18, 0))
				for side in [-1, 1]:
					rail(geometry, Vector3(side * 3, 0, -3 - row * 2), Vector3.FORWARD)
			for z in [-3, -9]:
				for x in [-2, 2]:
					visual(geometry, SUPPORT, Vector3(x, -0.38, z), Vector3(2, 2.26, 2), true)
			port(connections, "North", Vector3(0, 0, -12))
	assign_owners(module, module)
	return module


func strip(parent: Node, start_z: float, length: int, height: float = 0) -> void:
	for row in range(length / 2):
		for column in range(-1, 2):
			floor_tile(parent, Vector3(column * 2, height, start_z - 1 - row * 2))
		for side in [-1, 1]:
			rail(parent, Vector3(side * 3, height, start_z - 1 - row * 2), Vector3.FORWARD)


func floor_tile(parent: Node, at: Vector3) -> Node3D:
	var tile := visual(parent, TILE, at, Vector3(2, 1.9, 2), true)
	box(tile, Vector3(2, 1.9, 2), Vector3(0, -0.95, 0))
	return tile


func rail(parent: Node, at: Vector3, along: Vector3, length: float = 2) -> void:
	var railing := visual(parent, RAIL, at, Vector3(length, 1.05, 0.3))
	var x := along.normalized()
	var z := x.cross(Vector3.UP).normalized()
	var y := z.cross(x).normalized()
	railing.basis = Basis(x, y, z)
	box(railing, Vector3(length, 1.05, 0.3), Vector3(0, 0.525, 0))


func port(parent: Node, title: String, at: Vector3, yaw: float = 0) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = title
	marker.position = at
	marker.rotation.y = yaw
	marker.gizmo_extents = 1.5
	marker.set_meta("level_connection", true)
	marker.set_meta("width", 6.0)
	marker.set_meta("grid", 2.0)
	parent.add_child(marker)
	return marker


func visual(parent: Node, asset: PackedScene, at: Vector3, dimensions: Vector3, align_top: bool = false) -> Node3D:
	var piece := group(parent, "Piece_%03d" % parent.get_child_count())
	piece.position = at
	var model := asset.instantiate() as Node3D
	model.name = "Model"
	piece.add_child(model)
	var bounds := asset_bounds(asset)
	var correction := Transform3D(Basis.from_scale(dimensions / bounds.size), Vector3.ZERO)
	var adjusted := correction * bounds
	correction.origin = Vector3(-adjusted.get_center().x,
		-adjusted.end.y if align_top else -adjusted.position.y, -adjusted.get_center().z)
	model.transform = correction * model.transform
	return piece


func box(parent: Node, dimensions: Vector3, at := Vector3.ZERO) -> void:
	if not _boxes.has(dimensions):
		var resource := BoxShape3D.new()
		resource.size = dimensions
		_boxes[dimensions] = resource
	shape(parent, _boxes[dimensions], at)


func shape(parent: Node, resource: Shape3D, at := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision_%03d" % parent.get_child_count()
	parent.add_child(body)
	var collider := CollisionShape3D.new()
	collider.name = "Shape"
	collider.shape = resource
	collider.position = at
	body.add_child(collider)


func group(parent: Node, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	parent.add_child(node)
	return node


func assign_owners(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
		if not node.scene_file_path.is_empty():
			return
	for child in node.get_children():
		assign_owners(child, scene_root)


func save_scene(node: Node, path: String) -> Error:
	assign_owners(node, node)
	var packed := PackedScene.new()
	var result := packed.pack(node)
	if result == OK:
		result = ResourceSaver.save(packed, path)
	return result


func asset_bounds(asset: PackedScene) -> AABB:
	if not _bounds.has(asset.resource_path):
		var model := asset.instantiate()
		var boxes: Array[AABB] = []
		_collect_bounds(model, Transform3D.IDENTITY, boxes)
		var bounds := boxes[0]
		for i in range(1, boxes.size()):
			bounds = bounds.merge(boxes[i])
		_bounds[asset.resource_path] = bounds
		model.free()
	return _bounds[asset.resource_path]


func _collect_bounds(node: Node, accumulated: Transform3D, boxes: Array[AABB]) -> void:
	if node is Node3D:
		accumulated = accumulated * node.transform
	if node is MeshInstance3D and node.mesh != null:
		boxes.append(accumulated * node.get_aabb())
	for child in node.get_children():
		_collect_bounds(child, accumulated, boxes)


