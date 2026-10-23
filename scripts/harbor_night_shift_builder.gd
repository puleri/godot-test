extends RefCounted
## Builds saved, editable scenes from the existing harbor art and connector kit.

const KIT = preload("res://scripts/connector_kit_builder.gd")
const WALL = preload("res://Mesh/Harboretum-Mesh/habor_wall_4.tscn")
const ARCH = preload("res://Mesh/Harboretum-Mesh/habor_archway.tscn")
const BARREL = preload("res://Modules/Props/CargoBarrel.tscn")
const GRASS = preload("res://Mesh/Harboretum-Mesh/grass_tuft_01.tscn")
const PLAYER = preload("res://scenes/Player_v2.tscn")
const HOUND = preload("res://Characters/Hound/hound_npc.tscn")
const LEVEL_SCRIPT = preload("res://scripts/harbor_night_shift.gd")
const PLAYER_SCRIPT = preload("res://scripts/harbor_stealth_player.gd")
const GUARD_SCRIPT = preload("res://scripts/stealth_guard.gd")
var kit = KIT.new()


func build_room(title: String, width: int, depth: int) -> Node3D:
	var room := Node3D.new()
	room.name = title
	room.set_script(preload("res://scripts/level_connector.gd"))
	room.module_label = title
	var geometry = kit.group(room, "Geometry")
	for x in range(width / 2):
		for z in range(depth / 2):
			kit.floor_tile(geometry, Vector3(-width * 0.5 + 1 + x * 2, 0, -depth * 0.5 + 1 + z * 2))
	# Four 6m ports; cap unused ports in the level. The front parapet keeps
	# characters readable from the south-facing game camera.
	for side in [-1, 1]:
		for interval in [Vector2(-width * 0.5, -3), Vector2(3, width * 0.5)]:
			_wall_span(geometry, Vector3(interval.x, 0, side * depth * 0.5), Vector3.RIGHT, interval.y - interval.x, side > 0)
		for interval in [Vector2(-depth * 0.5, -3), Vector2(3, depth * 0.5)]:
			_wall_span(geometry, Vector3(side * width * 0.5, 0, interval.x), Vector3.BACK, interval.y - interval.x, side > 0)
	var ports = kit.group(room, "Connections")
	kit.port(ports, "South", Vector3(0, 0, depth * 0.5), PI)
	kit.port(ports, "North", Vector3(0, 0, -depth * 0.5))
	kit.port(ports, "West", Vector3(-width * 0.5, 0, 0), PI * 0.5)
	kit.port(ports, "East", Vector3(width * 0.5, 0, 0), -PI * 0.5)
	return room


func build_level() -> Node3D:
	var level := Node3D.new()
	level.name = "HarborNightShift"
	level.set_script(LEVEL_SCRIPT)
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	nav.agent_height = 1.5
	nav.agent_radius = 0.5
	nav.agent_max_climb = 0.25
	nav.region_min_size = 0.0
	nav.region_merge_size = 0.0
	region.navigation_mesh = nav
	level.add_child(region)
	var modules = kit.group(region, "Modules")
	var hall = _instance(modules, "res://Modules/Rooms/HarborHall.tscn", "CustomsHall")
	var entry = _connector(modules, "Straight", "EntryWalk")
	assert(entry.connect_to("North", hall.get_connection("South")))
	var entry_court = build_room("ArrivalCourt", 10, 6)
	modules.add_child(entry_court)
	assert(entry_court.connect_to("North", entry.get_connection("South")))
	_cap(entry_court, "South", true)
	_cap(entry_court, "East", true)
	_cap(entry_court, "West", true)
	_cap(hall, "North")
	var west_walk = _connector(modules, "Straight", "WestArcade")
	assert(west_walk.connect_to("South", hall.get_connection("West")))
	var west_turn = _connector(modules, "Corner", "WestTurn")
	assert(west_turn.connect_to("South", west_walk.get_connection("North")))
	var west_lane = _connector(modules, "Straight", "StoreLane")
	assert(west_lane.connect_to("South", west_turn.get_connection("East")))
	var stores = _instance(modules, "res://Modules/Rooms/HarborStorehouse.tscn", "SaltStores")
	assert(stores.connect_to("South", west_lane.get_connection("North")))
	_cap(stores, "North")
	_cap(stores, "West")
	var east_walk = _connector(modules, "Straight", "EastArcade")
	assert(east_walk.connect_to("South", hall.get_connection("East")))
	var east_turn = _connector(modules, "Corner", "EastTurn")
	assert(east_turn.connect_to("East", east_walk.get_connection("North")))
	var east_lane = _connector(modules, "Straight", "ArchiveLane")
	assert(east_lane.connect_to("South", east_turn.get_connection("South")))
	var archive = _instance(modules, "res://Modules/Rooms/HarborStorehouse.tscn", "BondedArchive")
	assert(archive.connect_to("South", east_lane.get_connection("North")))
	_cap(archive, "North")
	_cap(archive, "East", true)
	var crosswalk = _connector(modules, "Straight", "QuayWalk")
	assert(crosswalk.connect_to("South", stores.get_connection("East")))
	var bridge = _connector(modules, "Bridge", "TideBridge")
	assert(bridge.connect_to("South", crosswalk.get_connection("North")))
	# Check the far end in the assembled tree, including its room rotation.
	assert(_world(bridge.get_connection("North")).distance_to(_world(archive.get_connection("West"))) < 0.01)
	var cover = kit.group(region, "Cover")
	_cover_wall(cover, "CustomsScreen", Vector3(0, 0, 0), 4.6)
	_cover_wall(cover, "StoresScreen", Vector3(-17, 0, -17), 5.0)
	_cover_wall(cover, "ArchiveScreen", Vector3(17, 0, -17), 5.0)
	_cover_wall(cover, "ArchiveReturn", Vector3(18.9, 0, -18.1), 2.4, PI * 0.5)
	for entry_data in [
		[Vector3(-5, 0, 1.4), 1.5], [Vector3(5, 0, -1.2), 1.5],
		[Vector3(-21.5, 0, -14), 1.6], [Vector3(-20.4, 0, -14.7), 1.6],
		[Vector3(-13, 0, -20.5), 1.6], [Vector3(22.2, 0, -12.5), 1.6],
		[Vector3(12, 0, -20), 1.6], [Vector3(11.8, 0, -21.0), 1.6],
	]:
		_barrel(cover, entry_data[0], entry_data[1])
	var details = kit.group(level, "Details")
	var arch = kit.visual(details, ARCH, Vector3(0, 0, 6), Vector3(6, 4.0, 0.8))
	arch.name = "CustomsArch"
	# Side posts match the visual arch while keeping its 4m opening clear.
	for side in [-1, 1]:
		kit.box(arch, Vector3(0.8, 3.5, 0.8), Vector3(side * 2.6, 1.75, 0))
	for at in [Vector3(-22.7, 0, -21), Vector3(-11.3, 0, -12), Vector3(22.7, 0, -21), Vector3(4.9, 0, 18.5)]:
		kit.visual(details, GRASS, at, Vector3(0.65, 0.5, 0.65))
	_sign(details, "CUSTOMS HALL", Vector3(0, 3.4, -5.5))
	_sign(details, "SALT STORES", Vector3(-17, 3.4, -22.5))
	_sign(details, "BONDED ARCHIVE", Vector3(17, 3.4, -22.5))
	_sign(details, "TIDE BRIDGE", Vector3(2, 1.8, -19.7), Color("a0bac9"))
	_sign(details, "WAY OUT", Vector3(0, 2.6, 19), Color("77d5dc"))
	_environment(level)
	_routes_and_guards(level)
	_player(level)
	var objectives = kit.group(level, "CargoSeals")
	for data in [
		["CustomsSeal", "01 / CUSTOMS", Vector3(-4, 0, -3.5)],
		["StoresSeal", "02 / SALT STORES", Vector3(-20.5, 0, -20)],
		["ArchiveSeal", "03 / ARCHIVE", Vector3(20.5, 0, -20)],
	]:
		var seal = _instance(objectives, "res://Modules/Gameplay/CargoSeal.tscn", data[0])
		seal.position = data[2]
		seal.display_name = data[1]
	_exit(level)
	var markers = kit.group(level, "Markers")
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 0.49, 17)
	markers.add_child(spawn)
	_own_additions(level, level)
	return level


func _own_additions(node: Node, scene_root: Node) -> void:
	# Keep imported/instanced children owned by their source scenes, but save
	# additions beneath instances too (port caps, Hound lamps and player marker).
	for child in node.get_children():
		if child.owner == null:
			child.owner = scene_root
		_own_additions(child, scene_root)


func _world(node: Node3D) -> Vector3:
	var at := node.position
	var parent := node.get_parent()
	while parent is Node3D:
		at = parent.transform * at
		parent = parent.get_parent()
	return at


func _instance(parent: Node, path: String, title: String) -> Node3D:
	var instance: Node3D = load(path).instantiate()
	instance.name = title
	parent.add_child(instance)
	return instance


func _connector(parent: Node, kind: String, title: String) -> Node3D:
	return _instance(parent, "res://Modules/Connectors/%s.tscn" % kind, title)


func _wall_span(parent: Node, start: Vector3, direction: Vector3, length: float, low := false) -> void:
	var used := 0.0
	while used < length - 0.01:
		var segment := minf(2.0, length - used)
		var at := start + direction * (used + segment * 0.5)
		if low:
			kit.rail(parent, at, direction, segment)
		else:
			var piece = kit.visual(parent, WALL, at, Vector3(segment, 2.6, 0.6))
			piece.rotation.y = atan2(-direction.z, direction.x)
			kit.box(piece, Vector3(segment, 2.6, 0.6), Vector3(0, 1.3, 0))
		used += segment


func _cap(room: Node3D, port_name: String, low := false) -> void:
	var port: Marker3D = room.get_connection(port_name)
	var caps = room.get_node_or_null("PortCaps")
	if caps == null:
		caps = kit.group(room, "PortCaps")
	var along := port.basis.x
	_wall_span(caps, port.position - along * 3, along, 6, low)


func _cover_wall(parent: Node, title: String, at: Vector3, length: float, yaw := 0.0) -> void:
	var piece = kit.visual(parent, WALL, at, Vector3(length, 2.25, 0.8))
	piece.name = title
	piece.rotation.y = yaw
	kit.box(piece, Vector3(length, 2.25, 0.8), Vector3(0, 1.125, 0))


func _barrel(parent: Node, at: Vector3, height: float) -> void:
	var piece = kit.visual(parent, BARREL, at, Vector3(0.95, height, 0.95))
	piece.name = "CargoBarrel_%02d" % parent.get_child_count()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.475
	cylinder.height = height
	kit.shape(piece, cylinder, Vector3(0, height * 0.5, 0))


func _sign(parent: Node, text: String, at: Vector3, tint := Color("ebcb8d")) -> void:
	var sign := Label3D.new()
	sign.name = "Sign_%02d" % parent.get_child_count()
	sign.text = text
	sign.position = at
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.font_size = 36
	sign.pixel_size = 0.007
	sign.modulate = tint
	sign.outline_size = 8
	parent.add_child(sign)


func _environment(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	level.add_child(world)
	var water := MeshInstance3D.new()
	water.name = "HarborWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	water.mesh = plane
	water.position = Vector3(0, -2.3, -3)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("071726")
	water.material_override = material
	level.add_child(water)
	var lights = kit.group(level, "HarborLights")
	for at in [Vector3(0, 5, 17), Vector3(0, 5, 8), Vector3(-3, 5, 1), Vector3(3, 5, -3), Vector3(-10, 5, 0), Vector3(10, 5, 0), Vector3(-17, 5, -7), Vector3(17, 5, -7), Vector3(-20, 5, -14), Vector3(-14, 5, -20), Vector3(14, 5, -14), Vector3(20, 5, -20), Vector3(-5, 5, -17), Vector3(4, 5, -17)]:
		var lamp := SpotLight3D.new()
		lamp.name = "QuayLamp_%02d" % lights.get_child_count()
		lamp.position = at
		lights.add_child(lamp)
	apply_demo_lighting(level)
	var camera := Camera3D.new()
	camera.name = "LevelCamera"
	camera.position = Vector3(17, 24, 40)
	camera.basis = Basis.looking_at(Vector3(0, 0, 17) - camera.position)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21
	camera.far = 180
	camera.current = true
	level.add_child(camera)


func apply_demo_lighting(level: Node3D) -> void:
	# Copy the reference fixtures themselves, including implicit default values.
	# This also works on a saved level without rebuilding its layout or gameplay.
	var reference: Node3D = load("res://Levels/Demo_A2.tscn").instantiate()
	level.get_node("WorldEnvironment").environment = reference.get_node("WorldEnvironment").environment.duplicate(true)
	for pair in [["DirectionalLight3D", "NightFill"], ["StormFlashLight", "StormFlashLight"]]:
		var old := level.get_node_or_null(pair[1])
		if old != null:
			old.free()
		var light: DirectionalLight3D = reference.get_node(pair[0]).duplicate()
		light.name = pair[1]
		if pair[1] == "StormFlashLight":
			light.directional_shadow_max_distance = 85
		level.add_child(light)
	var source: SpotLight3D = reference.get_node("SpotLight3D")
	var lights := level.get_node("HarborLights")
	for old in lights.get_children():
		if old is SpotLight3D:
			var lamp := source.duplicate() as SpotLight3D
			lamp.name = old.name
			lamp.position = old.position
			old.free()
			lights.add_child(lamp)
	var ambient := lights.get_node_or_null("AmbientLamps")
	if ambient != null:
		ambient.free()
	ambient = kit.group(lights, "AmbientLamps")
	# Repeat Demo_A2's pair in the four rooms, relative to its original floor.
	var reference_center := Vector3(5.205885, 1.13, -1.769581)
	for center in [Vector3.ZERO, Vector3(-17, 0, -17), Vector3(17, 0, -17), Vector3(0, 0, 17)]:
		for fixture in ["OmniLight3D", "OmniLight3D2"]:
			var lamp: OmniLight3D = reference.get_node(fixture).duplicate()
			lamp.name = "RoomLamp_%02d" % ambient.get_child_count()
			lamp.position = center + lamp.position - reference_center
			ambient.add_child(lamp)
	var guards := level.get_node_or_null("Guards")
	if guards != null:
		for guard in guards.get_children():
			guard.get_node("SightLight").light_color = source.light_color
	_own_additions(level, level)
	reference.free()


func _routes_and_guards(level: Node3D) -> void:
	var routes = kit.group(level, "Routes")
	var guards = kit.group(level, "Guards")
	var route_data := [
		["CustomsHound", "CustomsPatrol", [Vector3(4, 0, 3), Vector3(4, 0, -3), Vector3(-4, 0, -3), Vector3(-4, 0, 3)]],
		["ArchiveHound", "ArchivePatrol", [Vector3(21, 0, -14), Vector3(21, 0, -20), Vector3(13.5, 0, -20), Vector3(13.5, 0, -14)]],
	]
	for i in route_data.size():
		var data: Array = route_data[i]
		var route = kit.group(routes, data[1])
		for at in data[2]:
			var point := Marker3D.new()
			point.name = "Point_%d" % route.get_child_count()
			point.position = at
			route.add_child(point)
		var guard := HOUND.instantiate() as CharacterBody3D
		guard.name = data[0]
		guard.set_script(GUARD_SCRIPT)
		guard.position = data[2][0]
		guard.player_path = NodePath("../../Player")
		guard.route_path = NodePath("../../Routes/" + data[1])
		guard.walk_speed = 1.25
		guard.run_speed = 3.4
		guard.acceleration = 7.0
		guard.braking = 9.0
		guard.seconds_to_detect = 1.25
		guard.pause_min_seconds = 0.8
		guard.pause_max_seconds = 1.4
		guard.alert_chance_on_arrival = 0.0
		guard.random_seed = 8101 + i
		guard.show_vision = false
		guards.add_child(guard)
		var beam := SpotLight3D.new()
		beam.name = "SightLight"
		beam.position.y = 0.75
		beam.light_color = Color.WHITE
		beam.light_energy = 8.0
		beam.shadow_enabled = true
		beam.shadow_bias = 0.03
		beam.spot_range = 7
		beam.spot_angle = 40
		beam.spot_attenuation = 0.0
		beam.spot_angle_attenuation = 0.35
		guard.add_child(beam)


func _player(level: Node3D) -> void:
	var player := PLAYER.instantiate() as CharacterBody3D
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 0.49, 17)
	player.side_plane_z = 17.0
	player.overview_camera_path = NodePath("../LevelCamera")
	player.max_walk_speed = 4.2
	player.jump_velocity = 6.5
	player.collision_layer = 4
	player.collision_mask = 1
	player.floor_snap_length = 0.35
	level.add_child(player)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.40
	var marker := MeshInstance3D.new()
	marker.name = "PlayerMarker"
	marker.mesh = ring
	marker.position.y = -0.44
	marker.material_override = _glow(Color("79dce3"))
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child(marker)


func _glow(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	return material


func _exit(level: Node3D) -> void:
	var exit := Area3D.new()
	exit.name = "Extraction"
	exit.position = Vector3(0, 0, 17)
	exit.collision_layer = 0
	exit.collision_mask = 4
	level.add_child(exit)
	var trigger := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 2.5
	trigger.shape = shape
	trigger.position.y = 0.8
	exit.add_child(trigger)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.15
	mesh.outer_radius = 1.25
	ring.mesh = mesh
	ring.position.y = 0.07
	ring.material_override = _glow(Color("79dce3"))
	exit.add_child(ring)
	_sign(exit, "EXTRACTION", Vector3(0, 2.3, 0), Color("79dce3"))
