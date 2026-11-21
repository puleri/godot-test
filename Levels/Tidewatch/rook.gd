extends "res://scripts/exchange_player.gd"
## Side-plane adapter for the shared exchange controller and its footstep events.

const LeanDoor = preload("res://Levels/Tidewatch/door.gd")
const SHUTTER_REACH := 0.38

var facing := 1.0
var lean_door: LeanDoor
var leaning: bool:
	get:
		return lean_door != null
var lean_reach := 0.0
var _pivot_home: Vector3


func _ready() -> void:
	_pivot_home = $VisualPivot.position
	# Resolve Rook's movement intent before the level updates the shutters.
	process_physics_priority = -1
	super._ready()


func handle_phase_1_movement(delta: float) -> Vector3:
	var axis := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(axis):
		facing = signf(axis)
	lean_door = _shutter_ahead(axis)
	var direction := Vector3.RIGHT * axis
	_update_phase_1_ground_velocity(Vector3.ZERO if leaning else direction, delta)
	velocity.z = 0.0
	return Vector3.RIGHT * facing if leaning else direction


func _shutter_ahead(axis: float) -> LeanDoor:
	if is_zero_approx(axis) or not is_on_floor() or Input.is_action_just_pressed("jump"):
		return null
	var shoulder := global_position + Vector3.UP * 0.35
	var end := shoulder + Vector3.RIGHT * signf(axis) * SHUTTER_REACH
	var ray := PhysicsRayQueryParameters3D.create(shoulder, end, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var panel := hit.get("collider") as StaticBody3D
	if panel == null:
		return null
	var door := panel.get_parent() as LeanDoor
	return door if door != null and door.opens_on_lean and not door.opened else null


func _physics_process(delta: float) -> void:
	if interaction_locked:
		lean_door = null
	super._physics_process(delta)
	var reach := 0.44 * facing if leaning else 0.0
	if leaning:
		# Keep the head and shot origin on this side of solid geometry.
		var head := global_position + Vector3.UP * 0.63
		var ray := PhysicsRayQueryParameters3D.create(head, head + Vector3.RIGHT * reach, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			reach = facing * maxf(0.0, head.distance_to(hit.position) - 0.12)
	lean_reach = move_toward(lean_reach, reach, delta * 3.6)
	visual_pivot.position.x = _pivot_home.x + lean_reach * 0.48
	visual_pivot.rotation.z = -lean_reach * 0.58 * cos(visual_pivot.rotation.y)
	$ExposureSensor.position.x = lean_reach


func _update_phase_camera() -> void:
	if overview_camera == null:
		return
	var lead := facing * 2.9 if leaning else clampf(velocity.x * 0.25, -1.1, 1.1) + 0.8
	var target := Vector3(clampf(position.x + lead, -0.8, 35.5), 1.67 + maxf(position.y - 0.5, 0) * 0.18, 0)
	_focus = _focus.lerp(target, 1.0 - exp(-6.5 * get_physics_process_delta_time()))
	overview_camera.position = _focus + Vector3(0, 2.4, 14)
	overview_camera.look_at(_focus)
