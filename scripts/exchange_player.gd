extends "res://scripts/stealth_test_player.gd"
## A stable, close orthographic view with gentle following and movement lead.

signal noise_emitted(at: Vector3, audible_radius: float, kind: String)

@export var walking_noise_radius := 5.0
@export var quiet_noise_radius := 1.6
@export var landing_noise_radius := 7.5
var _step_distance := 0.0
var _air_time := 0.0

@export var follow_size := 9.4
var _focus := Vector3.ZERO
const CAMERA_OFFSET := Vector3(12, 23, 19)


func _ready() -> void:
	super._ready()
	_focus = global_position
	_update_phase_camera()


func _update_phase_camera() -> void:
	if overview_camera == null:
		return
	var lead := Vector3(velocity.x, 0, velocity.z) * 0.24
	var target := Vector3(global_position.x, 0.3, global_position.z) + lead
	_focus = _focus.lerp(target, 1.0 - exp(-6.5 * get_physics_process_delta_time()))
	overview_camera.size = follow_size
	overview_camera.global_position = _focus + CAMERA_OFFSET
	overview_camera.look_at(_focus)


func _physics_process(delta: float) -> void:
	var before := global_position
	super._physics_process(delta)
	if interaction_locked:
		return
	if not is_on_floor():
		_air_time += delta
		return
	if _air_time > 0.15:
		noise_emitted.emit(global_position, landing_noise_radius, "LANDING")
	_air_time = 0.0
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved < 0.001:
		_step_distance = 0
		return
	_step_distance += moved
	if _step_distance >= 1.2:
		_step_distance = fmod(_step_distance, 1.2)
		var quiet := Input.is_physical_key_pressed(KEY_SHIFT)
		noise_emitted.emit(global_position, quiet_noise_radius if quiet else walking_noise_radius, "FOOTSTEPS")
