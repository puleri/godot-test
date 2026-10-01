class_name NPCController
extends CharacterBody3D

enum RouteMode { ORDERED, RANDOM_OTHER }
enum State { IDLE, MOVING }

@export var route_path: NodePath
@export var route_mode: RouteMode = RouteMode.ORDERED
@export var walk_speed := 0.8
@export var run_speed := 1.2
@export var gravity := 24.0
@export var acceleration := 3.5
@export var braking := 6.0
@export var turn_speed := 8.0
@export_range(0.0, PI, 0.01) var move_after_turn_angle := 0.12
@export var visual_pivot_path: NodePath = ^"VisualPivot"
# Rotates the source asset's authored forward axis into Godot's -Z forward.
# Hound (+X forward) uses PI / 2; Mouse (+Z forward) uses PI.
@export var visual_forward_yaw_offset := 0.0
@export var arrival_radius := 0.12
@export var pause_min_seconds := 1.0
@export var pause_max_seconds := 2.0
@export var start_delay_seconds := 0.0
@export var locomotion_uses_run := false
@export_range(0.0, 1.0, 0.01) var alert_chance_on_arrival := 0.0
@export var random_seed := 0
@export var stuck_timeout_seconds := 1.5
@export var ground_probe_distance := 0.55
@export var ground_mask := 1
@export var animation_driver_path: NodePath = ^"AnimationDriver"

var _route: Node3D
var _points: Array[Marker3D] = []
var _state := State.IDLE
var _target_index := -1
var _pause_remaining := 0.0
var _stuck_elapsed := 0.0
var _last_target_distance := INF
var _stuck_progress := 0.0
var _heading_yaw := 0.0
var _last_visual_yaw := 0.0
var _rng := RandomNumberGenerator.new()
var _warned_route := false
@onready var _animation_driver := get_node_or_null(animation_driver_path) as NPCAnimationDriver
@onready var _visual_pivot := get_node_or_null(visual_pivot_path) as Node3D


func _ready() -> void:
	add_to_group("npcs")
	_rng.seed = random_seed if random_seed != 0 else hash(get_path())
	_heading_yaw = global_rotation.y
	_last_visual_yaw = _heading_yaw + visual_forward_yaw_offset
	_route = get_node_or_null(route_path) as Node3D
	_collect_points()
	# Keep the physics body heading in world space and apply the source-model
	# correction only to the visual child. Animation tracks cannot overwrite it.
	_set_visual_yaw(_last_visual_yaw)
	_pause_remaining = maxf(0.0, start_delay_seconds)
	if _points.is_empty():
		_warn_route("has no valid Marker3D route points; it will remain idle.")
		return
	if _points.size() == 1:
		_target_index = 0
	else:
		_choose_next_target()


func _physics_process(delta: float) -> void:
	var previous_position := global_position
	_apply_gravity(delta)

	if _points.size() == 1:
		_move_to_single_point(delta)
	elif _points.size() > 1:
		_update_route(delta)
	else:
		_stop_horizontal(delta)

	move_and_slide()
	var resolved_velocity: Vector3 = (global_position - previous_position) / maxf(delta, 0.0001)
	var horizontal_speed: float = Vector2(resolved_velocity.x, resolved_velocity.z).length()
	if horizontal_speed > 0.001:
		_update_visual_facing(Vector3(resolved_velocity.x, 0.0, resolved_velocity.z), delta)
	else:
		# Animation and pre-turning must never alter a stationary actor's last
		# valid world-space facing direction.
		_set_visual_yaw(_last_visual_yaw)
	if _animation_driver != null:
		_animation_driver.set_resolved_motion(horizontal_speed, locomotion_uses_run, delta)


func _update_route(delta: float) -> void:
	if _pause_remaining > 0.0:
		_pause_remaining -= delta
		_state = State.IDLE
		_stop_horizontal(delta)
		return
	if _target_index < 0 or _target_index >= _points.size():
		_choose_next_target()
		return

	var target := _points[_target_index].global_position
	var to_target := target - global_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= arrival_radius:
		if Vector2(velocity.x, velocity.z).length() <= 0.04:
			_arrive()
		else:
			_stop_horizontal(delta)
		return
	if not _has_ground_ahead(to_target.normalized()):
		_recover_from_blockage()
		return

	_state = State.MOVING
	var braking_distance := maxf(distance - arrival_radius, 0.0)
	var desired_speed := minf(_current_speed(), sqrt(2.0 * braking * braking_distance))
	_steer_toward(to_target.normalized(), desired_speed, delta)
	_stuck_progress += maxf(_last_target_distance - distance, 0.0) if is_finite(_last_target_distance) else 0.0
	_stuck_elapsed += delta
	_last_target_distance = distance
	if _stuck_elapsed >= stuck_timeout_seconds:
		if _stuck_progress < 0.06 and Vector2(velocity.x, velocity.z).length() > 0.05:
			_recover_from_blockage()
		else:
			_stuck_elapsed = 0.0
			_stuck_progress = 0.0


func _move_to_single_point(delta: float) -> void:
	var to_target := _points[0].global_position - global_position
	to_target.y = 0.0
	if to_target.length() <= arrival_radius or not _has_ground_ahead(to_target.normalized()):
		_stop_horizontal(delta)
		_state = State.IDLE
		return
	_state = State.MOVING
	_steer_toward(to_target.normalized(), minf(_current_speed(), to_target.length() * 3.0), delta)


func _arrive() -> void:
	_state = State.IDLE
	_pause_remaining = _rng.randf_range(minf(pause_min_seconds, pause_max_seconds), maxf(pause_min_seconds, pause_max_seconds))
	if _animation_driver != null and _rng.randf() < alert_chance_on_arrival:
		_animation_driver.play_alert()
	_stuck_elapsed = 0.0
	_stuck_progress = 0.0
	_last_target_distance = INF
	_choose_next_target()


func _recover_from_blockage() -> void:
	_stop_horizontal(0.2)
	_state = State.IDLE
	_pause_remaining = maxf(0.25, _rng.randf_range(pause_min_seconds, pause_max_seconds))
	_stuck_elapsed = 0.0
	_stuck_progress = 0.0
	_last_target_distance = INF
	_choose_next_target()


func _choose_next_target() -> void:
	if _points.size() <= 1:
		return
	if route_mode == RouteMode.ORDERED:
		_target_index = (_target_index + 1) % _points.size()
		return
	var candidates: Array[int] = []
	for index in _points.size():
		if index != _target_index:
			candidates.append(index)
	_target_index = candidates[_rng.randi_range(0, candidates.size() - 1)]


func _collect_points() -> void:
	if _route == null:
		return
	for child in _route.get_children():
		if child is Marker3D:
			_points.append(child)


func _has_ground_ahead(direction: Vector3) -> bool:
	if direction.length_squared() < 0.001:
		return true
	var from := global_position + Vector3.UP * 0.2 + direction * ground_probe_distance
	var to := from + Vector3.DOWN * 1.4
	var query := PhysicsRayQueryParameters3D.create(from, to, ground_mask)
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1


func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, braking * delta)
	velocity.z = move_toward(velocity.z, 0.0, braking * delta)


func _steer_toward(direction: Vector3, speed: float, delta: float) -> void:
	# Turn before applying a new horizontal velocity. This avoids preserving the
	# previous leg of a route while the model is already visibly facing the next.
	var turn_complete := _turn_heading_toward(direction, delta)
	if not turn_complete:
		_stop_horizontal(delta)
		return
	var desired := direction * speed
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)


func _turn_heading_toward(direction: Vector3, delta: float) -> bool:
	var desired_yaw := atan2(-direction.x, -direction.z)
	# The capsule is rotationally symmetric, so keep the body transform fixed.
	# A separate world-space heading gates movement until the next route leg is
	# aligned; only resolved movement is allowed to turn the visual pivot.
	_heading_yaw = rotate_toward(_heading_yaw, desired_yaw, turn_speed * delta)
	var visual_target := _heading_yaw + visual_forward_yaw_offset
	_set_visual_yaw(rotate_toward(_last_visual_yaw, visual_target, turn_speed * delta))
	return absf(angle_difference(_heading_yaw, desired_yaw)) <= move_after_turn_angle and absf(angle_difference(_last_visual_yaw, visual_target)) <= move_after_turn_angle


func _update_visual_facing(resolved_direction: Vector3, delta: float) -> void:
	if resolved_direction.length_squared() < 0.000001:
		return
	var desired_yaw := atan2(-resolved_direction.x, -resolved_direction.z) + visual_forward_yaw_offset
	_set_visual_yaw(rotate_toward(_last_visual_yaw, desired_yaw, turn_speed * delta))


func _set_visual_yaw(yaw: float) -> void:
	if _visual_pivot == null:
		return
	_last_visual_yaw = yaw
	# `yaw` is world-space. The pivot is a child of the collision body, so write
	# the matching local yaw rather than mixing a global Euler angle with local
	# animation transforms below it.
	var local_rotation := _visual_pivot.rotation
	local_rotation.y = yaw - global_rotation.y
	_visual_pivot.rotation = local_rotation


func _current_speed() -> float:
	return run_speed if locomotion_uses_run else walk_speed


func _warn_route(problem: String) -> void:
	if _warned_route:
		return
	_warned_route = true
	push_warning("NPC '%s' %s" % [name, problem])
