class_name LayeredStealthGuard
extends "res://scripts/stealth_guard.gd"
## Separate illumination, recognition, uncertain sightings, sound and memory.
## Earlier levels retain StealthGuard and its original behavior.

@export var exposure_sensor_path: NodePath = ^"../../Player/ExposureSensor"
@export var has_lamp := true
@export var lamp_range := 6.0
@export var lamp_fov_degrees := 36.0
@export var lamp_height_offset := 0.0
@export_range(0.0, 60.0, 0.5) var lamp_downward_angle_degrees := 0.0
@export var hearing_range := 14.0
@export_range(0, 1) var sound_wall_transmission := 0.75
@export var close_recognition_distance := 1.25
@export var suspicion_cap := 0.35
@export var suspicion_per_second := 0.25
@export var uncertain_investigation_delay := 0.8
var recognition_strength := 0.0
var uncertain_visible := false
var uncertain_reason := "DIM FIGURE"
var visible_exposure := 0.0
var last_heard_position := Vector3.ZERO
var last_suspected_position := Vector3.ZERO
var investigation_target := Vector3.ZERO
var investigation_reason := "LAST SIGHTING"
var _sensor: StealthExposureSensor
var _uncertain_elapsed := 0.0
var _uncertain_suspicion := false


func _ready() -> void:
	super._ready()
	_sensor = get_node_or_null(exposure_sensor_path) as StealthExposureSensor
	if _sensor == null:
		push_error("%s needs a StealthExposureSensor; only close recognition remains available." % name)


func _sync_sight_light() -> void:
	if _sight_light == null:
		return
	_sight_light.visible = has_lamp
	_sight_light.global_position = global_position + Vector3.UP * (eye_height + lamp_height_offset)
	var pitch := deg_to_rad(lamp_downward_angle_degrees)
	var direction := sight_forward() * cos(pitch) - Vector3.UP * sin(pitch)
	_sight_light.look_at(_sight_light.global_position + direction, Vector3.UP)
	_sight_light.spot_range = lamp_range
	_sight_light.spot_angle = lamp_fov_degrees * 0.5


func can_see_player() -> bool:
	recognition_strength = 0.0
	visible_exposure = 0.0
	uncertain_visible = false
	if not is_instance_valid(_player):
		return false
	var eye := global_position + Vector3.UP * eye_height
	var target := _player.global_position + player_sight_offset
	var ground_distance := Vector2(target.x - eye.x, target.z - eye.z).length()
	# Contact cannot be defeated by darkness or by standing just behind a guard.
	if ground_distance <= close_recognition_distance and absf(target.y - eye.y) < 1.8 and _clear_sight(eye, target):
		recognition_strength = 1.0
		return true
	if _sensor == null:
		return false
	var points := _sensor.sample_positions()
	var seen_samples := 0
	var strongest_alignment := 0.0
	for i in points.size():
		var offset := points[i] - eye
		if offset.length() > sight_range:
			continue
		var flat := Vector3(offset.x, 0, offset.z)
		var alignment := sight_forward().dot(flat.normalized()) if flat.length_squared() > 0.001 else 1.0
		if alignment < cos(deg_to_rad(field_of_view_degrees * 0.5)) or not _clear_sight(eye, points[i]):
			continue
		seen_samples += 1
		strongest_alignment = maxf(strongest_alignment, alignment)
		if i < _sensor.sample_exposures.size():
			visible_exposure += _sensor.sample_exposures[i]
	if seen_samples == 0:
		return false
	# Occluded body samples contribute zero rather than averaging only exposed parts.
	visible_exposure /= maxi(points.size(), 1)
	if visible_exposure >= _sensor.exposed_threshold:
		var brightness := inverse_lerp(_sensor.exposed_threshold, 1, visible_exposure)
		var distance_weight := lerpf(1.0, 0.6, clampf(ground_distance / sight_range, 0, 1))
		var edge := cos(deg_to_rad(field_of_view_degrees * 0.5))
		var centrality := clampf(inverse_lerp(edge, 1, strongest_alignment), 0, 1)
		recognition_strength = lerpf(0.4, 1, brightness) * distance_weight * lerpf(0.65, 1, centrality)
		return true
	var moving := _player is CharacterBody3D and Vector2(_player.velocity.x, _player.velocity.z).length() > 0.35
	uncertain_visible = moving or visible_exposure > _sensor.hidden_threshold
	uncertain_reason = "MOVEMENT IN SHADOW" if moving else "DIM FIGURE"
	return false


func _clear_sight(eye: Vector3, point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye, point, sight_blocker_mask)
	query.exclude = [get_rid()]
	if _player is CollisionObject3D:
		query.exclude.append(_player.get_rid())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_awareness(delta: float) -> void:
	if player_visible:
		_uncertain_elapsed = 0.0
		_uncertain_suspicion = false
		_lost_sight_elapsed = 0.0
		awareness = minf(1, awareness + delta * recognition_strength / maxf(seconds_to_detect, 0.01))
		if awareness >= 1:
			_change_state(GuardState.CHASE)
		elif guard_state != GuardState.CHASE:
			_change_state(GuardState.SUSPICIOUS)
		return
	_lost_sight_elapsed += delta
	if guard_state == GuardState.CHASE:
		# Weak glimpses never update confirmed pursuit memory.
		awareness = maxf(0, awareness - delta / maxf(seconds_to_forget, 0.01))
		if _lost_sight_elapsed >= lose_sight_delay:
			_change_state(GuardState.SEARCH)
		return
	if uncertain_visible:
		if not _uncertain_suspicion:
			# A coarse location sampled once, rather than a hidden-player tracker.
			last_suspected_position = _player.global_position.snapped(Vector3(1.5, 0.5, 1.5))
		_uncertain_suspicion = true
		_uncertain_elapsed += delta
		if awareness < suspicion_cap:
			awareness = minf(suspicion_cap, awareness + delta * suspicion_per_second)
		else:
			awareness = maxf(suspicion_cap, awareness - delta / maxf(seconds_to_forget, 0.01))
		if guard_state != GuardState.SEARCH:
			_change_state(GuardState.SUSPICIOUS)
			if _uncertain_elapsed >= uncertain_investigation_delay:
				_start_investigation(last_suspected_position, uncertain_reason)
		return
	_uncertain_elapsed = 0.0
	awareness = maxf(0, awareness - delta / maxf(seconds_to_forget, 0.01))
	if guard_state == GuardState.SUSPICIOUS and awareness <= 0:
		_change_state(GuardState.SEARCH)


func hear_sound(at: Vector3, audible_radius: float, kind := "SOUND") -> bool:
	if not active or not navigation_ready or player_visible or guard_state == GuardState.CHASE:
		return false
	# Footsteps give one investigation location, not continuous homing updates.
	if kind != "BELL" and guard_state == GuardState.SEARCH:
		return false
	var reach := minf(hearing_range, audible_radius)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * eye_height, at + Vector3.UP * 0.3, sight_blocker_mask)
	query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		reach *= sound_wall_transmission
	if global_position.distance_to(at) > reach:
		return false
	last_heard_position = at
	_start_investigation(at, kind)
	return true


func _start_investigation(at: Vector3, reason: String) -> void:
	_change_state(GuardState.SEARCH)
	investigation_target = at
	investigation_reason = reason
	_search_elapsed = 0
	_search_travel_elapsed = 0
	_search_arrived = false
	_requested_destination = Vector3.INF
	_repath_remaining = 0


func _change_state(next: GuardState) -> void:
	if next == GuardState.SEARCH and guard_state != next:
		investigation_target = last_suspected_position if _uncertain_suspicion and guard_state != GuardState.CHASE else last_seen_position
		investigation_reason = uncertain_reason if _uncertain_suspicion and guard_state != GuardState.CHASE else "LAST SIGHTING"
	super._change_state(next)


func _face_position(at: Vector3, delta: float) -> void:
	super._face_position(last_suspected_position if _uncertain_suspicion and not player_visible else at, delta)


func _search(delta: float) -> void:
	_search_travel_elapsed += delta
	var distance := Vector2(investigation_target.x - global_position.x, investigation_target.z - global_position.z).length()
	if not _search_arrived:
		_navigate_to(investigation_target, walk_speed, delta)
		if distance < 0.65 or _search_travel_elapsed >= 8:
			_search_arrived = true
			_search_yaw = _heading_yaw
		return
	_stop_horizontal(delta)
	_search_elapsed += delta
	_heading_yaw = _search_yaw + sin(_search_elapsed * 1.8) * 1.1
	_set_visual_yaw(_heading_yaw + visual_forward_yaw_offset)
	if _search_elapsed >= search_seconds:
		_uncertain_suspicion = false
		_uncertain_elapsed = 0
		_change_state(GuardState.RETURN)


func _update_feedback(delta: float) -> void:
	super._update_feedback(delta)
	_last_seen_marker.global_position = Vector3(investigation_target.x, 0.06, investigation_target.z)
