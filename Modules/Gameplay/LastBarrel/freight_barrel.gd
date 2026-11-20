extends "res://scripts/barrel_interaction.gd"
## The level arbitrates interactions and owns the freight-hoist transfer.

func _process(_delta: float) -> void:
	_face_tooltip_to_camera()


func conceals(target: CharacterBody3D, observer: Node3D) -> bool:
	if not player_inside or inside_player != target:
		return false
	var moving := Vector2(target.velocity.x, target.velocity.z).length() > 0.1
	return not moving or observer.global_position.distance_to(target.global_position) > 2.2


func carry_to(positions: Array[Vector3]) -> void:
	transition_in_progress = true
	_set_player_locked(inside_player, true)
	_set_player_collision_enabled(inside_player, false)
	_set_barrel_lifted(false)
	_update_tooltip()
	var transfer := create_tween().set_trans(Tween.TRANS_SINE)
	var start := global_position
	for destination in positions:
		transfer.tween_method(_carry, start, destination, 0.7)
		start = destination
	await transfer.finished
	barrel_base_y = global_position.y
	await exit_barrel()


func _carry(at: Vector3) -> void:
	global_position = at
	inside_player.global_position = at + Vector3.UP * 0.49
