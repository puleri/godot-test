extends Node3D
## Original dock geometry. X is the side-scrolling axis, Y is height.

const Door = preload("res://Levels/Tidewatch/door.gd")
const Arch = preload("res://Mesh/Harboretum-Mesh/habor_archway.tscn")
const Barrel = preload("res://Modules/Props/CargoBarrel.tscn")
const Rail = preload("res://Mesh/Harboretum-Mesh/stone_railing.tscn")
const METAL := Color("263d48")
const STONE := Color("23313e")
const WOOD := Color("414750")
const TRIM := Color("4a777e")
const GOLD := Color("f6bb75")
const TEAL := Color("83e3dd")

var doors: Array[Node3D] = []
var lamps: Array[StaticBody3D] = []
var escape_gate: Node3D
var winch: Node3D
var beacon: MeshInstance3D
var slingshot: Node3D
var _materials: Dictionary = {}


func build() -> void:
	_backdrop()
	box(self, Vector3(16, -0.35, -0.35), Vector3(46, 0.7, 4.8), STONE, true)
	box(self, Vector3(16, -0.14, 2.01), Vector3(46, 0.18, 0.11), TRIM)
	box(self, Vector3(-6.9, 2.5, 0), Vector3(0.35, 5.0, 3.3), STONE, true)
	box(self, Vector3(38.9, 2.5, 0), Vector3(0.35, 5.0, 3.3), STONE, true)
	for x in range(-6, 39, 2):
		box(self, Vector3(x, -0.48, 2.03), Vector3(0.055, 0.42, 0.06), METAL)
	for x in [1.2, 17.4]:
		doors.append(_door(x))
	escape_gate = _door(32.0, true)
	_walkway(3.45, 0.68, 1.45)
	_walkway(8.75, 1.82, 7.4)
	_walkway(26.9, 1.04, 4.2)
	_fixture(6.35, 3.48, 4.45)
	_fixture(12.9, 3.0, 3.05)
	_fixture(21.45, 2.88, 4.7, -2.03)
	_fixture(28.1, 3.43, 3.55)
	for x in [-4.3, -3.25, 3.7, 10.7, 15.2, 19.0, 26.1, 34.5, 36.2]:
		var barrel := Barrel.instantiate() as Node3D
		add_child(barrel)
		barrel.position = Vector3(x, 1.04 if x == 26.1 else 0.0, -1.73)
		barrel.scale *= 0.8
		barrel.rotation.y = x * 2.0
	for x in [-4.8, 14.35, 35.35]:
		var arch := Arch.instantiate() as Node3D
		add_child(arch)
		arch.position = Vector3(x - 1.0, 0.04, -2.2)
	for x in [-4.8, -2.8, 15.1, 35.5, 37.5]:
		var rail := Rail.instantiate() as Node3D
		add_child(rail)
		rail.position = Vector3(x, 0, -1.82)
	_sign(Vector3(-1.62, 2.34, -1.3), "SERVICE DOCK")
	_sign(Vector3(8.6, 2.89, -1.62), "INSPECTION CATWALK")
	_sign(Vector3(15.1, 2.34, -1.55), "PUMP HOUSE  →")
	_sign(Vector3(26.9, 2.75, -1.52), "FLOODGATE WINCH")
	_sign(Vector3(35.3, 2.34, -1.55), "EAST QUAY")
	_build_winch()
	_build_slingshot()


func signal_gate_open() -> void:
	beacon.material_override = _material(TEAL, true)


func show_slingshot(at: Vector3, direction: Vector3, duration: float) -> void:
	slingshot.position = at + Vector3.FORWARD * -0.14
	slingshot.scale.x = signf(direction.x) if absf(direction.x) > 0.01 else 1.0
	slingshot.rotation.z = atan2(direction.y, absf(direction.x)) * slingshot.scale.x * 0.65
	slingshot.show()
	get_tree().create_timer(duration, false).timeout.connect(slingshot.hide)


func _build_slingshot() -> void:
	slingshot = Node3D.new()
	add_child(slingshot)
	var walnut := Color("b68156")
	box(slingshot, Vector3(-0.075, -0.15, 0), Vector3(0.065, 0.28, 0.065), walnut, false, true).rotation.z = -0.33
	box(slingshot, Vector3(-0.085, 0.048, 0), Vector3(0.038, 0.16, 0.055), walnut, false, true).rotation.z = 0.49
	box(slingshot, Vector3(0.004, 0.052, 0), Vector3(0.04, 0.17, 0.055), walnut, false, true).rotation.z = -0.5
	box(slingshot, Vector3(-0.036, 0.11, 0), Vector3(0.15, 0.017, 0.03), GOLD, false, true)
	slingshot.hide()


func _backdrop() -> void:
	box(self, Vector3(16, -0.79, -9), Vector3(108, 0.25, 46), Color("142637"), false, true)
	for i in 58:
		var x := fposmod(i * 13.79, 76.0) - 22.0
		var z := -18.0 + fposmod(i * 3.13, 18.0)
		box(self, Vector3(x, -0.655, z), Vector3(0.45 + fposmod(i * 0.63, 2.1), 0.012, 0.035), Color("294958"), false, true)
	for i in 26:
		var height := 1.4 + fposmod(i * 1.37, 4.4)
		var x := i * 3.7 - 39.0
		box(self, Vector3(x, height * 0.5 - 0.6, -24.0), Vector3(3.25, height, 3.2), Color("172437"), false, true)
		for row in int(height / 1.1):
			box(self, Vector3(x + 0.52, row * 1.1 + 0.32, -22.38), Vector3(0.12, 0.27, 0.02), Color("3c5467"), false, true)
	var moon := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = 0.48
	disc.height = 0.96
	moon.mesh = disc
	moon.material_override = _material(Color("9ab7c7"), true)
	moon.position = Vector3(-1.35, 5.45, -22.0)
	add_child(moon)
	for span: Vector2 in [Vector2(0.7, 13.0), Vector2(17.1, 31.8)]:
		var center := (span.x + span.y) * 0.5
		var width := span.y - span.x
		box(self, Vector3(center, 2.53, -2.64), Vector3(width, 5.1, 0.35), Color("2b3b49"))
		box(self, Vector3(center, 4.85, -0.75), Vector3(width + 0.45, 0.38, 4.1), STONE)
		box(self, Vector3(center, 4.64, 1.29), Vector3(width + 0.6, 0.13, 0.12), TRIM)
		for i in int(width / 1.5):
			var x := span.x + 0.85 + i * 1.5
			box(self, Vector3(x, 3.49, -2.43), Vector3(0.47, 1.08, 0.05), Color("3b677b"), false, true)
			box(self, Vector3(x, 3.25, -2.39), Vector3(0.52, 0.05, 0.06), METAL)
		for row in 5:
			var y := 0.54 + row * 0.51
			box(self, Vector3(center, y, -2.448), Vector3(width, 0.016, 0.025), Color("354956"))
			for i in int(width / 2.1):
				var x := span.x + 0.32 + i * 2.1 + (row % 2) * 0.98
				box(self, Vector3(x, y - 0.245, -2.448), Vector3(0.019, 0.48, 0.028), Color("354956"))
		for i in int(width / 3.1) + 1:
			var x := span.x + 0.12 + i * 3.1
			box(self, Vector3(x, 2.46, -2.39), Vector3(0.25, 4.92, 0.27), METAL)


func _door(x: float, gate := false) -> Node3D:
	var door := Door.new()
	door.name = "Floodgate" if gate else "LeanDoor"
	door.opens_on_lean = not gate
	door.position.x = x
	for z in [-1.48, 1.48]:
		box(door, Vector3(0, 1.13, z), Vector3(0.55, 2.26, 0.24), TRIM)
	box(door, Vector3(0, 2.24, 0), Vector3(0.53, 0.25, 3.17), TRIM)
	box(door, Vector3(0, 3.42, 0), Vector3(0.38, 2.12, 2.96), STONE, true)
	var panel := StaticBody3D.new()
	panel.name = "Panel"
	door.add_child(panel)
	box(panel, Vector3(0, 1.03, 0), Vector3(0.24, 2.06, 2.9), METAL)
	_shape(panel, Vector3(0, 1.12, 0), Vector3(0.24, 2.35, 2.9))
	for i in 6:
		box(panel, Vector3(0, 0.24 + i * 0.3, 0), Vector3(0.26, 0.027, 2.93), TRIM)
	box(panel, Vector3(0, 1.24, 1.63), Vector3(0.21, 0.22, 0.045), GOLD if gate else TEAL, false, true)
	add_child(door)
	return door


func _walkway(x: float, height: float, width: float) -> void:
	box(self, Vector3(x, height - 0.08, -0.12), Vector3(width, 0.16, 2.25), WOOD, true)
	box(self, Vector3(x, height - 0.08, 1.04), Vector3(width, 0.17, 0.16), TRIM)
	box(self, Vector3(x, height + 0.55, -1.25), Vector3(width, 0.075, 0.1), METAL)
	for i in int(width / 0.7) + 1:
		var post_x := x - width * 0.5 + minf(width - 0.08, 0.08 + i * 0.7)
		box(self, Vector3(post_x, height + 0.27, -1.25), Vector3(0.065, 0.55, 0.10), METAL)
	for post_x in [x - width * 0.5 + 0.22, x + width * 0.5 - 0.22]:
		box(self, Vector3(post_x, height * 0.5, -1.05), Vector3(0.13, height, 0.15), WOOD)


func _fixture(x: float, height: float, reach: float, depth := 0.0) -> void:
	var lamp := StaticBody3D.new()
	lamp.name = "BreakableLamp"
	lamp.position = Vector3(x, height, depth)
	lamp.collision_layer = 8
	lamp.collision_mask = 0
	add_child(lamp)
	_shape(lamp, Vector3.ZERO, Vector3(0.52, 0.45, 0.5))
	var bulb := box(lamp, Vector3.ZERO, Vector3(0.33, 0.26, 0.35), GOLD, false, true)
	bulb.name = "Bulb"
	box(lamp, Vector3(0, 0.17, 0), Vector3(0.58, 0.12, 0.53), METAL)
	box(lamp, Vector3(0, (4.65 - height) * 0.5 + 0.10, 0), Vector3(0.06, 4.65 - height - 0.20, 0.06), TRIM)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = GOLD
	light.light_energy = 4.2
	light.omni_range = reach
	light.omni_attenuation = 1.05
	light.shadow_enabled = true
	light.set_meta("stealth_strength", 0.52)
	lamp.add_child(light)
	light.add_to_group("stealth_lights")
	lamps.append(lamp)


func _build_winch() -> void:
	winch = Node3D.new()
	winch.position = Vector3(26.9, 1.04, 0)
	add_child(winch)
	box(winch, Vector3(0, 0.45, -0.64), Vector3(0.72, 0.90, 0.52), METAL)
	var wheel := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.20
	ring.outer_radius = 0.29
	wheel.mesh = ring
	wheel.material_override = _material(GOLD, false)
	wheel.position = Vector3(0, 0.62, -0.34)
	wheel.rotation.x = PI * 0.5
	winch.add_child(wheel)
	beacon = box(winch, Vector3(0, 0.97, -0.63), Vector3(0.14, 0.11, 0.10), GOLD, false, true)


func _sign(at: Vector3, content: String) -> void:
	var sign_label := Label3D.new()
	sign_label.text = content
	sign_label.position = at
	sign_label.font_size = 44
	sign_label.pixel_size = 0.005
	sign_label.modulate = Color("a5c3c9")
	sign_label.outline_size = 4
	add_child(sign_label)


func box(parent: Node3D, at: Vector3, size: Vector3, tint: Color, solid := false, unlit := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.material_override = _material(tint, unlit)
	part.position = at
	if solid:
		var body := StaticBody3D.new()
		parent.add_child(body)
		_shape(body, at, size)
	parent.add_child(part)
	return part


func _shape(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = at
	body.add_child(collider)


func _material(tint: Color, unlit: bool) -> StandardMaterial3D:
	var key := Vector2i(tint.to_rgba32(), int(unlit))
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = 0.83
		if unlit:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = material
	return _materials[key]
