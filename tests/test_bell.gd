extends SceneTree
## Checks actual imported skins and animation sampling, plus saved level integration.
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

func _run() -> void:
	var packed := load("res://Mesh/Bell/bell.tscn") as PackedScene
	var bell = packed.instantiate()
	var second = packed.instantiate()
	root.add_child(bell)
	root.add_child(second)
	var player: AnimationPlayer = bell.animation_player
	var skeleton: Skeleton3D = bell.get_node("Model/BellRig/Skeleton3D")
	_check(skeleton.get_bone_count() == 3, "Imported armature has root, bell and clapper bones")
	_check(player.has_animation("Ring") and player.has_animation("RingLoop"), "Both authored ringing clips import")
	_check(is_equal_approx(player.get_animation("Ring").length, 4.0), "One-shot lasts four seconds")
	_check(player.get_animation("RingLoop").loop_mode == Animation.LOOP_LINEAR, "Continuous clip loops")
	var materials := {}
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			_check(child.skin != null, "%s has an exported skin" % child.name)
			for surface in child.mesh.get_surface_count():
				var material: Material = child.mesh.surface_get_material(surface)
				materials[material.resource_name] = true
	_check(materials.has("Bell_Aged_Bronze") and materials.has("Frame_Dark_Oak") and materials.has("Hardware_Blackened_Iron"), "Bronze, oak and iron materials survive GLB import")
	bell.ring()
	player.seek(1.4, true)
	skeleton.force_update_all_bone_transforms()
	var root_bone := skeleton.find_bone("Root")
	var bell_bone := skeleton.find_bone("BellSwing")
	var clapper_bone := skeleton.find_bone("ClapperSwing")
	_check(skeleton.get_bone_pose_rotation(root_bone).is_equal_approx(Quaternion.IDENTITY), "Frame's root remains stationary during ringing")
	_check(skeleton.get_bone_pose_rotation(bell_bone).angle_to(skeleton.get_bone_rest(bell_bone).basis.get_rotation_quaternion()) > 0.1, "Bell actually swings on its imported bone")
	_check(skeleton.get_bone_pose_rotation(clapper_bone).angle_to(Quaternion.IDENTITY) > 0.1, "Clapper swings independently relative to the bell")
	var second_skeleton: Skeleton3D = second.get_node("Model/BellRig/Skeleton3D")
	_check(second_skeleton.get_bone_pose_rotation(bell_bone).is_equal_approx(skeleton.get_bone_rest(bell_bone).basis.get_rotation_quaternion()), "Ringing one instance leaves another at rest")
	bell.ring()
	_check(is_zero_approx(player.current_animation_position), "Retriggering restarts the one-shot")
	bell.stop_ringing()
	_check(skeleton.get_bone_pose_rotation(bell_bone).is_equal_approx(skeleton.get_bone_rest(bell_bone).basis.get_rotation_quaternion()) and skeleton.get_bone_pose_rotation(clapper_bone).is_equal_approx(Quaternion.IDENTITY), "Stop restores both bones to their rest pose")
	bell.ring()
	player.seek(4.0, true)
	_check(skeleton.get_bone_pose_rotation(bell_bone).is_equal_approx(skeleton.get_bone_rest(bell_bone).basis.get_rotation_quaternion()) and skeleton.get_bone_pose_rotation(clapper_bone).is_equal_approx(Quaternion.IDENTITY), "One-shot ends at rest")
	var loop: Animation = player.get_animation("RingLoop")
	var seamless := true
	for track in loop.get_track_count():
		seamless = seamless and loop.track_get_key_value(track, 0).is_equal_approx(loop.track_get_key_value(track, loop.track_get_key_count(track) - 1))
	_check(seamless, "Loop endpoints match on every animated bone")
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	for station in level.get_node("Bells").get_children():
		_check(station.get_node("Visual").scene_file_path == "res://Mesh/Bell/bell.tscn", "%s uses the rigged bell in the saved level" % station.name)
	level.free()
	var builder = load("res://scripts/midnight_exchange_builder.gd").new()
	var rebuilt = builder.build_exchange()
	for station in rebuilt.get_node("Bells").get_children():
		_check(station.get_node("Visual").scene_file_path == "res://Mesh/Bell/bell.tscn", "%s keeps the rigged bell after regeneration" % station.name)
	rebuilt.free()
	bell.free()
	second.free()
	print("BELL CHECKS: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
