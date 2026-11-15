extends "res://scripts/stealth_test_player.gd"
## Uses Rook's existing locomotion and animation with an elevation-aware follow camera.
const CAMERA_DISTANCE := 8.602325 # Length of the original (0, 5, 7) offset.
const CAMERA_YAW_SPEED := 2.2
const CAMERA_PITCH_SPEED := 1.6
const CAMERA_MIN_PITCH := deg_to_rad(8.0)
const CAMERA_MAX_PITCH := deg_to_rad(70.0)

var camera_yaw := 0.0
var camera_pitch := atan2(5.0, 7.0)
var follow_focus := Vector3.ZERO
var spawn_position := Vector3.ZERO
func _ready() -> void:
	super._ready()
	spawn_position = global_position
	follow_focus = global_position + Vector3.UP * 0.5
	floor_snap_length = 0.4
	_update_phase_camera()
func _update_phase_camera() -> void:
	if overview_camera == null or not is_inside_tree():
		return
	# Cast from Rook's current position. A smoothed focus can cut through a wall
	# at a corner and put the ray origin inside geometry.
	var target := global_position + Vector3.UP * 0.7
	follow_focus = target
	var preferred := (Vector3.BACK * CAMERA_DISTANCE).rotated(Vector3.RIGHT, -camera_pitch)
	preferred = preferred.rotated(Vector3.UP, camera_yaw)
	var space := get_world_3d().direct_space_state
	var chosen := target + preferred
	var best_score := -INF
	for angle: float in [0.0, -45.0, 45.0, -90.0, 90.0, 180.0]:
		var offset := preferred.rotated(Vector3.UP, deg_to_rad(angle))
		var direction := offset.normalized()
		var query := PhysicsRayQueryParameters3D.create(target, target + offset, 1, [get_rid()])
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		var clear_distance := offset.length()
		if not hit.is_empty():
			clear_distance = maxf(0.0, target.distance_to(hit.position) - 0.45)
		var score := clear_distance - absf(angle) * 0.012
		if score > best_score:
			best_score = score
			chosen = target + direction * maxf(clear_distance, 1.25)
		# Keep the normal angle whenever it has a useful view.
		if angle == 0.0 and clear_distance >= 3.0:
			break
	# A narrow passage needs an overhead fallback rather than a camera at Rook's face.
	if best_score < 1.25:
		chosen = target + Vector3(0, 3.0, 0.5)
	overview_camera.global_position = chosen
	overview_camera.look_at(target)
	overview_camera.make_current()
func _physics_process(delta: float) -> void:
	var look := Input.get_vector("hub_look_left", "hub_look_right", "hub_look_up", "hub_look_down")
	camera_yaw = wrapf(camera_yaw - look.x * CAMERA_YAW_SPEED * delta, -PI, PI)
	camera_pitch = clampf(camera_pitch + look.y * CAMERA_PITCH_SPEED * delta, CAMERA_MIN_PITCH, CAMERA_MAX_PITCH)
	super._physics_process(delta)
	if global_position.y < 1.0:
		respawn()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		respawn()
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	follow_focus = global_position + Vector3.UP * 0.5
	reset_procedural_motion()
