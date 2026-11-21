extends RefCounted

const JOINERY := preload("res://scripts/last_barrel_ship_mesh.gd")
const LIGHTS := preload("res://scripts/last_barrel_lights.gd")
var j := JOINERY.new()


func build(level: Node3D) -> void:
	var market: Node3D = level.get_node("Quay/FishMarket")
	var kit := Node3D.new()
	kit.name = "Kit"
	kit.position = Vector3(-5.88, 2.8, 30.15)
	level.get_node("People").add_child(kit)
	# A separate, editable character built from the level's existing material palette.
	j.box(kit, "teal", Vector3(0, 0.54, 0), Vector3(0.53, 0.74, 0.30), Basis.IDENTITY, 0.11)
	j.box(kit, "oak", Vector3(0, 1.08, -0.02), Vector3(0.48, 0.43, 0.37), Basis.IDENTITY, 0.12)
	for side in [-1.0, 1.0]:
		j.box(kit, "oak_dark", Vector3(side * 0.17, 1.36, -0.01), Vector3(0.14, 0.22, 0.15), Basis(Vector3.FORWARD, -side * 0.22), 0.025)
		j.box(kit, "oak_light", Vector3(side * 0.105, 1.12, -0.217), Vector3(0.09, 0.055, 0.025))
		j.box(kit, "soot", Vector3(side * 0.105, 1.12, -0.234), Vector3(0.025, 0.045, 0.02))
		j.timber(kit, "teal", Vector3(side * 0.28, 0.78, 0), Vector3(side * 0.38, 0.45, -0.05), 0.13, 0.13)
		j.box(kit, "soot", Vector3(side * 0.15, 0.12, 0), Vector3(0.16, 0.24, 0.25), Basis.IDENTITY, 0.035)
	j.box(kit, "wainscot", Vector3(0, 0.85, -0.01), Vector3(0.54, 0.16, 0.39))
	j.timber(kit, "oak", Vector3(0.16, 0.32, 0.13), Vector3(0.68, 0.31, 0.37), 0.15, 0.15)
	j.timber(kit, "oak_dark", Vector3(0.68, 0.31, 0.37), Vector3(0.77, 0.56, 0.40), 0.14, 0.14)
	j.box(kit, "oak_dark", Vector3(0.29, 0.45, 0.10), Vector3(0.27, 0.30, 0.14))
	j.box(kit, "brass", Vector3(0.30, 0.48, 0.18), Vector3(0.07, 0.08, 0.025))
	var table := Node3D.new()
	table.name = "BriefingTable"
	table.position = Vector3(-6.7, 2.8, 30.45)
	market.add_child(table)
	j.box(table, "oak", Vector3(0, 0.62, 0), Vector3(1.4, 0.12, 0.8))
	for x in [-0.58, 0.58]:
		for z in [-0.29, 0.29]:
			j.box(table, "frame", Vector3(x, 0.31, z), Vector3(0.11, 0.62, 0.11))
	j.box(table, "paper", Vector3(0, 0.695, 0), Vector3(0.95, 0.025, 0.53))
	for x in [-0.34, 0.2]:
		j.box(table, "ink", Vector3(x, 0.712, 0.08), Vector3(0.21, 0.005, 0.02))
		j.box(table, "ink", Vector3(x, 0.712, -0.05), Vector3(0.13, 0.005, 0.02))
	for index in 13:
		var z := 26.7 + index * 0.45
		var puddle := Node3D.new()
		puddle.name = "WetPaving"
		puddle.position = Vector3(-11.0 + fmod(index * 3.17, 11.0), 2.811, z)
		market.add_child(puddle)
		j.box(puddle, "glass", Vector3.ZERO, Vector3(0.66 + fmod(index * 0.19, 0.8), 0.008, 0.25), Basis(Vector3.UP, index * 0.29), 0.055)
	for at in [Vector3(-10.7, 2.8, 28.3), Vector3(-0.4, 2.8, 27.7), Vector3(-10.8, 2.8, 32.5)]:
		var baskets := Node3D.new()
		baskets.name = "FishBaskets"
		baskets.position = at
		market.add_child(baskets)
		j.rod(baskets, "oak_dark", Vector3(0, 0.05, 0), Vector3(0, 0.38, 0), 0.21, 0.31, 10)
		j.ring(baskets, "cord", Vector3(0, 0.39, 0), 0.30, 0.025, Vector3.RIGHT, Vector3.FORWARD, 12)
		j.box(baskets, "canvas_dark", Vector3(0.55, 0.11, 0.05), Vector3(0.55, 0.2, 0.38), Basis.IDENTITY, 0.06)
	LIGHTS.add_spot(market, "BriefingLantern", Vector3(-5.9, 5.0, 29.4),
		Vector3(-6.0, 2.8, 30.0), Color("ffc58a"), 3.8, 3.8, 32.0)
	var skyline := Node3D.new()
	skyline.name = "HillsideCity"
	level.add_child(skyline)
	for row in 4:
		for col in 10:
			var x := -52.0 + col * 9.2 + (row % 2) * 3.8
			var z := -75.0 - row * 11.0
			var height := 5.0 + fmod(col * 2.7 + row * 1.9, 7.0)
			var y := -0.6 + row * 4.1
			j.box(skyline, "harbor", Vector3(x, y + height * 0.5, z), Vector3(7.8, height, 7.2))
			for floor in 2:
				for window in 3:
					j.box(skyline, "lamp", Vector3(x - 2.2 + window * 2.15, y + 2.0 + floor * 2.4, z + 3.62), Vector3(0.45, 0.62, 0.05))
	j.finish()
