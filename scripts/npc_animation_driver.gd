class_name NPCAnimationDriver
extends Node

## Plays the explicitly configured clips for an ambient NPC. Movement remains
## owned by NPCController; this node only observes its resolved displacement.

@export var animation_player_path: NodePath
@export var idle_clip := "Root|Idle"
@export var walk_clip := "Root|Walk"
@export var run_clip := "Root|Run"
@export var alert_clip := "Root|Alert"
@export_range(0.0, 1.0, 0.01) var crossfade_seconds := 0.15
@export var walk_reference_speed := 0.8
@export var run_reference_speed := 1.2
@export var moving_start_speed := 0.06
@export var moving_stop_speed := 0.035

var _player: AnimationPlayer
var _current_clip := ""
var _smoothed_speed := 0.0
var _was_moving := false
var _alert_playing := false
var _warned: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if _player == null:
		_warn_once("player", "NPCAnimationDriver could not find AnimationPlayer at %s." % animation_player_path)
		return
	_make_animation_library_instance_local()
	_set_loop(idle_clip, false)
	_set_loop(walk_clip, true)
	_set_loop(run_clip, true)
	_player.animation_finished.connect(_on_animation_finished)
	_play_safe(idle_clip, 0.0, 1.0)


func set_resolved_motion(horizontal_speed: float, wants_run: bool, delta: float) -> void:
	if _alert_playing:
		return
	_smoothed_speed = move_toward(_smoothed_speed, horizontal_speed, max(0.01, delta * 5.0))
	if _was_moving:
		_was_moving = _smoothed_speed > moving_stop_speed
	else:
		_was_moving = _smoothed_speed >= moving_start_speed

	if not _was_moving:
		_play_safe(idle_clip, crossfade_seconds, 1.0)
		return

	var use_run := wants_run and _has_clip(run_clip)
	var clip := run_clip if use_run else walk_clip
	if not _has_clip(clip):
		# A project with only one locomotion clip can still move safely.
		clip = run_clip if _has_clip(run_clip) else idle_clip
		_warn_once("locomotion", "NPCAnimationDriver is missing locomotion clip '%s'; using '%s'." % [walk_clip, clip])
	var reference_speed := run_reference_speed if use_run else walk_reference_speed
	var playback_scale: float = clampf(_smoothed_speed / maxf(reference_speed, 0.01), 0.55, 1.6)
	_play_safe(clip, crossfade_seconds, playback_scale)


func play_alert() -> bool:
	if _alert_playing or not _has_clip(alert_clip):
		return false
	_alert_playing = true
	_play_safe(alert_clip, crossfade_seconds, 1.0)
	return true


func _play_safe(clip: String, blend: float, speed_scale: float) -> void:
	if _player == null or not _has_clip(clip):
		if _player != null:
			_warn_once("missing:" + clip, "NPCAnimationDriver is missing clip '%s'." % clip)
		return
	if _current_clip != clip:
		_player.play(clip, blend, speed_scale)
		_current_clip = clip
	elif not _player.is_playing() and clip != idle_clip:
		_player.play(clip, 0.0, speed_scale)
	else:
		_player.speed_scale = speed_scale


func _has_clip(clip: String) -> bool:
	return _player != null and not clip.is_empty() and _player.has_animation(clip)


func _set_loop(clip: String, loop: bool) -> void:
	if not _has_clip(clip):
		return
	var animation := _player.get_animation(clip)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


func _make_animation_library_instance_local() -> void:
	# Imported scenes can share their animation library. Duplicate it before
	# changing loop flags so sibling NPC instances cannot affect each other.
	var library_names: PackedStringArray = _player.get_animation_library_list()
	for library_name in library_names:
		var library := _player.get_animation_library(library_name)
		if library == null:
			continue
		var local_library := library.duplicate(true) as AnimationLibrary
		if local_library == null:
			continue
		_player.remove_animation_library(library_name)
		_player.add_animation_library(library_name, local_library)


func _warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


func _on_animation_finished(animation_name: StringName) -> void:
	if String(animation_name) == alert_clip:
		_alert_playing = false
		_current_clip = ""
