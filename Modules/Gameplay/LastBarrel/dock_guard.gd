extends "res://scripts/exchange_guard.gd"

const Cutaway := preload("res://Modules/Gameplay/LastBarrel/dock_cutaway.gd")
@export var fixed_post := false
@onready var barrel = $"../../Cargo/SpareBarrel"


func _ready() -> void:
	super._ready()
	_apply_flat_guard_lighting()
	_state_label.layers = Cutaway.FEEDBACK_MASK
	_vision_instance.layers = Cutaway.FEEDBACK_MASK


func _apply_flat_guard_lighting() -> void:
	# Lift the existing material colors in shadow while retaining scene lighting.
	# Duplicate per guard so civilians using the same scenes are unaffected.
	for mesh: MeshInstance3D in $VisualPivot/Model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			material.emission_enabled = true
			material.emission = source.albedo_color
			material.emission_energy_multiplier = 0.25
			mesh.set_surface_override_material(surface, material)


func can_see_player() -> bool:
	return not barrel.conceals(_player, self) and super.can_see_player()


func hear_sound(at: Vector3, audible_radius: float, kind := "SOUND") -> bool:
	return false if fixed_post else super.hear_sound(at, audible_radius, kind)


func _update_feedback(delta: float) -> void:
	super._update_feedback(delta)
	_state_label.visible = show_vision
	if fixed_post:
		_state_label.text = "SENTINEL\nROOK SPOTTED" if player_visible else "SENTINEL\nON POST"


func _physics_process(delta: float) -> void:
	if not fixed_post:
		super._physics_process(delta)
		return
	if not active:
		return
	player_visible = can_see_player()
	if player_visible:
		last_seen_position = _player.global_position
	_update_awareness(delta)
	if player_visible and global_position.distance_to(_player.global_position) < capture_distance:
		player_caught.emit()
	_update_feedback(delta)
