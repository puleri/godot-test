extends Node3D

@onready var _player: CharacterBody3D = $CrowPlayer
@onready var _camera: Camera3D = $Camera3D
@onready var _camera_offset := _camera.position - _player.position


func _physics_process(delta: float) -> void:
	var target := _player.position + _camera_offset
	_camera.position = _camera.position.lerp(target, 1.0 - exp(-9.0 * delta))
