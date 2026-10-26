class_name StealthGuard
extends "res://scripts/npc_controller.gd"

## Opt-in guard for the stealth study. Ambient NPCs keep their original controller.
signal player_caught

enum GuardState { PATROL, SUSPICIOUS, CHASE, SEARCH, RETURN }
const SELF_LIGHT_LAYER := 1 << 19

@export var player_path: NodePath
@export var sight_range := 7.0
@export_range(1.0, 179.0) var field_of_view_degrees := 80.0
@export var eye_height := 0.75
@export var player_sight_offset := Vector3(0.0, 0.5, 0.0)
@export_flags_3d_physics var sight_blocker_mask := 1
@export var seconds_to_detect := 1.1
@export var seconds_to_forget := 2.0
@export var lose_sight_delay := 0.65
@export var search_seconds := 4.0
@export var capture_distance := 0.9
@export var navigation_height_offset := 0.5
@export var show_vision := true
@export var sight_light_path: NodePath = ^"SightLight"

var guard_state := GuardState.PATROL
var awareness := 0.0
var player_visible := false
var last_seen_position := Vector3.ZERO
var navigation_ready := false
var active := true
var _player: Node3D
var _agent: NavigationAgent3D
var _lost_sight_elapsed := 0.0
var _search_elapsed := 0.0
var _search_travel_elapsed := 0.0
var _search_arrived := false
var _search_yaw := 0.0
var _repath_remaining := 0.0
var _requested_destination := Vector3.INF
var _vision_mesh: ImmediateMesh
var _vision_instance: MeshInstance3D
var _vision_material: StandardMaterial3D
var _vision_refresh := 0.0
var _state_label: Label3D
var _last_seen_marker: MeshInstance3D
var _sight_light: SpotLight3D


func _ready() -> void:
	add_to_group("stealth_guards")
	super._ready()
	_player = get_node_or_null(player_path) as Node3D
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.3
	_agent.target_desired_distance = 0.35
	# Recast's voxelized surface sits above the visible floor. Match its points
	# to this foot-origin character, or the first waypoint is never reached.
	_agent.path_height_offset = navigation_height_offset
	_agent.path_max_distance = 1.2
	add_child(_agent)
	_build_feedback()
	_sight_light = get_node_or_null(sight_light_path) as SpotLight3D
	if _sight_light != null:
		# Keep the eye-origin light from casting the Hound's own head across its
		# entire beam. Other lights still cast the Hound's shadow normally.
		_sight_light.shadow_caster_mask &= ~SELF_LIGHT_LAYER
		if _visual_pivot != null:
			for geometry in _visual_pivot.find_children("*", "GeometryInstance3D", true, false):
				(geometry as GeometryInstance3D).layers = SELF_LIGHT_LAYER
	_sync_sight_light()


func _physics_process(delta: float) -> void:
	if not active or not navigation_ready:
		return
	var previous_position := global_position
	_apply_gravity(delta)
	player_visible = can_see_player()
	if player_visible:
		last_seen_position = _player.global_position
	_update_awareness(delta)
	_repath_remaining -= delta

	match guard_state:
		GuardState.PATROL:
			_update_route(delta)
		GuardState.SUSPICIOUS:
			_stop_horizontal(delta)
			_face_position(last_seen_position, delta)
		GuardState.CHASE:
			# The destination changes only on a confirmed sighting.
			_navigate_to(last_seen_position, run_speed, delta)
			if player_visible and global_position.distance_to(_player.global_position) <= capture_distance:
				active = false
				player_caught.emit()
		GuardState.SEARCH:
			_search(delta)
		GuardState.RETURN:
			_return_to_patrol(delta)

	move_and_slide()
	var resolved := (global_position - previous_position) / maxf(delta, 0.0001)
	var speed := Vector2(resolved.x, resolved.z).length()
	if speed > 0.001:
		_update_visual_facing(Vector3(resolved.x, 0.0, resolved.z), delta)
	if _animation_driver != null:
		_animation_driver.set_resolved_motion(speed, guard_state == GuardState.CHASE, delta)
	_update_feedback(delta)


func can_see_player() -> bool:
	if not is_instance_valid(_player):
		return false
	var eye := global_position + Vector3.UP * eye_height
	var target := _player.global_position + player_sight_offset
	var offset := target - eye
	if offset.length() > sight_range:
		return false
	# Project the angle test onto the ground; the ray still checks actual height.
	var flat_offset := Vector3(offset.x, 0.0, offset.z)
	if flat_offset.length_squared() > 0.001:
		var threshold := cos(deg_to_rad(field_of_view_degrees * 0.5))
		if sight_forward().dot(flat_offset.normalized()) < threshold:
			return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, sight_blocker_mask)
	query.exclude = [get_rid()]
	if _player is CollisionObject3D:
		query.exclude.append((_player as CollisionObject3D).get_rid())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func sight_forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, _last_visual_yaw - visual_forward_yaw_offset)


func _update_awareness(delta: float) -> void:
	if player_visible:
		_lost_sight_elapsed = 0.0
		awareness = minf(1.0, awareness + delta / maxf(seconds_to_detect, 0.01))
		if awareness >= 1.0:
			_change_state(GuardState.CHASE)
		elif guard_state != GuardState.CHASE:
			_change_state(GuardState.SUSPICIOUS)
	else:
		_lost_sight_elapsed += delta
		awareness = maxf(0.0, awareness - delta / maxf(seconds_to_forget, 0.01))
		if guard_state == GuardState.CHASE and _lost_sight_elapsed >= lose_sight_delay:
			_change_state(GuardState.SEARCH)
		elif guard_state == GuardState.SUSPICIOUS and awareness <= 0.0:
			_change_state(GuardState.SEARCH)


func _change_state(next: GuardState) -> void:
	if guard_state == next:
		return
	guard_state = next
	_repath_remaining = 0.0
	_requested_destination = Vector3.INF
	if next == GuardState.SEARCH:
		_search_elapsed = 0.0
		_search_travel_elapsed = 0.0
		_search_arrived = false
	if next == GuardState.SUSPICIOUS and _animation_driver != null:
		_animation_driver.play_alert()


func _navigate_to(destination: Vector3, speed: float, delta: float) -> void:
	if _repath_remaining <= 0.0 and _requested_destination.distance_squared_to(destination) > 0.04:
		var surface := NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), destination)
		_agent.target_position = surface - Vector3.UP * navigation_height_offset
		_requested_destination = destination
		_repath_remaining = 0.2
	var next_position := _agent.get_next_path_position()
	if _agent.is_navigation_finished():
		_stop_horizontal(delta)
		return
	var direction := next_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001 or not _has_ground_ahead(direction.normalized()):
		_stop_horizontal(delta)
		return
	_steer_toward(direction.normalized(), speed, delta)


func _search(delta: float) -> void:
	_search_travel_elapsed += delta
	var distance := Vector2(last_seen_position.x - global_position.x, last_seen_position.z - global_position.z).length()
	if not _search_arrived:
		_navigate_to(last_seen_position, walk_speed, delta)
		# A bounded travel time also handles a last sighting on an unreachable ledge.
		if distance < 0.65 or _search_travel_elapsed >= 8.0:
			_search_arrived = true
			_search_yaw = _heading_yaw
		return
	_stop_horizontal(delta)
	_search_elapsed += delta
	_heading_yaw = _search_yaw + sin(_search_elapsed * 1.8) * 1.1
	_set_visual_yaw(_heading_yaw + visual_forward_yaw_offset)
	if _search_elapsed >= search_seconds:
		_change_state(GuardState.RETURN)


func _return_to_patrol(delta: float) -> void:
	if _points.is_empty():
		_stop_horizontal(delta)
		_change_state(GuardState.PATROL)
		return
	_target_index = clampi(_target_index, 0, _points.size() - 1)
	var destination := _points[_target_index].global_position
	_navigate_to(destination, walk_speed, delta)
	if global_position.distance_to(destination) < 0.65:
		_pause_remaining = 0.5
		_stuck_elapsed = 0.0
		_stuck_progress = 0.0
		_last_target_distance = INF
		_change_state(GuardState.PATROL)


func _face_position(position_to_face: Vector3, delta: float) -> void:
	var direction := position_to_face - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		_turn_heading_toward(direction.normalized(), delta)


func state_name() -> String:
	return ["PATROLLING", "SUSPICIOUS", "PURSUING", "SEARCHING", "RETURNING"][guard_state]


func state_color() -> Color:
	if guard_state == GuardState.CHASE:
		return Color("ff7468")
	if guard_state == GuardState.SUSPICIOUS:
		return Color("ffca76")
	if guard_state == GuardState.SEARCH:
		return Color("adabff")
	return Color("7cc9d2")


func _build_feedback() -> void:
	_vision_mesh = ImmediateMesh.new()
	_vision_material = StandardMaterial3D.new()
	_vision_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_vision_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vision_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_vision_instance = MeshInstance3D.new()
	_vision_instance.mesh = _vision_mesh
	_vision_instance.top_level = true
	add_child(_vision_instance)
	_vision_instance.global_transform = Transform3D.IDENTITY
	_state_label = Label3D.new()
	_state_label.position.y = 1.55
	_state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_state_label.font_size = 32
	_state_label.pixel_size = 0.008
	_state_label.outline_size = 8
	add_child(_state_label)
	_last_seen_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.28
	ring.outer_radius = 0.34
	_last_seen_marker.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("adabff")
	_last_seen_marker.material_override = material
	_last_seen_marker.top_level = true
	add_child(_last_seen_marker)
	_last_seen_marker.visible = false


func _update_feedback(delta: float) -> void:
	_sync_sight_light()
	_state_label.text = state_name()
	_state_label.modulate = state_color()
	_vision_instance.visible = show_vision
	_last_seen_marker.visible = show_vision and guard_state == GuardState.SEARCH
	_last_seen_marker.global_position = Vector3(last_seen_position.x, 0.06, last_seen_position.z)
	_vision_refresh -= delta
	if not show_vision or _vision_refresh > 0.0:
		return
	_vision_refresh = 0.08
	var tint := state_color()
	tint.a = 0.14
	_vision_material.albedo_color = tint
	_vision_mesh.clear_surfaces()
	_vision_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _vision_material)
	var origin := Vector3(global_position.x, 0.04, global_position.z)
	var previous := _vision_edge(-field_of_view_degrees * 0.5)
	for index in range(1, 33):
		var endpoint := _vision_edge(lerpf(-field_of_view_degrees * 0.5, field_of_view_degrees * 0.5, index / 32.0))
		_vision_mesh.surface_add_vertex(origin)
		_vision_mesh.surface_add_vertex(previous)
		_vision_mesh.surface_add_vertex(endpoint)
		previous = endpoint
	_vision_mesh.surface_end()


func _sync_sight_light() -> void:
	if _sight_light == null:
		return
	_sight_light.global_position = global_position + Vector3.UP * eye_height
	_sight_light.look_at(_sight_light.global_position + sight_forward(), Vector3.UP)
	_sight_light.spot_range = sight_range
	# Godot's spot_angle is a half-angle; the detection FOV is the full angle.
	_sight_light.spot_angle = field_of_view_degrees * 0.5


func _vision_edge(angle_degrees: float) -> Vector3:
	var eye := global_position + Vector3.UP * eye_height
	var endpoint := eye + sight_forward().rotated(Vector3.UP, deg_to_rad(angle_degrees)) * sight_range
	var query := PhysicsRayQueryParameters3D.create(eye, endpoint, sight_blocker_mask)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		endpoint = hit.position
	return Vector3(endpoint.x, 0.04, endpoint.z)
