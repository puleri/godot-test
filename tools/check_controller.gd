extends SceneTree
## Run with a native window: godot --path . --script tools/check_controller.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await create_timer(1.0).timeout
	var devices := Input.get_connected_joypads()
	if devices.is_empty():
		print("No controller detected. Connect it in macOS, then run this check again.")
	for device in devices:
		print("Controller %d: %s | mapped: %s | GUID: %s" % [device, Input.get_joy_name(device), Input.is_joy_known(device), Input.get_joy_guid(device)])
	quit(0 if not devices.is_empty() else 1)
