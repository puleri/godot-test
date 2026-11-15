extends "res://scripts/harbor_night_shift_builder.gd"
const CUTAWAY_LAYER := 1 << 18


func build_store() -> Node3D:
	var level := Node3D.new()
	level.name = "LamplightStore"
	level.set_script(preload("res://scripts/lamplight_store.gd"))
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
	var floor = kit.group(region, "Floors")
	for x in range(-9, 10, 2):
		for z in range(-1, 12, 2):
			kit.floor_tile(floor, Vector3(x, 0, z))
	for x in range(-6, 7, 2):
		for z in range(-13, -2, 2):
			kit.floor_tile(floor, Vector3(x, 0, z))
	var walls = kit.group(region, "Walls")
	_wall_span(walls, Vector3(-7, 0, -14), Vector3.RIGHT, 14)
	_wall_span(walls, Vector3(-7, 0, -14), Vector3.BACK, 12)
	_wall_span(walls, Vector3(-10, 0, -2), Vector3.BACK, 14, true)
	_wall_span(walls, Vector3(10, 0, -2), Vector3.BACK, 14, true)
	_wall_span(walls, Vector3(-10, 0, 12), Vector3.RIGHT, 20, true)
	var facade = kit.group(region, "CutawayFacade")
	_wall_span(facade, Vector3(7, 0, -14), Vector3.BACK, 12)
	_wall_span(facade, Vector3(-7, 0, -2), Vector3.RIGHT, 5.5)
	_wall_span(facade, Vector3(1.5, 0, -2), Vector3.RIGHT, 5.5)
	var arch = kit.visual(facade, ARCH, Vector3(0, 0, -2), Vector3(3, 3.0, 0.7))
	arch.name = "EntranceArch"
	_set_cutaway(facade)
	# Keep this collision outside the navigation bake: it is a weather roof,
	# not a second walkable floor. Camera culling never disables its shadows.
	var roof = kit.group(level, "WeatherRoof")
	for x in range(-6, 7, 2):
		for z in range(-13, -2, 2):
			kit.visual(roof, KIT.TILE, Vector3(x, 3.2, z), Vector3(2, 0.25, 2))
	kit.box(roof, Vector3(14, 0.25, 12), Vector3(0, 3.325, -8))
	_set_cutaway(roof)
	var cover = kit.group(region, "Cover")
	_cover_wall(cover, "AlcoveBack", Vector3(-4, 0, -11.1), 3)
	for at in [Vector3(-5, 0, -9.7), Vector3(-3, 0, -9.7), Vector3(-6, 0, -5), Vector3(6, 0, 6)]:
		_barrel(cover, at, 1.6)
	_barrel(cover, Vector3(5, 0, -12), 1.8)
	var details = kit.group(level, "Details")
	_sign(facade, "LAMPLIGHT STORE", Vector3(0, 3.1, -1.7))
	_sign(details, "HIDE / HOLD Q TO PEEK", Vector3(-4, 2.1, -10.8), Color("79dce3"))
	_sign(details, "LIGHT SWITCH", Vector3(-2.5, 1.8, -3.1))
	_sign(details, "LEDGER", Vector3(-0.5, 1.8, -12))
	_marker(level, "LightSwitch", Vector3(-2.5, 0.49, -3.2), Color("e4bc77"))
	_marker(level, "HideSpot", Vector3(-4, 0.49, -10), Color("79dce3"))
	_marker(level, "Ledger", Vector3(-0.5, 0.49, -12), Color("e4bc77"))
	_marker(level, "ExitMarker", Vector3(0, 0.49, 8), Color("79dce3"))
	var stand = kit.visual(details, KIT.PLANKS, Vector3(-0.5, 0.1, -12), Vector3(1, 0.7, 0.7))
	stand.name = "LedgerStand"
	var panel = kit.visual(details, KIT.PLANKS, Vector3(-2.5, 0.9, -2.5), Vector3(0.4, 0.6, 0.12))
	panel.name = "SwitchPanel"
	kit.visual(panel, KIT.PLANKS, Vector3(0, 0.2, -0.12), Vector3(0.12, 0.25, 0.15))
	_environment(level)
	var lights := level.get_node("HarborLights")
	for child in lights.get_children():
		child.free()
	var store_lights = kit.group(lights, "StoreLights")
	var reference: Node3D = load("res://Levels/Demo_A2.tscn").instantiate()
	for spec in [[Vector3(-3, 3, -6), store_lights], [Vector3(3, 3, -10), store_lights], [Vector3(-6, 5, 5), lights], [Vector3(6, 5, 2), lights]]:
		var lamp: SpotLight3D = reference.get_node("SpotLight3D").duplicate()
		lamp.name = "WhiteSpot_%02d" % spec[1].get_child_count()
		lamp.position = spec[0]
		lamp.rotation_degrees = Vector3(-90, 0, 0)
		lamp.spot_angle = 48
		lamp.spot_range = 12
		lamp.shadow_enabled = true
		spec[1].add_child(lamp)
	reference.free()
	_player(level)
	var player := level.get_node("Player")
	player.set_script(preload("res://scripts/lamplight_player.gd"))
	player.overview_camera_path = NodePath("../LevelCamera")
	player.max_walk_speed = MOVEMENT.ROOK_MOVE_SPEED
	player.jump_velocity = 6.5
	player.position = Vector3(0, 0.49, 8)
	player.side_plane_z = 8
	var sensor := Node3D.new()
	sensor.name = "ExposureSensor"
	sensor.set_script(preload("res://scripts/stealth_exposure_sensor.gd"))
	player.add_child(sensor)
	var routes = kit.group(level, "Routes")
	var guards = kit.group(level, "Guards")
	for spec in [["Watchman", false, [Vector3(5, 0, 3), Vector3(5, 0, 8), Vector3(-5, 0, 8), Vector3(-5, 0, 3)]], ["Tracker", true, [Vector3(3, 0, -11), Vector3(3, 0, -6)]]]:
		var route = kit.group(routes, spec[0])
		for at in spec[2]:
			var point := Marker3D.new()
			point.position = at
			route.add_child(point)
		var guard := HOUND.instantiate() as CharacterBody3D
		guard.name = spec[0]
		guard.set_script(preload("res://scripts/lamplight_guard.gd"))
		guard.guard_title = "TRACKER / CLOSE SENSE 2.6m" if spec[1] else "WATCHMAN / LAMP VISION"
		guard.tracker = spec[1]
		guard.position = spec[2][0]
		guard.player_path = NodePath("../../Player")
		guard.route_path = NodePath("../../Routes/" + spec[0])
		guard.walk_speed = 1.9 if spec[1] else 1.25
		guard.run_speed = MOVEMENT.HOUND_PURSUIT_SPEED
		guard.acceleration = 7.0 if spec[1] else 3.5
		guard.braking = 9.0 if spec[1] else 6.0
		guard.hearing_range = 12 if spec[1] else 9
		guard.sight_range = 7
		guard.field_of_view_degrees = 90
		guard.lamp_range = 6
		guard.lamp_height_offset = 0.55
		guard.lamp_downward_angle_degrees = 12
		guard.has_lamp = not spec[1]
		guard.seconds_to_detect = 0.9 if spec[1] else 1.5
		guard.suspicion_per_second = 0.5 if spec[1] else 0.25
		guard.uncertain_investigation_delay = 0.45 if spec[1] else 0.8
		guard.show_vision = false
		guards.add_child(guard)
		var lamp := SpotLight3D.new()
		lamp.name = "SightLight"
		lamp.light_energy = 8
		lamp.spot_attenuation = 0
		lamp.spot_angle_attenuation = 0.35
		lamp.shadow_enabled = true
		guard.add_child(lamp)
	for light in level.find_children("*", "Light3D", true, false):
		light.add_to_group("stealth_lights", true)
	_own_additions(level, level)
	return level


func _set_cutaway(group: Node) -> void:
	for geometry in group.find_children("*", "GeometryInstance3D", true, false):
		geometry.layers = CUTAWAY_LAYER


func _marker(level: Node, title: String, at: Vector3, tint: Color) -> void:
	var marker := Marker3D.new()
	marker.name = title
	marker.position = at
	level.add_child(marker)
	var circle := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.55
	mesh.outer_radius = 0.60
	circle.mesh = mesh
	circle.position.y = -0.43
	circle.material_override = _glow(tint)
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(circle)
