extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("PASS: " if ok else "FAIL: ", message)
func _run() -> void:
	root.size = Vector2i(1440, 900)
	var level = load("res://Levels/MidnightExchange.tscn").instantiate()
	level.play_opening_dialogue = false
	root.add_child(level)
	current_scene = level
	await level.ready_for_play
	level.set_process(false)
	level.get_node("StormFlashLight").stop_flashing()
	level.player.set_physics_process(false)
	for guard in level.guards:
		guard.set_physics_process(false)
		guard.player_visible = false
		guard.guard_state = StealthGuard.GuardState.PATROL
	var manifest = level.get_node("Stations/Manifest")
	level.player.position = manifest.position + Vector3(0, 0.49, 1.0)
	level._update_interaction_prompt()
	check(level._interaction_panel.visible and "[E]  Study" in level._interaction_label.text, "Nearby manifest has keyboard action prompt")
	level._using_controller = true
	level._update_interaction_prompt()
	check(level._interaction_art.visible and level._interaction_art.texture.resource_path.ends_with("ps-interact.png"), "Controller prompt uses supplied PlayStation artwork")
	var rest: Transform3D = manifest.moving_part.transform
	var forgery = level._signature
	var sticker: Sprite3D = manifest.moving_part.get_node("ClerkSignature")
	var ink_rect: Rect2 = forgery.SOURCE_INK_RECT
	var paper_rect: Rect2 = forgery.MANUSCRIPT_PAPER
	check(sticker.texture == forgery.source_ink and sticker.position.x > 0 and sticker.position.z > 0, "The desk prop uses the same signature on its lower-right leaf")
	check(paper_rect.encloses(ink_rect) and ink_rect.get_center().x > paper_rect.get_center().x and ink_rect.position.y > paper_rect.get_center().y, "The original always signs the bottom right of the manuscript")
	var variants := {}
	for strokes in forgery.Signatures.VARIANTS:
		variants[str(strokes)] = true
		var ink: ImageTexture = forgery.Signatures.make_ink(PackedInt32Array(strokes), strokes.size())
		check(strokes.size() == 4 and ink.get_image().get_used_rect().has_area(), "Signature variant renders four ink strokes")
	check(variants.size() == 6 and forgery.Signatures.VARIANTS.has(Array(forgery.target)), "Six distinct signatures are available to the random draw")
	check(level._try_open_signature() and manifest.moving_part.transform != rest and forgery.visible, "Studying raises the page and opens the manuscript")
	level._tuck_signature()
	check(manifest.moving_part.transform == rest and not forgery.visible, "Tucking away returns the page to rest")
	level._studied_signature = false
	level.player.position = Vector3(0, 0.49, 14)
	level._update_interaction_prompt()
	check(not level._interaction_panel.visible, "Prompt hides out of reach")
	level.player.position = level.get_node("Stations/Crank").position + Vector3(0, 0.49, 1)
	level._update_interaction_prompt()
	check("signature first" in level._interaction_label.text, "Locked station explains prerequisite")
	level.stage = 1
	level._update_interaction_prompt()
	check("Hound" in level._interaction_label.text, "Crank explains guard clearance")
	var eye = level._alert_eye
	eye.set_process(false)
	level._on_noise_emitted(Vector3(1000,0,1000), 1, "FOOTSTEP")
	check(eye._hearing_seconds == 0, "Inaudible noise does not show audio alert")
	var guard = level.guards[0]
	level._on_noise_emitted(guard.global_position, 8, "FOOTSTEP")
	check(eye._hearing_seconds > 0 and guard._suspicion_bubble._audio_remaining > 0, "Accepted footstep hearing shows audio artwork on the guard")
	var investigation_target: Vector3 = guard.investigation_target
	guard._suspicion_bubble._audio_remaining = 0.0
	level._on_noise_emitted(guard.global_position, 8, "FOOTSTEP")
	check(guard._suspicion_bubble._audio_remaining > 0 and guard.investigation_target == investigation_target, "Repeat audible footsteps show artwork without redirecting investigation")
	check(eye.texture_progress_bar.value == 0, "Hearing alone does not fill visual awareness eye")
	check(level._styled_hud.get_node("Control/EyeAnchor/AlertEye")._hearing_seconds > 0, "Styled HUD receives hearing feedback")
	eye._process(3)
	check(not eye._hearing_caption.visible, "Hearing notification expires")
	level._notify_heard("BELL")
	check(eye._hearing_caption.text == "BELL HEARD", "Distraction sound is distinguished from player noise")
	var seal = level.get_node("Stations/NightSeal")
	await process_frame
	check(not seal.get_node("Visual/Area3D").monitoring and not seal.get_node("Visual").is_processing(), "Seal cannot auto-collect or rotate independently of use")
	var shimmer = manifest.get_child(manifest.get_child_count()-1)
	shimmer.set_process(false)
	shimmer.elapsed = 0
	shimmer._process(0.35)
	check(float(shimmer.materials[0].get_shader_parameter("sweep")) > 0, "Shimmer sweeps across the surface")
	shimmer._process(0.5)
	check(shimmer.materials[0].get_shader_parameter("sweep") == -1.0, "Shimmer ends after its brief sweep")
	shimmer._process(4.5)
	check(float(shimmer.materials[0].get_shader_parameter("sweep")) > 0, "Shimmer repeats after five seconds")
	manifest.completed = true
	shimmer._process(0)
	check(shimmer.materials[0].get_shader_parameter("sweep") == -1.0, "Completed station stops shimmering")
	if "--preview" in OS.get_cmdline_user_args():
		manifest.completed = false
		level.stage = 0
		level._using_controller = true
		level.player.position = manifest.position + Vector3(0,0.49,1)
		level.player._focus = Vector3(-12,0.3,0)
		level.player._update_phase_camera()
		forgery.using_controller = true
		level._try_open_signature()
		level._notify_heard("FOOTSTEP")
		level._process(0.0)
		shimmer.elapsed = 0.35
		shimmer._process(0)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/exchange-polish.png")
		level._tuck_signature()
		level.player.position = Vector3(-11, 0.49, 2)
		level.guards[0].position = Vector3(-7, 0.49, 2)
		level.player._focus = Vector3(-11, 0.3, 2)
		level.player._update_phase_camera()
		level.exposure_sensor.exposure = 0.0
		level._try_open_signature()
		level._process(0.0)
		var place := InputEventAction.new()
		place.action = "interact"
		place.pressed = true
		forgery.handle_input(place)
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/exchange-signature-draft.png")
	print("POLISH CHECKS: ", checks - failures, " passed, ", failures, " failed")
	quit(1 if failures else 0)
