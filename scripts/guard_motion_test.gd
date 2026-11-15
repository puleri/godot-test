extends Node3D

const MOVEMENT = preload("res://scripts/movement_tuning.gd")
## A small repeatable patrol circuit using the production guard controllers.
var guards: Array[CharacterBody3D] = []
var _camera: Camera3D
var _label: Label
var _close := 0
var _weighted := true
var _scan_mode := false

func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16, 0.2, 12)
	shape.shape = box
	floor_body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var visual := BoxMesh.new()
	visual.size = box.size
	mesh.mesh = visual
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("38434c")
	mesh.material_override = material
	floor_body.add_child(mesh)
	floor_body.position.y = -0.1
	add_child(floor_body)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("172331")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c7d9e8")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -25, 0)
	light.light_color = Color("ffe1bd")
	light.light_energy = 1.5
	light.shadow_enabled = true
	add_child(light)
	for i in 2:
		var route := Node3D.new()
		route.name = "Route%d" % i
		var offset := Vector3(-2.8 if i == 0 else 2.3, 0, 0)
		for point in [Vector3(-1.1, 0, -1.4), Vector3(1.1, 0, -1.4), Vector3(1.1, 0, 1.4), Vector3(-1.1, 0, 1.4)]:
			var marker := Marker3D.new()
			marker.position = offset + point
			route.add_child(marker)
		add_child(route)
		var guard = load("res://Characters/Hound/hound_npc.tscn" if i == 0 else "res://Characters/Mouse/mouse_npc.tscn").instantiate()
		guard.set_script(preload("res://scripts/stealth_guard.gd"))
		guard.visual_forward_yaw_offset = PI / 2.0
		guard.locomotion_uses_run = i == 1
		guard.name = "HoundGuard" if i == 0 else "MouseGuard"
		guard.route_path = NodePath("../" + str(route.name))
		guard.position = route.get_child(0).position
		guard.walk_speed = 1.25 if i == 0 else 1.7
		guard.run_speed = MOVEMENT.HOUND_PURSUIT_SPEED if i == 0 else 3.15
		guard.pause_min_seconds = 0.8
		guard.pause_max_seconds = 1.1
		guard.random_seed = 7300 + i
		guard.alert_chance_on_arrival = 0.0
		guard.show_vision = false
		add_child(guard)
		guard.navigation_ready = true
		guard.get_node("SuspicionBubble").set_enabled(false)
		guard._state_label.visible = false
		guards.append(guard)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_camera)
	_camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 20)
	_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_label)
	_update_label()

func _physics_process(_delta: float) -> void:
	if _camera == null:
		return
	var focus := Vector3(0, 0.35, 0) if _close == 0 else guards[_close - 1].global_position + Vector3(0, 0.3, 0)
	_camera.global_position = focus + Vector3(4, 3, 6)
	_camera.look_at(focus)
	_camera.size = 11.0 if _close == 0 else (3.2 if _close == 1 else 1.8)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_P:
			_weighted = not _weighted
			for guard in guards:
				guard.weighted_motion_enabled = _weighted
		KEY_S:
			_scan_mode = not _scan_mode
			for guard in guards:
				if _scan_mode:
					guard.guard_state = StealthGuard.GuardState.SEARCH
					guard._search_arrived = true
					guard._search_elapsed = 0.0
					guard._search_yaw = guard._last_visual_yaw - guard.visual_forward_yaw_offset
					guard.search_seconds = 3600.0
				else:
					guard.guard_state = StealthGuard.GuardState.PATROL
					guard._pause_remaining = 0.25
		KEY_C:
			_close = (_close + 1) % 3
		KEY_R:
			get_tree().reload_current_scene()
		_:
			return
	_update_label()
	get_viewport().set_input_as_handled()

func _update_label() -> void:
	_label.text = "GUARD MOTION · %s\nP · Weight on/off     C · Close-up     S · Look-around     R · Restart\nWatch the head lead, paws hold contact, and the body settle after braking." % ("ON" if _weighted else "OFF")
