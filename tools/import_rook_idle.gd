@tool
extends EditorScenePostImport
## Bake foot contact into Rook's base idle once at import, not during gameplay.
## The original FBX exports have stationary torso roots and lifting feet.

const IDLE := &"Skeleton|Idle"
const BAKE_FPS := 240.0
const BAKE_VERSION := 1
const BODY_ROOTS := ["Spine", "Bone.027"]
const LEG_NAMES := [["Bone.030", "Bone.032", "Bone.034"], ["Bone.031", "Bone.033", "Bone.035"]]


func _post_import(scene: Node) -> Object:
	var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton == null or player == null or not player.has_animation(IDLE):
		push_error("Rook idle import: missing skeleton or idle animation.")
		return scene
	var source := player.get_animation(IDLE)
	if source.get_meta("rook_grounded_idle_version", 0) == BAKE_VERSION:
		return scene
	var roots: Array[int] = []
	var legs: Array[Vector3i] = []
	for name in BODY_ROOTS:
		var bone := skeleton.find_bone(name)
		if bone < 0:
			push_error("Rook idle import: missing body root " + name)
			return scene
		roots.append(bone)
	for names in LEG_NAMES:
		var chain := Vector3i(skeleton.find_bone(names[0]), skeleton.find_bone(names[1]), skeleton.find_bone(names[2]))
		if chain.x < 0 or chain.y < 0 or chain.z < 0:
			push_error("Rook idle import: missing leg chain.")
			return scene
		legs.append(chain)

	var original_pose: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		original_pose.append(skeleton.get_bone_pose(bone))
	# FBX armatures are rotated/scaled differently in the two Rook exports.
	var to_scene := Transform3D.IDENTITY
	var ancestor := skeleton as Node3D
	while ancestor != scene and ancestor != null:
		to_scene = ancestor.transform * to_scene
		ancestor = ancestor.get_parent() as Node3D
	var up := (to_scene.basis.inverse() * Vector3.UP).normalized()
	var skeleton_path := player.get_node(player.root_node).get_path_to(skeleton)
	_sample_pose(skeleton, source, skeleton_path, 0.0)
	var anchors: Array[Transform3D] = []
	for chain in legs:
		anchors.append(_global_pose(skeleton, chain.z))

	var baked := source.duplicate(true) as Animation
	baked.loop_mode = Animation.LOOP_LINEAR
	var tracks: Dictionary = {}
	for bone in roots:
		tracks[bone] = _replace_track(baked, skeleton_path, skeleton.get_bone_name(bone), Animation.TYPE_POSITION_3D)
	for chain in legs:
		for bone in [chain.x, chain.y, chain.z]:
			tracks[bone] = _replace_track(baked, skeleton_path, skeleton.get_bone_name(bone), Animation.TYPE_ROTATION_3D)
	var frames := ceili(source.length * BAKE_FPS)
	for frame in frames + 1:
		var time := source.length * float(frame) / frames
		_sample_pose(skeleton, source, skeleton_path, time)
		var lift := 0.0
		var knees: Array[Vector3] = []
		for i in legs.size():
			lift += (_global_pose(skeleton, legs[i].z).origin - anchors[i].origin).dot(up)
			knees.append(_global_pose(skeleton, legs[i].y).origin)
		lift /= legs.size()
		# Transfer the existing foot bounce into a body dip, retaining its timing.
		for bone in roots:
			var pose := _global_pose(skeleton, bone)
			pose.origin -= up * lift
			_set_global_pose(skeleton, bone, pose)
		for i in legs.size():
			_solve_leg(skeleton, legs[i], anchors[i], knees[i])
		for bone in tracks:
			var track: int = tracks[bone]
			var value: Variant = skeleton.get_bone_pose_position(bone) if bone in roots else skeleton.get_bone_pose_rotation(bone)
			# Match both ends exactly; interpolation also stays smooth at the seam.
			if frame == frames:
				value = baked.track_get_key_value(track, 0)
			baked.track_insert_key(track, time, value)
	for bone in original_pose.size():
		skeleton.set_bone_pose(bone, original_pose[bone])
	baked.set_meta("rook_grounded_idle_version", BAKE_VERSION)
	var library := player.get_animation_library("")
	library.remove_animation(IDLE)
	library.add_animation(IDLE, baked)
	print("Baked planted Rook idle: ", frames + 1, " poses; other clips unchanged.")
	return scene


func _replace_track(animation: Animation, skeleton_path: NodePath, bone: String, type: Animation.TrackType) -> int:
	var path := NodePath(str(skeleton_path) + ":" + bone)
	var track := animation.find_track(path, type)
	if track < 0:
		track = animation.add_track(type)
		animation.track_set_path(track, path)
	for key in range(animation.track_get_key_count(track) - 1, -1, -1):
		animation.track_remove_key(track, key)
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	return track


func _sample_pose(skeleton: Skeleton3D, animation: Animation, skeleton_path: NodePath, time: float) -> void:
	skeleton.reset_bone_poses()
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if path.get_concatenated_names() != str(skeleton_path) or path.get_subname_count() != 1 or not animation.track_is_enabled(track):
			continue
		var bone := skeleton.find_bone(path.get_subname(0))
		if bone < 0:
			continue
		match animation.track_get_type(track):
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone, animation.position_track_interpolate(track, time))
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track, time))
			Animation.TYPE_SCALE_3D:
				skeleton.set_bone_pose_scale(bone, animation.scale_track_interpolate(track, time))


func _solve_leg(skeleton: Skeleton3D, chain: Vector3i, foot: Transform3D, previous_knee: Vector3) -> void:
	var hip := _global_pose(skeleton, chain.x).origin
	var knee := _global_pose(skeleton, chain.y).origin
	var ankle := _global_pose(skeleton, chain.z).origin
	var upper := hip.distance_to(knee)
	var lower := knee.distance_to(ankle)
	var to_foot := foot.origin - hip
	var direction := to_foot.normalized()
	var distance := clampf(to_foot.length(), absf(upper - lower) + 1e-8, upper + lower - 1e-8)
	# Keep the authored knee plane instead of introducing a new bend direction.
	var bend := previous_knee - hip
	bend -= direction * bend.dot(direction)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	var target_knee := hip + direction * along + bend.normalized() * height
	_rotate_bone_to(skeleton, chain.x, chain.y, target_knee)
	_rotate_bone_to(skeleton, chain.y, chain.z, foot.origin)
	var ankle_pose := _global_pose(skeleton, chain.z)
	# A stable ankle rotation also plants the heel and toe, not only the joint.
	ankle_pose.basis = foot.basis
	_set_global_pose(skeleton, chain.z, ankle_pose)


func _rotate_bone_to(skeleton: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := _global_pose(skeleton, bone)
	var current := (_global_pose(skeleton, child).origin - pose.origin).normalized()
	var desired := (target - pose.origin).normalized()
	var axis := current.cross(desired)
	# The from/to Quaternion constructor discards very small corrections, which
	# leaves visible-scale drift after the imported armature's large scale factor.
	if axis.length_squared() > 1e-20:
		pose.basis = Basis(axis.normalized(), atan2(axis.length(), current.dot(desired))) * pose.basis
	_set_global_pose(skeleton, bone, pose)


func _global_pose(skeleton: Skeleton3D, bone: int) -> Transform3D:
	# Import nodes are outside the SceneTree; compute from local poses directly.
	var pose := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return pose


func _set_global_pose(skeleton: Skeleton3D, bone: int, pose: Transform3D) -> void:
	var parent := skeleton.get_bone_parent(bone)
	if parent >= 0:
		pose = _global_pose(skeleton, parent).affine_inverse() * pose
	skeleton.set_bone_pose(bone, pose)
