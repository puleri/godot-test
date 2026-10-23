extends SceneTree

const CONNECTOR = preload("res://scripts/level_connector.gd")
const DEMO = preload("res://Levels/ConnectorKitDemo.tscn")
const COURTYARD = preload("res://Levels/ModularCourtyard.tscn")
const KINDS := ["Straight", "Corner", "TJunction", "Staircase", "Bridge"]
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Try every source port under rotated/transformed parents, including the upper stair port.
	var source_parent := Node3D.new()
	source_parent.position = Vector3(-3, 4, 7)
	source_parent.rotation.y = 0.35
	var target_parent := Node3D.new()
	target_parent.position = Vector3(12, -2, -11)
	target_parent.rotation.y = -0.6
	var target := Marker3D.new()
	target_parent.add_child(target)
	target.position = Vector3(5, 3, -6)
	target.rotation.y = 1.12
	target.set_meta("level_connection", true)
	target.set_meta("width", 6.0)
	for kind in KINDS:
		var module = load("res://Modules/Connectors/%s.tscn" % kind).instantiate()
		source_parent.add_child(module)
		var all_aligned := true
		for marker in module.get_node("Connections").get_children():
			module.position = Vector3(9, 2, -8)
			module.rotation.y = 0.75
			all_aligned = all_aligned and module.connect_to(marker.name, target)
			var actual: Transform3D = CONNECTOR.world_transform(marker)
			var expected: Transform3D = CONNECTOR.world_transform(target)
			all_aligned = all_aligned and actual.origin.distance_to(expected.origin) < 0.0001
			all_aligned = all_aligned and actual.basis.z.dot(expected.basis.z) < -0.9999
			all_aligned = all_aligned and actual.basis.y.dot(expected.basis.y) > 0.9999
		_check(all_aligned, "%s ports align in position, opposite facing and height" % kind)
		module.free()
	source_parent.free()
	target_parent.free()

	var court = COURTYARD.instantiate()
	var bridge = load("res://Modules/Connectors/Bridge.tscn").instantiate()
	var entrance = court.get_node("Generated/Connections/Entrance")
	_check(bridge.connect_to("South", entrance), "Connectors attach to the courtyard's entrance marker")
	var source: Transform3D = CONNECTOR.world_transform(bridge.get_connection("South"))
	var destination: Transform3D = CONNECTOR.world_transform(entrance)
	_check(source.origin.distance_to(destination.origin) < 0.0001, "Courtyard connection has no position or elevation gap")
	bridge.free()
	court.free()

	var level = DEMO.instantiate()
	root.add_child(level)
	current_scene = level
	var player: CharacterBody3D = level.get_node("Player")
	player.set_physics_process(false)
	for i in range(8):
		await physics_frame
	var modules = level.get_node("Generated/Modules")
	_check(modules.get_node("EntryWalk").scene_file_path.ends_with("Straight.tscn") and modules.get_node("UpperWalk").scene_file_path.ends_with("Straight.tscn"), "Demo reuses the same straight scene at two elevations")
	_check(is_equal_approx(modules.get_node("UpperWalk").position.y, 2.0), "Staircase places the upper walkway exactly 2 meters higher")
	var plank = _find_plank_mesh(modules.get_node("Bridge"))
	_check(plank != null and plank.material_override != null and plank.material_override.resource_path.ends_with("NewToon-WoodPlank.tres"), "Wood material survives saving and loading the bridge")
	var seams_ok := true
	for module in modules.get_children():
		for marker in module.get_node("Connections").get_children():
			var outward: Vector3 = -marker.global_basis.z
			for offset in [-0.25, 0.0, 0.25]:
				var at: Vector3 = marker.global_position + outward * offset
				var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, at + Vector3.DOWN)
				ray.exclude = [player.get_rid()]
				var hit = root.world_3d.direct_space_state.intersect_ray(ray)
				seams_ok = seams_ok and not hit.is_empty()
				if not hit.is_empty():
					seams_ok = seams_ok and absf(hit.position.y - marker.global_position.y) < 0.02
	_check(seams_ok, "Every assembled connection has continuous collision on both sides")

	await _place(player, Vector3(0, 1, 3))
	await _walk(player, Vector3(0, 0, -4), 210)
	_check(player.position.distance_to(Vector3(0, 0.48, -11)) < 0.3 and player.is_on_floor(), "Walk from the start across the straight into the T-junction")
	await _walk(player, Vector3(-4, 0, 0), 90)
	await _walk(player, Vector3(0, 0, -4), 270)
	_check(player.position.z < -28 and player.position.y > 0 and player.is_on_floor(), "Turn through the corner and cross the wooden bridge to the lower court")
	await _place(player, Vector3(0, 1, -11))
	await _walk(player, Vector3(4, 0, 0), 350)
	_check(player.position.x > 22 and player.position.y > 2 and player.is_on_floor(), "Walk up the stairs, over the upper join and into the raised court")
	await _walk(player, Vector3(-4, 0, 0), 350)
	_check(player.position.x < 1 and player.position.y < 0.6 and player.is_on_floor(), "Walk back down the staircase without falling or jumping")
	await _place(player, Vector3(-6, 1, -20))
	await _walk(player, Vector3(-4, 0, 0), 90)
	_check(player.position.x > -9 and player.is_on_floor(), "Bridge railing blocks walking off the side")
	print("Connector checks: %d passed, %d failed" % [checks - failures, failures])
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _find_plank_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == "WoodPlanks":
		return node
	for child in node.get_children():
		var found := _find_plank_mesh(child)
		if found != null:
			return found
	return null


func _place(player: CharacterBody3D, at: Vector3) -> void:
	player.position = at
	player.velocity = Vector3.ZERO
	await _walk(player, Vector3.ZERO, 40)


func _walk(player: CharacterBody3D, direction: Vector3, frames: int) -> void:
	for i in range(frames):
		await physics_frame
		player.velocity.x = direction.x
		player.velocity.z = direction.z
		player.velocity.y -= 24.0 / 60.0
		player.move_and_slide()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
