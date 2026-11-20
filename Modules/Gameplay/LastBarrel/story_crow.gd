extends Node3D

const Cutaway := preload("res://Modules/Gameplay/LastBarrel/dock_cutaway.gd")
@onready var animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	$Speech.layers = Cutaway.FEEDBACK_MASK
	animation.play("Idle")


func walk_to(at: Vector3, delta: float, speed: float) -> bool:
	var distance := global_position.distance_to(at)
	if distance <= speed * delta:
		global_position = at
		animation.play("Idle", 0.12)
		return true
	look_at(Vector3(at.x, global_position.y, at.z))
	global_position = global_position.move_toward(at, speed * delta)
	if animation.current_animation != "Walk":
		animation.play("Walk", 0.12)
	return false


func says(line: String) -> void:
	$Speech.text = line
