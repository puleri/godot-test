extends Node3D

@export var interact_action: String = "interact"
@export var collision_radius: float = 0.42
@export var collision_height: float = 0.7
@export var collision_center_y: float = 0.35
@export var wall_thickness: float = 0.08
@export var wall_segment_width: float = 0.34
@export var wall_segment_count: int = 8
@export var interaction_radius: float = 0.9
@export var interaction_center: Vector3 = Vector3(0.0, 0.45, 0.0)
@export var exit_offset: Vector3 = Vector3(-0.8, 0.0, 0.0)
@export var occupied_player_offset: Vector3 = Vector3.ZERO
@export var occupied_speed_multiplier: float = 0.5
@export var occupied_lift_height: float = 0.12
@export var lift_transition_time: float = 0.12
@export var movement_threshold: float = 0.05
@export var hop_height: float = 0.45
@export var hop_duration: float = 0.36
@export var tooltip_offset: Vector3 = Vector3(0.0, 1.1, 0.0)
@export var enter_prompt: String = "E: Enter"
@export var exit_prompt: String = "E: Exit"
@export var music_bus_name: String = "Music"
@export var inside_music_cutoff_hz: float = 850.0
@export var normal_music_cutoff_hz: float = 20500.0
@export var music_filter_transition_time: float = 0.28

var nearby_player: CharacterBody3D
var inside_player: CharacterBody3D
var prompt_label: Label3D
var side_collision_shapes: Array[CollisionShape3D] = []
var player_inside := false
var transition_in_progress := false
var barrel_base_y: float
var barrel_lifted := false
var lift_tween: Tween
var music_filter: AudioEffectLowPassFilter
var music_filter_tween: Tween

func _ready() -> void:
	barrel_base_y = global_position.y
	_ensure_music_filter()
	_build_side_collision()
	_build_interaction_area()
	_build_tooltip()
	_update_tooltip()

func _exit_tree() -> void:
	_restore_music_filter_immediately()

func _physics_process(_delta: float) -> void:
	if not player_inside or transition_in_progress or inside_player == null:
		return

	_sync_barrel_to_player(inside_player)
	_update_barrel_lift_for_player(inside_player)

func _process(_delta: float) -> void:
	_face_tooltip_to_camera()

	if not Input.is_action_just_pressed(interact_action) or transition_in_progress:
		return

	if player_inside:
		exit_barrel()
	elif nearby_player != null:
		enter_barrel(nearby_player)

func enter_barrel(player: CharacterBody3D) -> void:
	transition_in_progress = true
	inside_player = player
	barrel_base_y = global_position.y

	_set_player_locked(player, true)
	_set_side_collision_enabled(false)
	_set_player_collision_enabled(player, false)
	_set_player_visual_visible(player, true)
	_set_player_barrel_hop_animation_active(player, true)
	await _hop_player_to(player, _get_inside_position(player))
	_set_player_barrel_hop_animation_active(player, false)

	_set_player_collision_enabled(player, true)
	_set_player_movement_speed_multiplier(player, occupied_speed_multiplier)
	_set_player_manual_jump_enabled(player, false)
	_set_player_barrel_animation_mode_enabled(player, true)
	_set_player_locked(player, false)
	player_inside = true
	_sync_barrel_to_player(player)
	_set_music_muffled(true)
	transition_in_progress = false
	_update_tooltip()

func exit_barrel() -> void:
	var player := inside_player
	if player == null:
		player = nearby_player

	if player == null:
		return

	transition_in_progress = true
	_set_music_muffled(false)
	_set_player_locked(player, true)
	_set_player_movement_speed_multiplier(player, 1.0)
	_set_player_manual_jump_enabled(player, true)
	_set_player_barrel_animation_mode_enabled(player, false)
	_set_player_collision_enabled(player, false)
	_set_barrel_lifted(false)
	_set_player_visual_visible(player, true)
	player_inside = false
	player.global_position = _get_inside_position(player)
	_set_side_collision_enabled(true)
	_set_player_barrel_hop_animation_active(player, true)
	await _hop_player_to(player, _get_exit_position(player))
	_set_player_barrel_hop_animation_active(player, false)

	_set_player_collision_enabled(player, true)
	_set_side_collision_enabled(true)
	_set_player_locked(player, false)
	inside_player = null
	nearby_player = player
	transition_in_progress = false
	_update_tooltip()

func _build_side_collision() -> void:
	var wall_body := StaticBody3D.new()
	wall_body.name = "SideCollision"
	add_child(wall_body)

	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(wall_segment_width, collision_height, wall_thickness)

	var segment_total := maxi(wall_segment_count, 3)
	for index in range(segment_total):
		var angle := TAU * float(index) / float(segment_total)
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "WallSegment%02d" % index
		collision_shape.shape = wall_shape
		collision_shape.position = Vector3(cos(angle) * collision_radius, collision_center_y, sin(angle) * collision_radius)
		collision_shape.rotation.y = (PI / 2.0) - angle
		wall_body.add_child(collision_shape)
		side_collision_shapes.append(collision_shape)

func _build_interaction_area() -> void:
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.position = interaction_center
	area.body_entered.connect(_on_interaction_area_body_entered)
	area.body_exited.connect(_on_interaction_area_body_exited)
	add_child(area)

	var shape := SphereShape3D.new()
	shape.radius = interaction_radius

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	area.add_child(collision_shape)

func _build_tooltip() -> void:
	prompt_label = Label3D.new()
	prompt_label.name = "InteractionPrompt"
	prompt_label.position = tooltip_offset
	prompt_label.font_size = 32
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.no_depth_test = true
	add_child(prompt_label)

func _on_interaction_area_body_entered(body: Node) -> void:
	if not _is_player_body(body):
		return

	nearby_player = body as CharacterBody3D
	_update_tooltip()

func _on_interaction_area_body_exited(body: Node) -> void:
	if body == nearby_player and not player_inside:
		nearby_player = null
		_update_tooltip()

func _hop_player_to(player: CharacterBody3D, target_position: Vector3) -> void:
	var start_position := player.global_position
	var middle_position := start_position.lerp(target_position, 0.5)
	middle_position.y += hop_height

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "global_position", middle_position, hop_duration * 0.5)
	tween.tween_property(player, "global_position", target_position, hop_duration * 0.5)
	await tween.finished

func _get_inside_position(player: CharacterBody3D = null) -> Vector3:
	var target_position := global_transform * occupied_player_offset
	if player != null:
		target_position.y = player.global_position.y

	return target_position

func _get_exit_position(player: CharacterBody3D = null) -> Vector3:
	var target_position := global_transform * exit_offset
	if player != null:
		target_position.y = player.global_position.y

	return target_position

func _update_tooltip() -> void:
	if prompt_label == null:
		return

	prompt_label.visible = player_inside or nearby_player != null
	prompt_label.text = exit_prompt if player_inside else enter_prompt

func _face_tooltip_to_camera() -> void:
	if prompt_label == null or not prompt_label.visible:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	prompt_label.global_position = global_position + tooltip_offset
	prompt_label.look_at(camera.global_position, Vector3.UP)
	prompt_label.rotate_y(PI)

func _is_player_body(body: Node) -> bool:
	return body is CharacterBody3D and body.name == "Player"

func _set_player_locked(player: CharacterBody3D, is_locked: bool) -> void:
	if player.has_method("set_interaction_locked"):
		player.set_interaction_locked(is_locked)

func _set_player_visual_visible(player: CharacterBody3D, is_visible: bool) -> void:
	if player.has_method("set_character_visual_visible"):
		player.set_character_visual_visible(is_visible)

func _set_player_collision_enabled(player: CharacterBody3D, is_enabled: bool) -> void:
	if player.has_method("set_player_collision_enabled"):
		player.set_player_collision_enabled(is_enabled)

func _set_player_movement_speed_multiplier(player: CharacterBody3D, multiplier: float) -> void:
	if player.has_method("set_movement_speed_multiplier"):
		player.set_movement_speed_multiplier(multiplier)

func _set_player_manual_jump_enabled(player: CharacterBody3D, is_enabled: bool) -> void:
	if player.has_method("set_manual_jump_enabled"):
		player.set_manual_jump_enabled(is_enabled)

func _set_player_barrel_animation_mode_enabled(player: CharacterBody3D, is_enabled: bool) -> void:
	if player.has_method("set_barrel_animation_mode_enabled"):
		player.set_barrel_animation_mode_enabled(is_enabled)

func _set_player_barrel_hop_animation_active(player: CharacterBody3D, is_active: bool) -> void:
	if player.has_method("set_barrel_hop_animation_active"):
		player.set_barrel_hop_animation_active(is_active)

func _set_side_collision_enabled(is_enabled: bool) -> void:
	for collision_shape in side_collision_shapes:
		if is_instance_valid(collision_shape):
			collision_shape.set_deferred("disabled", not is_enabled)

func _sync_barrel_to_player(player: CharacterBody3D) -> void:
	var synced_position := global_position
	synced_position.x = player.global_position.x - occupied_player_offset.x
	synced_position.z = player.global_position.z - occupied_player_offset.z
	global_position = synced_position

func _update_barrel_lift_for_player(player: CharacterBody3D) -> void:
	var ground_speed := Vector2(player.velocity.x, player.velocity.z).length()
	_set_barrel_lifted(ground_speed > movement_threshold)

func _set_barrel_lifted(is_lifted: bool) -> void:
	if barrel_lifted == is_lifted:
		return

	barrel_lifted = is_lifted
	if lift_tween != null:
		lift_tween.kill()

	var target_y := barrel_base_y + occupied_lift_height if barrel_lifted else barrel_base_y
	lift_tween = create_tween()
	lift_tween.set_trans(Tween.TRANS_SINE)
	lift_tween.set_ease(Tween.EASE_OUT)
	lift_tween.tween_property(self, "global_position:y", target_y, lift_transition_time)

func _ensure_music_filter() -> void:
	var bus_index := _ensure_audio_bus(music_bus_name)
	if bus_index == -1:
		return

	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		var existing_filter := AudioServer.get_bus_effect(bus_index, effect_index) as AudioEffectLowPassFilter
		if existing_filter != null:
			music_filter = existing_filter
			AudioServer.set_bus_effect_enabled(bus_index, effect_index, false)
			return

	music_filter = AudioEffectLowPassFilter.new()
	music_filter.cutoff_hz = normal_music_cutoff_hz
	AudioServer.add_bus_effect(bus_index, music_filter)
	AudioServer.set_bus_effect_enabled(bus_index, AudioServer.get_bus_effect_count(bus_index) - 1, false)

func _ensure_audio_bus(bus_name: String) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		return bus_index

	AudioServer.add_bus(AudioServer.get_bus_count())
	AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus_name)
	return AudioServer.get_bus_index(bus_name)

func _set_music_muffled(is_muffled: bool) -> void:
	var bus_index := _ensure_audio_bus(music_bus_name)
	if bus_index == -1:
		return

	if music_filter == null:
		_ensure_music_filter()

	if music_filter == null:
		return

	var effect_index := _get_music_filter_index(bus_index)
	if effect_index == -1:
		return

	if music_filter_tween != null:
		music_filter_tween.kill()

	AudioServer.set_bus_effect_enabled(bus_index, effect_index, true)
	var target_cutoff := inside_music_cutoff_hz if is_muffled else normal_music_cutoff_hz
	music_filter_tween = create_tween()
	music_filter_tween.set_trans(Tween.TRANS_SINE)
	music_filter_tween.set_ease(Tween.EASE_OUT)
	music_filter_tween.tween_property(music_filter, "cutoff_hz", target_cutoff, music_filter_transition_time)

	if not is_muffled:
		music_filter_tween.tween_callback(func() -> void:
			var current_bus_index := AudioServer.get_bus_index(music_bus_name)
			if current_bus_index == -1:
				return

			var current_effect_index := _get_music_filter_index(current_bus_index)
			if current_effect_index != -1:
				AudioServer.set_bus_effect_enabled(current_bus_index, current_effect_index, false)
		)

func _get_music_filter_index(bus_index: int) -> int:
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		if AudioServer.get_bus_effect(bus_index, effect_index) == music_filter:
			return effect_index

	return -1

func _restore_music_filter_immediately() -> void:
	if music_filter_tween != null:
		music_filter_tween.kill()

	var bus_index := AudioServer.get_bus_index(music_bus_name)
	if bus_index == -1 or music_filter == null:
		return

	var effect_index := _get_music_filter_index(bus_index)
	if effect_index == -1:
		return

	music_filter.cutoff_hz = normal_music_cutoff_hz
	AudioServer.set_bus_effect_enabled(bus_index, effect_index, false)

func is_pressure_plate_weight_source() -> bool:
	return true
