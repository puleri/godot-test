extends PanelContainer
## Show the action across the quay while the player's own camera follows Rook.

const FEEDBACK_LAYER := 19
const FEEDBACK_MASK := 1 << (FEEDBACK_LAYER - 1)
const OFFICE_SPEECH_LAYER := 15

@onready var view: SubViewport = $Column/Picture/View
@onready var lens: Camera3D = $Column/Picture/View/Lens
@onready var caption: Label = $Column/Caption
var subject: Node3D
var gangway_post: Node3D
var time_left := 0.0
var office_view := false:
	set(inside):
		office_view = inside
		visible = not inside and time_left > 0.0


func _ready() -> void:
	view.world_3d = get_viewport().world_3d
	lens.set_cull_mask_value(FEEDBACK_LAYER, false)
	lens.set_cull_mask_value(OFFICE_SPEECH_LAYER, false)
	set_process(false)


func follow(actor: Node3D, line: String, seconds: float, post: Node3D = null) -> void:
	subject = actor
	gangway_post = post
	time_left = seconds
	caption.text = line
	_frame_subject()
	visible = not office_view
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	set_process(true)


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0 or not is_instance_valid(subject):
		hide()
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)
		return
	_frame_subject()


func _frame_subject() -> void:
	var focus := subject.global_position + Vector3.UP * 0.88
	if gangway_post:
		# Frame the two sides of the dispute through the gap east of the bell.
		focus = gangway_post.global_position + Vector3(-0.88, 0.83, 1.11)
		lens.global_position = focus + Vector3(0.96, 1.22, 3.34)
	else:
		lens.global_position = focus + Vector3(1.35, 0.65, 2.75)
	lens.look_at(focus)
