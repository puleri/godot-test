extends CharacterBody3D

enum ControlPhase {
	PHASE_1_PLATFORMER,
	PHASE_2_THIRD_PERSON,
}

@export var max_walk_speed: float = 5.0
@export var ground_acceleration: float = 28.0
@export var ground_deceleration: float = 36.0
@export var air_acceleration: float = 12.0
@export var air_deceleration: float = 6.0
@export var jump_velocity: float = 8.0
@export var gravity: float = 24.0
@export var side_plane_z: float = 0.0
@export var visual_pivot_path: NodePath = ^"VisualPivot"
@export var animation_tree_path: NodePath = ^"AnimationTree"
@export var camera_path: NodePath = ^"Camera3D"
@export var facing_right_yaw: float = 0.0
@export var facing_left_yaw: float = PI
@export var facing_up_yaw: float = PI / 2.0
@export var facing_down_yaw: float = -PI / 2.0
@export var third_person_visual_yaw: float = 0.0
@export var phase_1_vertical_axis_sign: float = -1.0
@export var turn_speed: float = 2.8
@export var phase_1_camera_position: Vector3 = Vector3(0.0, .5, 10.0)
@export var phase_1_camera_rotation: Vector3 = Vector3(0, 0.0, 0.0)
@export var phase_2_camera_position: Vector3 = Vector3(-6.0, 3.0, 0.0)
@export var phase_2_camera_rotation: Vector3 = Vector3(-0.35, -PI / 2.0, 0.0)
@export var camera_transition_duration: float = 1.1
@export var phase_2_camera_fov: float = 62.0
@export var walk_blend_in_time: float = 0.16
@export var walk_blend_out_time: float = 0.12
@export var jump_blend_time: float = 0.05
@export var landing_blend_time: float = 0.12
@export var min_walk_playback_scale: float = 0.35
@export var max_walk_playback_scale: float = 1.0
@export var walk_animation_threshold: float = 0.03

@onready var visual_pivot: Node3D = get_node_or_null(visual_pivot_path) as Node3D
@onready var animation_tree: AnimationTree = get_node_or_null(animation_tree_path) as AnimationTree
@onready var game_camera: Camera3D = get_node_or_null(camera_path) as Camera3D

var current_phase: int = ControlPhase.PHASE_1_PLATFORMER
var animation_player: AnimationPlayer
var state_machine_playback: AnimationNodeStateMachinePlayback
var current_animation: String = ""
var current_animation_state: String = ""
var idle_animation_name: String = ""
var walk_animation_name: String = ""
var jump_animation_name: String = ""
var walk_blend_amount: float = 0.0
var using_animation_tree: bool = false
var transition_started: bool = false
var camera_tween: Tween

# Rook animation names come from the imported FBX animation list.
const IDLE_ANIMATION := "Skeleton|Idle"
const WALK_ANIMATION_PRIMARY := "Skeleton|Walk_v3"
const WALK_ANIMATION_FALLBACK := "Skeleton|Walk"
const JUMP_ANIMATION := "Skeleton|Jump"
const GROUND_STATE := "Ground"
const JUMP_STATE := "Jump"

func _ready() -> void:
	animation_player = _find_animation_player(self)
	global_position.z = side_plane_z

	if visual_pivot != null:
		visual_pivot.rotation.y = facing_right_yaw

	_configure_phase_1_camera()

	_configure_animation_loops()
	_configure_animation_tree()
	_initialize_animation_pose()

func _physics_process(delta: float) -> void:
	var movement_input := Vector3.ZERO
	match current_phase:
		ControlPhase.PHASE_1_PLATFORMER:
			movement_input = handle_phase_1_movement(delta)
		ControlPhase.PHASE_2_THIRD_PERSON:
			movement_input = handle_phase_2_movement(delta)

	var jumped := _update_vertical_velocity(delta)

	move_and_slide()
	_update_phase_camera()

	_update_facing(movement_input)
	_update_animation(delta, jumped)

func handle_phase_1_movement(delta: float) -> Vector3:
	var cardinal_input := _read_phase_1_cardinal_input()
	_update_phase_1_ground_velocity(cardinal_input, delta)
	return cardinal_input

func handle_phase_2_movement(delta: float) -> Vector3:
	var turn_input := Input.get_axis("move_right", "move_left")
	if not is_zero_approx(turn_input):
		rotation.y += turn_input * turn_speed * delta

	var forward_input := Input.get_axis("move_down", "move_up")
	var forward_direction := global_transform.basis.x.normalized()
	var target_velocity := forward_direction * forward_input * max_walk_speed
	target_velocity.y = 0.0
	_update_ground_plane_velocity(target_velocity, target_velocity.normalized() if target_velocity.length() > 0.0 else Vector3.ZERO, delta)
	return target_velocity.normalized() if target_velocity.length() > 0.0 else Vector3.ZERO

func transition_to_phase_2(trigger: Node = null) -> void:
	if transition_started:
		return

	transition_started = true
	current_phase = ControlPhase.PHASE_2_THIRD_PERSON

	if trigger != null:
		trigger.hide()
		if trigger is Area3D:
			trigger.set_deferred("monitoring", false)
			trigger.set_deferred("monitorable", false)

	var camera_transform := Transform3D.IDENTITY
	if game_camera != null:
		camera_transform = game_camera.global_transform

	rotation.y = visual_pivot.rotation.y if visual_pivot != null else rotation.y
	if visual_pivot != null:
		visual_pivot.rotation.y = third_person_visual_yaw

	if game_camera != null:
		game_camera.global_transform = camera_transform
		game_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		game_camera.fov = phase_2_camera_fov
		_start_camera_transition()

func _read_phase_1_cardinal_input() -> Vector3:
	var horizontal_input := Input.get_axis("move_left", "move_right")
	if not is_zero_approx(horizontal_input):
		return Vector3(_axis_sign(horizontal_input), 0.0, 0.0)

	var vertical_input := Input.get_axis("move_down", "move_up")
	if not is_zero_approx(vertical_input):
		return Vector3(0.0, 0.0, _axis_sign(vertical_input) * phase_1_vertical_axis_sign)

	return Vector3.ZERO

func _axis_sign(value: float) -> float:
	return 1.0 if value > 0.0 else -1.0

func _update_phase_1_ground_velocity(cardinal_input: Vector3, delta: float) -> void:
	var acceleration := _get_ground_plane_acceleration(cardinal_input)

	if not is_zero_approx(cardinal_input.x):
		velocity.x = move_toward(velocity.x, cardinal_input.x * max_walk_speed, acceleration * delta)
		velocity.z = 0.0
	elif not is_zero_approx(cardinal_input.z):
		velocity.x = 0.0
		velocity.z = move_toward(velocity.z, cardinal_input.z * max_walk_speed, acceleration * delta)
	else:
		_decelerate_phase_1_ground_velocity(acceleration, delta)

func _decelerate_phase_1_ground_velocity(deceleration: float, delta: float) -> void:
	if absf(velocity.x) >= absf(velocity.z):
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = 0.0
	else:
		velocity.x = 0.0
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

func _update_ground_plane_velocity(target_velocity: Vector3, movement_input: Vector3, delta: float) -> void:
	var acceleration := _get_ground_plane_acceleration(movement_input)
	var ground_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var updated_velocity := ground_velocity.move_toward(Vector3(target_velocity.x, 0.0, target_velocity.z), acceleration * delta)
	velocity.x = updated_velocity.x
	velocity.z = updated_velocity.z

func _get_ground_plane_acceleration(movement_input: Vector3) -> float:
	if movement_input.is_zero_approx():
		return ground_deceleration if is_on_floor() else air_deceleration

	return ground_acceleration if is_on_floor() else air_acceleration

func _update_vertical_velocity(delta: float) -> bool:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0

		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			return true
	else:
		velocity.y -= gravity * delta

	return false

func _update_facing(movement_input: Vector3) -> void:
	if visual_pivot == null or movement_input.is_zero_approx():
		return

	if current_phase == ControlPhase.PHASE_2_THIRD_PERSON:
		visual_pivot.rotation.y = third_person_visual_yaw
	elif absf(movement_input.x) > 0.0:
		visual_pivot.rotation.y = facing_right_yaw if movement_input.x > 0.0 else facing_left_yaw
	elif absf(movement_input.z) > 0.0:
		visual_pivot.rotation.y = facing_up_yaw if movement_input.z < 0.0 else facing_down_yaw

func _configure_phase_1_camera() -> void:
	if game_camera == null:
		return

	game_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game_camera.position = phase_1_camera_position
	game_camera.rotation = phase_1_camera_rotation

func _update_phase_camera() -> void:
	if current_phase != ControlPhase.PHASE_1_PLATFORMER or game_camera == null:
		return

	game_camera.global_position = Vector3(
		global_position.x + phase_1_camera_position.x,
		global_position.y + phase_1_camera_position.y,
		side_plane_z + phase_1_camera_position.z
	)
	game_camera.global_rotation = phase_1_camera_rotation

func _start_camera_transition() -> void:
	if camera_tween != null:
		camera_tween.kill()

	camera_tween = create_tween()
	camera_tween.set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_CUBIC)
	camera_tween.set_ease(Tween.EASE_OUT)
	camera_tween.tween_property(game_camera, "position", phase_2_camera_position, camera_transition_duration)
	camera_tween.tween_property(game_camera, "rotation", phase_2_camera_rotation, camera_transition_duration)

func _update_animation(delta: float, jumped: bool) -> void:
	var normalized_speed := _get_normalized_walk_speed()
	_update_ground_blend(normalized_speed, delta)

	if using_animation_tree:
		_update_animation_tree(normalized_speed, jumped)
	else:
		_update_animation_player_fallback(normalized_speed, jumped)

func _get_normalized_walk_speed() -> float:
	if max_walk_speed <= 0.0:
		return 0.0

	var ground_speed := Vector2(velocity.x, velocity.z).length()
	return clampf(ground_speed / max_walk_speed, 0.0, 1.0)

func _update_ground_blend(normalized_speed: float, delta: float) -> void:
	var target_blend := normalized_speed if normalized_speed > walk_animation_threshold else 0.0
	var blend_time := walk_blend_in_time if target_blend > walk_blend_amount else walk_blend_out_time

	if blend_time <= 0.0:
		walk_blend_amount = target_blend
	else:
		walk_blend_amount = move_toward(walk_blend_amount, target_blend, delta / blend_time)

func _update_animation_tree(normalized_speed: float, jumped: bool) -> void:
	animation_tree.set("parameters/%s/GroundBlend/blend_amount" % GROUND_STATE, walk_blend_amount)
	animation_tree.set("parameters/%s/WalkSpeed/scale" % GROUND_STATE, _get_walk_playback_scale(normalized_speed))

	var target_state := JUMP_STATE if jumped or not is_on_floor() else GROUND_STATE
	if target_state != current_animation_state:
		state_machine_playback.travel(target_state)
		current_animation_state = target_state

func _update_animation_player_fallback(normalized_speed: float, jumped: bool) -> void:
	var target_animation := idle_animation_name
	var blend_time := walk_blend_out_time
	var playback_scale := 1.0

	if jumped or not is_on_floor():
		target_animation = jump_animation_name
		blend_time = jump_blend_time
	elif normalized_speed > walk_animation_threshold:
		target_animation = walk_animation_name
		blend_time = walk_blend_in_time
		playback_scale = _get_walk_playback_scale(normalized_speed)

	if target_animation.is_empty():
		return

	animation_player.speed_scale = playback_scale
	_play_animation(target_animation, blend_time)

func _get_walk_playback_scale(normalized_speed: float) -> float:
	return lerpf(min_walk_playback_scale, max_walk_playback_scale, normalized_speed)

func _initialize_animation_pose() -> void:
	walk_blend_amount = 0.0

	if using_animation_tree:
		animation_tree.set("parameters/%s/GroundBlend/blend_amount" % GROUND_STATE, walk_blend_amount)
		animation_tree.set("parameters/%s/WalkSpeed/scale" % GROUND_STATE, min_walk_playback_scale)
	else:
		_play_animation(IDLE_ANIMATION)

func _configure_animation_tree() -> void:
	if animation_player == null:
		push_warning("PlayerController could not find an AnimationPlayer under the Rook instance.")
		return

	if animation_tree == null:
		push_warning("PlayerController could not find an AnimationTree node. Falling back to AnimationPlayer blends.")
		return

	idle_animation_name = _resolve_required_animation(IDLE_ANIMATION)
	walk_animation_name = _resolve_walk_animation()
	jump_animation_name = _resolve_required_animation(JUMP_ANIMATION)

	if idle_animation_name.is_empty() or walk_animation_name.is_empty() or jump_animation_name.is_empty():
		push_warning("PlayerController is missing one or more Rook animations. Falling back to direct AnimationPlayer playback.")
		_play_animation(idle_animation_name)
		return

	var ground_tree := _build_ground_blend_tree(idle_animation_name, walk_animation_name)
	var jump_node := AnimationNodeAnimation.new()
	jump_node.animation = jump_animation_name

	var state_machine := AnimationNodeStateMachine.new()
	state_machine.add_node(GROUND_STATE, ground_tree, Vector2(0, 0))
	state_machine.add_node(JUMP_STATE, jump_node, Vector2(240, 0))
	state_machine.add_transition(GROUND_STATE, JUMP_STATE, _make_transition(jump_blend_time))
	state_machine.add_transition(JUMP_STATE, GROUND_STATE, _make_transition(landing_blend_time))

	animation_tree.tree_root = state_machine
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.active = true

	state_machine_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if state_machine_playback == null:
		push_warning("PlayerController could not initialize AnimationTree playback. Falling back to AnimationPlayer blends.")
		animation_tree.active = false
		return

	state_machine_playback.start(GROUND_STATE)
	current_animation_state = GROUND_STATE
	using_animation_tree = true

func _build_ground_blend_tree(idle_animation: String, walk_animation: String) -> AnimationNodeBlendTree:
	var idle_node := AnimationNodeAnimation.new()
	idle_node.animation = idle_animation

	var walk_node := AnimationNodeAnimation.new()
	walk_node.animation = walk_animation

	var walk_speed_node := AnimationNodeTimeScale.new()
	var ground_blend_node := AnimationNodeBlend2.new()

	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node("Idle", idle_node, Vector2(0, 0))
	blend_tree.add_node("Walk", walk_node, Vector2(0, 140))
	blend_tree.add_node("WalkSpeed", walk_speed_node, Vector2(220, 140))
	blend_tree.add_node("GroundBlend", ground_blend_node, Vector2(440, 70))
	blend_tree.connect_node("WalkSpeed", 0, "Walk")
	blend_tree.connect_node("GroundBlend", 0, "Idle")
	blend_tree.connect_node("GroundBlend", 1, "WalkSpeed")
	blend_tree.connect_node("output", 0, "GroundBlend")
	return blend_tree

func _make_transition(blend_time: float) -> AnimationNodeStateMachineTransition:
	var transition := AnimationNodeStateMachineTransition.new()
	transition.xfade_time = maxf(blend_time, 0.0)
	return transition

func _resolve_required_animation(animation_name: String) -> String:
	if animation_player != null and animation_player.has_animation(animation_name):
		return animation_name

	push_warning("Rook animation not found: %s" % animation_name)
	return ""

func _resolve_walk_animation() -> String:
	if animation_player == null:
		return ""

	if animation_player.has_animation(WALK_ANIMATION_PRIMARY):
		return WALK_ANIMATION_PRIMARY

	if animation_player.has_animation(WALK_ANIMATION_FALLBACK):
		return WALK_ANIMATION_FALLBACK

	push_warning("Rook walk animation not found: %s or %s" % [WALK_ANIMATION_PRIMARY, WALK_ANIMATION_FALLBACK])
	return ""

func _play_animation(animation_name: String, blend_time: float = 0.0) -> void:
	if animation_player == null:
		return

	var resolved_name := _resolve_animation_name(animation_name)
	if resolved_name.is_empty() or resolved_name == current_animation:
		return

	animation_player.play(resolved_name, blend_time)
	current_animation = resolved_name

func _resolve_animation_name(animation_name: String) -> String:
	if animation_player == null:
		return ""

	if animation_name == WALK_ANIMATION_PRIMARY and not animation_player.has_animation(WALK_ANIMATION_PRIMARY):
		if animation_player.has_animation(WALK_ANIMATION_FALLBACK):
			return WALK_ANIMATION_FALLBACK
		return ""

	if animation_player.has_animation(animation_name):
		return animation_name

	return ""

func _configure_animation_loops() -> void:
	if animation_player == null:
		return

	_set_animation_loop(IDLE_ANIMATION, Animation.LOOP_LINEAR)
	_set_animation_loop(WALK_ANIMATION_PRIMARY, Animation.LOOP_LINEAR)
	_set_animation_loop(WALK_ANIMATION_FALLBACK, Animation.LOOP_LINEAR)
	_set_animation_loop(JUMP_ANIMATION, Animation.LOOP_NONE)

func _set_animation_loop(animation_name: String, loop_mode: int) -> void:
	if animation_player.has_animation(animation_name):
		animation_player.get_animation(animation_name).loop_mode = loop_mode

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root

	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found

	return null
