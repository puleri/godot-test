extends SceneTree
var checks := 0
var failures := 0
var caught := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(30).timeout.connect(func(): push_error("Pursuit checks timed out"); quit(1))
	var world := Node3D.new()
	var region := NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	nav.agent_radius = 0.4
	nav.cell_height = 0.25
	region.navigation_mesh = nav
	world.add_child(region)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.2, 30)
	collision.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(collision)
	region.add_child(floor_body)
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.49, 2.2)
	world.add_child(player)
	var route := Node3D.new()
	route.name = "Route"
	route.add_child(Marker3D.new())
	world.add_child(route)
	var guard = load("res://Characters/Hound/hound_npc.tscn").instantiate()
	guard.set_script(preload("res://scripts/stealth_guard.gd"))
	guard.player_path = NodePath("../Player")
	guard.route_path = NodePath("../Route")
	guard.sight_range = 25
	guard.field_of_view_degrees = 150
	guard.player_caught.connect(func(): caught = true)
	world.add_child(guard)
	root.add_child(world)
	guard.set_physics_process(false)
	region.bake_navigation_mesh(false)
	await physics_frame
	await physics_frame
	while NavigationServer3D.map_get_iteration_id(region.get_navigation_map()) == 0:
		await physics_frame
	guard.navigation_ready = true
	for fps in [30, 60, 120]:
		guard.guard_state = StealthGuard.GuardState.CHASE
		guard.velocity = Vector3(0, 0, guard.run_speed)
		for frame in int(fps * 0.25):
			guard._steer_toward(Vector3.RIGHT, guard.run_speed, 1.0 / fps)
		_check(guard.velocity.x > 3.0 and absf(guard.velocity.z) < 0.3, "90-degree pursuit turn redirects momentum within 0.25s at %d FPS" % fps)
		guard.velocity = Vector3(0, 0, guard.run_speed)
		for frame in int(fps * 0.25):
			guard._steer_toward(Vector3.FORWARD, guard.run_speed, 1.0 / fps)
		_check(guard.velocity.z < -1.0, "Pursuit can reverse instead of charging past at %d FPS" % fps)
	guard.guard_state = StealthGuard.GuardState.CHASE
	guard.velocity = Vector3(0, 0, guard.run_speed)
	guard._stop_horizontal(0.2)
	_check(guard.velocity.length() < 0.01, "Finishing a pursuit path brakes promptly")
	guard.guard_state = StealthGuard.GuardState.PATROL
	guard.velocity = Vector3.ZERO
	guard._heading_yaw = 0
	guard._set_visual_yaw(guard.visual_forward_yaw_offset)
	guard._steer_toward(Vector3.BACK, guard.walk_speed, 1.0 / 60)
	_check(Vector2(guard.velocity.x, guard.velocity.z).length() == 0, "Patrol still turns before walking")
	guard.guard_state = StealthGuard.GuardState.CHASE
	guard.awareness = 1
	guard.velocity = Vector3(0, 0, guard.run_speed)
	guard._heading_yaw = PI
	guard._set_visual_yaw(PI + guard.visual_forward_yaw_offset)
	guard.position = Vector3.ZERO
	for frame in 30:
		await physics_frame
		player.position.z += 4.2 / 60
		guard._physics_process(1.0 / 60)
	var corner_z: float = player.position.z
	var furthest_z: float = guard.position.z
	for frame in 180:
		await physics_frame
		player.position.x += 4.2 / 60
		guard._physics_process(1.0 / 60)
		furthest_z = maxf(furthest_z, guard.position.z)
		if caught:
			break
	_check(furthest_z < corner_z + 0.8, "Live pursuit follows a right-angle player turn without a charging overshoot")
	_check(caught, "Hound reacquires and catches a moving Rook after the sharp turn")
	print("PURSUIT STEERING: %d passed, %d failed" % [checks - failures, failures])
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
