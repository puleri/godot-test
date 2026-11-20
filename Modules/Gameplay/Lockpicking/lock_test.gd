extends Node3D

enum Mechanism { DIAL, SLIDERS, TIMING }
enum Phase { APPROACH, PICKING, OPENING, OPEN }

@export var mechanism: Mechanism = Mechanism.DIAL

@onready var player: CharacterBody3D = $Rook
@onready var camera: Camera3D = $Camera
@onready var dial: Node3D = $Hinge/DoorBody/LockPlate/Dial
@onready var hud: Control = $Overlay/HUD
@onready var hound := get_node_or_null("Hound") as CharacterBody3D

var phase := Phase.APPROACH
var angle := -1.15
var height := 0.17
var stage := 0
var beat := 0.0
var cursor := 0.0
var feedback := ""
var feedback_time := 0.0
var gamepad := false
var view_distance := Vector3(-3.0, 3.3, 6.2)
var view_target := Vector3(0, 1.1, 0.7)

func _ready() -> void:
	var plumage := StandardMaterial3D.new()
	plumage.albedo_color = Color("#263141")
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color("#65432e")
	for piece: MeshInstance3D in player.find_children("*", "MeshInstance3D", true, false):
		var part := String(piece.name).to_lower()
		if "eye" in part or "sphere" in part:
			continue
		piece.material_override = leather if "satchel" in part or "strap" in part else plumage
	if mechanism == Mechanism.TIMING:
		view_distance = Vector3(-5.4, 7.8, 9.0)
		view_target = Vector3(-1, 0.6, 1.5)
	dial.visible = mechanism == Mechanism.DIAL
	camera.position = view_target + view_distance
	camera.look_at(view_target)
	dial.rotation.z = angle

func in_reach() -> bool:
	return player.is_on_floor() and player.position.z > 0 and player.position.distance_to(Vector3(0.55, 0, 0.6)) < 1.22

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		gamepad = true
	elif event is InputEventKey:
		gamepad = false

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.PICKING and event.is_action_pressed("secondary_action"):
		_leave_lock()
	elif event.is_action_pressed("interact"):
		if phase == Phase.APPROACH and in_reach():
			phase = Phase.PICKING
			player.set_physics_process(false)
			player.velocity = Vector3.ZERO
			player.position = Vector3(0.34, 0, 0.73)
			player.get_node("Crow").rotation.y = -0.25
			player.get_node("AnimationPlayer").play("Idle")
			player.get_node("AnimationPlayer").advance(0.1)
			feedback_time = 0
			_on_lock_entered()
		elif phase == Phase.PICKING:
			_attempt()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()

func _on_lock_entered() -> void:
	pass

func _leave_lock() -> void:
	phase = Phase.APPROACH
	player.set_physics_process(true)

func _process(delta: float) -> void:
	feedback_time = maxf(0, feedback_time - delta)
	var target := view_target
	var eye := target + view_distance
	if phase == Phase.PICKING:
		var pose := _focus_camera(delta)
		target = pose[0]
		eye = pose[1]
	var blend := 1.0 - exp(-7.0 * delta)
	camera.position = camera.position.lerp(eye, blend)
	var facing := camera.global_transform.looking_at(target, Vector3.UP).basis
	camera.basis = camera.basis.slerp(facing, blend)
	hud.queue_redraw()

func _focus_camera(delta: float) -> Array[Vector3]:
	var target := view_target
	var eye := target + view_distance
	match mechanism:
		Mechanism.DIAL:
			angle = clampf(angle - Input.get_axis("move_left", "move_right") * delta * 1.7, -PI, PI)
			dial.rotation.z = angle
			target = dial.global_position
			eye = target + Vector3(0.50, 0.20, 1.30)
		Mechanism.SLIDERS:
			height = clampf(height + Input.get_axis("move_down", "move_up") * delta * 0.75, 0, 1)
			target = Vector3(0.9, 1.20, 0.25)
			eye = target + Vector3(-1.5, 0.92, 3.8)
		Mechanism.TIMING:
			beat += delta * (0.7 + stage * 0.12)
			cursor = pingpong(beat, 1)
	return [target, eye]

func gate_target() -> float:
	return [0.73, 0.36, 0.64][mini(stage, 2)]

func _attempt() -> void:
	var success := false
	match mechanism:
		Mechanism.DIAL:
			success = absf(angle) <= 0.15
		Mechanism.SLIDERS:
			success = absf(height - 0.57) <= 0.085
		Mechanism.TIMING:
			success = absf(cursor - gate_target()) <= 0.105
	$Sound.pitch_scale = 2.1 if success else 0.85
	$Sound.play()
	if not success:
		feedback = "The lock catches" if mechanism == Mechanism.DIAL else "Missed"
		feedback_time = 0.7
		if mechanism == Mechanism.TIMING and hound.position.distance_to(player.position) < 3.25:
			feedback = "The Hound heard you • Step back"
			feedback_time = 1.8
			stage = 0
			_leave_lock()
		return
	stage += 1
	if mechanism != Mechanism.DIAL and stage < 3:
		height = 0.91 if stage == 1 else 0.12
		feedback = "Set"
		feedback_time = 0.45
		return
	_open_door()

func _open_door() -> void:
	phase = Phase.OPENING
	feedback_time = 0
	var swing := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing.tween_property($Hinge/DoorBody/Bolt, "position:x", 1.39, 0.12)
	swing.tween_property($Hinge, "rotation:y", deg_to_rad(98), 0.68)
	await swing.finished
	phase = Phase.OPEN
	player.set_physics_process(true)
