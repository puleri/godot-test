extends "res://scripts/harbor_night_shift_builder.gd"
## Authored three-zone layout. The saved scene remains fully editable.

const BELL = preload("res://Mesh/Bell/bell.tscn")
const MOUSE = preload("res://Characters/Mouse/mouse_npc.tscn")
const EXCHANGE_GUARD = preload("res://scripts/exchange_guard.gd")


func build_exchange() -> Node3D:
	var level := Node3D.new()
	level.name = "MidnightExchange"
	level.set_script(preload("res://scripts/midnight_exchange.gd"))
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
	var floor_group = kit.group(region, "StoneFloor")
	for x in range(-15, 16, 2):
		for z in range(-16, 17, 2):
			kit.floor_tile(floor_group, Vector3(x, 0, z))
	var walls = kit.group(region, "Walls")
	_wall_span(walls, Vector3(-16, 0, -17), Vector3.RIGHT, 32)
	_wall_span(walls, Vector3(-16, 0, 17), Vector3.RIGHT, 32, true)
	_wall_span(walls, Vector3(-16, 0, -17), Vector3.BACK, 34)
	_wall_span(walls, Vector3(16, 0, -17), Vector3.BACK, 34, true)
	# Two four-metre doorways connect both wings to the vault gallery.
	for span in [Vector2(-16, -7), Vector2(-3, 3), Vector2(7, 16)]:
		_wall_span(walls, Vector3(span.x, 0, -4), Vector3.RIGHT, span.y - span.x)
	var cover = kit.group(region, "Cover")
	_cover_wall(cover, "ArrivalScreen", Vector3(0, 0, 10), 10)
	_cover_wall(cover, "WingDivider", Vector3(0, 0, 3), 9, PI / 2)
	_cover_wall(cover, "SortingScreen", Vector3(-9, 0, 2), 4, PI / 2)
	_cover_wall(cover, "CrankScreen", Vector3(9, 0, 3), 4, PI / 2)
	_cover_wall(cover, "VaultScreen", Vector3(0, 0, -11), 5)
	_cover_wall(cover, "WestGalleryScreen", Vector3(-10, 0, -9), 4, PI / 2)
	_cover_wall(cover, "EastGalleryScreen", Vector3(10, 0, -9), 4, PI / 2)
	for at in [Vector3(-14, 0, 8), Vector3(-13, 0, 8), Vector3(13, 0, 8), Vector3(14, 0, 8), Vector3(-14, 0, -14), Vector3(14, 0, -14), Vector3(6, 0, -10), Vector3(-6, 0, -10)]:
		_barrel(cover, at, 1.6)
	var details = kit.group(level, "Details")
	_sign(details, "01 / SORTING", Vector3(-11, 2.8, 6))
	_sign(details, "02 / VAULT CRANK", Vector3(12, 2.8, 5))
	_sign(details, "03 / NIGHT VAULT", Vector3(0, 3.2, -16))
	_sign(details, "MOUSE WATCH\nWide sight / quick reactions", Vector3(-6, 1.8, 8), Color("a0bac9"))
	for at in [Vector3(-15, 0, 15), Vector3(15, 0, 15), Vector3(-15, 0, -16), Vector3(15, 0, -16)]:
		kit.visual(details, GRASS, at, Vector3(0.8, 0.6, 0.8))
	# Reuse the exact fixture resources, environment and storm from Demo_A2.
	_environment(level)
	for lamp in level.get_node("HarborLights").get_children():
		if lamp is SpotLight3D:
			lamp.free()
	var reference: Node3D = load("res://Levels/Demo_A2.tscn").instantiate()
	for at in [Vector3(0, 5, 14), Vector3(-12, 5, 2), Vector3(-5, 5, 6), Vector3(12, 5, 0), Vector3(5, 5, 6), Vector3(-5, 5, -5), Vector3(5, 5, -5), Vector3(0, 5, -14), Vector3(-12, 5, -12), Vector3(12, 5, -12)]:
		var lamp: SpotLight3D = reference.get_node("SpotLight3D").duplicate()
		lamp.name = "ExchangeLamp_%02d" % level.get_node("HarborLights").get_child_count()
		# Demo_A2 aims its lamp diagonally; offset to center each pool here.
		lamp.position = at + Vector3(3.178, 0, 0)
		level.get_node("HarborLights").add_child(lamp)
	# Position the paired reference fills inside the actual encounter wings.
	var ambient := level.get_node("HarborLights/AmbientLamps")
	for lamp in ambient.get_children():
		lamp.free()
	for center in [Vector3(-9, 0, 3), Vector3(9, 0, 3), Vector3(0, 0, -11), Vector3(0, 0, 14)]:
		for fixture in ["OmniLight3D", "OmniLight3D2"]:
			var lamp: OmniLight3D = reference.get_node(fixture).duplicate()
			lamp.name = "Fill_%02d" % ambient.get_child_count()
			lamp.position = center + lamp.position - Vector3(5.205885, 1.13, -1.769581)
			ambient.add_child(lamp)
	reference.free()
	_exchange_guards(level)
	_player(level)
	var player = level.get_node("Player")
	player.set_script(preload("res://scripts/exchange_player.gd"))
	player.position = Vector3(0, 0.49, 14)
	player.side_plane_z = 14.0
	player.overview_camera_path = NodePath("../LevelCamera")
	player.max_walk_speed = 4.2
	level.get_node("LevelCamera").size = 9.4
	var stations = kit.group(level, "Stations")
	_station(stations, "Manifest", "COPY MANIFEST", Vector3(-12, 0, 0), 1.8)
	var crank = _station(stations, "Crank", "RELEASE VAULT", Vector3(12, 0, 0), 2.2)
	crank.clearance_guard = NodePath("../../Guards/CrankHound")
	crank.clearance_distance = 5.0
	_station(stations, "NightSeal", "TAKE NIGHT SEAL", Vector3(0, 0, -14), 2.6)
	var bells = kit.group(level, "Bells")
	for at in [Vector3(-5, 0, 6), Vector3(5, 0, 6), Vector3(5, 0, -7)]:
		var bell = kit.group(bells, "Bell_%d" % bells.get_child_count())
		bell.position = at
		var visual := BELL.instantiate()
		visual.name = "Visual"
		bell.add_child(visual)
		var caption := Label3D.new()
		caption.name = "Caption"
		caption.position.y = 1.8
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.font_size = 30
		caption.pixel_size = 0.006
		caption.modulate = Color("e4bc77")
		bell.add_child(caption)
		var pulse := MeshInstance3D.new()
		pulse.name = "Pulse"
		var ring := TorusMesh.new()
		ring.inner_radius = 0.5
		ring.outer_radius = 0.55
		pulse.mesh = ring
		pulse.position.y = 0.1
		pulse.material_override = _glow(Color("e4bc77"))
		pulse.visible = false
		bell.add_child(pulse)
	_exit(level)
	level.get_node("Extraction").position.z = 14
	# Gameplay illumination uses the same light transforms and obstruction geometry.
	for light in level.find_children("*", "Light3D", true, false):
		light.add_to_group("stealth_lights", true)
		light.shadow_enabled = true
	var sensor := Node3D.new()
	sensor.name = "ExposureSensor"
	sensor.set_script(preload("res://scripts/stealth_exposure_sensor.gd"))
	player.add_child(sensor)
	_own_additions(level, level)
	return level


func _station(parent: Node, title: String, action: String, at: Vector3, duration: float) -> Node3D:
	var station = kit.group(parent, title)
	station.set_script(preload("res://scripts/exchange_station.gd"))
	station.title = action
	station.hold_seconds = duration
	station.position = at
	var source: Node3D = load("res://Modules/Gameplay/CargoSeal.tscn").instantiate()
	for node_name in ["Visual", "Ring", "Caption"]:
		var child := source.get_node(node_name)
		child.owner = null
		source.remove_child(child)
		station.add_child(child)
	station.get_node("Ring").material_override = station.get_node("Ring").material_override.duplicate()
	source.free()
	if title != "NightSeal":
		station.get_node("Visual").free()
		var visual = kit.group(station, "Visual")
		if title == "Manifest":
			_prop_box(visual, Vector3(1.1, 0.18, 0.8), Vector3(0, 0.7, 0), Color("63524a"))
			_prop_box(visual, Vector3(0.65, 0.03, 0.52), Vector3(0, 0.81, 0), Color("f0d9a0"))
			for side in [-1, 1]:
				_prop_box(visual, Vector3(0.12, 0.7, 0.6), Vector3(side * 0.4, 0.35, 0), Color("63524a"))
		else:
			_prop_box(visual, Vector3(0.6, 0.9, 0.5), Vector3(0, 0.45, 0), Color("526875"))
			var wheel := MeshInstance3D.new()
			wheel.name = "Wheel"
			var mesh := TorusMesh.new()
			mesh.inner_radius = 0.26
			mesh.outer_radius = 0.34
			wheel.mesh = mesh
			wheel.rotation.x = PI / 2
			wheel.position = Vector3(0, 0.8, 0.3)
			wheel.material_override = _glow(Color("e4bc77"))
			visual.add_child(wheel)
			_prop_box(visual, Vector3(0.5, 0.06, 0.06), Vector3(0, 0.8, 0.3), Color("e4bc77"))
	return station


func _prop_box(parent: Node3D, size: Vector3, at: Vector3, tint: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _glow(tint)
	parent.add_child(instance)


func _exchange_guards(level: Node3D) -> void:
	var routes = kit.group(level, "Routes")
	var guards = kit.group(level, "Guards")
	var specs := [
		["SortingMouse", "SORTING MOUSE", MOUSE, [Vector3(-13, 0, 5), Vector3(-5, 0, 5), Vector3(-5, 0, -1.5), Vector3(-13, 0, -1.5)]],
		["CrankHound", "CRANK HOUND", HOUND, [Vector3(10.5, 0, -2), Vector3(14, 0, -2), Vector3(14, 0, 2), Vector3(10.5, 0, 2)]],
		["VaultMouse", "VAULT MOUSE", MOUSE, [Vector3(4, 0, -14), Vector3(-4, 0, -14), Vector3(-4, 0, -7), Vector3(4, 0, -7)]],
	]
	for i in specs.size():
		var spec: Array = specs[i]
		var route = kit.group(routes, spec[0])
		for at in spec[3]:
			var point := Marker3D.new()
			point.name = "Point_%d" % route.get_child_count()
			point.position = at
			route.add_child(point)
		var guard: CharacterBody3D = spec[2].instantiate()
		guard.name = spec[0]
		guard.set_script(EXCHANGE_GUARD)
		guard.guard_title = spec[1]
		guard.position = spec[3][0]
		guard.player_path = NodePath("../../Player")
		guard.route_path = NodePath("../../Routes/" + spec[0])
		guard.route_mode = 0
		guard.walk_speed = 1.4 if i == 1 else 1.65
		guard.run_speed = 3.55 if i == 1 else 3.15
		guard.locomotion_uses_run = i != 1
		guard.acceleration = 8.0
		guard.braking = 10.0
		guard.sight_range = 10.0 if i == 1 else 8.0
		guard.lamp_range = 7.0 if i == 1 else 5.0
		guard.lamp_fov_degrees = 40.0 if i == 1 else 32.0
		guard.field_of_view_degrees = 100.0 if i == 1 else 110.0
		guard.eye_height = 0.75 if i == 1 else 0.32
		guard.lamp_height_offset = 0.55 if i == 1 else 0.48
		guard.lamp_downward_angle_degrees = 12.0
		guard.player_sight_offset = Vector3(0, 0.45, 0)
		guard.seconds_to_detect = 1.2 if i == 1 else 0.85
		guard.capture_distance = 0.85 if i == 1 else 0.7
		guard.hearing_range = 14.0 if i == 1 else 9.0
		guard.search_seconds = 6.0
		guard.pause_min_seconds = 1.8 if i == 1 else 2.0
		guard.pause_max_seconds = guard.pause_min_seconds
		guard.alert_chance_on_arrival = 0.0
		guard.random_seed = 901 + i
		guard.show_vision = false
		guards.add_child(guard)
		var beam := SpotLight3D.new()
		beam.name = "SightLight"
		beam.position.y = guard.eye_height + guard.lamp_height_offset
		beam.rotation_degrees.x = -guard.lamp_downward_angle_degrees
		beam.light_energy = 8.0
		beam.shadow_enabled = true
		beam.shadow_bias = 0.03
		beam.spot_attenuation = 0.0
		beam.spot_angle_attenuation = 0.35
		guard.add_child(beam)
