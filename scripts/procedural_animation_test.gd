extends Node3D
## Staging room for Rook contact, turn sequencing and cape follow-through.

@onready var player = $Player
@onready var status: Label = $CanvasLayer/Panel/Margin/VBox/Status
var _spawn := Vector3.ZERO
var _close_view := false
var _focus := Vector3.ZERO
var _demo_running := false
var _demo_index := 0
var _demo_remaining := 0.0
var _demo_action := ""
const DEMO := [
	["", 0.5], ["move_right", 0.6], ["", 0.65],
	["move_up", 0.45], ["", 0.55], ["move_left", 0.8],
	["move_right", 0.45], ["", 0.8], ["move_down", 0.45],
	["", 0.4], ["jump", 0.1], ["", 1.2],
]


func _ready() -> void:
	get_viewport().content_scale_size = Vector2i(1280, 720)
	_spawn = player.global_position
	_focus = _spawn
	player.transition_to_phase_3_static_isometric()
	player.procedural_animation_toggled.connect(_update_status)
	_update_status(player.procedural_animation_enabled)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_T:
		if _demo_running:
			_stop_demo()
		else:
			_reset_player()
			_demo_running = true
			_demo_index = 0
			_demo_remaining = 0.0
	elif event.physical_keycode == KEY_R:
		_stop_demo()
		_reset_player()
	elif event.physical_keycode == KEY_C:
		_close_view = not _close_view
		_focus = player.global_position
		if player.camera_tween != null:
			player.camera_tween.kill()
		if not _close_view:
			player.game_camera.global_position = player.phase_3_static_camera_position
			player.game_camera.global_rotation = player.phase_3_static_camera_rotation
			player.game_camera.size = player.phase_3_static_camera_size
	else:
		if event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT, KEY_SPACE]:
			_stop_demo()
		return
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if _demo_running:
		_demo_remaining -= delta
		if _demo_remaining <= 0.0:
			if not _demo_action.is_empty():
				Input.action_release(_demo_action)
			if _demo_index >= DEMO.size():
				_stop_demo()
			else:
				_demo_action = DEMO[_demo_index][0]
				_demo_remaining = DEMO[_demo_index][1]
				_demo_index += 1
				if not _demo_action.is_empty():
					Input.action_press(_demo_action)
	if player.global_position.y < -5:
		_reset_player()
	if _close_view:
		_focus = _focus.lerp(player.global_position, 1.0 - exp(-12.0 * delta))
		var target := _focus + Vector3(0, 0.2, 0)
		player.game_camera.global_position = target + Vector3(3.5, 2.5, 4.5)
		player.game_camera.look_at(target)
		player.game_camera.size = 4.0


func _reset_player() -> void:
	player.global_position = _spawn
	player.velocity = Vector3.ZERO
	player.reset_procedural_motion()
	_focus = _spawn


func _update_status(enabled: bool) -> void:
	status.text = "P  ·  Procedural motion: %s" % ("ON" if enabled else "OFF — original animation")
	status.modulate = Color("91e7c4") if enabled else Color("ffc586")


func _stop_demo() -> void:
	if not _demo_action.is_empty():
		Input.action_release(_demo_action)
	_demo_action = ""
	_demo_running = false


func _exit_tree() -> void:
	_stop_demo()
