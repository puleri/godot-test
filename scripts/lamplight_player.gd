extends "res://scripts/exchange_player.gd"
## Threshold-aware camera with hysteresis; movement remains camera-relative.
const CUTAWAY_LAYER := 1 << 18
@export var exterior_camera_size := 30.0
@export var interior_camera_size := 15.5
@export var camera_transition_rate := 4.5
@export var interior_bounds := AABB(Vector3(-7, -1, -14), Vector3(14, 5, 12))
var indoors := false
var indoor_blend := 0.0
var concealed := false
var peeking := false
var hide_anchor := Vector3.ZERO
var _camera_initialized := false


func _update_phase_camera() -> void:
	if overview_camera == null:
		return
	var at := global_position
	if indoors:
		if not interior_bounds.grow(0.6).has_point(at):
			indoors = false
	elif interior_bounds.grow(-0.4).has_point(at):
		indoors = true
	var delta := get_physics_process_delta_time()
	var weight := 1.0 - exp(-camera_transition_rate * delta)
	indoor_blend = lerpf(indoor_blend, 1.0 if indoors else 0.0, weight)
	var outdoor_focus := Vector3(at.x * 0.5, 0.4, at.z * 0.4 - 2)
	var center := interior_bounds.get_center()
	var indoor_focus := Vector3(center.x + (at.x - center.x) * 0.18, 0.4, center.z + (at.z - center.z) * 0.16)
	if peeking:
		indoor_focus.z += 0.6
	var target := outdoor_focus.lerp(indoor_focus, indoor_blend)
	if not _camera_initialized:
		_focus = target
		_camera_initialized = true
	_focus = _focus.lerp(target, 1.0 - exp(-6 * delta))
	overview_camera.size = lerpf(exterior_camera_size, interior_camera_size, indoor_blend)
	overview_camera.global_position = _focus + Vector3(16, 26, 23).lerp(Vector3(10, 20, 16), indoor_blend)
	overview_camera.look_at(_focus)
	# Camera culling preserves the roof's real light shadows and collision.
	overview_camera.set_cull_mask_value(19, not indoors)


func enter_hide(at: Vector3) -> void:
	concealed = true
	peeking = false
	hide_anchor = at
	global_position = at
	set_interaction_locked(true)
	visual_pivot.hide()
	$PlayerMarker.hide()


func set_peeking(enabled: bool) -> void:
	if not concealed:
		return
	peeking = enabled
	global_position = hide_anchor + (Vector3(0, 0, 1.0) if enabled else Vector3.ZERO)
	visual_pivot.visible = enabled
	$PlayerMarker.visible = enabled


func leave_hide() -> void:
	if not concealed:
		return
	global_position = hide_anchor + Vector3(0, 0, 1.0)
	concealed = false
	peeking = false
	visual_pivot.show()
	$PlayerMarker.show()
	set_interaction_locked(false)
