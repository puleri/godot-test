extends Node3D
## Screen-sized character feedback, projected from a world-space head anchor.
const CREAM := Color("fff4dc")
const AMBER := Color("ffca76")
const CORAL := Color("ff7468")
const HEIGHT := 48.0

var guard: StealthGuard
var enabled := true
var _layer: CanvasLayer
var _anchor: Node2D
var _art: Sprite2D
var _motion: Tween
var _state := 0 # 0 clear, 1 suspicious, 2 confirmed pursuit
var _phase := 0.0
var _entrance_drop := 0.0
var _occluded := false
var _frozen := false


func _ready() -> void:
	guard = get_parent() as StealthGuard
	_layer = CanvasLayer.new()
	_layer.layer = 4
	add_child(_layer)
	_anchor = Node2D.new()
	_layer.add_child(_anchor)
	_art = Sprite2D.new()
	_art.texture = preload("res://textures/Exclamation.png")
	_art.scale = Vector2.ONE * HEIGHT / _art.texture.get_height()
	# The pointed tail stays at the head anchor as the bubble stretches upward.
	_art.offset.y = -_art.texture.get_height() * 0.5
	_anchor.add_child(_art)
	_anchor.modulate.a = 0.0
	_anchor.hide()


func refresh() -> void:
	var next := 0
	if guard.guard_state == StealthGuard.GuardState.CHASE:
		next = 2
	elif guard.guard_state == StealthGuard.GuardState.SUSPICIOUS or (guard.guard_state == StealthGuard.GuardState.SEARCH and guard.awareness > 0.01):
		next = 1
	if next != _state:
		var previous := _state
		_state = next
		_entrance_drop = 0.0
		if _motion:
			_motion.kill()
		_motion = create_tween()
		if next == 0:
			_motion.set_parallel(true)
			_motion.tween_property(_anchor, "modulate:a", 0.0, 0.18)
			_motion.tween_property(_anchor, "scale", Vector2.ONE * 0.8, 0.18)
		elif next == 2:
			_anchor.rotation = 0.0
			_anchor.modulate.a = 1.0
			_motion.tween_property(_anchor, "scale", Vector2.ONE * 1.2, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_motion.tween_property(_anchor, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif previous == 0:
			_entrance_drop = 8.0
			_anchor.scale = Vector2(0.65, 0.6)
			_anchor.rotation = deg_to_rad(-8)
			_anchor.modulate.a = 0.0
			_motion.set_parallel(true)
			_motion.tween_property(self, "_entrance_drop", 0.0, 0.12)
			_motion.tween_property(_anchor, "modulate:a", 1.0, 0.08)
			_motion.tween_property(_anchor, "scale", Vector2(0.92, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_motion.tween_property(_anchor, "rotation", 0.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_motion.chain().tween_property(_anchor, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			_motion.tween_property(_anchor, "scale", Vector2.ONE, 0.12)
	# Modulate the pale paper while preserving the PNG's black exclamation mark.
	var target := CORAL if next == 2 else CREAM.lerp(AMBER, clampf(guard.awareness, 0.0, 1.0))
	_art.modulate = target


func _process(delta: float) -> void:
	if not guard.active:
		if not _frozen and _motion:
			_motion.pause()
		_frozen = true
	else:
		_frozen = false
		refresh()
		_phase += delta
	var camera := get_viewport().get_camera_3d()
	var at := guard.global_position + Vector3.UP * (guard.eye_height + 0.65)
	_anchor.visible = enabled and guard.is_visible_in_tree() and camera != null and not _occluded and (_state != 0 or _anchor.modulate.a > 0.01)
	if camera == null or camera.is_position_behind(at):
		_anchor.hide()
		return
	_anchor.position = camera.unproject_position(at)
	_anchor.position.y += _entrance_drop
	# Two pixels of float; no continuous wobble or repeated entrance on lost sight.
	_anchor.position.y += sin(_phase * 2.6) * 2.0 if _state == 1 else 0.0


func _physics_process(_delta: float) -> void:
	if not enabled or _state == 0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var at := guard.global_position + Vector3.UP * (guard.eye_height + 0.65)
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, at, guard.sight_blocker_mask)
	query.exclude = [guard.get_rid()]
	_occluded = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func set_enabled(value: bool) -> void:
	enabled = value
	_process(0.0)
