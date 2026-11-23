extends "res://scripts/midnight_exchange_builder.gd"
## Authored room shell, two berths, and saved markers for the encounter.

const SHIP := preload("res://scripts/last_barrel_ship.gd")
const LIGHTS := preload("res://scripts/last_barrel_lights.gd")
const QUAY_ART := preload("res://scripts/last_barrel_quay.gd")
const OFFICE := preload("res://Modules/Gameplay/LastBarrel/office_layout.gd")
const PLANKS := preload("res://Mesh/Harboretum-Mesh/wood_planks.tscn")
const LOCK_DEMO := preload("res://Modules/Gameplay/Lockpicking/Doorway.tscn")
const CROW := preload("res://Characters/Crow/crow.glb")
const MASTER_MODEL := preload("res://Mesh/TheLastBarrel/Shipmaster.glb")
const ARRIVAL := Vector3(-4.75, 3.29, 29.6)
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
	_build_upper_floor(office)
	_build_break_court(quay)
	var ships := kit.group(level, "Ships")
	_ships(ships)
	var cargo := kit.group(level, "Cargo")
	_cargo(cargo)
	_actors(level)
	QUAY_ART.new().build(level)
	preload("res://scripts/last_barrel_market.gd").new().build(level)
	var points := kit.group(level, "Points")
	for entry in [
		["Arrival", ARRIVAL],
		["Scout", Vector3(0.5, 0, -4)],
		["OfficeApproach", Vector3(-4.5, 0.49, 7.5)],
		["OfficeLock", Vector3(-6.1, 0, 5.45)],
		["OfficeThreshold", Vector3(-6.1, 0, 4.5)],
		["Desk", Vector3(-10.1, 2.8, -1.45)],
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
	_wall_span(quay, Vector3(-14, 0, -11), Vector3.RIGHT, 19.0, true)
	_wall_span(quay, Vector3(7, 0, -11), Vector3.RIGHT, 7.0)
	_wall_span(quay, Vector3(-14, 0, -11), Vector3.BACK, 28.0)
	_wall_span(quay, Vector3(14, 0, -11), Vector3.BACK, 17.5)
	_wall_span(quay, Vector3(14, 0, 9.4), Vector3.BACK, 7.6)
	_wall_span(quay, Vector3(-14, 0, 17), Vector3.RIGHT, 7.75, true)
	_wall_span(quay, Vector3(-3.25, 0, 17), Vector3.RIGHT, 17.25, true)
	_market_approach(quay)
	for x in [-6.2, -3.3]:
		_solid(quay, "ArrivalGatePier", Vector3(x, 1.13, 17), Vector3(0.57, 2.26, 0.62), TRIM)
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


func _market_approach(quay: Node3D) -> void:
	var market := kit.group(quay, "FishMarket")
	var granite := Color("5d5860")
	var paving := Color("777078")
	_solid(market, "GateApron", Vector3(-6.2, -0.25, 18.55), Vector3(11.5, 0.5, 3.1), granite)
	_solid(market, "MarketTerrace", Vector3(-5.0, 0.65, 29.7), Vector3(13.4, 4.3, 7.0), granite)
	_solid(market, "UpperStreet", Vector3(-8.8, 0.65, 35.4), Vector3(9.6, 4.3, 4.4), granite)
	_descent(market, "Fish Steps", -4.75, 2.65, 20.0, 26.3, 0.0, 2.8, paving, true)
	_descent(market, "Cart Ramp", -9.3, 3.2, 20.0, 26.3, 0.0, 2.8, granite, false)
	# Retaining walls frame the two routes while leaving both ends connected.
	for x in [-11.25, -7.2, -3.2]:
		var rail := _solid(market, "DescentParapet", Vector3(x, 1.84, 23.15), Vector3(0.31, 0.78, 6.9), granite)
		rail.rotation.x = -atan2(2.8, 6.3)
	for x in [-10.2, -7.5, -2.2, 0.55]:
		_solid(market, "FishStall", Vector3(x, 3.24, 31.25), Vector3(2.05, 0.88, 1.0), WOOD)
		for side in [-0.89, 0.89]:
			_box(market, "AwningPost", Vector3(x + side, 3.92, 31.25), Vector3(0.12, 2.23, 0.12), WOOD)
		for strip in 8:
			var awning := _box(market, "StripedCanvas", Vector3(x - 1.03 + strip * 0.29, 4.93, 31.28), Vector3(0.286, 0.08, 1.53), Color("556f70") if strip % 2 else Color("b2a18b"))
			awning.rotation.x = 0.21
		_box(market, "ClosedShutter", Vector3(x, 3.94, 31.64), Vector3(2.02, 1.32, 0.12), TRIM)
	_wall_span(market, Vector3(-11.65, 2.8, 26.3), Vector3.BACK, 6.9, true)
	_wall_span(market, Vector3(1.7, 2.8, 26.3), Vector3.BACK, 6.9, true)
	_wall_span(market, Vector3(-3.2, 2.8, 26.3), Vector3.RIGHT, 4.9, true)
	_wall_span(market, Vector3(-13.5, 2.8, 37.6), Vector3.RIGHT, 9.5, true)

	var archway := preload("res://Modules/Props/QuayArchway.tscn").instantiate() as Node3D
	archway.position = Vector3(-4.75, 0, 18.15)
	market.add_child(archway)
	for spec in [
		["MarketStallLight", Vector3(-2.25, 5.1, 29.0), Vector3(-2.85, 2.8, 28.65), 3.8],
		["CartRampLight", Vector3(-10.8, 4.45, 26.4), Vector3(-9.55, 2.8, 26.1), 3.2],
		["FishStepsLight", Vector3(-5.85, 2.45, 17.4), Vector3(-4.9, 0.0, 18.8), 4.4],
	]:
		var fixture: Vector3 = spec[1]
		LIGHTS.add_spot(market, spec[0], fixture + Vector3.DOWN * 0.18, spec[2], Color("ffc586"), 3.5, spec[3], 28.0)
		_box(market, "WallLantern", fixture, Vector3(0.17, 0.24, 0.17), BRASS)

	var landing := kit.group(quay, "TideLanding")
	_solid(landing, "WaterlinePlatform", Vector3(16.95, -1.13, 7.95), Vector3(3.5, 0.39, 3.0), Color("49464a"))
	_solid(landing, "MooringFinger", Vector3(19.2, -1.07, 8.55), Vector3(1.2, 0.27, 1.8), WOOD)
	var steps := kit.group(landing, "TideSteps")
	steps.position = Vector3(0, 0, 8.0)
	steps.rotation.y = -PI / 2.0
	_descent(steps, "Wet Steps", 0.0, 2.67, -15.93, -14.5, -0.935, 0.0, Color("625d65"), true, 0.72)
	_box(landing, "SeawallThreshold", Vector3(14.14, -0.12, 8.0), Vector3(0.72, 0.24, 2.67), granite)
	_wall_span(landing, Vector3(15.5, -0.935, 6.5), Vector3.RIGHT, 3.1, true)
	_wall_span(landing, Vector3(15.5, -0.935, 9.45), Vector3.RIGHT, 3.1, true)
	for z in [6.62, 9.3]:
		_solid(landing, "MooringPost", Vector3(18.48, -0.51, z), Vector3(0.23, 0.83, 0.24), WOOD)


func _descent(parent: Node3D, title: String, x: float, width: float, start: float, end: float,
		low: float, high: float, tint: Color, steps: bool, top_landing := 0.0) -> void:
	var lane := kit.group(parent, title)
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for edge in [x - width / 2, x + width / 2]:
		points.append_array([Vector3(edge, low - 0.27, start), Vector3(edge, low, start),
			Vector3(edge, low - 0.27, end + top_landing), Vector3(edge, high, end + top_landing),
			Vector3(edge, high, end)])
	shape.points = points
	kit.shape(lane, shape)
	if steps:
		var count := ceili((high - low) / 0.18)
		for index in count:
			var depth := (end - start) / count
			var top := lerpf(low, high, float(index + 1) / count)
			_box(lane, "StoneTread", Vector3(x, (top + low - 0.2) * 0.5, start + depth * (index + 0.5)),
				Vector3(width, top - low + 0.2, depth), tint)
	else:
		var angle := atan2(high - low, end - start)
		var ramp := _box(lane, "PavedSlope", Vector3(x, (low + high) * 0.5 - 0.11, (start + end) * 0.5),
			Vector3(width, 0.2, Vector2(end - start, high - low).length()), tint)
		ramp.rotation.x = -angle


func _office(office: Node3D) -> void:
	var ground := kit.group(office, "GroundFloor")
	var loft := kit.group(office, "UpperFloor")
	var shell := kit.group(office, "ExteriorWalls")
	var width: float = OFFICE.EAST - OFFICE.WEST
	var depth: float = OFFICE.FRONT - OFFICE.REAR
	_wall_span(ground, Vector3(OFFICE.WEST, 0, OFFICE.REAR), Vector3.RIGHT, width)
	_wall_span(ground, Vector3(OFFICE.WEST, 0, OFFICE.REAR), Vector3.BACK, depth)
	_wall_span(shell, Vector3(OFFICE.EAST, 0, OFFICE.REAR), Vector3.BACK, depth)
	# The window opening is visual only. Its wall still blocks traversal.
	kit.box(shell, Vector3(5.55, 2.6, 0.6), Vector3(-9.825, 1.3, OFFICE.FRONT))
	_wall_span(shell, Vector3(-5.15, 0, OFFICE.FRONT), Vector3.RIGHT, 1.6)
	var floor_center := Vector3((OFFICE.WEST + OFFICE.EAST) * 0.5, 0.005, (OFFICE.REAR + OFFICE.FRONT) * 0.5)
	_box(ground, "Subfloor", floor_center + Vector3.DOWN * 0.035, Vector3(width, 0.07, depth), TRIM)
	var board_width := width / 23.0
	for board in 23:
		var at := Vector3(OFFICE.WEST + board_width * (board + 0.5), 0.01, floor_center.z)
		var tint := WOOD.lightened(0.020 * (board % 4))
		_box(ground, "Floorboard", at, Vector3(board_width - 0.015, 0.02, depth), tint)
	_box(ground, "DoorSill", Vector3(-6.1, 0.022, 4.30), Vector3(1.82, 0.04, 0.40), WOOD.lightened(0.16))
	var door := kit.group(office, "Door")
	door.position = Vector3(-6.10, 0, OFFICE.FRONT)
	var assembly := LOCK_DEMO.instantiate()
	for part in ["Hinge", "Jamb0", "Jamb1"]:
		var node := assembly.get_node(part)
		_clear_owner(node)
		assembly.remove_child(node)
		door.add_child(node)
	assembly.free()
	_box(door, "Timber lintel", Vector3(0, 2.79, 0), Vector3(2.16, 0.26, 0.35), WOOD)
	var door_recess := _box(shell, "DoorwayShadow", Vector3(-6.1, 1.28, 4.24), Vector3(2.0, 2.58, 0.08), Color("171319"))
	door_recess.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var desk = _station(loft, "Manifest", "SHIPMASTER’S MANIFEST", Vector3(-10.10, OFFICE.UPPER_HEIGHT, -2.75), 1.8)
	desk.get_node("Ring").hide()
	desk.get_node("Caption").hide()
	kit.box(desk, Vector3(1.10, 0.78, 0.8), Vector3.UP * 0.39)
	_box(loft, "ReplacedPage", Vector3(-10.03, 3.659, -2.53), Vector3(0.24, 0.008, 0.17), Color("e8cb8c")).hide()
	_solid(loft, "Bookcase", Vector3(-11.83, 3.53, 0.33), Vector3(0.58, 1.46, 2.8), WOOD)
	for shift in [0.0, 0.42, 0.83]:
		for index in 8:
			_box(loft, "LedgerVolume", Vector3(-11.49, 3.16 + shift, -0.72 + index * 0.27), Vector3(0.18, 0.30, 0.18), BRASS if index % 3 == 0 else Color("5e7974"))
	_cover_wall(loft, "FoldingScreen", Vector3(-8.48, OFFICE.UPPER_HEIGHT, 1.10), 3.1)
	_solid(loft, "WritingCabinet", Vector3(-4.1, 3.45, -1.1), Vector3(0.52, 1.3, 1.8), WOOD)
	_box(loft, "OfficeRunner", Vector3(-7.7, 2.821, -1.6), Vector3(2.1, 0.025, 3.0), Color("63524b"))
	_sign(office, "SHIPMASTER", Vector3(-6.1, 2.93, 4.5))


func _build_upper_floor(office: Node3D) -> void:
	var loft: Node3D = office.get_node("UpperFloor")
	var ground: Node3D = office.get_node("GroundFloor")
	var stairs := kit.group(office, "Staircase")
	_solid(loft, "WritingRoomFloor", Vector3(-9.95, 2.70, 0.05), Vector3(5.3, 0.2, 8.5), WOOD)
	_solid(loft, "Landing", Vector3(-5.48, 2.70, -3.53), Vector3(3.64, 0.2, 1.55), WOOD)
	var stair := ConvexPolygonShape3D.new()
	var vertices := PackedVector3Array()
	for edge in [-0.5, 0.5]:
		var x_offset := Vector3.RIGHT * float(edge) * OFFICE.STAIR_WIDTH
		vertices.append(OFFICE.STAIR_FOOT + x_offset + Vector3.DOWN * 0.18)
		vertices.append(OFFICE.STAIR_FOOT + x_offset)
		vertices.append(Vector3(OFFICE.STAIR_HEAD.x, -0.18, OFFICE.STAIR_HEAD.z) + x_offset)
		vertices.append(OFFICE.STAIR_HEAD + x_offset)
	stair.points = vertices
	kit.shape(stairs, stair)
	const STEP_COUNT := 14
	var tread_depth: float = (OFFICE.STAIR_FOOT.z - OFFICE.STAIR_HEAD.z) / STEP_COUNT
	var rise: float = OFFICE.UPPER_HEIGHT / STEP_COUNT
	var nosing := BoxMesh.new()
	nosing.size = Vector3(OFFICE.STAIR_WIDTH - 0.06, 0.012, 0.055)
	var nosing_material := _material(WOOD.lightened(0.16))
	nosing_material.emission_enabled = true
	nosing_material.emission = Color("86674d")
	nosing_material.emission_energy_multiplier = 0.18
	nosing.material = nosing_material
	for step in STEP_COUNT:
		var at := OFFICE.STAIR_FOOT + Vector3(0, rise * (step + 0.5), -tread_depth * (step + 0.5))
		_box(stairs, "OakTread", at - Vector3.UP * rise * 0.5, Vector3(OFFICE.STAIR_WIDTH, rise, tread_depth + 0.014), WOOD)
		var edge := MeshInstance3D.new()
		edge.name = "TreadNosing"
		edge.mesh = nosing
		edge.position = at + Vector3(0, 0.004, tread_depth * 0.5 - 0.032)
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stairs.add_child(edge, true)
	var landing_edge := _box(stairs, "LandingEdge", Vector3(-6.03, 2.69, -2.75), Vector3(OFFICE.STAIR_WIDTH, 0.20, 0.16), WOOD)
	landing_edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var facade := kit.group(office, "UpperFrontage")
	_office_roof(facade)
	_solid(loft, "UpperWestWall", Vector3(-12.58, 3.55, 0.05), Vector3(0.23, 1.9, 8.9), TRIM)
	_solid(loft, "UpperRearWall", Vector3(-8.08, 3.55, -4.32), Vector3(9.12, 1.9, 0.27), TRIM)
	_solid(facade, "UpperEastWall", Vector3(-3.6, 3.55, 0.05), Vector3(0.23, 1.9, 8.9), TRIM)
	for side in [-1, 1]:
		_box(facade, "EavesWall", Vector3(-8.08, 4.95, 4.43 * side), Vector3(9.26, 1.02, 0.33), TRIM)
	var runner := _box(loft, "LandingRunner", Vector3(-9.2, 2.815, 2.86), Vector3(2.7, 0.026, 1.12), Color("824f39"))
	runner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-12.4, -10.1, -7.85, -5.65, -3.75]:
		_box(facade, "TimberPost", Vector3(x, 4.08, 4.46), Vector3(0.22, 2.58, 0.35), WOOD)
	for y in [3.06, 4.98]:
		_box(facade, "FrontBeam", Vector3(-8.08, y, 4.46), Vector3(9.13, 0.53, 0.38), WOOD)
	var left: float = OFFICE.WEST - 0.12
	for x: float in [-11.25, -9.0, -6.75, -4.68]:
		var pier_width := x - 0.75 - left
		_box(facade, "WindowPier", Vector3(left + pier_width * 0.5, 4.0, 4.43), Vector3(pier_width, 1.5, 0.3), TRIM)
		var window := _box(facade, "LitWindow", Vector3(x, 4.02, 4.44), Vector3(1.5, 1.15, 0.14), Color("dfa45e"))
		var glass := window.mesh.material as StandardMaterial3D
		glass.emission_enabled = true
		glass.emission = Color("ad6b28")
		_box(facade, "WindowMullion", Vector3(x, 4.02, 4.54), Vector3(0.09, 1.19, 0.1), WOOD)
		left = x + 0.75
	_box(facade, "WindowPier", Vector3(-3.68, 4.0, 4.43), Vector3(0.50, 1.5, 0.3), TRIM)
	_box(facade, "FrontSillWall", Vector3(-8.08, 3.03, 4.43), Vector3(9.26, 0.83, 0.33), TRIM)
	_box(facade, "UpperEaves", Vector3(-8.08, 5.35, 4.36), Vector3(9.45, 0.25, 1.74), TRIM)
	_solid(loft, "ChartRack", Vector3(-9.02, 3.48, 0.16), Vector3(0.27, 1.36, 1.32), WOOD)
	_solid(loft, "ChartRackWing", Vector3(-7.91, 3.48, 0.16), Vector3(0.21, 1.36, 1.32), WOOD)
	_solid(loft, "StairRail", Vector3(-7.18, 3.23, 0.66), Vector3(0.16, 0.86, 6.66), WOOD)
	_solid(ground, "BreakBench", Vector3(-10.5, 0.32, 2.8), Vector3(2.6, 0.64, 0.65), WOOD)

	var kettle := kit.group(ground, "TeaKettle")
	kettle.position = Vector3(-7.63, 0.94, 3.62)
	var pot := MeshInstance3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.19
	body.bottom_radius = 0.23
	body.height = 0.38
	body.material = _material(BRASS)
	pot.mesh = body
	kettle.add_child(pot)
	_solid(ground, "TeaStand", Vector3(-7.63, 0.34, 3.64), Vector3(0.65, 0.68, 0.68), WOOD)


func _office_roof(facade: Node3D) -> void:
	const ROOF_SLOPE := 0.24
	const HALF_RUN := 2.32
	const EAVE_Z := 4.6
	var gable_base: float = OFFICE.ROOF_PEAK - tan(ROOF_SLOPE) * EAVE_Z
	for side in [-1, 1]:
		var roof := _box(facade, "SlateRoof", Vector3(-8.08, OFFICE.ROOF_PEAK - 0.07 - tan(ROOF_SLOPE) * HALF_RUN, HALF_RUN * side),
			Vector3(9.65, 0.19, 4.88), Color("283546"))
		roof.rotation.x = ROOF_SLOPE * side
	for x in [OFFICE.WEST, OFFICE.EAST]:
		_box(facade, "GableBase", Vector3(x, (4.45 + gable_base) * 0.5, 0), Vector3(0.23, gable_base - 4.44, 9.2), TRIM)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var material := _material(TRIM)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.set_material(material)
		surface.add_vertex(Vector3(x, gable_base, -EAVE_Z))
		surface.add_vertex(Vector3(x, OFFICE.ROOF_PEAK, 0))
		surface.add_vertex(Vector3(x, gable_base, EAVE_Z))
		surface.generate_normals()
		var gable := MeshInstance3D.new()
		gable.name = "RoofGable"
		gable.mesh = surface.commit()
		facade.add_child(gable, true)


func _build_break_court(quay: Node3D) -> void:
	var court := kit.group(quay, "BreakCourtyard")
	_wall_span(court, Vector3(-14, 0, 9), Vector3.RIGHT, 5.4, true)
	_wall_span(court, Vector3(-8.6, 0, 9), Vector3.BACK, 2.6)
	_wall_span(court, Vector3(-8.6, 0, 14.25), Vector3.BACK, 2.75)
	for z in [11.5, 14.35]:
		_solid(court, "EntryPier", Vector3(-8.6, 1.46, z), Vector3(0.65, 2.92, 0.48), TRIM)
	_box(court, "EntryLintel", Vector3(-8.6, 2.9, 12.93), Vector3(0.68, 0.42, 3.4), WOOD)
	_solid(court, "CardBench", Vector3(-12.6, 0.35, 12.8), Vector3(0.6, 0.7, 2.0), WOOD)
	for offset in [Vector3(7.2, 0, 8.9), Vector3(10.6, 0, 9.8), Vector3(8.8, 0, 5.0)]:
		_solid(quay, "CargoSkid", offset + Vector3.UP * 0.08, Vector3(1.9, 0.16, 1.3), WOOD)
		for x in [-0.45, 0.45]:
			_solid(quay, "RopeboundCargo", offset + Vector3(x, 0.54, 0), Vector3(0.85, 0.77, 1.08), Color("72614c"))
	for x in [5.5, 9.5, 11.2]:
		_solid(quay, "FreightCrate", Vector3(x, 0.46, -8.2), Vector3(1.0, 0.92, 0.76), WOOD)



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
	barrel.position = Vector3(-10.5, 0, 12.8)
	kit.visual(barrel, BARREL, Vector3.ZERO, Vector3(0.87, 1.12, 0.87))
	barrel.collision_height = 1.12
	barrel.collision_center_y = 0.56
	barrel.interaction_radius = 1.35
	barrel.exit_offset = Vector3(0.8, 0, 0)
	barrel.enter_prompt = ""
	barrel.exit_prompt = ""
	var tabletop := kit.group(barrel, "Tabletop")
	_box(tabletop, "LooseBoard", Vector3(0, 1.12, 0), Vector3(1.3, 0.10, 1.07), WOOD)
	for x in [-0.35, 0.31]:
		_box(tabletop, "Cup", Vector3(x, 1.24, 0.30), Vector3(0.14, 0.15, 0.14), IRON)
	for index in 4:
		_box(tabletop, "Card", Vector3(-0.18 + index * 0.12, 1.18, 0), Vector3(0.085, 0.008, 0.13), Color("d4ba8e"))
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
	for spec in [["CardWatch", Vector3(-11.55, 0, 12.8)], ["CardPartner", Vector3(-10.4, 0, 11.55)], ["TeaWatch", Vector3(-9.5, 0, 2)], ["LandingWatch", Vector3(-10.9, 2.8, 3.1)]]:
		var on_break := preload("res://Modules/Gameplay/LastBarrel/quay_mouse.tscn").instantiate()
		on_break.name = spec[0]
		on_break.set_script(preload("res://Modules/Gameplay/LastBarrel/story_porter.gd"))
		on_break.position = spec[1]
		on_break.collision_layer = 0
		on_break.collision_mask = 0
		people.add_child(on_break)
	var lighter_hand := preload("res://Modules/Gameplay/LastBarrel/quay_mouse.tscn").instantiate()
	lighter_hand.name = "LighterHand"
	lighter_hand.set_script(preload("res://Modules/Gameplay/LastBarrel/story_porter.gd"))
	lighter_hand.position = Vector3(-8.2, 0, -18.6)
	lighter_hand.collision_layer = 0
	lighter_hand.collision_mask = 0
	people.add_child(lighter_hand)
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
	var reference: Node3D = load("res://Levels/MidnightExchange.tscn").instantiate()
	world.environment = reference.get_node("WorldEnvironment").environment.duplicate(true)
	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://Materials/harbor_sky.gdshader")
	sky.sky_material = sky_material
	world.environment.sky = sky
	world.environment.background_mode = Environment.BG_SKY
	world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# A trace of fill keeps silhouettes readable between the lantern pools.
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("71809c")
	world.environment.ambient_light_energy = 0.035
	reference.free()
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
	moon.light_energy = 0.045
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
