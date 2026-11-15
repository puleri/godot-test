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
var guard_pose: SkeletonModifier3D
var _guard_body: CharacterBody3D
var _guard_last_position := Vector3.ZERO
var _guard_phase := 0.0
var _guard_gait_blend := 0.0
var _guard_gait := "walk"
var _guard_contact_strength := 0.0


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
	return {"speed": _smoothed_speed, "weight": _locomotion_weight, "rate": _locomotion_rate, "alert_requested": _alert_requested, "alert_playing": _alert_playing, "weighted": guard_pose != null and guard_pose.enabled, "gait": _guard_gait, "phase": _guard_phase}


func _build_tree() -> void:
	var locomotion_clip := run_clip if _has_clip(run_clip) else walk_clip
	if not _has_clip(idle_clip) or not _has_clip(locomotion_clip):
		_warn_once("base", "NPCAnimationDriver is missing base clips (idle '%s', locomotion '%s')." % [idle_clip, locomotion_clip])
		return
	if _tree != null:
		_tree.free()
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
	if guard_pose != null:
		var walk_node := AnimationNodeAnimation.new()
		walk_node.animation = walk_clip
		var run_node := AnimationNodeAnimation.new()
		run_node.animation = run_clip if _has_clip(run_clip) else walk_clip
		blend_tree.add_node("GuardWalk", walk_node, Vector2(-960, 0))
		blend_tree.add_node("GuardRun", run_node, Vector2(-960, 200))
		blend_tree.add_node("WalkSeek", AnimationNodeTimeSeek.new(), Vector2(-760, 0))
		blend_tree.add_node("RunSeek", AnimationNodeTimeSeek.new(), Vector2(-760, 200))
		blend_tree.add_node("GaitBlend", AnimationNodeBlend2.new(), Vector2(-520, 100))
		blend_tree.connect_node("WalkSeek", 0, "GuardWalk")
		blend_tree.connect_node("RunSeek", 0, "GuardRun")
		blend_tree.connect_node("GaitBlend", 0, "WalkSeek")
		blend_tree.connect_node("GaitBlend", 1, "RunSeek")
		blend_tree.connect_node("LocomotionTimeScale", 0, "GaitBlend")
	else:
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


func configure_guard_motion(actor: CharacterBody3D) -> void:
	if _player == null or _tree == null or not _has_clip(walk_clip):
		return
	var skeletons := actor.get_node(actor.visual_pivot_path).find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_guard_body = actor
	var skeleton := skeletons[0] as Skeleton3D
	guard_pose = preload("res://scripts/guard_procedural_pose.gd").new()
	guard_pose.name = "GuardWeightAndContacts"
	skeleton.add_child(guard_pose)
	if not guard_pose.configure(actor, _player, idle_clip, walk_clip, run_clip if _has_clip(run_clip) else walk_clip):
		guard_pose.free()
		guard_pose = null
		return
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	_guard_last_position = actor.global_position
	_guard_gait = "run" if actor.locomotion_uses_run else "walk"
	_guard_gait_blend = 1.0 if _guard_gait == "run" else 0.0
	if guard_pose.profile == "hound":
		guard_pose.contacts.set_gait(_guard_gait)
	_build_tree()


func reset_guard_motion() -> void:
	if guard_pose == null:
		return
	guard_pose.reset_motion()
	_guard_phase = 0.0
	_guard_contact_strength = 0.0
	_guard_last_position = _guard_body.global_position


func update_guard_motion(resolved: Vector3, heading: float, wants_run: bool, delta: float, suppressed := false) -> void:
	if guard_pose == null:
		return
	var actor := _guard_body
	var relocated := actor.global_position.distance_to(_guard_last_position) > maxf(1.0, actor.run_speed * delta * 4.0)
	_guard_last_position = actor.global_position
	if relocated:
		reset_guard_motion()
	# Patrol gait is configured by the wrapper; a confirmed chase requests run.
	var running: bool = wants_run or actor.locomotion_uses_run
	_guard_gait_blend = move_toward(_guard_gait_blend, 1.0 if running else 0.0, delta / 0.22)
	var gait := "run" if _guard_gait_blend >= 0.5 else "walk"
	if gait != _guard_gait:
		_guard_gait = gait
		if guard_pose.profile == "hound":
			guard_pose.contacts.set_gait(gait)
	var motion := resolved - (actor.get_platform_velocity() if actor.is_on_floor() else Vector3.ZERO)
	var speed := Vector2(motion.x, motion.z).length()
	var stride: float = guard_pose.contacts.stride_length if guard_pose.profile == "hound" else lerpf(walk_reference_speed * _player.get_animation(walk_clip).length, run_reference_speed * _player.get_animation(run_clip if _has_clip(run_clip) else walk_clip).length, _guard_gait_blend)
	if actor.is_on_floor() and not suppressed and not relocated:
		_guard_phase = fposmod(_guard_phase + speed * delta / maxf(stride, 0.1), 1.0)
	_tree.set("parameters/GaitBlend/blend_amount", _guard_gait_blend)
	_tree.set("parameters/LocomotionTimeScale/scale", 0.0)
	var walk_period := 0.5 if guard_pose.profile == "hound" else 1.0
	_tree.set("parameters/WalkSeek/seek_request", _guard_phase * _player.get_animation(walk_clip).length * walk_period)
	_tree.set("parameters/RunSeek/seek_request", _guard_phase * _player.get_animation(run_clip if _has_clip(run_clip) else walk_clip).length)
	# Fade contacts through an alert or gait handover, preserving authored gestures.
	var alert_active := _alert_playing
	if _has_clip(alert_clip):
		alert_active = alert_active or bool(_tree.get("parameters/Alert/active"))
	var target_contact := absf(_guard_gait_blend * 2.0 - 1.0) if not alert_active and not suppressed else 0.0
	_guard_contact_strength = move_toward(_guard_contact_strength, target_contact, delta / 0.10)
	guard_pose.enabled = actor.weighted_motion_enabled
	guard_pose.motion_strength = actor.guard_motion_strength
	guard_pose.contact_strength = _guard_contact_strength
	guard_pose.phase = _guard_phase
	guard_pose.update_motion(delta, motion, heading, actor.is_on_floor(), actor.run_speed if running else actor.walk_speed, actor.acceleration, suppressed)
