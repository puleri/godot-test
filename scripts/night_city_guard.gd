extends "res://scripts/exchange_guard.gd"
## Distant patrols sleep as complete actor branches, including rig animation.

var home_position := Vector3.ZERO

func _ready() -> void:
	home_position = position
	super._ready()
	_state_label.visible = show_vision

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if position.y < -5:
		position = home_position
		velocity = Vector3.ZERO

func _update_feedback(delta: float) -> void:
	super._update_feedback(delta)
	_state_label.visible = show_vision
