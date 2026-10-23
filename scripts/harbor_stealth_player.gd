extends "res://scripts/stealth_test_player.gd"
## Close overview for play; M reveals the connected layout without changing controls.

var map_view := false
var _focus := Vector3.ZERO
const CAMERA_OFFSET := Vector3(17, 24, 23)


func _ready() -> void:
	super._ready()
	_focus = global_position
	_update_phase_camera()


func _update_phase_camera() -> void:
	if overview_camera == null:
		return
	if map_view:
		_focus = Vector3(0, 0, -2)
		overview_camera.size = 58
	else:
		var weight := 1.0 - exp(-7.0 * get_physics_process_delta_time())
		_focus = _focus.lerp(Vector3(global_position.x, 0, global_position.z), weight)
		overview_camera.size = 21
	# Both modes use the same orientation, keeping camera-relative input stable.
	overview_camera.global_position = _focus + CAMERA_OFFSET
	overview_camera.look_at(_focus)


func toggle_map() -> void:
	map_view = not map_view
	if not map_view:
		_focus = Vector3(global_position.x, 0, global_position.z)
	_update_phase_camera()
