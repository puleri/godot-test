extends "res://scripts/layered_stealth_guard.gd"
## Predictable patrols with readable pauses and sound investigations.

@export var guard_title := "HOUND"
var investigating_noise := false


func set_vision_visible(enabled: bool) -> void:
	show_vision = enabled
	# Refresh immediately even when completion has stopped the guard's AI.
	_vision_refresh = 0.0
	_update_feedback(0.0)


func _ready() -> void:
	# Mouse wrappers author random routes; this encounter teaches fixed timing.
	route_mode = RouteMode.ORDERED
	alert_chance_on_arrival = 0.0
	super._ready()


func investigate_noise(at: Vector3) -> bool:
	investigating_noise = hear_sound(at, hearing_range, "BELL")
	return investigating_noise


func _update_feedback(delta: float) -> void:
	super._update_feedback(delta)
	if guard_state != GuardState.SEARCH:
		investigating_noise = false
	if guard_state == GuardState.PATROL and _pause_remaining > 0:
		_state_label.text = "%s\nMOVES IN %.1fs" % [guard_title, _pause_remaining]
	elif guard_state == GuardState.SEARCH:
		_state_label.text = guard_title + "\n" + investigation_reason
	else:
		_state_label.text = guard_title + "\n" + state_name()


func _current_speed() -> float:
	return walk_speed
