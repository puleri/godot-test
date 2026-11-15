extends "res://scripts/systems_lab_guard.gd"
## Explicit concealment plus a close-range tracker profile; no shared AI changes.
@export var tracker := false
@export var tracking_radius := 2.6


func can_see_player() -> bool:
	if not is_instance_valid(_player):
		return super.can_see_player()
	var distance := global_position.distance_to(_player.global_position)
	if tracker and distance < tracking_radius and _clear_sight(global_position + Vector3.UP * eye_height, _player.global_position + player_sight_offset):
		recognition_strength = 1.0
		uncertain_visible = false
		visible_exposure = 0
		return true
	if _player.concealed and not _player.peeking:
		recognition_strength = 0
		uncertain_visible = false
		visible_exposure = 0
		# Ordinary guards still recognize contact; hiding is not invulnerability.
		if distance > close_recognition_distance:
			return false
	return super.can_see_player()
