extends "res://scripts/exchange_player.gd"
## Shift from the dock overview to a closer view through the cutaway hull.

const LANTERN := preload("res://Modules/Gameplay/LastBarrel/search_lantern.tscn")
var aboard := false
var quay_intro := 6.0
var _lantern: Node3D
var _skeleton: Skeleton3D
var _hand: int
var _enabled_msaa := false


func _ready() -> void:
	super._ready()
	overview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	overview_camera.fov = 46.0
	var harbor: Environment = get_world_3d().environment.duplicate()
	harbor.ambient_light_color = Color("a1b2ce")
	harbor.ambient_light_energy = 0.34
	harbor.glow_enabled = true
	harbor.glow_intensity = 0.5
	harbor.glow_hdr_threshold = 1.35
	harbor.ssao_enabled = true
	harbor.ssao_radius = 0.7
	harbor.fog_enabled = true
	harbor.fog_density = 0.002
	harbor.fog_light_color = Color("41526b")
	overview_camera.environment = harbor
	if get_viewport().msaa_3d == Viewport.MSAA_DISABLED:
		get_viewport().msaa_3d = Viewport.MSAA_2X
		_enabled_msaa = true


func begin_ship_search() -> void:
	if aboard:
		return
	aboard = true
	$PlayerMarker.hide()
	_lantern = LANTERN.instantiate()
	add_child(_lantern)
	_skeleton = visual_pivot.find_children("*", "Skeleton3D", true, false)[0]
	_hand = _skeleton.find_bone("Wrist_R")
	_update_lantern()
	# Let rooms, ribs and crates recede in perspective as Rook approaches them.
	overview_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	overview_camera.fov = 42.0
	overview_camera.environment = get_world_3d().environment.duplicate()
	var atmosphere := overview_camera.environment
	atmosphere.background_color = Color("263854")
	atmosphere.ambient_light_color = Color("9eb0d0")
	atmosphere.ambient_light_energy = 0.44
	atmosphere.ssao_enabled = true
	atmosphere.ssao_radius = 0.65
	atmosphere.ssao_intensity = 1.6
	atmosphere.glow_enabled = true
	atmosphere.glow_intensity = 0.48
	atmosphere.glow_hdr_threshold = 1.25
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("44536a")
	atmosphere.fog_density = 0.003
	atmosphere.fog_sky_affect = 0.0
	_focus = global_position
	_update_phase_camera()


func _exit_tree() -> void:
	if _enabled_msaa:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED


func _process(_delta: float) -> void:
	if aboard:
		_update_lantern()


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
	# At the threshold, lift the view over the eaves so the desk and both
	# sides of Rook's cover remain visible throughout the shipmaster's patrol.
	var office := (1.0 - smoothstep(-4.0, -2.7, at.x)) * (1.0 - smoothstep(3.3, 5.2, at.z))
	var frontage := get_node("../Quay/Office/UpperFrontage") as Node3D
	frontage.visible = office < 0.45
	quay_intro = 0.0 if velocity.length() > 1.0 or interaction_locked else maxf(0.0, quay_intro - get_physics_process_delta_time())
	var wide := smoothstep(0.0, 2.0, quay_intro)
	var near_south_wall := smoothstep(12.0, 16.6, at.z)
	var offset := Vector3(2.25, 4.0 + 2.4 * near_south_wall, 7.55)
	offset = offset.lerp(Vector3(2.9, 8.6, 4.0), office)
	var lead := Vector3(velocity.x, 0, velocity.z) * 0.18
	var target := at + Vector3(0, 0.34, -0.92) + lead
	_focus = _focus.lerp(target, 1.0 - exp(-6.5 * get_physics_process_delta_time()))
	var focus := _focus.lerp(Vector3(-2.0, 1.2, 7.0), wide)
	overview_camera.global_position = focus + (offset * (follow_size / 11.1)).lerp(Vector3(14, 28, 39), wide)
	overview_camera.look_at(focus)
