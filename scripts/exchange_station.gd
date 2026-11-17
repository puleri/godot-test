extends Node3D
## A short, interruptible interaction; progress resets when Rook leaves or is seen.

@export var title := "MANIFEST"
@export var hold_seconds := 1.8
@export var clearance_guard: NodePath
@export var clearance_distance := 5.0
var completed := false
var progress := 0.0
var moving_part: Node3D
var _rest_transform := Transform3D.IDENTITY


func _ready() -> void:
	prepare_visuals()


func prepare_visuals() -> void:
	if moving_part != null:
		return
	var visual := get_node("Visual") as Node3D
	if name == "Manifest":
		moving_part = visual.get_child(1) as Node3D
		moving_part.name = "TurningPage"
	elif name == "Crank":
		var wheel := visual.get_node("Wheel") as Node3D
		var handle := visual.get_child(2) as Node3D
		moving_part = Node3D.new()
		moving_part.name = "CrankRotor"
		moving_part.position = wheel.position
		visual.add_child(moving_part)
		for part in [wheel, handle]:
			var local: Transform3D = part.transform
			part.owner = null
			visual.remove_child(part)
			moving_part.add_child(part)
			part.transform = local
			part.position -= moving_part.position
	else:
		# This objective uses coin art, but must never auto-collect on contact.
		visual.set_process(false)
		visual.remove_from_group("coins")
		var trigger := visual.get_node_or_null("Area3D") as Area3D
		if trigger:
			trigger.set_deferred("monitoring", false)
		moving_part = visual
	_rest_transform = moving_part.transform


func _pose_work() -> void:
	if moving_part == null:
		return
	moving_part.transform = _rest_transform
	var amount := clampf(progress / hold_seconds, 0.0, 1.0)
	if name == "Manifest":
		moving_part.rotation.z += sin(amount * PI * 4.0) * 0.3
		moving_part.position.y += absf(sin(amount * PI * 4.0)) * 0.1
	elif name == "Crank":
		moving_part.rotate_object_local(Vector3.FORWARD, amount * TAU * 2.0)
	else:
		moving_part.rotation.y += amount * TAU
		moving_part.position.y += amount * 0.4


func reset_progress() -> void:
	progress = 0.0
	_pose_work()
	$Caption.text = title


func guard_is_clear() -> bool:
	var guard := get_node_or_null(clearance_guard) as Node3D
	return guard == null or guard.global_position.distance_to(global_position) > clearance_distance


func advance(delta: float) -> bool:
	if completed:
		return false
	progress += delta
	_pose_work()
	$Caption.text = "%s\n%d%%" % [title, mini(100, int(progress / hold_seconds * 100))]
	if progress < hold_seconds:
		return false
	completed = true
	$Caption.text = title + "\nCOMPLETE"
	$Caption.modulate = Color("87d1c5")
	if name == "NightSeal":
		$Visual.hide()
	$Ring.material_override.albedo_color = Color("87d1c5")
	return true
