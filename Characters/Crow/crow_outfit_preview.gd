extends Node3D

const OutfitMotion = preload("res://Characters/Crow/crow_outfit_motion.gd")
const DURATION := 4.4

@onready var crow: Node3D = $Crow
var _elapsed := 0.0


func _ready() -> void:
	var skeleton: Skeleton3D = crow.find_children("*", "Skeleton3D", true, false)[0]
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	var outfit := OutfitMotion.new()
	outfit.name = "CrowOutfitMotion"
	skeleton.add_child(outfit)


func _physics_process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, DURATION)
	# A quick shift and turn, then a hold so the coat and bag can settle.
	var shift := smoothstep(0.35, 0.75, _elapsed) - smoothstep(1.85, 2.33, _elapsed)
	var turn := smoothstep(0.47, 0.82, _elapsed) - smoothstep(1.92, 2.36, _elapsed)
	crow.position.x = 0.31 * shift
	crow.rotation.y = -0.65 * turn
