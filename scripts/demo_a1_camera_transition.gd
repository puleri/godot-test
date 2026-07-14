extends Node3D

@export var start_camera_path: NodePath = ^"Camera3D"
@export var target_camera_path: NodePath = ^"45"
@export var player_path: NodePath = ^"Player"
@export_range(0.0, 10.0, 0.05, "or_greater") var startup_camera_transition_duration := 1.2
@export var next_stage_trigger_position := Vector3(0.0, 0.0, -5.0)
@export var next_stage_camera_offset := Vector3(0.0, 0.0, -28.0)
@export var next_stage_camera_yaw_degrees := 95.0
@export_range(0.0, 10.0, 0.05, "or_greater") var next_stage_camera_transition_duration := 1.0

var startup_camera_tween: Tween
var next_stage_camera_tween: Tween
var next_stage_camera_started := false

func _ready() -> void:
	_start_camera_transition_to_target()

func _physics_process(_delta: float) -> void:
	if next_stage_camera_started:
		return

	var player := get_node_or_null(player_path) as Node3D
	if player == null:
		return

	if player.global_position.z <= next_stage_trigger_position.z:
		next_stage_camera_started = true
		_start_next_stage_camera_transition()

func _start_camera_transition_to_target() -> void:
	var start_camera := get_node_or_null(start_camera_path) as Camera3D
	var target_camera := get_node_or_null(target_camera_path) as Camera3D
	if start_camera == null or target_camera == null:
		push_warning("Demo_A1 camera transition skipped: expected Camera3D and 45 cameras.")
		return

	if startup_camera_transition_duration <= 0.0:
		target_camera.make_current()
		return

	var transition_camera := Camera3D.new()
	transition_camera.name = "StartupTransitionCamera"
	transition_camera.top_level = true
	add_child(transition_camera)

	_copy_camera_settings(start_camera, transition_camera)
	transition_camera.global_transform = start_camera.global_transform
	transition_camera.make_current()

	startup_camera_tween = create_tween()
	startup_camera_tween.set_parallel(true)
	startup_camera_tween.set_trans(Tween.TRANS_CUBIC)
	startup_camera_tween.set_ease(Tween.EASE_IN_OUT)
	startup_camera_tween.tween_property(transition_camera, "global_position", target_camera.global_position, startup_camera_transition_duration)
	startup_camera_tween.tween_property(transition_camera, "global_rotation", target_camera.global_rotation, startup_camera_transition_duration)
	startup_camera_tween.tween_property(transition_camera, "size", target_camera.size, startup_camera_transition_duration)
	startup_camera_tween.tween_property(transition_camera, "fov", target_camera.fov, startup_camera_transition_duration)
	startup_camera_tween.finished.connect(_finish_camera_transition.bind(transition_camera, target_camera))

func _finish_camera_transition(transition_camera: Camera3D, target_camera: Camera3D) -> void:
	if is_instance_valid(target_camera):
		target_camera.make_current()

	if is_instance_valid(transition_camera):
		transition_camera.queue_free()

	startup_camera_tween = null

func _start_next_stage_camera_transition() -> void:
	var stage_camera := _get_active_stage_camera()
	if stage_camera == null:
		push_warning("Demo_A1 next stage camera transition skipped: no active camera found.")
		return

	var target_position := stage_camera.global_position + next_stage_camera_offset
	var target_rotation := stage_camera.global_rotation + Vector3(0.0, deg_to_rad(next_stage_camera_yaw_degrees), 0.0)
	if next_stage_camera_transition_duration <= 0.0:
		stage_camera.global_position = target_position
		stage_camera.global_rotation = target_rotation
		return

	if next_stage_camera_tween != null:
		next_stage_camera_tween.kill()

	next_stage_camera_tween = create_tween()
	next_stage_camera_tween.set_parallel(true)
	next_stage_camera_tween.set_trans(Tween.TRANS_CUBIC)
	next_stage_camera_tween.set_ease(Tween.EASE_IN_OUT)
	next_stage_camera_tween.tween_property(stage_camera, "global_position", target_position, next_stage_camera_transition_duration)
	next_stage_camera_tween.tween_property(stage_camera, "global_rotation", target_rotation, next_stage_camera_transition_duration)
	next_stage_camera_tween.finished.connect(_on_next_stage_camera_transition_finished)

func _get_active_stage_camera() -> Camera3D:
	var target_camera := get_node_or_null(target_camera_path) as Camera3D
	if target_camera != null:
		target_camera.make_current()
		return target_camera

	return get_viewport().get_camera_3d()

func _on_next_stage_camera_transition_finished() -> void:
	next_stage_camera_tween = null

func _copy_camera_settings(source_camera: Camera3D, target_camera: Camera3D) -> void:
	target_camera.projection = source_camera.projection
	target_camera.keep_aspect = source_camera.keep_aspect
	target_camera.fov = source_camera.fov
	target_camera.size = source_camera.size
	target_camera.frustum_offset = source_camera.frustum_offset
	target_camera.near = source_camera.near
	target_camera.far = source_camera.far
	target_camera.h_offset = source_camera.h_offset
	target_camera.v_offset = source_camera.v_offset
	target_camera.cull_mask = source_camera.cull_mask
	target_camera.environment = source_camera.environment
	target_camera.attributes = source_camera.attributes
