extends "res://scripts/exchange_guard.gd"
## Lab-only investigator/sentry duties and a bounded, reachable area search.

@export var bay := 0
@export var listen_only := false
var duty := "PATROL"
var heard_note := "WAITING FOR SOUND"
var home := Vector3.ZERO
var search_points: Array[Vector3] = []
var visited_search_points := 0
var _sentry_elapsed := 0.0
var _sentry_incident := Vector3.ZERO
var covered_incident := Vector3.ZERO
var _sound_glance_cooldown := 0.0
var _watch_index := 0
var _watch_pause := 0.0


func _ready() -> void:
	home = position
	super._ready()


func reset_demo() -> void:
	position = home
	velocity = Vector3.ZERO
	active = true
	has_lamp = not listen_only
	awareness = 0
	player_visible = false
	uncertain_visible = false
	_uncertain_suspicion = false
	_uncertain_elapsed = 0
	_lost_sight_elapsed = 0
	guard_state = GuardState.PATROL
	_alerted_detection = false
	duty = "LISTENER" if listen_only else "PATROL"
	heard_note = "WAITING FOR SOUND"
	search_points.clear()
	visited_search_points = 0
	_sentry_elapsed = 0
	_sound_glance_cooldown = 0
	_watch_index = 0
	_watch_pause = 0
	_target_index = 0
	_pause_remaining = 1.0
	_requested_destination = Vector3.INF
	_repath_remaining = 0
	_heading_yaw = 0
	_set_visual_yaw(visual_forward_yaw_offset)
	if _animation_driver != null:
		_animation_driver.reset_guard_motion()
	_update_feedback(0)


func _physics_process(delta: float) -> void:
	_sound_glance_cooldown = maxf(0, _sound_glance_cooldown - delta)
	if listen_only:
		_update_feedback(delta)
		return
	super._physics_process(delta)


func _update_route(delta: float) -> void:
	if duty == "SENTRY":
		_sentry_elapsed += delta
		if _sentry_elapsed < 1.2:
			_stop_horizontal(delta)
			_face_position(_sentry_incident, delta)
		elif _watch_pause > 0:
			_stop_horizontal(delta)
			_watch_pause = maxf(0, _watch_pause - delta)
			var outward := Vector3.LEFT if home.x < 0 else Vector3.RIGHT
			var sweep := sin((_sentry_elapsed - 1.2) * 1.1) * deg_to_rad(35)
			_turn_heading_toward(outward.rotated(Vector3.UP, sweep), delta)
		else:
			# Holding an exit is an active watch, not a movement lock.
			var target := home + Vector3(0, 0, 1.2 if _watch_index == 0 else -1.2)
			_navigate_to(target, walk_speed * 0.7, delta)
			if Vector2(position.x - target.x, position.z - target.z).length() < 0.5:
				_watch_index = 1 - _watch_index
				_watch_pause = 1.0
		return
	super._update_route(delta)


func hold_exit(at: Vector3) -> void:
	duty = "SENTRY"
	_sentry_incident = at
	_sentry_elapsed = 0
	_sound_glance_cooldown = 3.0
	_watch_index = 0
	_watch_pause = 0
	covered_incident = at
	last_heard_position = at


func investigate_incident(at: Vector3, kind: String) -> void:
	last_heard_position = at
	duty = "INVESTIGATOR"
	_start_investigation(at, kind)
	search_points.clear()
	visited_search_points = 0


func receive_noise(at: Vector3, kind: String, result: Dictionary, investigate := true) -> bool:
	if not result.audible:
		heard_note = "BLOCKED" if is_inf(result.distance) else "OUT OF RANGE"
		return false
	heard_note = "HEARD %.1fm / %s" % [result.distance, "DIRECT" if result.direct else "AROUND DOOR"]
	if listen_only or not active or player_visible or uncertain_visible or guard_state == GuardState.CHASE:
		return true
	_suspicion_bubble.show_audio_alert()
	if not investigate:
		if duty == "SENTRY" and guard_state == GuardState.PATROL:
			last_heard_position = at
			# Same-source repeats cannot continually pin the guard's gaze.
			if _sound_glance_cooldown <= 0 or at.distance_to(_sentry_incident) > 2.0:
				_sentry_incident = at
				_sentry_elapsed = 0
				_sound_glance_cooldown = 3.0
		return true
	if guard_state == GuardState.SEARCH and kind != "CHIME":
		return true
	investigate_incident(at, kind)
	return true


func _search(delta: float) -> void:
	_search_travel_elapsed += delta
	if not _search_arrived:
		_navigate_to(investigation_target, walk_speed, delta)
		if Vector2(position.x - investigation_target.x, position.z - investigation_target.z).length() < 0.65 or _search_travel_elapsed > 8:
			_search_arrived = true
			_search_elapsed = 0
			_make_search_points()
		return
	_search_elapsed += delta
	if visited_search_points < search_points.size() and _search_elapsed < 10:
		var target := search_points[visited_search_points]
		_navigate_to(target, walk_speed, delta)
		if Vector2(position.x - target.x, position.z - target.z).length() < 0.55:
			visited_search_points += 1
		return
	_uncertain_suspicion = false
	_uncertain_elapsed = 0
	_change_state(GuardState.RETURN)


func _make_search_points() -> void:
	search_points.clear()
	var map := _agent.get_navigation_map()
	for offset in [Vector3(-2, 0, 0), Vector3(0, 0, -2), Vector3(2, 0, 0)]:
		var candidate: Vector3 = investigation_target + offset
		var surface := NavigationServer3D.map_get_closest_point(map, candidate)
		if Vector2(candidate.x - surface.x, candidate.z - surface.z).length() > 0.8:
			continue
		var path := NavigationServer3D.map_get_path(map, position, surface, true)
		if path.is_empty() or path[-1].distance_to(surface) > 0.2:
			continue
		search_points.append(Vector3(surface.x, 0, surface.z))


func _update_feedback(delta: float) -> void:
	super._update_feedback(delta)
	if not active:
		_state_label.text = guard_title + "\nOUT OF ACTION"
	elif listen_only:
		_state_label.text = guard_title + "\n" + heard_note
	elif duty == "SENTRY" and guard_state == GuardState.PATROL:
		_state_label.text = guard_title + ("\nSENTRY / CHECKING SOUND" if _sentry_elapsed < 1.2 else ("\nSENTRY / SCANNING EXIT" if _watch_pause > 0 else "\nSENTRY / WATCH PATROL"))
	elif guard_state == GuardState.SEARCH:
		_state_label.text = guard_title + ("\nAREA SEARCH %d/%d" % [visited_search_points, search_points.size()] if _search_arrived else "\nINVESTIGATOR / TO INCIDENT")
