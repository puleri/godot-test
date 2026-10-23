extends SceneTree
## Actual physics-ray tests of the independent sensing layers.

var checks := 0
var failures := 0
var world: Node3D
var player: CharacterBody3D
var sensor: StealthExposureSensor
var guard: LayeredStealthGuard
var beam: SpotLight3D
var spot: SpotLight3D
var flash: DirectionalLight3D
var cover: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Awareness checks timed out"); quit(1))
	_build_fixture()
	await physics_frame
	await physics_frame
	sensor.refresh_lights()
	sensor.set_physics_process(false)
	_sense()
	_check(sensor.exposure_name() == "HIDDEN" and not guard.player_visible, "Unlit Rook is hidden inside the broad view cone")
	for fps in [30, 60, 120]:
		_reset_guard()
		for frame in fps * 20:
			_sense()
			guard._update_awareness(1.0 / fps)
		_check(guard.awareness == 0 and guard.guard_state == StealthGuard.GuardState.PATROL, "Stationary deep shadow stays safe indefinitely at %d FPS" % fps)
	guard.last_seen_position = Vector3(12, 0.49, 12)
	player.velocity = Vector3(3, 0, 0)
	for frame in 300:
		_sense()
		guard._update_awareness(1.0 / 60)
	_check(guard.awareness <= guard.suspicion_cap and guard.guard_state == StealthGuard.GuardState.SEARCH, "Movement in darkness leads to capped suspicion and investigation, never recognition")
	_check(guard.last_seen_position.is_equal_approx(Vector3(12, 0.49, 12)), "Uncertain movement does not overwrite confirmed sighting memory")
	var suspect := guard.last_suspected_position
	player.position.x += 0.8
	_sense()
	guard._update_awareness(0.1)
	_check(guard.last_suspected_position == suspect, "An uncertain investigation uses a coarse frozen location")
	player.position = Vector3(0, 0.49, -4)
	player.velocity = Vector3.ZERO
	_reset_guard()
	guard.has_lamp = true
	guard._sync_sight_light()
	_sense()
	_check(guard.player_visible and sensor.exposure_name() == "EXPOSED", "A narrow guard lamp illuminates Rook and enables recognition")
	_check(beam.spot_angle * 2 < guard.field_of_view_degrees and beam.spot_range < guard.sight_range, "Lamp beam and reach are independent of the wider, longer view cone")
	var full_strength := guard.recognition_strength
	for fps in [30, 60, 120]:
		_reset_guard()
		_sense()
		for frame in fps / 2:
			guard._update_awareness(1.0 / fps)
		_check(is_equal_approx(guard.awareness, 0.5 * guard.recognition_strength / guard.seconds_to_detect), "Recognition integrates elapsed time at %d FPS" % fps)
	player.position = Vector3(2.8, 0.49, -4)
	_sense()
	_check(not guard.player_visible and sensor.exposure == 0, "The outer view cone remains dark outside the lamp beam")
	player.velocity = Vector3(2, 0, 0)
	_sense()
	guard._update_awareness(0.4)
	guard._face_position(Vector3.ZERO, 0.5)
	guard._sync_sight_light()
	_sense()
	_check(guard.player_visible, "Investigating shadow movement can turn a narrow lamp onto Rook and reveal him")
	player.velocity = Vector3.ZERO
	guard._set_visual_yaw(0)
	_reset_guard()
	guard.has_lamp = false
	guard._sync_sight_light()
	spot.position = Vector3(2.8, 5, -4)
	spot.visible = true
	await physics_frame
	_sense()
	_check(guard.player_visible, "An independent spotlight reveals Rook outside the guard's lamp")
	spot.light_energy = 0.2
	_sense()
	_check(sensor.exposure_name() == "DIM" and not guard.player_visible and guard.uncertain_visible, "A stationary dim figure supplies uncertainty rather than recognition")
	spot.light_energy = 1
	player.position.z = 4
	spot.position.z = 4
	await physics_frame
	_sense()
	_check(sensor.exposure > 0.9 and not guard.player_visible, "Illumination behind the guard does not grant rear vision")
	player.position = Vector3(0, 0.49, -4)
	spot.position = Vector3(0, 5, -4)
	_wall(Vector3(0, 1.5, -2), Vector3(8, 3, 0.3))
	await physics_frame
	_sense()
	_check(sensor.exposure > 0.9 and not guard.player_visible, "Lit Rook remains hidden behind solid sight-blocking cover")
	await _clear_cover()
	spot.position = Vector3(-3, 1.2, -4)
	spot.look_at(player.position + Vector3.UP * 0.3)
	_wall(Vector3(-1.5, 1.5, -4), Vector3(0.3, 3, 3))
	await physics_frame
	_sense()
	_check(sensor.exposure == 0 and not guard.player_visible, "A wall can block the light while leaving the guard's view unobstructed")
	await _clear_cover()
	spot.position = Vector3(0, 5, -4)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	_wall(Vector3(0, 0.4, -2), Vector3(8, 0.8, 0.3))
	await physics_frame
	_sense()
	_check(guard.player_visible and is_equal_approx(guard.visible_exposure, 0.5), "Head-only sight contributes half the visual evidence")
	_check(guard.recognition_strength < full_strength, "Partial cover slows recognition")
	await _clear_cover()
	_wall(Vector3(0, 0.82, -4), Vector3(2, 0.1, 2))
	await physics_frame
	_sense()
	_check(is_equal_approx(sensor.exposure, 0.5), "Illumination samples distinguish a lit head from a shadowed torso")
	await _clear_cover()
	spot.visible = false
	flash.visible = true
	flash.light_energy = 1
	_sense()
	var view_range := guard.sight_range
	_check(guard.player_visible and sensor.lightning_exposure > 0.9, "Lightning reveals exposed Rook through shared illumination")
	_wall(Vector3(0, 2, -4), Vector3(3, 0.2, 3))
	await physics_frame
	_sense()
	_check(sensor.exposure == 0 and not guard.player_visible, "Overhead shelter blocks the lightning illumination ray")
	await _clear_cover()
	_wall(Vector3(0, 1.5, -2), Vector3(8, 3, 0.3))
	await physics_frame
	_sense()
	_check(not guard.player_visible and guard.sight_range == view_range, "Lightning respects cover and does not expand the view cone")
	await _clear_cover()
	_sense()
	_reset_guard()
	guard.last_seen_position = player.position
	guard.guard_state = StealthGuard.GuardState.CHASE
	guard.awareness = 1
	var confirmed := guard.last_seen_position
	flash.visible = false
	player.position.x = 2
	player.velocity = Vector3(2, 0, 0)
	for frame in 50:
		_sense()
		guard._update_awareness(1.0 / 60)
	_check(guard.guard_state == StealthGuard.GuardState.SEARCH and guard.investigation_target == confirmed, "Losing illumination changes pursuit into a search at the last confirmed sighting")
	_check(guard.last_seen_position == confirmed, "Movement in darkness never refreshes pursuit memory")
	_reset_guard()
	player.velocity = Vector3.ZERO
	player.position = Vector3(0, 0.49, 0.7)
	_sense()
	_check(guard.player_visible, "Very close contact can reveal Rook even in darkness behind the guard")
	_wall(Vector3(0, 1, 0.35), Vector3(3, 2, 0.1))
	await physics_frame
	_sense()
	_check(not guard.player_visible, "Close recognition cannot bypass a wall")
	await _clear_cover()
	_reset_guard()
	guard.last_seen_position = confirmed
	guard.navigation_ready = true
	_check(guard.hear_sound(Vector3(0, 0, 4), 5, "FOOTSTEPS"), "Sound can be heard behind the guard without illumination")
	_check(not guard.player_visible and guard.guard_state == StealthGuard.GuardState.SEARCH and guard.last_seen_position == confirmed, "Hearing starts an investigation without recognizing or tracking Rook")
	var heard := guard.last_heard_position
	_check(not guard.hear_sound(Vector3(1, 0, 3), 5, "FOOTSTEPS") and guard.last_heard_position == heard, "Repeated footsteps cannot continuously steer an ongoing investigation")
	_reset_guard()
	_check(not guard.hear_sound(Vector3(0, 0, 4), 2, "FOOTSTEPS"), "Quiet footsteps have a smaller audible radius")
	guard.hearing_range = 3
	_check(not guard.hear_sound(Vector3(0, 0, 4), 20, "BELL"), "Sound is also bounded by the guard's hearing range")
	guard.hearing_range = 14
	_wall(Vector3(0, 1, 2), Vector3(8, 2, 0.2))
	await physics_frame
	_check(not guard.hear_sound(Vector3(0, 0, 4), 5, "FOOTSTEPS"), "Walls attenuate quieter sound")
	_check(guard.hear_sound(Vector3(0, 0, 4), 14, "BELL"), "Loud bells can still be heard through cover")
	guard.guard_state = StealthGuard.GuardState.CHASE
	_check(not guard.hear_sound(Vector3.ZERO, 14, "BELL"), "Sound cannot override a confirmed chase")
	print("AWARENESS CHECKS: %d passed, %d failed" % [checks - failures, failures])
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _build_fixture() -> void:
	world = Node3D.new()
	world.name = "AwarenessFixture"
	var routes := Node3D.new()
	routes.name = "Route"
	var marker := Marker3D.new()
	routes.add_child(marker)
	world.add_child(routes)
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.49, -4)
	player.collision_layer = 4
	sensor = StealthExposureSensor.new()
	sensor.name = "ExposureSensor"
	player.add_child(sensor)
	world.add_child(player)
	guard = LayeredStealthGuard.new()
	guard.name = "Guard"
	guard.sight_range = 10
	guard.field_of_view_degrees = 110
	guard.player_path = NodePath("../Player")
	guard.route_path = NodePath("../Route")
	guard.exposure_sensor_path = NodePath("../Player/ExposureSensor")
	guard.has_lamp = false
	guard.eye_height = 0.75
	var pivot := Node3D.new()
	pivot.name = "VisualPivot"
	guard.add_child(pivot)
	beam = SpotLight3D.new()
	beam.name = "SightLight"
	beam.light_energy = 8
	beam.spot_attenuation = 0
	beam.add_to_group("stealth_lights")
	guard.add_child(beam)
	world.add_child(guard)
	cover = Node3D.new()
	world.add_child(cover)
	spot = SpotLight3D.new()
	spot.position = Vector3(0, 5, -4)
	spot.rotation_degrees.x = -90
	spot.spot_range = 10
	spot.spot_angle = 30
	spot.spot_attenuation = 0
	spot.visible = false
	spot.add_to_group("stealth_lights")
	world.add_child(spot)
	flash = DirectionalLight3D.new()
	flash.rotation_degrees.x = -90
	flash.visible = false
	flash.add_to_group("stealth_lights")
	world.add_child(flash)
	root.add_child(world)
	guard.set_physics_process(false)


func _sense() -> void:
	sensor.refresh()
	guard.player_visible = guard.can_see_player()


func _reset_guard() -> void:
	guard.guard_state = StealthGuard.GuardState.PATROL
	guard.awareness = 0
	guard.player_visible = false
	guard._uncertain_suspicion = false
	guard._uncertain_elapsed = 0
	guard._lost_sight_elapsed = 0


func _wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	cover.add_child(body)


func _clear_cover() -> void:
	for child in cover.get_children():
		child.free()
	await physics_frame


func _check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
