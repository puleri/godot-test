extends "res://scripts/harbor_night_shift_builder.gd"
## Saved showcase using the same room, connector, wall, barrel and bell assets.


func build_lab() -> Node3D:
	var level := Node3D.new()
	level.name = "StealthSystemsLab"
	level.set_script(preload("res://scripts/stealth_systems_lab.gd"))
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
	nav.region_min_size = 0
	nav.region_merge_size = 0
	region.navigation_mesh = nav
	level.add_child(region)
	var modules = kit.group(region, "Modules")
	var rooms: Array[Node3D] = []
	for i in 3:
		var room = _instance(modules, "res://Modules/Rooms/HarborStorehouse.tscn", ["AcousticBay", "SquadBay", "LureBay"][i])
		room.position.x = (i - 1) * 22
		_cap(room, "North")
		_cap(room, "South", true)
		rooms.append(room)
	_cap(rooms[0], "West")
	_cap(rooms[2], "East", true)
	for i in 2:
		var walk = _connector(modules, "Straight", "Link_%d" % i)
		assert(walk.connect_to("South", rooms[i].get_connection("East")))
	var cover = kit.group(region, "Cover")
	_wall_span(cover, Vector3(-29, 0, 0), Vector3.RIGHT, 5.5)
	_wall_span(cover, Vector3(-20.5, 0, 0), Vector3.RIGHT, 5.5)
	var gate = kit.group(region, "AcousticGate")
	_cover_wall(gate, "Door", Vector3(-22, 0, 0), 3.0)
	gate.visible = false
	for body in gate.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
	# A genuinely sealed control enclosure has no acoustic portal.
	_wall_span(cover, Vector3(-19, 0, -6), Vector3.BACK, 5)
	_wall_span(cover, Vector3(-19, 0, -1), Vector3.RIGHT, 4)
	_wall_span(cover, Vector3(-15, 0, -6), Vector3.BACK, 5, true)
	_cover_wall(cover, "SquadScreen", Vector3(0, 0, 0), 4.0)
	_cover_wall(cover, "LureScreen", Vector3(22, 0, 0), 4.0)
	_barrel(cover, Vector3(27, 0, -4), 1.6)
	var acoustic = kit.group(level, "Acoustics")
	acoustic.set_script(preload("res://scripts/lab_acoustics.gd"))
	for at in [Vector3(-22, 0, 1.2), Vector3(-22, 0, -1.2), Vector3(-3.2, 0, 1.2), Vector3(-3.2, 0, -1.2), Vector3(3.2, 0, 1.2), Vector3(3.2, 0, -1.2), Vector3(18.8, 0, 1.2), Vector3(18.8, 0, -1.2), Vector3(25.2, 0, 1.2), Vector3(25.2, 0, -1.2)]:
		var marker := Marker3D.new()
		marker.name = "SoundCorner_%02d" % acoustic.get_child_count()
		marker.position = at
		acoustic.add_child(marker)
	var details = kit.group(level, "Details")
	for i in 3:
		_sign(details, ["01 / SOUND THROUGH DOORS", "02 / DIVIDE THE WATCH", "03 / SET THE TRAP"][i], Vector3((i - 1) * 22, 3.4, -5.5))
		_pad(details, Vector3((i - 1) * 22 - 4, 0, 3), Color("79dce3"))
	_sign(details, "SEALED CONTROL", Vector3(-17, 3.0, -5))
	_environment(level)
	# Keep Demo_A2 fixture settings; put them over this showcase's actual bays.
	var reference: Node3D = load("res://Levels/Demo_A2.tscn").instantiate()
	var lights := level.get_node("HarborLights")
	for old in lights.get_children():
		old.free()
	for i in 3:
		for z in [-3, 3]:
			var lamp: SpotLight3D = reference.get_node("SpotLight3D").duplicate()
			lamp.name = "WhitePool_%02d" % lights.get_child_count()
			lamp.position = Vector3((i - 1) * 22 + 3.178, 5, z)
			lamp.shadow_enabled = true
			lights.add_child(lamp)
		for fixture in ["OmniLight3D", "OmniLight3D2"]:
			var lamp: OmniLight3D = reference.get_node(fixture).duplicate()
			lamp.name = "RoomFill_%02d" % lights.get_child_count()
			lamp.position += Vector3((i - 1) * 22, 0, 0) - Vector3(5.205885, 1.13, -1.769581)
			lamp.shadow_enabled = true
			lights.add_child(lamp)
	reference.free()
	_player(level)
	var player := level.get_node("Player")
	player.set_script(preload("res://scripts/systems_lab_player.gd"))
	player.overview_camera_path = NodePath("../LevelCamera")
	player.max_walk_speed = MOVEMENT.ROOK_MOVE_SPEED
	player.jump_velocity = 6.5
	player.position = Vector3(-26, 0.49, 3)
	player.side_plane_z = 3.0
	player.follow_size = 18.0
	var sensor := Node3D.new()
	sensor.name = "ExposureSensor"
	sensor.set_script(preload("res://scripts/stealth_exposure_sensor.gd"))
	player.add_child(sensor)
	_guards(level)
	var lure := Node3D.new()
	lure.name = "RemoteChime"
	lure.visible = false
	var bell := preload("res://Mesh/Bell/bell.tscn").instantiate()
	bell.name = "Visual"
	bell.scale = Vector3.ONE * 0.6
	lure.add_child(bell)
	level.add_child(lure)
	_pad(lure, Vector3.ZERO, Color("e4bc77"))
	for light in level.find_children("*", "Light3D", true, false):
		light.add_to_group("stealth_lights", true)
	_own_additions(level, level)
	return level


func _pad(parent: Node, at: Vector3, tint: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Pad_%d" % parent.get_child_count()
	ring.position = at + Vector3.UP * 0.06
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.65
	mesh.outer_radius = 0.72
	ring.mesh = mesh
	ring.material_override = _glow(tint)
	parent.add_child(ring)


func _guards(level: Node3D) -> void:
	var guards = kit.group(level, "Guards")
	var routes = kit.group(level, "Routes")
	var specs := [
		["DoorListener", 0, Vector3(-26, 0, -3), true],
		["SealedListener", 0, Vector3(-17, 0, -3), true],
		["WestWatch", 1, Vector3(-4, 0, -3), false],
		["ExitWatch", 1, Vector3(4, 0, -3), false],
		["LureWatch", 2, Vector3(26, 0, -3), false],
	]
	for spec in specs:
		var route = kit.group(routes, spec[0])
		var point := Marker3D.new()
		point.name = "Home"
		point.position = spec[2]
		route.add_child(point)
		var guard := HOUND.instantiate() as CharacterBody3D
		guard.name = spec[0]
		guard.set_script(preload("res://scripts/systems_lab_guard.gd"))
		guard.position = spec[2]
		guard.guard_title = spec[0].to_upper()
		guard.bay = spec[1]
		guard.listen_only = spec[3]
		guard.player_path = NodePath("../../Player")
		guard.route_path = NodePath("../../Routes/" + spec[0])
		guard.walk_speed = 1.6
		guard.run_speed = MOVEMENT.HOUND_PURSUIT_SPEED
		guard.hearing_range = 14.0
		guard.sight_range = 8.0
		guard.field_of_view_degrees = 90.0
		guard.lamp_range = 7.0
		guard.lamp_height_offset = 0.55
		guard.lamp_downward_angle_degrees = 12
		guard.has_lamp = not spec[3]
		guard.seconds_to_detect = 1.5
		guard.show_vision = false
		guard.alert_chance_on_arrival = 0.0
		guards.add_child(guard)
		var beam := SpotLight3D.new()
		beam.name = "SightLight"
		beam.light_energy = 8
		beam.shadow_enabled = true
		beam.shadow_bias = 0.03
		beam.spot_attenuation = 0
		beam.spot_angle_attenuation = 0.35
		guard.add_child(beam)
