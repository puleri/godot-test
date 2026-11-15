extends SceneTree
const MOVEMENT = preload("res://scripts/movement_tuning.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60).timeout.connect(func(): push_error("Movement checks timed out"); quit(1))
	for path in ["res://scenes/Player_v2.tscn", "res://scenes/Player.tscn", "res://scenes/ROOK_v2.tscn"]:
		var rook = load(path).instantiate()
		_check(is_equal_approx(rook.max_walk_speed, MOVEMENT.ROOK_MOVE_SPEED), "Reusable Rook baseline: " + path.get_file())
		rook.free()
	for path in ["Demo_A2", "StealthTraversalTest", "HarborNightShift", "MidnightExchange", "NocturneCity", "StealthSystemsLab", "LamplightStore"]:
		var level = load("res://Levels/" + path + ".tscn").instantiate()
		_check_characters(level, path)
		level.free()
	for script in ["stealth_systems_lab_builder", "lamplight_store_builder"]:
		var builder = load("res://scripts/" + script + ".gd").new()
		var level = builder.build_lab() if script == "stealth_systems_lab_builder" else builder.build_store()
		_check_characters(level, "New " + script)
		level.free()
	# A Hound keeps its identity when a level replaces the ambient controller.
	# Even an obsolete pre-ready override must not lower its global pursuit speed.
	var fixture := Node3D.new()
	var route := Node3D.new()
	route.name = "Route"
	route.add_child(Marker3D.new())
	fixture.add_child(route)
	var player = load("res://scenes/Player_v2.tscn").instantiate()
	player.name = "Rook"
	player.max_walk_speed = 1.0
	fixture.add_child(player)
	for spec in [["Hound", 1.0], ["Mouse", 3.15]]:
		var actor = load("res://Characters/%s/%s_npc.tscn" % [spec[0], spec[0].to_lower()]).instantiate()
		actor.name = spec[0]
		actor.set_script(preload("res://scripts/stealth_guard.gd"))
		actor.route_path = NodePath("../Route")
		actor.run_speed = spec[1]
		fixture.add_child(actor)
	root.add_child(fixture)
	await physics_frame
	_check(is_equal_approx(player.max_walk_speed, MOVEMENT.ROOK_MOVE_SPEED), "Rook restores the shared baseline even with a legacy scene override")
	_check(is_equal_approx(fixture.get_node("Hound").run_speed, MOVEMENT.HOUND_PURSUIT_SPEED), "Global Hound speed survives controller replacement and old overrides")
	_check(is_equal_approx(fixture.get_node("Mouse").run_speed, 3.15), "Mouse-specific pursuit tuning remains independent")
	fixture.queue_free()
	await process_frame
	print("MOVEMENT TUNING: %d passed, %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)


func _check_characters(level: Node, context: String) -> void:
	var hounds := 0
	var players := 0
	var hounds_match := true
	var players_match := true
	for actor in level.find_children("*", "CharacterBody3D", true, false):
		if actor.is_in_group("hounds"):
			hounds += 1
			hounds_match = hounds_match and is_equal_approx(actor.run_speed, MOVEMENT.HOUND_PURSUIT_SPEED)
		if actor.has_method("handle_phase_1_movement"):
			players += 1
			players_match = players_match and is_equal_approx(actor.max_walk_speed, MOVEMENT.ROOK_MOVE_SPEED)
	_check(hounds > 0 and hounds_match, context + " uses consistent Hound pursuit speed")
	_check(players > 0 and players_match, context + " uses consistent Rook movement speed")


func _check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1
