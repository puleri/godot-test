extends Node
## Own camera and pause-safe timeline; never changes the gameplay camera pose.
signal completed
@export var duration := 7.0
var active := false
var _camera: Camera3D
var _timeline: Tween
var _level: Node3D
var _fill: DirectionalLight3D

func start(level: Node3D) -> void:
	_level = level
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = Camera3D.new()
	_camera.name = "EstablishingCamera"
	_camera.fov = 64
	_camera.far = 900
	add_child(_camera)
	_frame(0.0)
	_camera.make_current()
	# A soft cinematic fill reveals the location; removed before gameplay so
	# the existing light-based stealth rules receive no extra illumination.
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-35,-30,0)
	_fill.light_color = Color("849ac4")
	_fill.light_energy = 0.28
	add_child(_fill)
	active = true
	level.player.set_interaction_locked(true)
	level.get_tree().paused = true
	_timeline = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_timeline.tween_method(_frame,0.0,1.0,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_timeline.tween_callback(finish)

func _frame(progress: float) -> void:
	_camera.position = Vector3(30,11,48).lerp(Vector3(22,9,39),progress)
	_camera.look_at(Vector3(-5,7,-65).lerp(Vector3(-2,6,-45),progress))

func _input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		finish()

func finish() -> void:
	if not active:
		return
	active = false
	_timeline.kill()
	_level.get_node("LevelCamera").make_current()
	_level.get_tree().paused = false
	_fill.visible = false
	_camera.queue_free()
	completed.emit()
	queue_free()
