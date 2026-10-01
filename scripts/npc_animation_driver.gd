class_name NPCAnimationDriver
extends Node

## Per-instance, physics-driven idle/locomotion blend with a cosmetic alert
## one-shot. The AnimationTree is the sole owner of playback and time scale.

@export var animation_player_path: NodePath
@export var idle_clip := "Root|Idle"
@export var walk_clip := "Root|Walk"
@export var run_clip := "Root|Run"
@export var alert_clip := "Root|Alert"
@export var walk_reference_speed := 0.8
@export var run_reference_speed := 1.2
@export var blend_full_speed := 0.8
@export var speed_smoothing_seconds := 0.10
@export var playback_smoothing_seconds := 0.12
@export var blend_in_seconds := 0.20
@export var blend_out_seconds := 0.25
@export var moving_start_speed := 0.06
@export var moving_stop_speed := 0.035
@export var alert_fade_in_seconds := 0.10
@export var alert_fade_out_seconds := 0.15

var _player: AnimationPlayer
var _tree: AnimationTree
var _smoothed_speed := 0.0
var _locomotion_weight := 0.0
var _locomotion_rate := 1.0
var _alert_requested := false
var _alert_playing := false
var _alert_remaining := 0.0
var _warned: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if _player == null:
		_warn_once("player", "NPCAnimationDriver could not find AnimationPlayer at %s." % animation_player_path)
		return
	_make_animation_library_instance_local()
	_hold_idle_pose()
	_set_loop(walk_clip, true)
	_set_loop(run_clip, true)
	_build_tree()


func set_resolved_motion(horizontal_speed: float, wants_run: bool, delta: float) -> void:
	if _tree == null:
		return
	_smoothed_speed = lerpf(_smoothed_speed, horizontal_speed, _filter_alpha(speed_smoothing_seconds, delta))
	var target_weight := _target_locomotion_weight()
	var blend_seconds := blend_in_seconds if target_weight > _locomotion_weight else blend_out_seconds
	_locomotion_weight = move_toward(_locomotion_weight, target_weight, delta / maxf(blend_seconds, 0.001))
	_tree.set("parameters/BaseBlend/blend_amount", _locomotion_weight)

	var reference_speed := run_reference_speed if wants_run else walk_reference_speed
	var target_rate := clampf(_smoothed_speed / maxf(reference_speed, 0.01), 0.55, 1.6)
	_locomotion_rate = lerpf(_locomotion_rate, target_rate, _filter_alpha(playback_smoothing_seconds, delta))
	_tree.set("parameters/LocomotionTimeScale/scale", _locomotion_rate)

	if _alert_playing:
		_alert_remaining -= delta
		if target_weight > 0.08:
			_tree.set("parameters/Alert/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
			_alert_playing = false
			_alert_requested = false
		elif _alert_remaining <= 0.0:
			_alert_playing = false
	if _alert_requested and not _alert_playing and _locomotion_weight <= 0.04:
		_start_alert()


func play_alert() -> bool:
	if _tree == null or not _has_clip(alert_clip) or _alert_requested or _alert_playing:
		return false
	# Queue the accent until collision braking and base blending have settled.
	_alert_requested = true
	return true


func debug_snapshot() -> Dictionary:
	return {"speed": _smoothed_speed, "weight": _locomotion_weight, "rate": _locomotion_rate, "alert_requested": _alert_requested, "alert_playing": _alert_playing}


func _build_tree() -> void:
	var locomotion_clip := run_clip if _has_clip(run_clip) else walk_clip
	if not _has_clip(idle_clip) or not _has_clip(locomotion_clip):
		_warn_once("base", "NPCAnimationDriver is missing base clips (idle '%s', locomotion '%s')." % [idle_clip, locomotion_clip])
		return
	_tree = AnimationTree.new()
	_tree.name = "RuntimeNPCAnimationTree"
	_tree.process_callback = AnimationTree.ANIMATION_PROCESS_PHYSICS
	var blend_tree := AnimationNodeBlendTree.new()
	var idle_node := AnimationNodeAnimation.new()
	idle_node.animation = &"" + idle_clip
	var locomotion_node := AnimationNodeAnimation.new()
	locomotion_node.animation = &"" + locomotion_clip
	var time_scale := AnimationNodeTimeScale.new()
	var base_blend := AnimationNodeBlend2.new()
	blend_tree.add_node("Idle", idle_node, Vector2(-520, -80))
	blend_tree.add_node("Locomotion", locomotion_node, Vector2(-520, 80))
	blend_tree.add_node("LocomotionTimeScale", time_scale, Vector2(-300, 80))
	blend_tree.add_node("BaseBlend", base_blend, Vector2(-80, 0))
	blend_tree.connect_node("LocomotionTimeScale", 0, "Locomotion")
	blend_tree.connect_node("BaseBlend", 0, "Idle")
	blend_tree.connect_node("BaseBlend", 1, "LocomotionTimeScale")
	if _has_clip(alert_clip):
		var alert_node := AnimationNodeAnimation.new()
		alert_node.animation = &"" + alert_clip
		var one_shot := AnimationNodeOneShot.new()
		one_shot.fadein_time = alert_fade_in_seconds
		one_shot.fadeout_time = alert_fade_out_seconds
		one_shot.mix_mode = AnimationNodeOneShot.MIX_MODE_BLEND
		blend_tree.add_node("AlertClip", alert_node, Vector2(-80, 180))
		blend_tree.add_node("Alert", one_shot, Vector2(160, 0))
		blend_tree.connect_node("Alert", 0, "BaseBlend")
		blend_tree.connect_node("Alert", 1, "AlertClip")
		blend_tree.connect_node("output", 0, "Alert")
	else:
		blend_tree.connect_node("output", 0, "BaseBlend")
	_tree.tree_root = blend_tree
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.active = true
	_player.speed_scale = 1.0
	_tree.set("parameters/BaseBlend/blend_amount", 0.0)
	_tree.set("parameters/LocomotionTimeScale/scale", 1.0)


func _start_alert() -> void:
	_alert_requested = false
	_alert_playing = true
	_alert_remaining = _player.get_animation(alert_clip).length + alert_fade_out_seconds
	_tree.set("parameters/Alert/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _target_locomotion_weight() -> float:
	if _smoothed_speed <= moving_stop_speed:
		return 0.0
	if _smoothed_speed < moving_start_speed and _locomotion_weight <= 0.0:
		return 0.0
	return clampf(_smoothed_speed / maxf(blend_full_speed, 0.01), 0.0, 1.0)


func _filter_alpha(seconds: float, delta: float) -> float:
	return 1.0 - exp(-delta / maxf(seconds, 0.001))


func _has_clip(clip: String) -> bool:
	return _player != null and not clip.is_empty() and _player.has_animation(clip)


func _hold_idle_pose() -> void:
	if not _has_clip(idle_clip):
		return
	var animation := _player.get_animation(idle_clip)
	if animation != null:
		animation.loop_mode = Animation.LOOP_NONE
		animation.length = maxf(animation.length, 0.25)


func _set_loop(clip: String, loop: bool) -> void:
	if not _has_clip(clip):
		return
	var animation := _player.get_animation(clip)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


func _make_animation_library_instance_local() -> void:
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
