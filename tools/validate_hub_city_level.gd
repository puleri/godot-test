extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var packed = load("res://Levels/HubCityFoliage.tscn")
	assert(packed is PackedScene)
	var level = packed.instantiate()
	root.add_child(level)
	current_scene = level
	var player: CharacterBody3D = level.get_node("Player")
	var sailboats = level.get_node("City").find_children("Sailboat*", "MeshInstance3D", true, false)
	assert(sailboats.size() == 1, "Expected a separate lagoon sailboat")
	var sailboat: Node3D = sailboats[0]
	var boat_start := sailboat.position
	for i in range(120):
		await physics_frame
	assert(player.is_on_floor(), "Rook did not settle on the civic square")
	assert(sailboat.position.distance_to(boat_start) > 0.05, "Lagoon sailboat is not moving")
	print("SAILBOAT_MOTION_PASS")
	# Reproduce the near-wall camera obstruction that previously collapsed the view.
	var obstruction := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45,0.45,0.45)
	collision.shape = box
	obstruction.add_child(collision)
	level.add_child(obstruction)
	var focus := player.global_position + Vector3.UP * 0.7
	obstruction.global_position = focus + Vector3(0,5,7).normalized() * 0.6
	for i in range(3):
		await physics_frame
	var camera: Camera3D = level.get_node("LevelCamera")
	assert(camera.global_position.distance_to(focus) >= 2.0, "Camera collapsed into Rook near a wall")
	assert(camera.is_position_in_frustum(focus), "Camera lost sight of Rook")
	print("CAMERA_OBSTRUCTION_PASS distance=",camera.global_position.distance_to(focus))
	obstruction.queue_free()
	for i in range(5):
		await physics_frame
	var before := player.global_position
	Input.action_press("move_right")
	for i in range(60):
		await physics_frame
	Input.action_release("move_right")
	var distance := player.global_position.distance_to(before)
	print("MOVEMENT_DEBUG ",before," to ",player.global_position," distance=",distance)
	assert(distance > 1.0, "Rook movement is blocked")
	player.global_position = Vector3(51.95128,19.5,-53.18629)
	player.velocity = Vector3.ZERO
	for i in range(90):
		await physics_frame
	assert(player.is_on_floor(), "Rook did not settle on stair ramp")
	var stair_start := player.global_position
	Input.action_press("move_right")
	for i in range(60):
		await physics_frame
	Input.action_release("move_right")
	assert(player.global_position.x-stair_start.x > 2.0, "Stair traversal blocked")
	assert(player.global_position.y-stair_start.y > 0.3, "Rook failed to climb stairs")
	print("STAIR_CLIMB_PASS rise=",player.global_position.y-stair_start.y)
	player.respawn()
	for i in range(90):
		await physics_frame
	assert(player.is_on_floor())
	assert(level.get_node("LevelCamera").current)
	assert(level.get_node("Foliage").instance_count > 100)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art/HubCityMaster/hub_city_rook_gameplay.png")
	print("HUB_LEVEL_PASS floor=",player.is_on_floor()," movement_m=",distance," spawn=",player.global_position," camera=current foliage=",level.get_node("Foliage").instance_count)
	quit(0)
