extends Node3D
## Rigid skeletal bell. Gameplay owns sound, hearing and cooldown; ring() animates it.
signal ringing_finished

@export var autoplay_loop := false
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer


func _ready() -> void:
	# Libraries are shared by imported scenes. Copy before changing loop flags so
	# previewing or stopping one bell cannot affect another instance.
	for library_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(library_name).duplicate(true) as AnimationLibrary
		animation_player.remove_animation_library(library_name)
		animation_player.add_animation_library(library_name, library)
	animation_player.get_animation("Ring").loop_mode = Animation.LOOP_NONE
	animation_player.get_animation("RingLoop").loop_mode = Animation.LOOP_LINEAR
	animation_player.animation_finished.connect(_on_animation_finished)
	if autoplay_loop:
		start_loop()


func ring() -> void:
	animation_player.stop()
	animation_player.play("Ring")
	animation_player.seek(0.0, true)


func start_loop() -> void:
	animation_player.play("RingLoop", 0.15)


func stop_ringing() -> void:
	animation_player.play("Ring")
	animation_player.seek(0.0, true)
	animation_player.pause()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"Ring":
		ringing_finished.emit()
