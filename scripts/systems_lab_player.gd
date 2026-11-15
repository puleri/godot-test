extends "res://scripts/exchange_player.gd"

var map_view := false


func _update_phase_camera() -> void:
	if overview_camera == null:
		return
	if map_view:
		overview_camera.size = 67
		overview_camera.global_position = Vector3(14, 36, 30)
		overview_camera.look_at(Vector3.ZERO)
	else:
		super._update_phase_camera()


func jump_to(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_focus = at
	set_interaction_locked(false)
	_update_phase_camera()
