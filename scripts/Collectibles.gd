extends Node3D



@export var speed : Vector3 = Vector3(0,50,0)
func _process (delta):
	rotation_degrees += speed * delta;
