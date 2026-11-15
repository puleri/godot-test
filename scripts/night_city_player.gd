extends "res://scripts/exchange_player.gd"
## Follow Rook's elevation so upper streets remain framed like the quays.

func _update_phase_camera() -> void:
	if overview_camera == null:
		return
	var target := global_position + Vector3(velocity.x, 0, velocity.z) * 0.24
	_focus = _focus.lerp(target, 1.0 - exp(-7.0 * get_physics_process_delta_time()))
	overview_camera.size = follow_size
	overview_camera.global_position = _focus + CAMERA_OFFSET
	overview_camera.look_at(_focus)
