extends Node3D

const Dock = preload("res://Levels/Tidewatch/dock.gd")
const HUD = preload("res://Levels/Tidewatch/hud.gd")
const SHOT_RANGE := 8.5
const SHOT_SPEED := 31.0
const GLASS_RADIUS := 6.5

@onready var player: CharacterBody3D = $Player
@onready var sensor: StealthExposureSensor = $Player/ExposureSensor
@onready var camera: Camera3D = $Camera
var dock: Node3D
var hud: CanvasLayer
var lever_pulled := false
var escaped := false
var caught := false
var _shot_cooldown := 0.0
var _mouse_shot := Vector3.INF
var _keyboard_shot := false
var _interact := false
var _message := ""
var _message_time := 0.0
var _door_sound: AudioStreamPlayer3D
var _glass_sound: AudioStreamPlayer3D


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 810)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_make_lighting()
	dock = Dock.new()
	dock.name = "Drydock"
	add_child(dock)
	dock.build()
	# Keep each Hound on the ground of its own bay. Rook alone uses the platforms.
	_navigation_strip(4.35, 16.25)
	_navigation_strip(18.55, 24.35, -2.22)
	_door_sound = _spatial_sound(preload("res://Music/FX/knock1.mp3"), -13.0)
	_glass_sound = _spatial_sound(_glass_clip(), -10.0)
	sensor.refresh_lights()
	player.noise_emitted.connect(_on_noise)
	hud = HUD.new()
	add_child(hud)
	await get_tree().physics_frame
	for guard in $Guards.get_children():
		guard.navigation_ready = true
		guard.player_caught.connect(_on_caught)
		# Keep the shared indicator with the guard in the side-on camera.
		guard._state_label.position.y = 1.23
		guard._state_label.pixel_size = 0.0057


func _physics_process(delta: float) -> void:
	if escaped or caught:
		return
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_message_time = maxf(0.0, _message_time - delta)
	for door in dock.doors:
		if door.opened:
			continue
		door.update_lean(player.lean_door == door, delta)
		if door.opened:
			_door_sound.position = door.position
			_door_sound.play()
			_on_noise(door.position, 2.8, "SHUTTER")
	if _mouse_shot.is_finite():
		_fire(_mouse_shot)
		_mouse_shot = Vector3.INF
	elif _keyboard_shot:
		var lamp := _nearest_lamp()
		if lamp != null:
			_fire(lamp.position)
		else:
			_report("No clear lamp in front of Rook.")
	_keyboard_shot = false
	if _interact:
		_interact = false
		_try_winch()
	if player.position.x > 35.6 and lever_pulled:
		escaped = true
		player.set_interaction_locked(true)
	if player.position.y < -4.0:
		_on_caught()


func _process(_delta: float) -> void:
	if hud == null:
		return
	var x := player.position.x
	var objective := "Reach the pump house"
	var tip := "Walk into the shutter to peek. Keep moving into it to open it."
	if dock.doors[0].opened:
		tip = "Shoot a lamp with a click or F. Jump from the step to take the catwalk."
	if x > 12.5:
		tip = "Walk into the pump house shutter. Release movement to end the peek."
	if dock.doors[1].opened:
		objective = "Raise the floodgate"
		tip = "Shoot the recessed lamp. Let the Hound go to it, then jump to the winch."
	if lever_pulled:
		objective = "Escape to the east quay"
		tip = "The floodgate is up. Head right to the quay."
	var danger := ""
	for guard in $Guards.get_children():
		if guard.guard_state == StealthGuard.GuardState.CHASE:
			danger = "PURSUIT"
			break
		if guard.guard_state == StealthGuard.GuardState.SEARCH:
			danger = "HOUND SEARCHING"
		elif guard.guard_state == StealthGuard.GuardState.SUSPICIOUS and danger.is_empty():
			danger = "SUSPICION"
	hud.update_display(objective, _message if _message_time > 0 else tip, sensor.exposure, danger)
	var selected := _hover_lamp(get_viewport().get_mouse_position()) if not caught and not escaped else null
	hud.set_target(camera.unproject_position(selected.global_position) if selected != null else Vector2.INF)
	if escaped:
		hud.show_result("Across at low tide", "Floodgate raised. Rook reached the east quay.")
	elif caught:
		hud.show_result("The watch caught Rook", "Use shade and height to break pursuit.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not event.is_echo():
		get_tree().reload_current_scene()
		return
	if escaped or caught or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var assisted := _hover_lamp(event.position)
		_mouse_shot = assisted.global_position if assisted != null else _aim_point(event.position)
	elif event is InputEventKey and event.physical_keycode == KEY_F:
		_keyboard_shot = true
	elif event.is_action_pressed("interact"):
		_interact = true


func _try_winch() -> void:
	var feet := player.position - Vector3.UP * 0.47
	if lever_pulled or feet.distance_to(dock.winch.position) > 0.9 or not player.is_on_floor():
		return
	lever_pulled = true
	dock.escape_gate.open()
	dock.signal_gate_open()
	_door_sound.position = dock.escape_gate.position
	_door_sound.play()


func _aim_point(screen: Vector2) -> Vector3:
	var ray := camera.project_ray_normal(screen)
	var origin := camera.project_ray_origin(screen)
	return origin - ray * origin.z / ray.z


func _shot_origin() -> Vector3:
	return player.position + Vector3(player.lean_reach, 0.50, 0.0)


func _cast_shot(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
	)


func _hover_lamp(screen: Vector2) -> StaticBody3D:
	var chosen: StaticBody3D
	var radius := 27.0
	for lamp in dock.lamps:
		if lamp.collision_layer == 0 or camera.is_position_behind(lamp.global_position):
			continue
		var distance := screen.distance_to(camera.unproject_position(lamp.global_position))
		if distance < radius:
			chosen = lamp
			radius = distance
	return chosen


func _nearest_lamp() -> StaticBody3D:
	var chosen: StaticBody3D
	var distance := SHOT_RANGE
	var from := _shot_origin()
	for lamp in dock.lamps:
		var offset: Vector3 = lamp.position - from
		if lamp.collision_layer == 0 or offset.x * player.facing < 0 or offset.length() >= distance:
			continue
		if _cast_shot(from, lamp.position).get("collider") == lamp:
			chosen = lamp
			distance = offset.length()
	return chosen


func _fire(point: Vector3) -> void:
	if _shot_cooldown > 0:
		return
	var from := _shot_origin()
	if from.distance_squared_to(point) < 0.04:
		return
	_shot_cooldown = 0.37
	var direction := (point - from).normalized()
	dock.show_slingshot(from, direction, 0.28)
	var to := from + direction * SHOT_RANGE
	var hit := _cast_shot(from, to)
	var end: Vector3 = hit.get("position", to)
	var pellet: MeshInstance3D = dock.box(self, from, Vector3(0.12, 0.08, 0.08), Dock.GOLD, false, true)
	var flight := create_tween()
	flight.tween_property(pellet, "position", end, from.distance_to(end) / SHOT_SPEED)
	flight.tween_callback(pellet.queue_free)
	var lamp := hit.get("collider") as StaticBody3D
	if lamp in dock.lamps:
		flight.tween_callback(_break_lamp.bind(lamp))


func _break_lamp(lamp: StaticBody3D) -> void:
	if lamp.collision_layer == 0 or escaped or caught:
		return
	lamp.collision_layer = 0
	lamp.get_node("Light").hide()
	lamp.get_node("Bulb").hide()
	_glass_sound.position = lamp.position
	_glass_sound.play()
	_on_noise(Vector3(lamp.position.x, 0.0, lamp.position.z), GLASS_RADIUS, "BROKEN GLASS")
	_glass_feedback(lamp.position)
	_report("Lamp out. Glass draws the watch toward the impact.")


func _on_noise(at: Vector3, reach: float, kind: String) -> void:
	if caught or escaped:
		return
	for guard in $Guards.get_children():
		guard.hear_sound(at, reach, kind)


func _glass_feedback(at: Vector3) -> void:
	for i in 7:
		var angle := i * TAU / 7.0
		var shard: MeshInstance3D = dock.box(self, at, Vector3(0.057, 0.10, 0.046), Dock.GOLD, false, true)
		shard.rotation.z = angle
		var offset := Vector3(cos(angle) * 0.68, sin(angle) * 0.47 - 0.52, 0)
		var effect := create_tween()
		effect.tween_property(shard, "position", at + offset, 0.34).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		effect.tween_callback(shard.queue_free)
	var pulse := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.94
	ring.outer_radius = 1.0
	pulse.mesh = ring
	pulse.material_override = dock._material(Dock.TEAL, true).duplicate()
	pulse.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pulse.position = Vector3(at.x, 0.04, at.z)
	pulse.scale = Vector3.ONE * 0.18
	add_child(pulse)
	var spread := create_tween()
	spread.set_parallel()
	spread.tween_property(pulse, "scale", Vector3(GLASS_RADIUS, 1.0, 1.2), 0.48)
	spread.tween_property(pulse.material_override, "albedo_color:a", 0.0, 0.48)
	spread.chain().tween_callback(pulse.queue_free)


func _report(message: String) -> void:
	_message = message
	_message_time = 2.1


func _on_caught() -> void:
	caught = true
	player.set_interaction_locked(true)
	for guard in $Guards.get_children():
		guard.active = false


func _navigation_strip(left: float, right: float, back := -0.65) -> void:
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([
		Vector3(left, 0, back), Vector3(right, 0, back),
		Vector3(right, 0, 0.65), Vector3(left, 0, 0.65),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	add_child(region)


func _make_lighting() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("22354b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("95b9e2")
	environment.environment.ambient_light_energy = 0.42
	add_child(environment)
	# Moon fill gives silhouettes an edge while registered lamps govern stealth.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-40, -24, -10)
	moon.light_color = Color("8fafdf")
	moon.light_energy = 0.38
	add_child(moon)


func _spatial_sound(clip: AudioStream, volume: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.stream = clip
	voice.volume_db = volume
	voice.max_distance = 30
	voice.unit_size = 9
	add_child(voice)
	return voice


func _glass_clip() -> AudioStreamWAV:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	var length := 3100
	var pcm := PackedByteArray()
	pcm.resize(length * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1607
	for i in length:
		var t := float(i) / clip.mix_rate
		var crack := rng.randf_range(-0.5, 0.5) * exp(-t * 82)
		var chime := (sin(t * TAU * 2700) + 0.5 * sin(t * TAU * 3510)) * 0.22 * exp(-t * 43)
		pcm.encode_s16(i * 2, int((crack + chime) * 30000))
	clip.data = pcm
	return clip
