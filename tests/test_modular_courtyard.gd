extends SceneTree

const GENERATOR = preload("res://scripts/modular_courtyard_generator.gd")
const LEVEL = preload("res://Levels/ModularCourtyard.tscn")
var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var generator = GENERATOR.new()
	var first = generator.build_layout()
	var second = generator.build_layout()
	_check(_signature(first) == _signature(second), "Same seed reproduces the layout and dressing")
	generator.layout_seed = 99
	var third = generator.build_layout()
	_check(_signature(first) != _signature(third), "Different seed changes the layout")
	first.free()
	second.free()
	third.free()
	# Regeneration preserves hand-authored siblings and packs reusable scene instances.
	var handmade := Node3D.new()
	handmade.name = "HandPlaced"
	generator.add_child(handmade)
	handmade.owner = generator
	generator.regenerate()
	generator.regenerate()
	_check(generator.get_node("HandPlaced") == handmade, "Regeneration preserves manual siblings")
	_check(generator.get_child_count() == 2, "Regeneration replaces its subtree without duplicates")
	var packed := PackedScene.new()
	_check(packed.pack(generator) == OK, "Generated children can be packed into a scene")
	var restored = packed.instantiate()
	var model = restored.get_node("Generated/Ground/Tile_0_0/Model")
	_check(model.scene_file_path.ends_with("stone_tile_block.tscn"), "Packed tiles retain their original scene reference")
	_check(restored.has_node("Generated/Ground/Tile_0_0/Collision/Shape"), "Collision survives scene packing")
	_check(restored.has_node("Generated/Markers/PlayerSpawn"), "Spawn marker survives scene packing")
	restored.free()
	generator.free()

	var level = LEVEL.instantiate()
	root.add_child(level)
	current_scene = level
	var player = level.get_node("Player")
	player.set_physics_process(false)
	for i in range(10):
		await physics_frame
	var world = root.world_3d.direct_space_state
	var ground = level.get_node("Generated/Ground")
	var continuous := true
	for tile in ground.get_children():
		var at: Vector3 = tile.global_position
		var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 8, at + Vector3.DOWN * 3)
		query.exclude = [player.get_rid()]
		var hit = world.intersect_ray(query)
		continuous = continuous and not hit.is_empty()
	_check(continuous, "Every courtyard and approach tile has a supporting collider")
	await _place(player, Vector3(0, 1, 15))
	await _walk(player, Vector3(0, 0, -4), 150)
	_check(player.position.z < 9 and player.is_on_floor(), "Player walks through the arch onto the courtyard")
	for terrace in level.get_node("Generated/Terraces").get_children():
		var rise: float = level.terrace_height
		var start: Vector3 = terrace.global_position + Vector3(0, 1, 3 + ceili(rise / 0.3) * 0.55 + 0.8)
		await _place(player, start)
		await _walk(player, Vector3(0, 0, -3), 145)
		_check(player.position.y > rise and player.is_on_floor(), "%s stairs can be climbed by walking" % terrace.name)
	await _place(player, Vector3(11, 1, 5))
	await _walk(player, Vector3(4, 0, 0), 90)
	_check(player.position.x < 13 and player.is_on_floor(), "Boundary railing keeps the player inside")
	# Largest supported stairs and grid also stay playable.
	level.width_cells = 25
	level.depth_cells = 23
	level.terrace_height = 2.4
	level.layout_seed = 7
	level.regenerate()
	for i in range(3):
		await physics_frame
	var tall = level.get_node("Generated/Terraces/WestTerrace")
	await _place(player, tall.global_position + Vector3(0, 1, 8.2))
	await _walk(player, Vector3(0, 0, -3), 205)
	_check(player.position.y > 2.4 and player.is_on_floor(), "Maximum-height terrace is walkable")
	print("Courtyard checks: %d passed, %d failed" % [checks - failures, failures])
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _place(player: CharacterBody3D, at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	await _walk(player, Vector3.ZERO, 40)


func _walk(player: CharacterBody3D, direction: Vector3, frames: int) -> void:
	for i in range(frames):
		await physics_frame
		player.velocity.x = direction.x
		player.velocity.z = direction.z
		player.velocity.y -= 24.0 / 60.0
		player.move_and_slide()


func _signature(node: Node) -> String:
	var result := str(node.name)
	if node is Node3D:
		result += str(node.transform)
	for child in node.get_children():
		result += _signature(child)
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)
