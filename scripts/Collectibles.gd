extends Node3D

signal coin_collected

@export var speed : Vector3 = Vector3(0,50,0)

var is_collected := false

func _process (delta):
	rotation_degrees += speed * delta;

func collected ():
	if is_collected:
		return
	is_collected = true
	$Area3D.set_deferred("monitoring", false)
	coin_collected.emit()

	var tween = create_tween()
	speed = Vector3(0,1500,0)
	tween.tween_property(self, "position", position + Vector3(0,1,0), .2)
	tween.tween_property(self, "scale", Vector3.ONE * 0.001, .2)
	tween.tween_callback(queue_free)


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name == "Player":
		collected()
