extends Area3D
## Reusable objective, with existing coin art and a player-only pickup trigger.

signal recovered(seal: Area3D)
@export var display_name := "CARGO SEAL"
var collected := false


func _ready() -> void:
	$Caption.text = display_name
	body_entered.connect(recover)


func _process(delta: float) -> void:
	if not collected:
		$Visual.rotation.y += delta * 1.2
		$Visual.position.y = 0.85 + sin(Time.get_ticks_msec() * 0.002) * 0.08


func recover(body: Node3D) -> void:
	if collected or not body.is_in_group("stealth_player"):
		return
	collected = true
	set_deferred("monitoring", false)
	$Visual.hide()
	$Ring.hide()
	$Caption.text = "RECOVERED"
	$Caption.modulate = Color("87c8bb")
	recovered.emit(self)
