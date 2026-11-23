extends Node3D

const LANTERN := preload("res://Modules/Gameplay/LastBarrel/search_lantern.tscn")
const CARVED_CUTS := [
	[Vector2(-0.66, 0.28), Vector2(0.23, 0.38), Vector2(0.56, 0.29), Vector2(0.08, 0.23), Vector2(-0.46, 0.22)],
	[Vector2(-0.36, 0.08), Vector2(0.53, 0.18), Vector2(0.69, 0.08), Vector2(0.28, 0.04), Vector2(-0.31, 0.01)],
	[Vector2(-0.70, -0.14), Vector2(-0.16, -0.07), Vector2(-0.02, -0.15), Vector2(-0.47, -0.22)],
	[Vector2(-0.23, -0.32), Vector2(0.40, -0.23), Vector2(0.25, -0.33), Vector2(-0.11, -0.41)],
]
const INK_BREAKS := [
	[Vector2(-0.63, 0.04), Vector2(-0.16, 0.13), Vector2(-0.23, 0.00), Vector2(-0.54, -0.05)],
	[Vector2(-0.09, 0.29), Vector2(0.11, 0.34), Vector2(0.06, 0.25), Vector2(-0.04, 0.23)],
	[Vector2(0.22, -0.16), Vector2(0.53, -0.03), Vector2(0.64, -0.12), Vector2(0.39, -0.22)],
]

@onready var camera: Camera3D = $Camera3D
@onready var marks: Node3D = $Marks
@onready var controls: Label = $Interface/Controls

var guard_beam: SpotLight3D
var carrier: Node3D
var sweep_time := 0.0
var sweep_paused := false
var camera_focus := Vector3.ZERO


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1280, 800)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("37342f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e4dac4")
	environment.ambient_light_energy = 0.022
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	_box(self, Vector3(0, -0.22, 0), Vector3(15, 0.42, 8), Color("ada59a"))
	_box(self, Vector3(0, 0.66, -3.75), Vector3(15, 1.32, 0.45), Color("474039"))
	_box(self, Vector3(0, 1.36, -3.75), Vector3(15, 0.12, 0.53), Color("9c9081"))
	for x in [-7.2, -2.45, 2.35, 7.2]:
		_box(self, Vector3(x, 0.8, -3.5), Vector3(0.27, 1.6, 0.35), Color("785849"))
	_box(self, Vector3(2.2, 0.34, -1.4), Vector3(1.55, 0.68, 0.9), Color("b1a18d"))
	_box(self, Vector3(2.2, 0.72, -1.4), Vector3(1.65, 0.10, 0.98), Color("c8b69d"))
	_box(self, Vector3(1.78, 0.776, -1.4), Vector3(0.65, 0.012, 0.83), Color("302822"))
	_box(self, Vector3(-0.25, 0.25, -2.4), Vector3(0.7, 0.5, 0.66), Color("776859"))
	_box(self, Vector3(5.65, 0.28, -2.6), Vector3(1.25, 0.56, 0.65), Color("7b6750"))

	# These shapes sit on the test meshes and shade with the light hitting them.
	_stamp(CARVED_CUTS, Vector3(2.50, 0.773, -1.4), Vector3(-PI / 2, 0, 0), 0.59, Color("352b24"))
	_stamp(INK_BREAKS, Vector3(1.78, 0.785, -1.4), Vector3(-PI / 2, 0, 0), 0.43, Color("ded2ba"))
	_stamp(CARVED_CUTS, Vector3(1.15, -0.007, -0.27), Vector3(-PI / 2, 0, 0), 0.95, Color("51473e"))

	var desk_lamp := Vector3(2.15, 3.0, -1.18)
	_box(self, Vector3(3.19, 1.47, -2.5), Vector3(0.12, 3.0, 0.12), Color("554237"))
	_box(self, Vector3(2.67, 2.98, -1.84), Vector3(0.09, 0.09, 1.7), Color("766150")).rotation.y = -0.65
	_box(self, desk_lamp + Vector3.UP * 0.1, Vector3(0.44, 0.17, 0.40), Color("ded2ba"))
	_spot("FixedLamp", desk_lamp, Vector3(2.15, 0.0, -1.18), 7.5, 4.6, 26.0, 0.7, 0.7)

	var watch_origin := Vector3(-6.6, 1.0, -1.3)
	_box(self, Vector3(-6.85, 0.46, -1.3), Vector3(0.62, 0.92, 0.58), Color("58483a"))
	guard_beam = _spot("GuardBeam", watch_origin, Vector3(-2.6, 0.0, 0.6), 10.0, 8.2, 15.0, 0.0, 0.24)
	carrier = Node3D.new()
	carrier.position = Vector3(5.3, 0.0, 1.65)
	add_child(carrier)
	_box(carrier, Vector3(-0.24, 0.32, 0), Vector3(0.38, 0.64, 0.38), Color("493a31"))
	var lantern := LANTERN.instantiate() as Node3D
	lantern.position = Vector3(0.18, 0.70, 0.0)
	carrier.add_child(lantern)
	var handheld := lantern.get_node("LanternLight") as OmniLight3D
	handheld.light_energy = 1.7
	handheld.omni_range = 1.25
	_update_camera()
	_update_controls()


func _process(delta: float) -> void:
	if not sweep_paused:
		sweep_time += delta
		guard_beam.look_at(Vector3(-2.75, 0.0, 0.50 + 1.65 * sin(sweep_time * 0.9)))
	var walking := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var move := walking.limit_length() * 2.4 * delta
	carrier.position.x = clampf(carrier.position.x + move.x, -5.8, 6.6)
	carrier.position.z = clampf(carrier.position.z + move.y, -0.35, 3.45)
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * 3.0 * delta
	if pan != Vector2.ZERO:
		camera_focus.x = clampf(camera_focus.x + pan.x, -3.0, 3.0)
		camera_focus.z = clampf(camera_focus.z + pan.y, -2.0, 2.0)
		_update_camera()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_T:
			marks.visible = not marks.visible
		KEY_SPACE:
			sweep_paused = not sweep_paused
		KEY_R:
			camera_focus = Vector3.ZERO
			_update_camera()
		_:
			return
	_update_controls()
	get_viewport().set_input_as_handled()


func _update_camera() -> void:
	camera.position = camera_focus + Vector3(0, 10.5, 11.0)
	camera.look_at(camera_focus)


func _update_controls() -> void:
	controls.text = "WASD  Move handheld lantern   ·   Arrows  Pan   ·   R  Reset view\nT  Marks %s   ·   Space  Sweep %s" % [
		"on" if marks.visible else "off", "paused" if sweep_paused else "moving"]


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = _matte(color)
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.position = at
	parent.add_child(instance)
	return instance


func _spot(title: String, at: Vector3, target: Vector3, energy: float, reach: float,
		angle: float, distance_falloff: float, angle_falloff: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = title
	light.position = at
	light.light_energy = energy
	light.spot_range = reach
	light.spot_angle = angle
	light.spot_attenuation = distance_falloff
	light.spot_angle_attenuation = angle_falloff
	light.shadow_enabled = true
	add_child(light)
	light.look_at(target, Vector3.BACK)
	return light


func _stamp(shapes: Array, at: Vector3, orientation: Vector3, scale_factor: float, color: Color) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for shape: Array in shapes:
		var polygon := PackedVector2Array(shape)
		for index in Geometry2D.triangulate_polygon(polygon):
			var point := polygon[index] * scale_factor
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(Vector3(point.x, point.y, 0.0))
	var material := _matte(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	var stamp := MeshInstance3D.new()
	stamp.mesh = surface.commit()
	stamp.position = at
	stamp.rotation = orientation
	stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marks.add_child(stamp)


func _matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material
