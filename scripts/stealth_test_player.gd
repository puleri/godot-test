extends "res://scripts/player_controller.gd"

## The study uses an overview camera so cover and guard sightlines are legible.
@export var overview_camera_path: NodePath
var overview_camera: Camera3D


func _ready() -> void:
	super._ready()
	overview_camera = get_node(overview_camera_path) as Camera3D
	game_camera.current = false
	overview_camera.make_current()
	add_to_group("stealth_player")


func _configure_phase_1_camera() -> void:
	pass


func _update_phase_camera() -> void:
	pass


func handle_phase_1_movement(delta: float) -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := CONTROLLER_INPUT.camera_relative_direction(input, overview_camera.global_basis)
	_update_ground_plane_velocity(direction * _get_current_max_walk_speed(), direction, delta)
	return direction


func _update_facing(direction: Vector3) -> void:
	if visual_pivot != null and direction.length_squared() > 0.001:
		_set_visual_facing_yaw(atan2(-direction.z, direction.x))
