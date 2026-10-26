extends SceneTree
## Shared eye behavior plus the actual Midnight Exchange and Demo A2 HUDs.

const EyeScene = preload("res://UI/alert_eye.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(40).timeout.connect(func(): push_error("Eye tests timed out"); quit(1))
	var eye = EyeScene.instantiate()
	root.add_child(eye)
	var bar: TextureProgressBar = eye.texture_progress_bar
	_check(bar.value == 0 and bar.tint_over.a == 0, "No guards starts empty and clear")
	var first := _guard()
	var second := _guard()
	_check(first.is_in_group("stealth_guards"), "Real guard ready registers the shared group")
	first.awareness = 0.1234
	second.awareness = 0.68
	eye.refresh()
	_check(is_equal_approx(bar.value, 68), "Highest awareness sets fill")
	second.awareness = 0.05
	eye.refresh()
	_check(is_equal_approx(bar.value, 12.34), "Fill decays and retains fractional precision")
	first.player_visible = true
	first.guard_state = StealthGuard.GuardState.SUSPICIOUS
	eye.refresh()
	_check(bar.tint_over.a == 0, "Visibility and suspicion alone do not show pursuit")
	first.guard_state = StealthGuard.GuardState.SEARCH
	eye.refresh()
	_check(eye._overlay_state == eye.OverlayState.CLEAR, "Ordinary investigation does not pulse")
	first.guard_state = StealthGuard.GuardState.CHASE
	eye.refresh()
	var chase_tween: Tween = eye._overlay_tween
	await create_timer(0.1).timeout
	_check(bar.tint_over.a > 0 and bar.tint_over.a < 1, "Pursuit starts fading immediately")
	eye.refresh()
	_check(eye._overlay_tween == chase_tween, "Repeated state does not restart tween")
	await create_timer(0.15).timeout
	_check(is_equal_approx(bar.tint_over.a, 1), "Pursuit reaches solid opacity")
	first.awareness = 0.2
	eye.refresh()
	_check(is_equal_approx(bar.value, 20), "Pursuit fill still follows actual awareness")
	first.guard_state = StealthGuard.GuardState.SEARCH
	eye.refresh()
	var low := 1.0
	var high := 0.0
	for frame in 70:
		await process_frame
		low = minf(low, bar.tint_over.a)
		high = maxf(high, bar.tint_over.a)
	_check(low >= 0.299 and low < 0.32 and high > 0.98 and high <= 1, "Search pulses smoothly within 30–100 percent")
	second.guard_state = StealthGuard.GuardState.CHASE
	eye.refresh()
	await create_timer(0.25).timeout
	_check(eye._overlay_state == eye.OverlayState.PURSUIT and is_equal_approx(bar.tint_over.a, 1), "Another guard's chase overrides searching")
	second.guard_state = StealthGuard.GuardState.RETURN
	eye.refresh()
	_check(eye._overlay_state == eye.OverlayState.SEARCH, "Original searching guard retains chase history")
	first.guard_state = StealthGuard.GuardState.RETURN
	eye.refresh()
	await create_timer(0.25).timeout
	_check(is_zero_approx(bar.tint_over.a), "Leaving search fades overlay away")
	first.guard_state = StealthGuard.GuardState.SEARCH
	eye.refresh()
	_check(eye._overlay_state == eye.OverlayState.CLEAR, "Later unrelated search does not reuse old pursuit")
	first.guard_state = StealthGuard.GuardState.CHASE
	eye.refresh()
	first.queue_free()
	second.queue_free()
	await process_frame
	eye.refresh()
	await create_timer(0.25).timeout
	_check(bar.value == 0 and is_zero_approx(bar.tint_over.a), "Removed guards clear fill and pursuit")
	eye.queue_free()
	await process_frame

	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.get_node("StormFlashLight").stop_flashing()
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
		guard.awareness = 0
		guard.guard_state = StealthGuard.GuardState.PATROL
	level.guards[0].awareness = 0.42
	level._alert_eye.refresh()
	_check(is_equal_approx(level._alert_eye.texture_progress_bar.value, 42), "Saved encounter displays guard awareness")
	_check(level._alert_eye.scale == Vector2(0.5, 0.5), "Encounter uses half-size artwork")
	level.guards[0].guard_state = StealthGuard.GuardState.CHASE
	level._alert_eye.refresh()
	await create_timer(0.08).timeout
	level._end_run(false)
	var alpha: float = level._alert_eye.texture_progress_bar.tint_over.a
	await create_timer(0.3).timeout
	_check(is_equal_approx(alpha, level._alert_eye.texture_progress_bar.tint_over.a) and not level._alert_eye.is_processing(), "End of encounter freezes eye and animation")
	level.queue_free()
	await process_frame

	var demo = load("res://Levels/Demo_A2.tscn").instantiate()
	root.add_child(demo)
	current_scene = demo
	await process_frame
	var demo_eye = demo.get_node("HUD/Control/AlertEye")
	_check(demo_eye.texture_progress_bar.value == 0 and demo_eye.texture_progress_bar.tint_over.a == 0, "Demo A2 starts clear without guards or stale history")
	_check(demo.get_node("HUD/Control/CoinIcon/CoinCount").text == "x 00" and demo.has_node("HUD/Control/DialogueBox"), "Demo retains coins and dialogue")
	var demo_guard := _guard()
	demo_guard.awareness = 0.73
	demo_eye.refresh()
	_check(is_equal_approx(demo_eye.texture_progress_bar.value, 73), "Existing Demo HUD automatically sees new guards")
	demo_guard.queue_free()
	demo.queue_free()
	await process_frame
	print("ALERT EYE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _guard() -> StealthGuard:
	var guard := StealthGuard.new()
	# A minimal valid route avoids unrelated route-authoring warnings.
	var route := Node3D.new()
	route.name = "Route"
	route.add_child(Marker3D.new())
	guard.add_child(route)
	guard.route_path = ^"Route"
	guard.active = false
	root.add_child(guard)
	return guard


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
