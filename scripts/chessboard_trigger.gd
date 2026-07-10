extends Area3D

@export var hover_amplitude: float = 0.12
@export var hover_frequency: float = 1.4
@export var rotation_speed: float = 0.7
@export var target_transition_method: StringName = &"transition_to_phase_2"

var activated: bool = false
var start_y: float = 0.0
var elapsed: float = 0.0

func _ready() -> void:
	start_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if activated:
		return

	elapsed += delta
	rotation.y += rotation_speed * delta
	position.y = start_y + sin(elapsed * TAU * hover_frequency) * hover_amplitude

func _on_body_entered(body: Node) -> void:
	if activated or not body.has_method(target_transition_method):
		return

	activated = true
	set_deferred("monitoring", false)
	body.call(target_transition_method, self)
