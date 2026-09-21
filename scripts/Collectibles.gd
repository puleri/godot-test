extends Node3D


@export var speed : Vector3 = Vector3(0,50,0)

func _process (delta):
	rotation_degrees += speed * delta;

func collected ():
	var tween = create_tween()
	speed = Vector3(0,1500,0)
	tween.tween_property(self, "position", position + Vector3(0,1,0), .2)
	tween.tween_property(self, "scale", Vector3(0,0,0), .2)


func _on_area_3d_body_entered(body: Node3D) -> void:
	collected()
