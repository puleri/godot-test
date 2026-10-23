extends Node3D
## A short, interruptible interaction; progress resets when Rook leaves or is seen.

@export var title := "MANIFEST"
@export var hold_seconds := 1.8
@export var clearance_guard: NodePath
@export var clearance_distance := 5.0
var completed := false
var progress := 0.0


func reset_progress() -> void:
	progress = 0.0


func guard_is_clear() -> bool:
	var guard := get_node_or_null(clearance_guard) as Node3D
	return guard == null or guard.global_position.distance_to(global_position) > clearance_distance


func advance(delta: float) -> bool:
	if completed:
		return false
	progress += delta
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
