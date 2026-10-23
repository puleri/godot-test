extends "res://scripts/player_controller.gd"
## Camera-relative controls for the generated courtyard; retains the Rook animations.

var overview: Camera3D
var _spawn := Vector3.ZERO
var _close_camera := false


func _ready() -> void:
	super._ready()
	overview = get_parent().get_node("OverviewCamera") as Camera3D
	game_camera.current = false
	overview.make_current()
	_spawn = get_parent().get_node("Generated/Markers/PlayerSpawn").global_position
	global_position = _spawn
	frame_camera()


func _configure_phase_1_camera() -> void:
	pass


func _update_phase_camera() -> void:
	if _close_camera:
		overview.global_position = global_position + Vector3(12, 15, 17)
		overview.look_at(global_position)


func frame_camera() -> void:
	var generated := get_parent().get_node("Generated")
	var focus: Vector3 = generated.get_node("Markers/CameraFocus").global_position
	overview.global_position = focus + Vector3(24, 32, 36)
	overview.look_at(focus)
	overview.size = float(generated.get_meta("camera_size", 36.0))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.physical_keycode == KEY_R:
		global_position = _spawn
		velocity = Vector3.ZERO
	elif event.physical_keycode == KEY_TAB:
		_close_camera = not _close_camera
		if _close_camera:
			overview.size = 16
		else:
			frame_camera()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if global_position.y < -8:
		global_position = _spawn
		velocity = Vector3.ZERO


func handle_phase_1_movement(delta: float) -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := overview.global_basis.x
	var forward := -overview.global_basis.z
	right.y = 0
	forward.y = 0
	var direction := (right.normalized() * input.x - forward.normalized() * input.y).limit_length()
	_update_ground_plane_velocity(direction * max_walk_speed, direction, delta)
	return direction


func _update_facing(direction: Vector3) -> void:
	if visual_pivot != null and direction.length_squared() > 0.001:
		_set_visual_facing_yaw(atan2(-direction.z, direction.x))
