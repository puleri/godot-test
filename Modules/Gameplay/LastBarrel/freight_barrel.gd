extends "res://scripts/barrel_interaction.gd"
## The level arbitrates interactions and owns the freight-hoist transfer.

func _process(_delta: float) -> void:
	_face_tooltip_to_camera()


func conceals(target: CharacterBody3D, observer: Node3D) -> bool:
	if not player_inside or inside_player != target:
		return false
	var moving := Vector2(target.velocity.x, target.velocity.z).length() > 0.1
	return not moving or observer.global_position.distance_to(target.global_position) > 2.2


func carry_to(positions: Array[Vector3], hoist_line: MeshInstance3D) -> void:
	transition_in_progress = true
	_set_player_locked(inside_player, true)
	_set_player_collision_enabled(inside_player, false)
	_set_barrel_lifted(false)
	_update_tooltip()
	var transfer := create_tween().set_trans(Tween.TRANS_SINE)
	var start := global_position
	for destination in positions:
		transfer.tween_method(_carry.bind(hoist_line), start, destination, 0.9)
		start = destination
	await transfer.finished
	barrel_base_y = global_position.y
	await exit_barrel()


func _carry(at: Vector3, hoist_line: MeshInstance3D) -> void:
	var length := maxf(0.12, 3.55 - at.y - 1.10)
	hoist_line.scale.y = length / 2.1
	hoist_line.global_position = Vector3(at.x, 3.55 - length * 0.5, at.z)
	global_position = at
	inside_player.global_position = at + Vector3.UP * 0.49
