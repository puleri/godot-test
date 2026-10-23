extends SceneTree
## Verify the imported base idle, including interpolation and both player scales.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func _run() -> void:
	for path in ["res://Rook/v2/Rook_v2.fbx", "res://Objects/Rook.fbx", "res://scenes/Player_v2.tscn", "res://scenes/Player.tscn"]:
		_check_idle(path)
	print("ROOK IDLE CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)


func _check_idle(path: String) -> void:
	var model: Node3D = load(path).instantiate()
	root.add_child(model)
	model.set_physics_process(false)
	model.rotation.y = 0.73
	if model is CharacterBody3D:
		model.procedural_animation_enabled = false
		model.animation_tree.active = false
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clip := player.get_animation("Skeleton|Idle")
	var label := path.trim_prefix("res://")
	_check(clip.get_meta("rook_grounded_idle_version", 0) == 1, label + " contains the baked base idle")
	_check(clip.loop_mode == Animation.LOOP_LINEAR, label + " idle loops without controller setup")
	player.play("Skeleton|Idle")
	player.advance(0)
	var first := _pose(skeleton)
	var legs := [Vector3i(skeleton.find_bone("Bone.030"), skeleton.find_bone("Bone.032"), skeleton.find_bone("Bone.034")), Vector3i(skeleton.find_bone("Bone.031"), skeleton.find_bone("Bone.033"), skeleton.find_bone("Bone.035"))]
	var roots := [skeleton.find_bone("Spine"), skeleton.find_bone("Bone.027")]
	var max_foot_drift := 0.0
	var max_foot_rotation_error := 0.0
	var max_length_error := 0.0
	var max_root_mismatch := 0.0
	var body_range := Vector2(INF, -INF)
	var collider: Transform3D = model.get_node("CollisionShape3D").global_transform if model is CharacterBody3D else Transform3D.IDENTITY
	# 480 Hz intentionally samples between the 240 Hz baked keys over two loops.
	var samples := ceili(clip.length * 480.0)
	for frame in samples * 2 + 1:
		var time := fmod(clip.length * float(frame) / samples, clip.length)
		player.seek(time, true)
		player.advance(0)
		var pose := _pose(skeleton)
		var spine_height: float = pose[roots[0]].origin.y
		body_range.x = minf(body_range.x, spine_height)
		body_range.y = maxf(body_range.y, spine_height)
		var spine_delta: Vector3 = pose[roots[0]].origin - first[roots[0]].origin
		var hip_delta: Vector3 = pose[roots[1]].origin - first[roots[1]].origin
		max_root_mismatch = maxf(max_root_mismatch, spine_delta.distance_to(hip_delta))
		for chain in legs:
			max_foot_drift = maxf(max_foot_drift, pose[chain.z].origin.distance_to(first[chain.z].origin))
			var before: Basis = first[chain.z].basis.orthonormalized()
			var after: Basis = pose[chain.z].basis.orthonormalized()
			max_foot_rotation_error = maxf(max_foot_rotation_error, maxf(before.x.distance_to(after.x), maxf(before.y.distance_to(after.y), before.z.distance_to(after.z))))
			for pair in [Vector2i(chain.x, chain.y), Vector2i(chain.y, chain.z)]:
				var original_length: float = first[pair.x].origin.distance_to(first[pair.y].origin)
				var length: float = pose[pair.x].origin.distance_to(pose[pair.y].origin)
				max_length_error = maxf(max_length_error, absf(length - original_length))
	_check(max_foot_drift < 0.0001 and max_foot_rotation_error < 0.0001, "%s plants ankles, heels and toes between keys (drift %.7f)" % [label, max_foot_drift])
	var leg_length: float = first[legs[0].x].origin.distance_to(first[legs[0].y].origin) + first[legs[0].y].origin.distance_to(first[legs[0].z].origin)
	_check(body_range.y - body_range.x > leg_length * 0.02 and max_root_mismatch < 0.0001, "%s transfers the bounce to both body roots (travel %.5f)" % [label, body_range.y - body_range.x])
	_check(max_length_error < 0.0001, label + " bends legs without stretching bones")
	# Disable looping temporarily to inspect the actual final key, not wrapped t=0.
	clip.loop_mode = Animation.LOOP_NONE
	player.seek(clip.length, true)
	player.advance(0)
	var last := _pose(skeleton)
	clip.loop_mode = Animation.LOOP_LINEAR
	var seam_ok := true
	for bone in first.size():
		seam_ok = seam_ok and first[bone].origin.distance_to(last[bone].origin) < 0.0001
		var before: Basis = first[bone].basis.orthonormalized()
		var after: Basis = last[bone].basis.orthonormalized()
		seam_ok = seam_ok and before.x.distance_to(after.x) < 0.0001 and before.y.distance_to(after.y) < 0.0001 and before.z.distance_to(after.z) < 0.0001
	_check(seam_ok, label + " has matching poses at the loop boundary")
	if model is CharacterBody3D:
		_check(model.get_node("CollisionShape3D").global_transform.is_equal_approx(collider), label + " idle leaves collision unchanged")
	model.free()


func _pose(skeleton: Skeleton3D) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		result.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone))
	return result
