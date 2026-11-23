extends "res://scripts/exchange_player.gd"
## Shift from the dock overview to a closer view through the cutaway hull.

const LANTERN := preload("res://Modules/Gameplay/LastBarrel/search_lantern.tscn")
const OFFICE := preload("res://Modules/Gameplay/LastBarrel/office_layout.gd")
const Cutaway := preload("res://Modules/Gameplay/LastBarrel/dock_cutaway.gd")
const OFFICE_SHARED := 1 << 15
const OFFICE_GROUND := 1 << 16
const OFFICE_UPPER := 1 << 17
const OFFICE_SPEECH := 1 << (Cutaway.OFFICE_SPEECH_LAYER - 1)

signal office_view_changed(inside: bool)

var aboard := false
var quay_intro := 6.0
var _lantern: Node3D
var _skeleton: Skeleton3D
var _hand: int
var _enabled_msaa := false
var _office_environment: Environment
var _quay_mask: int
var _office_mask := 0
var _master_mask := 1
var print_study_treatment := true

@onready var _office := $"../Quay/Office"
@onready var _master := $"../People/Shipmaster" as Node3D


func _ready() -> void:
	super._ready()
	overview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	overview_camera.fov = 46.0
	overview_camera.environment = null
	_quay_mask = overview_camera.cull_mask
	_office_environment = get_world_3d().environment.duplicate() as Environment
	_office_environment.background_mode = Environment.BG_COLOR
	_office_environment.background_color = Color.BLACK
	_office_environment.ambient_light_energy = 0.12
	_set_render_layer(self, OFFICE_SHARED)
	_set_render_layer(_office.get_node("GroundFloor"), OFFICE_GROUND)
	_set_render_layer(_office.get_node("UpperFloor"), OFFICE_UPPER)
	_set_render_layer(_office.get_node("Staircase"), OFFICE_SHARED)
	if get_viewport().msaa_3d == Viewport.MSAA_DISABLED:
		get_viewport().msaa_3d = Viewport.MSAA_2X
		_enabled_msaa = true


func begin_ship_search() -> void:
	if aboard:
		return
	_set_office_view(0)
	aboard = true
	$PlayerMarker.hide()
	_lantern = LANTERN.instantiate()
	add_child(_lantern)
	set_print_study_treatment(print_study_treatment)
	_skeleton = visual_pivot.find_children("*", "Skeleton3D", true, false)[0]
	_hand = _skeleton.find_bone("Wrist_R")
	_update_lantern()
	# Let rooms, ribs and crates recede in perspective as Rook approaches them.
	overview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	overview_camera.fov = 42.0
	overview_camera.environment = null
	_focus = global_position
	_update_phase_camera()


func set_print_study_treatment(enabled: bool) -> void:
	print_study_treatment = enabled
	if is_instance_valid(_lantern):
		var light := _lantern.get_node("LanternLight") as OmniLight3D
		light.light_energy = 1.7 if enabled else 0.74
		light.omni_range = 1.25 if enabled else 2.65


func _exit_tree() -> void:
	if _enabled_msaa:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED


func _process(_delta: float) -> void:
	if aboard:
		_update_lantern()
	else:
		_update_office_actors()


func _update_lantern() -> void:
	# Only follow the wrist position. A weighted oil lantern hangs upright as the wing turns.
	var wrist := _skeleton.to_global(_skeleton.get_bone_global_pose(_hand).origin)
	_lantern.global_position = wrist + visual_pivot.global_basis.z.normalized() * 0.213 - Vector3.UP * 0.068
	_lantern.rotation.y = visual_pivot.rotation.y
	_lantern.rotation.z = clampf(-velocity.dot(visual_pivot.global_basis.x.normalized()) * 0.03, -0.14, 0.14)


func _update_phase_camera() -> void:
	if overview_camera == null:
		return
	if not aboard:
		_frame_quay()
		return
	var at := global_position
	# The deck establishes the mast and hatch. Below, ease closer to read the tags.
	var inside := smoothstep(3.5, 7.0, at.x)
	var cabin := smoothstep(21.0, 24.0, at.x)
	var offset := Vector3(2.15, 4.0, 7.5).lerp(Vector3(1.65, 2.4, 6.15), inside)
	offset = offset.lerp(Vector3(1.2, 2.2, 5.0), cabin)
	var lead := Vector3(velocity.x, 0, velocity.z) * 0.15
	var target := at + Vector3(0.45, 0.32, -0.35) + lead
	_focus = _focus.lerp(target, 1.0 - exp(-7.5 * get_physics_process_delta_time()))
	overview_camera.global_position = _focus + offset
	overview_camera.look_at(_focus)


func _frame_quay() -> void:
	var at := global_position
	var inside := OFFICE.contains(at)
	var floor_mask := 0
	if inside:
		# Reveal the writing room near the top of the stair. The margin keeps
		# the view steady as Rook moves across the edge of the landing.
		var upper_height := 2.68 if _office_mask == OFFICE_UPPER else 2.93
		floor_mask = OFFICE_UPPER if at.y >= upper_height else OFFICE_GROUND
	_set_office_view(floor_mask)
	quay_intro = 0.0 if velocity.length() > 1.0 or interaction_locked else maxf(0.0, quay_intro - get_physics_process_delta_time())
	var wide := 0.0 if inside else smoothstep(0.0, 2.0, quay_intro)
	var near_south_wall := smoothstep(12.0, 16.6, at.z)
	var offset := Vector3(2.25, 4.0 + 2.4 * near_south_wall, 7.55)
	var overhead := 0.0
	if inside:
		offset = Vector3(2.9, 8.6, 4.0)
	else:
		# Pull the lens over Rook in the narrow alleys behind the office and
		# keep its heading so camera-relative controls stay consistent.
		var rear_alley := smoothstep(OFFICE.REAR - 6.0, OFFICE.REAR - 1.4, at.z)
		rear_alley *= 1.0 - smoothstep(0.0, 2.4, maxf(OFFICE.WEST - at.x, at.x - OFFICE.EAST))
		var west_alley := smoothstep(OFFICE.WEST - 5.0, OFFICE.WEST - 1.4, at.x)
		west_alley *= 1.0 - smoothstep(0.0, 2.4, maxf(OFFICE.REAR - at.z, at.z - OFFICE.FRONT))
		overhead = maxf(rear_alley if at.z <= OFFICE.REAR else 0.0, west_alley if at.x <= OFFICE.WEST else 0.0)
		offset = offset.lerp(Vector3(0.18, 9.7, 0.60), overhead)
	var lead := Vector3(velocity.x, 0, velocity.z) * 0.18
	var target := at + Vector3(0, 0.34, lerpf(-0.92, 0, overhead)) + lead
	_focus = _focus.lerp(target, 1.0 - exp(-6.5 * get_physics_process_delta_time()))
	var focus := _focus.lerp(Vector3(-2.0, 1.2, 7.0), wide)
	var eye := focus + (offset * (follow_size / 11.1)).lerp(Vector3(14, 28, 39), wide)
	if not inside:
		# Keep the exterior lens and its near plane above the roof as the
		# follow camera passes over the building.
		var overhang := maxf(maxf(OFFICE.WEST - eye.x, eye.x - OFFICE.EAST),
			maxf(OFFICE.REAR - eye.z, eye.z - OFFICE.FRONT))
		eye.y = lerpf(maxf(eye.y, OFFICE.ROOF_PEAK + 0.55), eye.y, smoothstep(0.55, 2.5, overhang))
	overview_camera.global_position = eye
	overview_camera.look_at(focus)


func _set_office_view(floor_mask: int) -> void:
	if floor_mask == _office_mask:
		return
	var was_inside := _office_mask != 0
	_office_mask = floor_mask
	var inside := floor_mask != 0
	overview_camera.cull_mask = (OFFICE_SHARED | OFFICE_SPEECH | floor_mask) if inside else _quay_mask
	overview_camera.environment = _office_environment if inside else null
	if inside and not was_inside:
		_set_render_layer($"../People/TeaWatch", OFFICE_GROUND)
		_set_render_layer($"../People/LandingWatch", OFFICE_UPPER)
	_update_office_actors()
	if inside != was_inside:
		office_view_changed.emit(inside)


func _update_office_actors() -> void:
	var mask := 1
	if OFFICE.contains(_master.global_position):
		mask = OFFICE_UPPER if _master.global_position.y >= OFFICE.UPPER_HEIGHT - 0.2 else OFFICE_GROUND
	if mask != _master_mask:
		_master_mask = mask
		_set_render_layer(_master, mask)
	var speech := _master.get_node("Speech") as Label3D
	speech.layers = Cutaway.FEEDBACK_MASK if _office_mask == 0 else OFFICE_SPEECH
	speech.visible = _office_mask == 0 or _office_mask == mask


func _set_render_layer(root: Node, mask: int) -> void:
	for visual: VisualInstance3D in root.find_children("*", "VisualInstance3D", true, false):
		if (visual.layers & (Cutaway.FEEDBACK_MASK | OFFICE_SPEECH)) == 0:
			visual.layers = mask
