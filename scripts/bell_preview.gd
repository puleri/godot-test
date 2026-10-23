extends Node3D

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: $Bell.ring()
			KEY_L: $Bell.start_loop()
			KEY_R: $Bell.stop_ringing()
