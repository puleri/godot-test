extends Node3D

@export var hinge_path: NodePath = ^"HingePivot"
@export var trigger_path: NodePath = ^"BumpTrigger"
@export var knock_sound_path: NodePath = ^"KnockSound"
@export var first_wiggle_degrees: float = -8.0
@export var rebound_wiggle_degrees: float = 10.0
@export var wiggle_out_time: float = 0.08
@export var rebound_time: float = 0.12
@export var settle_time: float = 0.10
@export var pressure_open_degrees: float = -90.0
@export var pressure_open_time: float = 0.35
@export var pressure_close_time: float = 0.28

var hinge: Node3D
var trigger_area: Area3D
var knock_sound: AudioStreamPlayer
var closed_rotation: Vector3
var wiggle_in_progress := false
var pressure_open := false
var door_tween: Tween

func _ready() -> void:
	hinge = get_node_or_null(hinge_path) as Node3D
	trigger_area = get_node_or_null(trigger_path) as Area3D
	knock_sound = get_node_or_null(knock_sound_path) as AudioStreamPlayer

	if hinge != null:
		closed_rotation = hinge.rotation
	else:
		push_warning("DoorBumpWiggle could not find HingePivot.")

	if trigger_area != null:
		trigger_area.body_entered.connect(_on_bump_trigger_body_entered)
	else:
		push_warning("DoorBumpWiggle could not find BumpTrigger.")

func _on_bump_trigger_body_entered(body: Node) -> void:
	if pressure_open or wiggle_in_progress or not _is_player_body(body):
		return

	bump_wiggle()

func bump_wiggle() -> void:
	if hinge == null or pressure_open:
		return

	wiggle_in_progress = true
	_play_knock_sound()

	_kill_door_tween()
	door_tween = create_tween()
	door_tween.set_trans(Tween.TRANS_SINE)
	door_tween.set_ease(Tween.EASE_OUT)
	door_tween.tween_property(hinge, "rotation:y", closed_rotation.y + deg_to_rad(first_wiggle_degrees), wiggle_out_time)
	door_tween.tween_property(hinge, "rotation:y", closed_rotation.y + deg_to_rad(rebound_wiggle_degrees), rebound_time)
	door_tween.tween_property(hinge, "rotation:y", closed_rotation.y, settle_time)
	door_tween.tween_callback(_finish_bump_wiggle)

func set_pressure_open(is_open: bool) -> void:
	if hinge == null or pressure_open == is_open:
		return

	pressure_open = is_open
	wiggle_in_progress = false
	_kill_door_tween()

	var target_rotation := closed_rotation
	if pressure_open:
		target_rotation.y += deg_to_rad(pressure_open_degrees)

	door_tween = create_tween()
	door_tween.set_trans(Tween.TRANS_SINE)
	door_tween.set_ease(Tween.EASE_OUT)
	door_tween.tween_property(hinge, "rotation:y", target_rotation.y, pressure_open_time if pressure_open else pressure_close_time)
	door_tween.tween_callback(func() -> void:
		if is_instance_valid(hinge):
			hinge.rotation = target_rotation
	)

func _is_player_body(body: Node) -> bool:
	return body is CharacterBody3D and body.name == "Player"

func _play_knock_sound() -> void:
	if knock_sound == null:
		return

	knock_sound.stop()
	knock_sound.play()

func _finish_bump_wiggle() -> void:
	if hinge == null or pressure_open:
		return

	hinge.rotation = closed_rotation
	wiggle_in_progress = false

func _kill_door_tween() -> void:
	if door_tween != null:
		door_tween.kill()
		door_tween = null
