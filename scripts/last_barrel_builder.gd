extends "res://scripts/midnight_exchange_builder.gd"
## Authored room shell, two berths, and saved markers for the encounter.

const SHIP := preload("res://scripts/last_barrel_ship.gd")
const QUAY_ART := preload("res://scripts/last_barrel_quay.gd")
const PLANKS := preload("res://Mesh/Harboretum-Mesh/wood_planks.tscn")
const LOCK_DEMO := preload("res://Modules/Gameplay/Lockpicking/Doorway.tscn")
const CROW := preload("res://Characters/Crow/crow.glb")
const MASTER_MODEL := preload("res://Mesh/TheLastBarrel/Shipmaster.glb")
const ARRIVAL := Vector3(-4.75, 0.49, 13.60)
const WOOD := Color("574139")
const TRIM := Color("392f32")
const IRON := Color("343c49")
const BRASS := Color("b7945d")


func build() -> Node3D:
	wall_asset = preload("res://Modules/Gameplay/LastBarrel/quay_wall.tscn")
	var level := Node3D.new()
	level.name = "TheLastBarrel"
	level.set_script(preload("res://scripts/last_barrel.gd"))
	_lighting(level)
	var quay := NavigationRegion3D.new()
	quay.name = "Quay"
	quay.navigation_mesh = NavigationMesh.new()
	quay.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	quay.navigation_mesh.geometry_collision_mask = 1
	quay.navigation_mesh.cell_size = 0.25
	quay.navigation_mesh.cell_height = 0.25
	quay.navigation_mesh.agent_height = 1.5
	quay.navigation_mesh.agent_radius = 0.50
	level.add_child(quay)
	_quay(quay)
	var office := kit.group(quay, "Office")
	_office(office)
	var ships := kit.group(level, "Ships")
	_ships(ships)
	var cargo := kit.group(level, "Cargo")
	_cargo(cargo)
	_actors(level)
	QUAY_ART.new().build(level)
	var points := kit.group(level, "Points")
	for entry in [
		["Arrival", ARRIVAL],
		["Scout", Vector3(0.5, 0, -4)],
		["OfficeApproach", Vector3(-4.5, 0.49, 7.5)],
		["OfficeLock", Vector3(-6.1, 0, 5.45)],
		["OfficeThreshold", Vector3(-6.1, 0, 4.5)],
		["Desk", Vector3(-10.1, 0, -1.45)],
		["OfficeExit", Vector3(-5.7, 0, 5.8)],
		["SmokingPost", QUAY_ART.SMOKING_POST],
		["Ashtray", QUAY_ART.ASH_TRAY],
		["WatchArgument", Vector3(4.28, 0, -7.68)],
		["SortingOverlook", Vector3(-4.05, 0.49, -7.05)],
		["ClerkHandoff", Vector3(-3.0, 0, -7.3)],
		["LoadingMark", Vector3(0.4, 0, -9.1)],
	]:
		kit.port(points, entry[0], entry[1])
	for marker: String in SHIP.POINTS:
		kit.port(points, marker, SHIP.POINTS[marker])
	_own_additions(level, level)
	return level


func _quay(quay: Node3D) -> void:
	var paving := kit.group(quay, "Paving")
	kit.box(paving, Vector3(28, 0.34, 28), Vector3(0, -0.17, 3))
	_wall_span(quay, Vector3(-14, 0, -11), Vector3.RIGHT, 19.0)
	_wall_span(quay, Vector3(7, 0, -11), Vector3.RIGHT, 7.0)
	_wall_span(quay, Vector3(-14, 0, -11), Vector3.BACK, 28.0)
	_wall_span(quay, Vector3(14, 0, -11), Vector3.BACK, 28.0)
	_wall_span(quay, Vector3(-14, 0, 17), Vector3.RIGHT, 28.0, true)
	_solid(quay, "GangwayShutter", Vector3(6, 1.43, -11), Vector3(2.05, 2.86, 0.31), TRIM)
	var crank := preload("res://Mesh/MidnightExchange/Crank.glb").instantiate() as Node3D
	crank.name = "Crank"
	crank.position = Vector3(7.72, 0, -9.4)
	quay.add_child(crank)
	var bell := BELL.instantiate() as Node3D
	bell.name = "DistractionBell"
	bell.position = Vector3(3.2, 0.45, -5.0)
	quay.add_child(bell)
	_solid(quay, "BellStand", Vector3(3.2, 0.19, -5), Vector3(0.55, 0.38, 0.55), WOOD)
	_cover_wall(quay, "QuayScreen", Vector3(1.5, 0, -5.3), 3.0, PI / 2.0)
	_cover_wall(quay, "SortingScreen", Vector3(-1.1, 0, -7.0), 3.0)
	_cover_wall(quay, "ApproachScreen", Vector3(-4.4, 0, 10.1), 2.7, PI / 2.0)
	_cover_wall(quay, "EastCargoScreen", Vector3(8, 0, -4.2), 4.2)
	for at in [Vector3(-11, 0, 11), Vector3(-10, 0, 11), Vector3(9, 0, 2), Vector3(10, 0, 2), Vector3(10, 0, -6), Vector3(-8, 0, -8)]:
		_barrel(quay, at, 1.22)
	_solid(quay, "SortingDesk", Vector3(-3, 0.48, -9.15), Vector3(2.1, 0.96, 0.76), WOOD)
	_box(quay, "ClerkLedger", Vector3(-3.02, 1.015, -9.16), Vector3(0.60, 0.06, 0.36), Color("d4ba8e"))
	_box(quay, "ClerkDelivery", Vector3(-2.70, 1.013, -9.0), Vector3(0.30, 0.025, 0.33), Color("eed6a3")).hide()
	_box(quay, "LoadingPaint", Vector3(0.4, 0.014, -9.1), Vector3(1.30, 0.025, 1.30), Color("ab8f60"))
	for x in [-0.4, 1.1]:
		_solid(quay, "HoistSupport", Vector3(x, 1.83, -10.1), Vector3(0.14, 3.66, 0.18), WOOD)
	_box(quay, "HoistBoom", Vector3(0.37, 3.63, -15.4), Vector3(0.36, 0.23, 11.0), WOOD)
	_box(quay, "HoistLine", Vector3(0.39, 2.56, -9.14), Vector3(0.045, 2.1, 0.045), BRASS)
	_sign(quay, "PERSONNEL GANGWAY", Vector3(6, 3.35, -10.9))
	_sign(quay, "FREIGHT  /  SORTING", Vector3(-2.8, 2.5, -9))
	_sign(quay, "HOIST", Vector3(0.4, 2.35, -9.1), Color("c5d9de"))


func _office(office: Node3D) -> void:
	_wall_span(office, Vector3(-12.6, 0, -4.4), Vector3.RIGHT, 9.05)
	_wall_span(office, Vector3(-12.6, 0, -4.4), Vector3.BACK, 8.9)
	_wall_span(office, Vector3(-3.55, 0, -4.4), Vector3.BACK, 8.9)
	# A glazed opening in the quay frontage lets Rook glimpse the writing room.
	kit.box(office, Vector3(5.55, 2.6, 0.6), Vector3(-9.825, 1.3, 4.5))
	_wall_span(office, Vector3(-5.15, 0, 4.5), Vector3.RIGHT, 1.6)
	var door := kit.group(office, "Door")
	door.position = Vector3(-6.10, 0, 4.50)
	var assembly := LOCK_DEMO.instantiate()
	for part in ["Hinge", "Jamb0", "Jamb1"]:
		var node := assembly.get_node(part)
		_clear_owner(node)
		assembly.remove_child(node)
		door.add_child(node)
	assembly.free()
	_box(door, "Timber lintel", Vector3(0, 2.79, 0), Vector3(2.16, 0.26, 0.35), WOOD)
	var desk = _station(office, "Manifest", "SHIPMASTER’S MANIFEST", Vector3(-10.10, 0, -2.75), 1.8)
	desk.get_node("Ring").hide()
	desk.get_node("Caption").hide()
	kit.box(desk, Vector3(1.10, 0.78, 0.8), Vector3.UP * 0.39)
	_box(office, "ReplacedPage", Vector3(-10.03, 0.859, -2.53), Vector3(0.24, 0.008, 0.17), Color("e8cb8c")).hide()
	_solid(office, "Bookcase", Vector3(-11.83, 0.73, 0.33), Vector3(0.58, 1.46, 2.8), WOOD)
	for shift in [0.0, 0.42, 0.83]:
		for index in 8:
			_box(office, "LedgerVolume", Vector3(-11.49, 0.36 + shift, -0.72 + index * 0.27), Vector3(0.18, 0.30, 0.18), BRASS if index % 3 == 0 else Color("5e7974"))
	_cover_wall(office, "FoldingScreen", Vector3(-8.48, 0, 1.10), 3.1)
	_solid(office, "WritingCabinet", Vector3(-4.1, 0.65, -1.1), Vector3(0.52, 1.3, 1.8), WOOD)
	_box(office, "OfficeRunner", Vector3(-7.7, 0.021, -1.6), Vector3(2.1, 0.025, 3.0), Color("63524b"))
	_sign(office, "SHIPMASTER", Vector3(-6.1, 2.93, 4.5))


func _ships(ships: Node3D) -> void:
	var outbound := kit.group(ships, "OutboundMerchant")
	SHIP.new().build(outbound, kit)
	var other := kit.group(ships, "PotatoLighter")
	_hull(other, Vector3(-8.3, -1.4, -17.7), 9.9, 4.6, Color("576861"))
	kit.visual(other, PLANKS, Vector3(-8.3, -0.05, -17.7), Vector3(8, 0.20, 3.4), true)
	kit.visual(other, PLANKS, Vector3(-8.3, -0.05, -13.35), Vector3(1.5, 0.22, 5.4), true)
	_mast(other, Vector3(-8.9, -0.1, -17.7), 3.55, Color("8ba49a"))
	_sign(other, "POTATO LIGHTER", Vector3(-8.3, 1.75, -16.4), Color("b8d3c8"))
	var fire := kit.group(ships, "Fire")
	_fire_patch(fire, "DeckShortcut", Vector3(18.45, -0.90, -21.65), 2.52)
	_fire_patch(fire, "PortAisle", Vector3(18.45, -0.90, -18.85), 2.54)
	_fire_patch(fire, "Smoke", Vector3(1.32, 0.03, -18.46), 1.00)


func _cargo(cargo: Node3D) -> void:
	# Keep the interaction origin at the feet and fit the same cask used in the freight stock.
	var barrel = kit.group(cargo, "SpareBarrel")
	barrel.set_script(preload("res://Modules/Gameplay/LastBarrel/freight_barrel.gd"))
	barrel.position = Vector3(-5.9, 0, 13.35)
	kit.visual(barrel, BARREL, Vector3.ZERO, Vector3(0.87, 1.12, 0.87))
	barrel.collision_height = 1.12
	barrel.collision_center_y = 0.56
	barrel.interaction_radius = 1.35
	barrel.exit_offset = Vector3(0.8, 0, 0)
	barrel.enter_prompt = ""
	barrel.exit_prompt = ""
	var stock := kit.group(cargo, "PotatoStock")
	for index in 3:
		var at := Vector3(-6.1 - index * 0.93, 0, -9.3)
		var prop := kit.visual(stock, BARREL, at, Vector3(0.77, 1.02, 0.77))
		prop.name = "Potatoes%d" % (index + 1)


func _actors(level: Node3D) -> void:
	var routes := kit.group(level, "Routes")
	var guards := kit.group(level, "Guards")
	var sentinel := _guard(guards, routes, preload("res://Modules/Gameplay/LastBarrel/quay_hound.tscn"), "Sentinel", [Vector3(6, 0, -9.85)], true)
	sentinel.rotation.y = PI
	var quay_mouse := preload("res://Modules/Gameplay/LastBarrel/quay_mouse.tscn")
	_guard(guards, routes, quay_mouse, "DockWatch", [
		Vector3(-2.1, 0, 6.9), Vector3(1.0, 0, 3.1),
		Vector3(0.1, 0, -3.3), Vector3(-2.05, 0, -0.25),
		Vector3(-2.1, 0, 6.1), Vector3(-6.1, 0, 6.2),
	])
	var people := kit.group(level, "People")
	var clerk := _crow(people, "Clerk", CROW, Vector3(-3, 0, -9.7))
	clerk.rotation.y = PI
	var shipmaster := _crow(people, "Shipmaster", MASTER_MODEL, QUAY_ART.SMOKING_POST)
	shipmaster.rotation.y = PI + 0.48
	var paper := _box(shipmaster, "DeliveryPaper", Vector3(0.23, 0.80, -0.25), Vector3(0.26, 0.20, 0.026), Color("eed6a3"))
	paper.rotation.z = -0.22
	paper.hide()
	var porter = quay_mouse.instantiate()
	porter.name = "Porter"
	porter.set_script(preload("res://Modules/Gameplay/LastBarrel/story_porter.gd"))
	porter.position = Vector3(-5.9, 0, -8.5)
	porter.collision_layer = 0
	porter.collision_mask = 0
	people.add_child(porter)
	_player(level)
	var player = level.get_node("Player")
	player.set_script(preload("res://Modules/Gameplay/LastBarrel/ship_player.gd"))
	player.overview_camera_path = ^"../LevelCamera"
	player.max_walk_speed = MOVEMENT.ROOK_MOVE_SPEED
	player.position = ARRIVAL
	player.side_plane_z = ARRIVAL.z
	player.follow_size = 11.1
	player.jump_velocity = 5.0
	var sensor := StealthExposureSensor.new()
	sensor.name = "ExposureSensor"
	sensor.sample_offsets = PackedVector3Array([Vector3(0, 0.15, 0), Vector3(0, 0.55, 0)])
	player.add_child(sensor)


func _clear_owner(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owner(child)


func _guard(guards: Node3D, routes: Node3D, model: PackedScene, title: String, points: Array, fixed: bool = false) -> Node3D:
	var route := kit.group(routes, title)
	for at in points:
		kit.port(route, "Point%d" % route.get_child_count(), at)
	var guard = model.instantiate()
	guard.name = title
	guard.set_script(preload("res://Modules/Gameplay/LastBarrel/dock_guard.gd"))
	guard.guard_title = "SENTINEL" if fixed else "DOCK WATCH"
	guard.fixed_post = fixed
	guard.position = points[0]
	guard.player_path = NodePath("../../Player")
	guard.route_path = NodePath("../../Routes/" + title)
	guard.show_vision = false
	guard.walk_speed = 1.8
	guard.pause_min_seconds = 1.45
	guard.pause_max_seconds = 1.45
	guard.sight_range = 8.0
	guard.field_of_view_degrees = 100.0
	guard.lamp_range = 5.8
	guard.lamp_downward_angle_degrees = 14.0
	guard.lamp_height_offset = 0.46
	guard.sight_light_path = NodePath("WatchLamp")
	guards.add_child(guard)
	var spot := SpotLight3D.new()
	spot.name = "WatchLamp"
	spot.light_color = Color("ffdaa1")
	spot.light_energy = 3.3
	spot.shadow_enabled = true
	spot.add_to_group("stealth_lights", true)
	guard.add_child(spot)
	return guard


func _crow(parent: Node3D, title: String, asset: PackedScene, at: Vector3) -> Node3D:
	var bird := kit.group(parent, title)
	bird.set_script(preload("res://Modules/Gameplay/LastBarrel/story_crow.gd"))
	bird.position = at
	var model := asset.instantiate() as Node3D
	model.name = "Model"
	bird.add_child(model)
	var animation := AnimationPlayer.new()
	animation.name = "AnimationPlayer"
	animation.root_node = ^"../Model"
	var clips := AnimationLibrary.new()
	clips.add_animation("Idle", preload("res://Characters/Crow/crow_idle.tres"))
	clips.add_animation("Walk", preload("res://Characters/Crow/crow_walk.tres"))
	animation.add_animation_library("", clips)
	bird.add_child(animation)
	var speech := Label3D.new()
	speech.name = "Speech"
	speech.position.y = 2.0
	speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech.font_size = 32
	speech.outline_size = 8
	speech.pixel_size = 0.005
	speech.modulate = Color("f4d6a6")
	bird.add_child(speech)
	return bird


func _lighting(level: Node3D) -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("192235")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("8895b3")
	world.environment.ambient_light_energy = 0.46
	level.add_child(world)
	var water := MeshInstance3D.new()
	water.name = "HarborWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(180, 180)
	water.mesh = plane
	water.position.y = -1.45
	var tide := ShaderMaterial.new()
	tide.shader = preload("res://Materials/harbor_water.gdshader")
	water.material_override = tide
	level.add_child(water)
	var backdrop := preload("res://scenes/backdrops/HarborBackdrop.tscn").instantiate() as Node3D
	backdrop.position = Vector3(0, 0, -55)
	level.add_child(backdrop)
	var camera := Camera3D.new()
	camera.name = "LevelCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.1
	camera.far = 140
	camera.current = true
	level.add_child(camera)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-49, -32, 0)
	moon.light_color = Color("9dadd3")
	moon.light_energy = 0.76
	moon.shadow_enabled = true
	level.add_child(moon)


func _hull(parent: Node3D, at: Vector3, length: float, width: float, tint: Color) -> void:
	# Transverse stations follow the kit's hollow cargo boat profile.
	var stations := [-0.5, -0.39, -0.27, 0.27, 0.39, 0.5]
	var widths := [0.03, 0.68, 1.0, 1.0, 0.68, 0.03]
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := _material(tint)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.set_material(material)
	for side in [-1.0, 1.0]:
		for index in stations.size() - 1:
			var a := Vector3(stations[index] * length, 1.86, widths[index] * width * 0.5 * side)
			var b := Vector3(stations[index + 1] * length, 1.86, widths[index + 1] * width * 0.5 * side)
			var c := Vector3(b.x, -0.27, b.z * 0.48)
			var d := Vector3(a.x, -0.27, a.z * 0.48)
			for vertex in [a, b, c, a, c, d]:
				hull.add_vertex(vertex)
	hull.generate_normals()
	var shell := MeshInstance3D.new()
	shell.name = "FacetedHull"
	shell.mesh = hull.commit()
	shell.position = at
	parent.add_child(shell)


func _mast(parent: Node3D, at: Vector3, height: float, flag: Color) -> void:
	_box(parent, "Mast", at + Vector3.UP * height * 0.5, Vector3(0.20, height, 0.20), WOOD)
	_box(parent, "Yardarm", at + Vector3.UP * (height - 0.65), Vector3(2.8, 0.13, 0.13), WOOD)
	_box(parent, "FurledCanvas", at + Vector3.UP * (height - 0.80), Vector3(2.47, 0.23, 0.20), flag)
	_box(parent, "MastPennant", at + Vector3(0.36, height, 0), Vector3(0.83, 0.30, 0.045), flag)


func _fire_patch(parent: Node3D, title: String, at: Vector3, span: float) -> void:
	var patch := kit.group(parent, title)
	patch.position = at
	patch.set_meta("half_width", 0.62)
	patch.set_meta("half_span", span * 0.5)
	var haze := CPUParticles3D.new()
	haze.name = "Embers"
	haze.amount = 30
	haze.lifetime = 1.4
	haze.direction = Vector3.UP
	haze.gravity = Vector3(0, 1.8, 0)
	haze.spread = 20
	haze.initial_velocity_min = 0.45
	haze.initial_velocity_max = 1.2
	haze.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	haze.emission_box_extents = Vector3(0.17, 0.05, span * 0.46)
	haze.scale_amount_min = 0.35
	haze.scale_amount_max = 1.0
	var ember := SphereMesh.new()
	ember.radius = 0.018
	ember.height = 0.083
	ember.radial_segments = 6
	ember.rings = 3
	ember.material = _glow(Color("ff9a48"))
	haze.mesh = ember
	haze.emitting = false
	patch.add_child(haze)
	var smoke := haze.duplicate() as CPUParticles3D
	smoke.name = "Haze"
	smoke.amount = 22
	smoke.lifetime = 3.0
	smoke.gravity = Vector3(0.37, 0.48, -0.12)
	smoke.initial_velocity_min = 0.55
	smoke.initial_velocity_max = 0.95
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 1.45
	var expansion := Curve.new()
	expansion.max_value = 2
	expansion.add_point(Vector2(0, 0.13))
	expansion.add_point(Vector2(0.42, 1.2))
	expansion.add_point(Vector2(1, 1.9))
	smoke.scale_amount_curve = expansion
	smoke.color_ramp = Gradient.new()
	smoke.color_ramp.offsets = PackedFloat32Array([0.0, 0.24, 1.0])
	smoke.color_ramp.colors = PackedColorArray([Color(0.32,0.25,0.24,0.10), Color(0.30,0.27,0.30,0.5), Color(0.33,0.34,0.39,0)])
	var cloud := SphereMesh.new()
	cloud.radius = 0.27
	cloud.height = 0.39
	cloud.radial_segments = 7
	cloud.rings = 3
	var ash := _material(Color.WHITE)
	ash.vertex_color_use_as_albedo = true
	ash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud.material = ash
	smoke.mesh = cloud
	patch.add_child(smoke)
	var burning := ShaderMaterial.new()
	burning.shader = preload("res://Materials/TheLastBarrel/deck_flame.gdshader")
	for index in 5:
		var flame := MeshInstance3D.new()
		flame.name = "Flame%d" % index
		flame.mesh = _flame_tongues(index, burning)
		flame.position = Vector3(0.10 * sin(index * 5.0), 0.0, (index - 2) * span * 0.20)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		patch.add_child(flame)
	var lamp := OmniLight3D.new()
	lamp.name = "FireLight"
	lamp.position.y = 0.9
	lamp.light_color = Color("ff8138")
	lamp.light_energy = 1.9
	lamp.omni_range = 4.5
	patch.add_child(lamp)
	patch.hide()
	lamp.hide()


func _flame_tongues(index: int, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var heights := [0.0, 0.22, 0.54, 0.77, 1.0]
	var radii := [0.72, 1.0, 0.61, 0.37, 0.015]
	for strand in 2:
		var height := (0.80 + 0.31 * sin(index * 2.4) + 0.19 * strand)
		var width := 0.165 if strand == 0 else 0.11
		var rings: Array[PackedVector3Array] = []
		for band in heights.size():
			var t: float = heights[band]
			var center := Vector3(strand * 0.13 + sin(t * 5.0 + index) * t * 0.12, t * height, 0.055 * strand)
			var ring := PackedVector3Array()
			for side in 6:
				var angle := TAU * side / 6.0 + 0.29 * band
				ring.append(center + Vector3(cos(angle), 0, sin(angle)) * width * float(radii[band]))
			rings.append(ring)
		for band in rings.size() - 1:
			for side in 6:
				var next := (side + 1) % 6
				for point in [Vector2i(band,side), Vector2i(band,next), Vector2i(band+1,next),
						Vector2i(band,side), Vector2i(band+1,next), Vector2i(band+1,side)]:
					surface.set_uv(Vector2(0, heights[point.x]))
					surface.add_vertex(rings[point.x][point.y])
	surface.generate_normals()
	return surface.commit()


func _solid(parent: Node3D, title: String, at: Vector3, dimensions: Vector3, tint: Color) -> MeshInstance3D:
	var solid := _box(parent, title, at, dimensions, tint)
	kit.box(solid, dimensions)
	return solid


func _box(parent: Node3D, title: String, at: Vector3, dimensions: Vector3, tint: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = title
	var cube := BoxMesh.new()
	cube.size = dimensions
	cube.material = _material(tint)
	piece.mesh = cube
	piece.position = at
	parent.add_child(piece, true)
	return piece


func _material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.86
	return material
