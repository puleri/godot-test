extends Node3D

@export var target_door_path: NodePath
@export var weight_area_path: NodePath = ^"WeightArea"
@export var plate_visual_path: NodePath = ^"PlateVisual"
@export var inactive_material: Material
@export var active_material: Material
@export var depressed_offset_y: float = -0.035
@export var depress_time: float = 0.08
@export var release_time: float = 0.12

var target_door: Node
var weight_area: Area3D
var plate_visual: MeshInstance3D
var raised_plate_y: float
var active := false
var plate_tween: Tween

func _ready() -> void:
	if target_door_path != NodePath(""):
		target_door = get_node_or_null(target_door_path)

	weight_area = get_node_or_null(weight_area_path) as Area3D
	plate_visual = get_node_or_null(plate_visual_path) as MeshInstance3D

	if weight_area == null:
		push_warning("PressurePlate could not find WeightArea.")

	if target_door == null:
		push_warning("PressurePlate could not find target door: %s" % target_door_path)

	if plate_visual != null:
		raised_plate_y = plate_visual.position.y
		_set_plate_material(inactive_material)

func _exit_tree() -> void:
	_set_target_door_open(false)

func _physics_process(_delta: float) -> void:
	if weight_area == null:
		return

	_set_active(_has_valid_weight())

func _has_valid_weight() -> bool:
	for body in weight_area.get_overlapping_bodies():
		if _is_valid_weight_body(body):
			return true

	return false

func _is_valid_weight_body(body: Node) -> bool:
	if body is CharacterBody3D and body.name == "Player":
		return true

	var current := body
	while current != null:
		if current.has_method("is_pressure_plate_weight_source") and current.call("is_pressure_plate_weight_source"):
			return true

		current = current.get_parent()

	return false

func _set_active(is_active: bool) -> void:
	if active == is_active:
		return

	active = is_active
	_set_plate_material(active_material if active else inactive_material)
	_tween_plate(active)
	_set_target_door_open(active)

func _set_plate_material(material: Material) -> void:
	if plate_visual == null or material == null:
		return

	plate_visual.material_override = material

func _tween_plate(is_pressed: bool) -> void:
	if plate_visual == null:
		return

	if plate_tween != null:
		plate_tween.kill()

	var target_y := raised_plate_y + depressed_offset_y if is_pressed else raised_plate_y
	plate_tween = create_tween()
	plate_tween.set_trans(Tween.TRANS_SINE)
	plate_tween.set_ease(Tween.EASE_OUT)
	plate_tween.tween_property(plate_visual, "position:y", target_y, depress_time if is_pressed else release_time)

func _set_target_door_open(is_open: bool) -> void:
	if target_door == null:
		return

	if target_door.has_method("set_pressure_open"):
		target_door.call("set_pressure_open", is_open)
