extends "res://Modules/Gameplay/Lockpicking/lock_test.gd"

const ListeningPins := preload("res://Modules/Gameplay/Lockpicking/listening_pins.gd")
const CONTACTS := ListeningPins.CONTACTS
const SET_TIME := ListeningPins.SET_TIME
var pins := ListeningPins.new()

@onready var tools_rig: Node3D = $Hinge/DoorBody/LockPlate/Tools
@onready var probe: Node3D = tools_rig.get_node("Probe")
@onready var brace: Node3D = tools_rig.get_node("Brace")
@onready var tick: AudioStreamPlayer = $Tick

const CrowPlayer = preload("res://Characters/Crow/crow_player.gd")
@onready var bird: CrowPlayer = $Rook
@onready var handle: MeshInstance3D = probe.get_node("Grip")
@onready var shank: MeshInstance3D = probe.get_node("Pick")
@onready var ferrule: MeshInstance3D = probe.get_node("Ferrule")
@onready var bar: MeshInstance3D = brace.get_node("Wrench")
@onready var pad: MeshInstance3D = brace.get_node("LeatherPad")

func _ready() -> void:
	super()
	bird.performance.contacts_updated.connect(_place_tools)

var travel: float:
	get: return pins.travel
var contact: bool:
	get: return pins.contact
var glint := 0.0
var settling: float:
	get: return pins.settling
var pad_id := -1

func _input(event: InputEvent) -> void:
	super(event)
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		pad_id = event.device

func _on_lock_entered() -> void:
	player.position = Vector3(0.13, 0, 0.60)
	player.get_node("Crow").rotation.y = -0.65
	bird.performance.brace_target = tools_rig.to_global(Vector3(0.13, -0.18, 0.055))
	bird.performance.working = true
	tools_rig.show()
	_clear_touch()

func _clear_touch() -> void:
	pins.release()
	glint = 0

func _leave_lock() -> void:
	bird.performance.working = false
	tools_rig.hide()
	_clear_touch()
	super()

func _focus_camera(delta: float) -> Array[Vector3]:
	glint = maxf(0, glint - delta)
	if pins.sweep(Input.get_axis("move_left", "move_right"), delta):
		glint = 0.32
		_cue(1.25, 0.12)
	bird.performance.sweep = travel + settling * 0.1
	if pins.listen(Input.is_action_pressed("interact"), delta):
		_set_pin()
	var target := tools_rig.global_position + Vector3(-0.02, 0.035, 0)
	return [target, target + Vector3(0.12, 0.12, 1.04)]

func _attempt() -> void:
	if contact:
		pins.listening = true
		glint = SET_TIME
	else:
		feedback = "No contact"
		feedback_time = 0.65
		_cue(0.62, 0.0)

func _set_pin() -> void:
	stage = pins.seated
	_clear_touch()
	_cue(1.75, 0.28)
	if stage == CONTACTS.size():
		bird.performance.working = false
		tools_rig.hide()
		_open_door()
	else:
		feedback = "Pin seated"
		feedback_time = 0.65

func _cue(pitch: float, strength: float) -> void:
	tick.pitch_scale = pitch
	tick.play()
	if gamepad and strength > 0 and pad_id >= 0:
		Input.start_joy_vibration(pad_id, strength, 0, 0.065)

# Both ends use the same world-space character pose for every observer.
func _place_tools(bill_world: Vector3, wing_world: Vector3) -> void:
	var bill := probe.to_local(bill_world)
	var direction := bill.normalized()
	var collar := bill - direction * 0.07
	_span(shank, Vector3.ZERO, collar, 0.17)
	handle.position = bill
	handle.quaternion = Quaternion(Vector3.UP, direction)
	ferrule.position = collar
	ferrule.quaternion = handle.quaternion
	var wing := brace.to_local(wing_world)
	_span(bar, Vector3(0, -0.078, 0.02), wing, 0.145)
	pad.position = wing
	pad.quaternion = bar.quaternion

func _span(mesh: MeshInstance3D, start: Vector3, end: Vector3, length_at_rest: float) -> void:
	var span := end - start
	mesh.position = (start + end) * 0.5
	mesh.quaternion = Quaternion(Vector3.RIGHT, span.normalized())
	mesh.scale.x = span.length() / length_at_rest
