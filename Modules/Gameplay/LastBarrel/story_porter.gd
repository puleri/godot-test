extends Node3D

@onready var driver = $AnimationDriver
@onready var last_position := global_position


func _physics_process(delta: float) -> void:
	var travel := global_position - last_position
	last_position = global_position
	driver.set_resolved_motion(Vector2(travel.x, travel.z).length() / delta, false, delta)
	if travel.length_squared() > 0.00003:
		$VisualPivot.rotation.y = atan2(-travel.x, -travel.z) + PI / 2.0
