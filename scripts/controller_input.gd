extends RefCounted
## Shared controller direction math for every camera and movement phase.

static func is_movement_event(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		# A diagonal reaches the radial deadzone before either axis reaches 0.2.
		return event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] and absf(event.axis_value) > 0.2 / sqrt(2.0)
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]
	return false

static func is_keyboard_movement_event(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and (event.is_action("move_left") or event.is_action("move_right") or event.is_action("move_up") or event.is_action("move_down"))

static func camera_relative_direction(stick: Vector2, camera_basis: Basis) -> Vector3:
	# Ground-plane axes stay perpendicular, preserving speed at every angle.
	var right := camera_basis.x
	right.y = 0.0
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var forward := Vector3.UP.cross(right)
	return (right * stick.x - forward * stick.y).limit_length()
