extends Area3D

@export var player_name: String = "Player"
@export var inside_is_negative_z := true

var entry_inside_by_body_id: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not _is_player_body(body):
		return

	var player := body as CharacterBody3D
	entry_inside_by_body_id[player.get_instance_id()] = _is_inside_side(player.global_position)

func _on_body_exited(body: Node) -> void:
	if not _is_player_body(body):
		return

	var player := body as CharacterBody3D
	var body_id := player.get_instance_id()
	if not entry_inside_by_body_id.has(body_id):
		return

	var entered_inside: bool = entry_inside_by_body_id[body_id]
	entry_inside_by_body_id.erase(body_id)

	var exited_inside := _is_inside_side(player.global_position)
	if entered_inside == exited_inside:
		return

	player.call("set_phase_1_camera_flipped", exited_inside)

func _is_player_body(body: Node) -> bool:
	return body is CharacterBody3D and body.name == player_name and body.has_method("set_phase_1_camera_flipped")

func _is_inside_side(global_point: Vector3) -> bool:
	var local_z := global_point.z - global_position.z
	return local_z < 0.0 if inside_is_negative_z else local_z > 0.0
