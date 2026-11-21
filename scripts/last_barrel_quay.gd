extends RefCounted
## The shipmaster's waterfront office and the working quay around the freight hoist.

const JOINERY := preload("res://scripts/last_barrel_ship_mesh.gd")
const PIPE_SCRIPT := preload("res://Modules/Gameplay/LastBarrel/smoking_pipe.gd")
const SMOKING_POST := Vector3(-7.65, 0, 5.42)
const ASH_TRAY := Vector3(-8.0, 0.97, 5.36)
const STONE_COLORS := ["70727b", "777985", "686e7b", "77767a", "6d707a", "73717b"]
var joinery := JOINERY.new()


func build(level: Node3D) -> void:
	var quay: Node3D = level.get_node("Quay")
	var office: Node3D = quay.get_node("Office")
	_lay_setts(quay.get_node("Paving"))
	_office_front(office)
	_pipe_stand(office)
	_smoking_pipe(level.get_node("People/Shipmaster"))
	_dock_gate(quay)
	_bell_frame(quay)
	_freight(quay)
	_lamps(quay, office)
	_harbor_life(level, quay, office)
	_waterfront(quay)
	joinery.finish()


func _group(parent: Node3D, title: String, at := Vector3.ZERO) -> Node3D:
	var group := Node3D.new()
	group.name = title
	group.position = at
	parent.add_child(group, true)
	return group


func _lay_setts(paving: Node3D) -> void:
	for color: String in STONE_COLORS:
		var stone := StandardMaterial3D.new()
		stone.resource_name = "Quay granite " + color
		stone.albedo_color = Color(color)
		stone.roughness = 0.78
		joinery.materials[color] = stone
	var rng := RandomNumberGenerator.new()
	rng.seed = 1842
	var bedding := _group(paving, "MortarBed", Vector3(0,-0.14,3))
	joinery.box(bedding, "soot", Vector3.ZERO, Vector3(28,0.24,28))
	# Hand-laid courses, broken joints and dressed edges read in low raking light.
	for course in 48:
		var z := -11.0 + course * 28.0 / 48.0
		var strip := _group(paving, "GraniteCourse%02d" % course, Vector3(-14,0,z))
		var x := 0.0
		while x < 27.99:
			var length := minf(28.0-x, rng.randf_range(0.82,1.53))
			if 28.0-x-length < 0.3:
				length = 28.0-x
			var tone: String = STONE_COLORS[rng.randi_range(0,STONE_COLORS.size()-1)]
			_flagstone(strip, tone, Vector3(x+length/2,0,28.0/96.0), length-0.016, 28.0/48.0-0.016, rng.randf_range(0.015,0.043))
			x += length


func _flagstone(part: Node3D, shade: String, center: Vector3, width: float, depth: float, wear: float) -> void:
	var corner := Vector2(width,depth) * 0.5
	var outer := PackedVector3Array()
	var top := PackedVector3Array()
	for direction in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var clipped: Vector2 = direction * (corner-Vector2(wear,wear))
		var first := Vector3(clipped.x,0,clipped.y)
		var second := first
		if direction.x == direction.y:
			first.x += direction.x*wear
			second.z += direction.y*wear
		else:
			first.z += direction.y*wear
			second.x += direction.x*wear
		for offset in [first,second]:
			outer.append(center + offset + Vector3.DOWN*0.015)
			top.append(center + offset - Vector3(direction.x,0,direction.y)*0.016 + Vector3.UP*0.008)
	joinery.face(part,shade,top,Vector3.UP)
	for index in outer.size():
		var next := (index+1)%outer.size()
		var normal := Vector3.UP + ((outer[index]+outer[next])*0.5-center).normalized()
		joinery.face(part,shade,[outer[index],outer[next],top[next],top[index]],normal)


func _office_front(office: Node3D) -> void:
	var face := _group(office,"HarbormastersFrontage",Vector3(-12.6,0,4.5))
	# The open glazed bay runs between timber piers and looks into the office.
	for span in [Vector2(0,1.31),Vector2(4.34,5.55)]:
		var width: float = span.y-span.x
		var count := ceili(width/0.24)
		for plank in count:
			var x: float = span.x + width*(plank+0.5)/count
			joinery.box(face,"oak" if plank%2 else "oak_red",Vector3(x,1.32,0.04),Vector3(width/count-0.012,2.64,0.38))
	for rail in [Vector2(0.47,0.94),Vector2(2.52,0.38)]:
		joinery.box(face,"wainscot",Vector3(2.82,rail.x,0.03),Vector3(3.12,rail.y,0.38))
	for x: float in [0.12,1.32,4.34,5.48]:
		joinery.box(face,"frame",Vector3(x,1.35,0.12),Vector3(0.19,2.7,0.43))
	for y: float in [0.30,0.89,2.35,2.65]:
		joinery.box(face,"frame",Vector3(2.78,y,0.17),Vector3(5.54,0.16,0.34))
	var window := _group(face,"OfficeWindow",Vector3(2.82,1.62,0.20))
	for x: float in [-1.42,-0.48,0.48,1.42]:
		joinery.box(window,"oak_light",Vector3(x,0,0),Vector3(0.066,1.42,0.085))
	joinery.box(window,"oak_light",Vector3(0,0.14,0),Vector3(2.92,0.060,0.085))
	joinery.box(window,"oak",Vector3(0,-0.69,0.04),Vector3(3.15,0.11,0.38))
	var roof := _group(face,"SlateEaves")
	for x: float in [0.1,1.35,4.34,5.58,7.58,8.91]:
		joinery.timber(roof,"frame",Vector3(x,2.24,0.22),Vector3(x,2.72,0.62),0.13,0.15)
	joinery.box(roof,"oak_dark",Vector3(4.5,2.74,0.52),Vector3(9.12,0.20,0.26))
	var slope := Basis(Vector3.RIGHT,0.36)
	for row in 3:
		for column in 18:
			var x := 0.15+column*0.52
			var z := 0.66-row*0.38
			joinery.box(roof,"blue" if (row+column)%3 else "wainscot",Vector3(x,2.88+row*0.148,z),Vector3(0.51,0.08,0.47),slope)
	var gable := _group(face,"DoorGable",Vector3(6.50,2.83,0.63))
	joinery.face(gable,"oak_red",[Vector3(-1.45,0,0),Vector3(1.45,0,0),Vector3(0,1.0,0)],Vector3.BACK)
	for side: float in [-1.0,1.0]:
		var eave := Vector3(side*1.46,0,0.045)
		var peak := Vector3(0,1.00,0.045)
		joinery.timber(gable,"frame",eave,peak,0.14,0.17)
		joinery.timber(gable,"blue",eave+Vector3.UP*0.10,peak+Vector3.UP*0.10,0.14,0.90)
		joinery.timber(gable,"oak_light",Vector3(0,0.05,0.04),Vector3(side*0.70,0.50,0.04),0.085,0.105)
	joinery.timber(gable,"frame",Vector3.ZERO,Vector3(0,0.91,0),0.13,0.14)
	var hardware := _group(office.get_node("Door/Hinge/DoorBody"),"NightLatch")
	var plate := Vector3(1.50,1.18,0.182)
	joinery.box(hardware,"brass",plate,Vector3(0.21,0.36,0.047))
	joinery.rod(hardware,"soot",plate+Vector3(0,0.02,0.024),plate+Vector3(0,0.02,0.031),0.034)
	joinery.box(hardware,"soot",plate+Vector3(0,-0.031,0.031),Vector3(0.034,0.090,0.012))
	joinery.rod(hardware,"brass_lit",plate+Vector3(0,0.25,0),plate+Vector3(0,0.25,0.104),0.077,0.081)


func _pipe_stand(office: Node3D) -> void:
	var rest := _group(office,"SandPot",ASH_TRAY)
	joinery.box(rest,"frame",Vector3(0,-0.50,0),Vector3(0.12,0.92,0.12))
	joinery.box(rest,"metal",Vector3(0,-0.93,0),Vector3(0.33,0.07,0.33))
	joinery.rod(rest,"metal",Vector3(0,-0.19,0),Vector3(0,0.015,0),0.08,0.205,12)
	joinery.rod(rest,"cord_dark",Vector3(0,0.011,0),Vector3(0,0.019,0),0.171,0.171,12)
	joinery.ring(rest,"brass",Vector3(0,0.021,0),0.19,0.018,Vector3.RIGHT,Vector3.FORWARD,12)


func _smoking_pipe(master: Node3D) -> void:
	var pipe := _group(master,"SmokingPipe",Vector3(0.03,1.07,-0.38))
	pipe.set_script(PIPE_SCRIPT)
	var shank := Vector3(0.160,-0.088,-0.24)
	var bowl := Vector3(0.206,-0.081,-0.30)
	joinery.rod(pipe,"soot",Vector3.ZERO,shank*0.58,0.018,0.028)
	joinery.rod(pipe,"oak_red",shank*0.58,shank,0.028,0.039)
	joinery.rod(pipe,"brass",shank*0.64,shank*0.73,0.033,0.035)
	joinery.rod(pipe,"oak_red",shank,bowl,0.042,0.061)
	joinery.rod(pipe,"wainscot",bowl,bowl+Vector3.UP*0.118,0.057,0.087,10)
	var lip := bowl + Vector3.UP*0.12
	joinery.ring(pipe,"brass_lit",lip,0.081,0.012,Vector3.RIGHT,Vector3.FORWARD,12)
	var ember := _group(pipe,"Ember",lip)
	joinery.rod(ember,"ember",Vector3.ZERO,Vector3.UP*0.006,0.064,0.058,10)
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.position = lip+Vector3.UP*0.018
	smoke.local_coords = false
	smoke.amount = 19
	smoke.lifetime = 1.75
	smoke.preprocess = 1.25
	smoke.initial_velocity_min = 0.27
	smoke.initial_velocity_max = 0.41
	smoke.direction = Vector3.UP
	smoke.spread = 10
	smoke.gravity = Vector3(-0.095,0.16,0.035)
	smoke.scale_amount_curve = Curve.new()
	smoke.scale_amount_curve.add_point(Vector2(0,0.19))
	smoke.scale_amount_curve.add_point(Vector2(0.65,0.82))
	smoke.scale_amount_curve.add_point(Vector2(1,1.0))
	smoke.color_ramp = Gradient.new()
	smoke.color_ramp.offsets = PackedFloat32Array([0,0.18,0.7,1])
	smoke.color_ramp.colors = PackedColorArray([Color(0.83,0.8,0.74,0.12),Color(0.81,0.80,0.77,0.75),Color(0.75,0.77,0.83,0.35),Color(0.74,0.76,0.83,0)])
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.vertex_color_use_as_albedo = true
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wisp := SphereMesh.new()
	wisp.radius = 0.085
	wisp.height = 0.16
	wisp.radial_segments = 7
	wisp.rings = 3
	wisp.material = haze
	smoke.mesh = wisp
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pipe.add_child(smoke)
	smoke.emitting = true


func _dock_gate(quay: Node3D) -> void:
	var gate := _group(quay, "GangwayIronwork", Vector3(6, 0, -10.81))
	for index in 8:
		var x := (index - 3.5) * 0.25
		joinery.box(gate, "oak_dark" if index % 3 == 0 else "oak_red", Vector3(x, 1.38, 0), Vector3(0.24, 2.74, 0.075))
	for x: float in [-1.15, 1.15]:
		joinery.box(gate, "frame", Vector3(x, 1.54, 0), Vector3(0.24, 3.08, 0.39))
	for y: float in [0.28, 1.44, 2.55]:
		joinery.box(gate, "metal", Vector3(0, y, 0.064), Vector3(2.06, 0.12, 0.065))
		for x: float in [-0.86, -0.43, 0.0, 0.43, 0.86]:
			joinery.rod(gate, "brass", Vector3(x, y, 0.095), Vector3(x, y, 0.116), 0.029, 0.022)
	joinery.box(gate, "frame", Vector3(0, 3.02, 0), Vector3(2.55, 0.22, 0.40))


func _bell_frame(quay: Node3D) -> void:
	var stand := _group(quay, "BellTimbers", Vector3(3.20, 0, -5.42))
	for x: float in [-0.60, 0.60]:
		joinery.box(stand, "frame", Vector3(x, 1.13, 0), Vector3(0.16, 2.26, 0.17))
		joinery.box(stand, "metal", Vector3(x, 0.20, 0), Vector3(0.18, 0.23, 0.19))
		joinery.timber(stand, "oak", Vector3(x, 1.68, 0), Vector3(x * 0.35, 2.16, 0), 0.11, 0.10)
	joinery.box(stand, "oak_light", Vector3(0, 2.22, 0), Vector3(1.48, 0.14, 0.21))


func _freight(quay: Node3D) -> void:
	# The empty loading skids are the visual clue: the valuable cargo is already aboard.
	for at in [Vector3(6.82, 0, -6.40), Vector3(9.20, 0, -7.18)]:
		var skid := _group(quay, "EmptyLoadingSkid", at)
		for x: float in [-0.64, 0.64]:
			joinery.box(skid, "oak_dark", Vector3(x, 0.070, 0), Vector3(0.15, 0.14, 1.14))
		for slat in 5:
			joinery.box(skid, "oak" if slat % 2 else "oak_light", Vector3(0, 0.15, (slat - 2) * 0.235), Vector3(1.63, 0.073, 0.192))
	var coils := _group(quay, "HoistTackle", Vector3(-0.36, 0.35, -10.10))
	for wrap in 6:
		joinery.ring(coils, "cord_dark" if wrap % 2 else "cord", Vector3.UP * wrap * 0.041, 0.155, 0.028, Vector3.RIGHT, Vector3.FORWARD)


func _lamps(quay: Node3D, office: Node3D) -> void:
	var fittings := preload("res://scripts/last_barrel_ship.gd").new()
	for spec in [
		[office, "OfficePorchLamp", Vector3(-6.9, 2.03, 4.96), false],
		[office, "WritingLamp", Vector3(-9.9, 5.1, -2.2), false],
		[quay, "BellLamp", Vector3(3.38, 2.85, -5.28), true],
		[quay, "SortingLamp", Vector3(-3, 2.5, -9.7), true],
		[quay, "GateLamp", Vector3(7.6, 2.6, -9.9), true],
		[quay, "LighterLamp", Vector3(-8.2, 2.0, -17.3), true],
		[quay, "BarrelLamp", Vector3(-11.6, 2.6, 14.1), true],
		[office, "TeaLamp", Vector3(-10.4, 2.4, 2.1), false],
	]:
		var parent: Node3D = spec[0]
		var at: Vector3 = spec[2]
		fittings._lantern(parent, spec[1], at, 4.8)
		var fixture: Node3D = parent.get_node(spec[1])
		var light: OmniLight3D = fixture.get_node("Light")
		light.light_energy = 1.7
		light.light_color = Color("ffc48a")
		light.add_to_group("stealth_lights", true)
		if spec[3]:
			joinery.timber(fixture, "frame", Vector3(0, -at.y, -0.43), Vector3(0, 0.49, -0.43), 0.135, 0.14)
	fittings.j.finish()


func _harbor_life(level: Node3D, quay: Node3D, office: Node3D) -> void:
	var frontage: Node3D = office.get_node("UpperFrontage")
	var roof := _group(frontage, "SlateCourses")
	for side in [-1.0, 1.0]:
		var slope := Basis(Vector3.RIGHT, 0.24 * side)
		for row in 8:
			for column in 18:
				var distance := 0.28 + row * 0.60
				var at := Vector3(-12.59 + column * 0.53, 6.49 - distance * 0.245, side * distance)
				joinery.box(roof, "blue" if (row + column) % 4 else "ironblue", at, Vector3(0.52, 0.07, 0.62), slope)
	joinery.box(roof, "soot", Vector3(-8.08, 6.49, 0), Vector3(9.65, 0.17, 0.19))
	var gable := _group(frontage, "QuaysideGable", Vector3(-6.1, 5.1, 4.96))
	joinery.face(gable, "oak_dark", [Vector3(-1.65, 0, 0), Vector3(1.65, 0, 0), Vector3(0, 1.37, 0)], Vector3.BACK)
	for side in [-1.0, 1.0]:
		joinery.timber(gable, "frame", Vector3(side * 1.67, 0, 0.16), Vector3(0, 1.4, 0.16), 0.17, 0.21)

	var court: Node3D = quay.get_node("BreakCourtyard")
	var arch := _group(court, "CourtyardArch", Vector3(-8.6, 1.83, 12.92))
	for index in 13:
		var angle := PI * index / 12.0
		var at := Vector3(0, sin(angle) * 1.33, cos(angle) * 1.33)
		joinery.box(arch, "ironblue", at, Vector3(0.72, 0.32, 0.32), Basis(Vector3.RIGHT, -angle))
	var canopy := _group(court, "TeaShelter", Vector3(-12.85, 2.9, 15.25))
	joinery.box(canopy, "canvas_dark", Vector3.ZERO, Vector3(1.8, 0.11, 2.4), Basis(Vector3.BACK, 0.13))
	for z in [-1.1, 1.1]:
		joinery.timber(canopy, "oak_dark", Vector3(0.81, -2.9, z), Vector3(0.81, 0, z), 0.11, 0.11)

	var town := _group(quay, "ShoreWarehouses")
	joinery.box(town, "ironblue", Vector3(-20, -0.79, 13), Vector3(12, 1.53, 32))
	for z in [6.4, 13.6, 20.8]:
		var shed := _group(town, "Warehouse", Vector3(-17.1, 0, z))
		joinery.box(shed, "wainscot", Vector3(0, 1.8, 0), Vector3(4.6, 3.6, 6.6))
		for side in [-1.0, 1.0]:
			joinery.box(shed, "blue", Vector3(side * 1.25, 3.94, 0), Vector3(2.75, 0.18, 7.05), Basis(Vector3.BACK, -side * 0.31))
		for window_z in [-1.7, 1.7]:
			joinery.box(shed, "lamp", Vector3(2.32, 2.52, window_z), Vector3(0.04, 0.53, 0.62))
			joinery.box(shed, "frame", Vector3(2.36, 2.52, window_z), Vector3(0.05, 0.56, 0.07))

	var lighter := _group(level.get_node("Ships/PotatoLighter"), "LighterFittings", Vector3(-8.3, 0, -17.7))
	for side in [-1.0, 1.0]:
		joinery.box(lighter, "oak_dark", Vector3(0, 0.42, side * 1.78), Vector3(7.8, 0.18, 0.16))
		for x in [-3.55, -1.5, 1.5, 3.55]:
			joinery.box(lighter, "oak", Vector3(x, 0.2, side * 1.78), Vector3(0.14, 0.54, 0.14))
		joinery.rod(lighter, "cord_dark", Vector3(-0.6, 3.23, 0), Vector3(side * 3.8, 0.42, side * 1.6), 0.024)
	joinery.box(lighter, "oak_red", Vector3(-2.65, 0.72, 0), Vector3(1.85, 1.44, 2.18))
	joinery.box(lighter, "blue", Vector3(-2.65, 1.48, 0), Vector3(2.02, 0.16, 2.4))
	joinery.box(lighter, "lamp", Vector3(-1.71, 1.08, 0), Vector3(0.025, 0.37, 0.6))

	var shore_lamps := preload("res://scripts/last_barrel_ship.gd").new()
	shore_lamps._lantern(quay, "NetMendingLamp", Vector3(10.35, 1.42, 7.12), 4.2)
	shore_lamps._lantern(quay, "TallyLamp", Vector3(-12.27, 2.14, -7.12), 4.1)
	shore_lamps.j.finish()
	var details := _group(quay, "PlacesToExplore")
	_exhibit(details, "Tide slate", Vector3(-12.85, 0, 15.95),
		"LOW WATER AT ONE BELL. Steps slick below the third rung. Leave a lamp for the oyster boats.")
	_exhibit(details, "Net mender’s bench", Vector3(9.5, 0, 7.4),
		"Someone patched this net with a blue sleeve. The other sleeve is folded under the bench.")
	_exhibit(details, "Lost property shelf", Vector3(11.7, 0, 1.8),
		"A brass button, a child’s carved gull, and three keys. A card asks claimants to describe what they lost.")
	_exhibit(details, "Dockers’ tally", Vector3(-11.25, 0, -7.0),
		"Paid through Thursday. Friday’s crew left their marks anyway. Beside each mark is a mug ring.")
	_exhibit(details, "Fishmongers’ board", Vector3(-1.0, 2.8, 29.25),
		"The first bell is for the boats. The second is for the buyers. Unsold fish goes to the kitchens on Mill Street.")
	_exhibit(details, "Tide marks", Vector3(17.45, -0.935, 8.75),
		"Names are scratched beside the high-water lines. The newest one is higher than Rook can reach.")
	for spec in [[Vector3(-13.6, 0.3, 34.4), Vector3(3.1, 4.9, 7.3)],
			[Vector3(-16.05, 0.02, 29.6), Vector3(5.1, 4.3, 4.6)],
			[Vector3(2.7, 0.45, 33.8), Vector3(3.1, 5.1, 5.6)]]:
		var house := _group(quay, "MarketBackstreet", spec[0])
		var size: Vector3 = spec[1]
		joinery.box(house, "ironblue", Vector3.UP * (size.y * 0.5 - 1.9), size)
		for side in [-1.0, 1.0]:
			joinery.box(house, "blue", Vector3(side * size.x * 0.24, size.y - 1.55, 0),
				Vector3(size.x * 0.55, 0.15, size.z + 0.3), Basis(Vector3.BACK, -side * 0.36))
		for x in [-0.85, 0.85]:
			joinery.box(house, "lamp", Vector3(x, size.y - 2.98, -size.z * 0.5 - 0.02),
				Vector3(0.48, 0.69, 0.06))

	for at in [Vector3(9.8, 0, 10.1), Vector3(11.5, 0, 6.4), Vector3(-11.9, 0, -8.1)]:
		var pile := _group(quay, "SackStack", at)
		for index in 3:
			joinery.box(pile, "canvas" if index % 2 else "canvas_dark", Vector3((index % 2) * 0.49, 0.2 + (index / 2) * 0.27, 0), Vector3(0.57, 0.33, 0.86), Basis(Vector3.UP, index * 0.19), 0.14)


func _exhibit(parent: Node3D, title: String, at: Vector3, inscription: String) -> void:
	var prop := _group(parent, title, at)
	prop.set_meta("inscription", inscription)
	joinery.box(prop, "oak_dark", Vector3(0, 0.63, 0), Vector3(1.18, 0.12, 0.53))
	for x in [-0.47, 0.47]:
		joinery.box(prop, "frame", Vector3(x, 0.31, 0), Vector3(0.12, 0.62, 0.39))
	joinery.box(prop, "paper", Vector3(0.08, 0.701, 0.04), Vector3(0.39, 0.018, 0.29), Basis(Vector3.UP, 0.16))
	match title:
		"Net mender’s bench":
			for strand in 7:
				joinery.rod(prop, "cord_dark", Vector3(-0.44, 0.72, -0.23 + strand * 0.07), Vector3(0.51, 0.72, -0.20 + strand * 0.07), 0.008)
			for strand in 10:
				joinery.rod(prop, "cord", Vector3(-0.44 + strand * 0.10, 0.73, -0.23), Vector3(-0.40 + strand * 0.10, 0.73, 0.23), 0.009)
		"Lost property shelf":
			joinery.ring(prop, "brass", Vector3(-0.30, 0.71, 0), 0.08, 0.016, Vector3.RIGHT, Vector3.FORWARD)
			joinery.box(prop, "oak_light", Vector3(0.35, 0.76, -0.12), Vector3(0.12, 0.12, 0.19))
		_:
			joinery.box(prop, "blue", Vector3(-0.26, 0.714, -0.05), Vector3(0.31, 0.035, 0.30))


func _waterfront(quay: Node3D) -> void:
	var shore := _group(quay, "WaterfrontMasonry")
	# Stepped outer faces sit below the walkable quay and frame the tide steps.
	for spec in [
		[Vector3(14.45, -0.8, -5.1), Vector3(1.3, 1.3, 11.8)],
		[Vector3(14.85, -0.8, 0.8), Vector3(2.1, 1.3, 2.0)],
		[Vector3(14.4, -0.8, 3.7), Vector3(1.2, 1.3, 4.0)],
		[Vector3(14.45, -0.8, 12.1), Vector3(1.3, 1.3, 5.4)],
		[Vector3(15.05, -0.8, 15.6), Vector3(2.5, 1.3, 2.0)],
		[Vector3(12.0, -0.8, 17.35), Vector3(4.2, 1.3, 1.3)],
		[Vector3(6.8, -0.8, 17.55), Vector3(3.0, 1.3, 1.7)],
	]:
		joinery.box(shore, "ironblue", spec[0], spec[1], Basis.IDENTITY, 0.08)
	for at in [Vector3(15.1, -1.16, -8), Vector3(15.8, -1.20, -2.1),
			Vector3(15.9, -1.2, 2.1), Vector3(15.75, -1.2, 12.4),
			Vector3(16.4, -1.2, 16.2), Vector3(12.4, -1.2, 18.5),
			Vector3(8.1, -1.2, 18.7)]:
		var rock := _group(shore, "ShoreRock", at)
		joinery.box(rock, "soot", Vector3.ZERO, Vector3(1.7, 0.75, 1.25), Basis(Vector3.UP, at.z * 0.27), 0.27)
	for at in [Vector3(13.6, 0, -8.2), Vector3(13.6, 0, -3.0), Vector3(13.6, 0, 2.8),
			Vector3(13.6, 0, 11.1), Vector3(13.6, 0, 15.4)]:
		var bollard := _group(shore, "MooringBollard", at)
		joinery.rod(bollard, "metal", Vector3.ZERO, Vector3.UP * 0.48, 0.13, 0.10, 10)
		joinery.rod(bollard, "metal_lit", Vector3.UP * 0.46, Vector3.UP * 0.54, 0.16, 0.16, 10)
