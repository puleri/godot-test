extends SceneTree
## Runs both control schemes against the saved layout and the real stage transitions.

var level: Node3D
var failures := 0
var using_pad := false


func _initialize() -> void:
	Input.use_accumulated_input = false
	_run.call_deferred()


func _run() -> void:
	create_timer(440.0).timeout.connect(func(): push_error("The Last Barrel checks timed out"); quit(1))
	change_scene_to_file("res://Levels/TheLastBarrel.tscn")
	await scene_changed
	await _attach()
	await _play_quay()
	if failures == 0:
		await _play_ship()
	if failures == 0:
		using_pad = true
		change_scene_to_file("res://Levels/TheLastBarrel.tscn")
		await scene_changed
		await _attach()
		await _play_quay()
	if failures == 0:
		await _play_ship()
	if failures == 0:
		await _check_checkpoints()
	if failures == 0:
		await _check_early_lock()
	unload_current_scene()
	await process_frame
	print("THE LAST BARREL: ", failures, " failed")
	quit(1 if failures else 0)


func _attach() -> void:
	level = current_scene
	await level.ready_for_play
	level.player.set_physics_process(false)


func _seat_pin(index: int) -> bool:
	var axis := KEY_D if level.Pins.CONTACTS[index] > level.pins.travel else KEY_A
	_input(axis, true)
	for frame in 130:
		if level.pins.contact or level.modal != level.Modal.LOCK:
			break
		await physics_frame
	_input(axis, false)
	if not level.pins.contact:
		return false
	_input(KEY_E, true)
	await create_timer(0.38).timeout
	_input(KEY_E, false)
	return level.pins.seated == index + 1


func _check_argument(expected_phase: int) -> void:
	var post: Vector3 = level._point("SmokingPost")
	var sentinel_post: Vector3 = level.sentinel.position
	var pipe: Node3D = level.pipe
	var smoke: CPUParticles3D = pipe.find_children("*", "CPUParticles3D", true, false)[0]
	_check(smoke.emitting and level.master.position.distance_to(post) < 0.1, "The shipmaster smokes at his door until Rook rings the bell")
	await _tap(KEY_Q)
	var sentinel_stayed := true
	var left_with_lit_pipe := false
	var confronted_watch := false
	var argument_framed := false
	for frame in 2000:
		if not is_instance_valid(level):
			break
		sentinel_stayed = sentinel_stayed and level.sentinel.position.distance_to(sentinel_post) < 0.02
		if smoke.emitting and level.master.position.distance_to(post) > 0.5:
			left_with_lit_pipe = true
		if level.master.position.distance_to(level._point("WatchArgument")) < 0.5 and not level.master.get_node("Speech").text.is_empty():
			confronted_watch = true
			var inset = level._dock_cutaway
			if inset.visible and inset.subject == level.master and inset.gangway_post == level.sentinel:
				var hound_mesh: MeshInstance3D = level.sentinel.get_node("VisualPivot/Model/Root/Skeleton3D/Hat_006")
				argument_framed = (inset.lens.cull_mask & hound_mesh.layers) != 0 and inset.lens.is_position_in_frustum(level.sentinel.position + Vector3.UP * 0.5) and inset.lens.is_position_in_frustum(level.guard.position + Vector3.UP * 0.25)
		if level.phase == expected_phase:
			break
		await physics_frame
	_check(not smoke.emitting and pipe.global_position.distance_to(level._point("Ashtray")) < 0.05 and not left_with_lit_pipe, "The shipmaster puts out the pipe before leaving his post")
	_check(sentinel_stayed, "The sentinel stays at the crank throughout the dispute")
	_check(confronted_watch and level.phase == expected_phase, "The shipmaster walks to the argument and addresses the watch")
	_check(argument_framed, "The argument cutaway frames both guards and renders the sentinel")


func _play_quay() -> void:
	var sentinel_position: Vector3 = level.sentinel.position
	var watch_start: Vector3 = level.guard.position
	var arrival: Vector3 = level.player.position
	_check(arrival.distance_to(level._point("Arrival")) < 0.10, "Rook starts at the authored arrival marker beside the barrel")
	var barrel_start: Vector3 = level.barrel.position
	await _tap(KEY_E)
	await create_timer(0.47).timeout
	_check(level.barrel.player_inside and level.phase == level.Phase.SCOUT, "The barrel is usable at the start")
	_check(await _walk(barrel_start + Vector3(0, 0, 1.25), 2.1), "Rook can walk in the barrel before the bell")
	_check(level.barrel.position.distance_to(barrel_start) > 1.0, "The occupied barrel follows Rook during scouting")
	_check(await _walk(barrel_start, 2.1), "Rook can put the spare barrel back")
	await _tap(KEY_E)
	await create_timer(0.47).timeout
	_check(not level.barrel.player_inside and not level.player.interaction_locked, "An early barrel exit restores movement")
	level._place_player(arrival)
	level.player.set_physics_process(true)
	_input(KEY_D, true)
	await create_timer(0.55).timeout
	_input(KEY_D, false)
	level.player.set_physics_process(false)
	_check(level.player.position.distance_to(arrival) > 0.7, "Movement works through the live input map")
	level._place_player(arrival)
	await create_timer(2.4).timeout
	_check(level.guard.position.distance_to(watch_start) > 0.7, "The live dock watch moves along the navigation route")
	_check(not level.sentinel.hear_sound(level.sentinel.position, 20.0, "BELL"), "The sentinel refuses a distraction")
	level.guard.active = false
	_check(await _walk(Vector3(-2.55, 0, 13.35)) and await _walk(Vector3(0.5, 0, 13.35)), "Rook can rejoin the approach from the barrel")
	_check(await _walk(Vector3(0.5, 0, -4)), "Rook physically reaches the harbor overlook")
	_check(level.phase == level.Phase.DISTRACTION, "The loaded valuables change the objective")
	_check(await _walk(Vector3(0.55, 0, -2.66)) and await _walk(Vector3(3.15, 0, -2.66)) and await _walk(Vector3(3.15, 0, -4.12)), "Rook can approach the bell")
	if failures > 0:
		return
	await _check_argument(level.Phase.OFFICE_LOCK)
	_check(level.sentinel.position == sentinel_position and level.door.rotation.y == 0.0, "The sentinel stays at the crank and the office lock is visibly shut")
	level.guard.set_physics_process(false)
	_check(await _walk(Vector3(-2.52, 0, 5.85)), "The outer corridor is traversable")
	_check(await _walk(Vector3(-6.1, 0, 5.45)), "The office lock can be reached")
	await _tap(KEY_E)
	_check(level.modal == level.Modal.LOCK, "Interact opens the listening lock")
	for index in 4:
		_check(await _seat_pin(index), "Rook finds and seats pin %d" % (index + 1))
		if index == 0:
			await _tap(KEY_Q)
			_check(level.modal == level.Modal.NONE and level.pins.seated == 1, "Backing out preserves the seated pin")
			await _tap(KEY_E)
	await create_timer(0.6).timeout
	_check(level.door_unlocked and level.phase == level.Phase.ENTER_OFFICE, "Four pins open the physical office door")
	_check(await _walk(Vector3(-6.1, 0, 2.55)), "Rook can cross the picked doorway")
	_check(await _walk(Vector3(-6.1, 0, -1.45)), "The office cover leaves a playable route to the desk")
	_check(await _walk(Vector3(-10.1, 0, -1.45)), "Rook reaches the manuscript")
	await _tap(KEY_E)
	_check(level.signature.view == level.Forgery.View.MANUSCRIPT, "The source is readable at the desk")
	var pattern: PackedInt32Array = level.signature.target.duplicate()
	await _tap(KEY_Q)
	_check(await _walk(Vector3(-8.5, 0, -0.16)), "Rook can reach the shadow behind the shelf")
	for frame in 1000:
		if level._office_patrolling:
			break
		await physics_frame
	_check(level._office_patrolling and level.master.get_node("Speech").text in level.SONNET, "The returning shipmaster crosses the doorway and begins his sonnet")
	await _tap(KEY_E)
	if level.modal != level.Modal.SIGNATURE:
		# Wait for a cover opening if the shipmaster has just passed.
		for frame in 360:
			await physics_frame
			if level._office_cover() and not level._seen():
				await _tap(KEY_E)
				break
	_check(level.signature.view == level.Forgery.View.DRAFT, "Rook can open the draft in cover")
	if failures > 0:
		return
	for stroke in pattern:
		for step in posmod(stroke - level.signature.selection, level.Forgery.Signatures.STROKES.size()):
			await _tap(KEY_RIGHT)
		await _tap(KEY_E)
	await _tap(KEY_E)
	_check(level.phase == level.Phase.REPLACE and not level.manifest_swapped, "A valid draft still requires a physical swap")
	for attempt in 4:
		if level._seen():
			await create_timer(0.5).timeout
		else:
			break
	_check(await _walk(Vector3(-10.1, 0, -1.45)), "Rook gets back to the desk")
	# The actual shipmaster patrol and sight stay live through the approach.
	for attempt in 8:
		await _tap(KEY_E)
		if level.manifest_swapped:
			break
		await create_timer(0.18).timeout
	_check(level.manifest_swapped and level.phase == level.Phase.LEAVE_OFFICE, "Interact replaces the original")
	if failures > 0:
		return
	_check(await _walk(Vector3(-10.60, 0, -0.25)) and await _walk(Vector3(-10.60, 0, 2.52)) and await _walk(Vector3(-8.05, 0, 3.15)) and await _walk(Vector3(-6.1, 0, 3.57)), "Office has an escape route")
	if failures > 0:
		return
	await _tap(KEY_E)
	await create_timer(1.05).timeout
	_check(await _walk(Vector3(-6.10, 0, 5.8)), "Rook escapes the office through the picked door")
	_check(await _walk(Vector3(-2.63, 0, 5.8)) and await _walk(Vector3(-2.66, 0, -5.8)) and await _walk(Vector3(-4.05, 0, -7.05)), "Rook reaches the sorting overlook")
	_check(level.phase == level.Phase.BARREL_RUN and level.delivery_left > 39.0, "Wrong-ship reveal starts the handoff clock")
	for destination in [Vector3(-2.65, 0, -5.65), Vector3(-2.65, 0, 12.81), Vector3(-4.78, 0, 13.35)]:
		_check(await _walk(destination), "The arrival barrel is reachable before the handoff")
	await _tap(KEY_E)
	await create_timer(0.47).timeout
	_check(level.barrel.player_inside, "Rook climbs into the real moving barrel")
	for destination in [Vector3(-2.65, 0, 12.82), Vector3(-2.66, 0, -5.60), Vector3(-3.25, 0, -7.98), Vector3(0.4, 0, -8.2), Vector3(0.4, 0, -9.1)]:
		_check(await _walk(destination, 2.1), "Occupied barrel fits the dock route")
	_check(level.delivery_left > 4.0, "The timed barrel route has a margin for stealth")
	if failures > 0:
		return
	_check(await _wait_phase(level.Phase.SHIP, 47.0), "The clerk reads the forged entry and the hoist puts Rook aboard")
	_check(not level.barrel.player_inside and not level.player.interaction_locked, "Freight transfer returns control outside the barrel on deck")


func _play_ship() -> void:
	_check(level.ship_step == level.ShipStep.SLATE and not level.seal.visible, "Rook begins without the seal’s whereabouts")
	_check(await _walk(level._point("CargoSlate")), "Rook reaches the hatch tally on the freight deck")
	await _tap(KEY_E)
	_check(level.ship_step == level.ShipStep.MARKS and level.checkpoint == level.Checkpoint.HATCH, "Reading the slate records the cargo mark")
	for destination in [Vector3(3.7, 0, -21.8), Vector3(7.35, -1.2, -21.8), level._point("SailclothCrate")]:
		_check(await _walk(destination), "Rook walks down the hatch stair to the lower hold")
	_check(level.player.position.y < -0.5, "The hold sits below the freight deck")
	await _tap(KEY_E)
	_check(level.ship_step == level.ShipStep.MARKS and "triangle" in level._story.text, "The sailcloth tag identifies a different consignment")
	_check(await _walk(Vector3(9.25, -1.2, -21.7)) and await _walk(Vector3(12.7, -1.2, -21.7)) and await _walk(level._point("SilverCrate")), "The silver freight can be searched from the central aisle")
	await _tap(KEY_E)
	_check(level.ship_step == level.ShipStep.MARKS and "diamond" in level._story.text, "The silver crate carries a second distinct mark")
	_check(await _walk(Vector3(12.7, -1.2, -21.7)) and await _walk(Vector3(15.25, -1.2, -21.7)) and await _walk(level._point("CrescentCrate")), "Rook finds the crate at the back of the hold")
	await _tap(KEY_E)
	await create_timer(0.5).timeout
	_check(level.ship_step == level.ShipStep.TRANSFER_SLIP and level._crate_lid().rotation.x < -1.6, "Matching the marked case reveals its empty recess and transfer slip")
	await _tap(KEY_E)
	_check(level.ship_step == level.ShipStep.STRONGBOX and level.checkpoint == level.Checkpoint.TRANSFER and not level._crate_lid().get_node("DispatchKey").visible, "Taking the dispatch key records the purser’s cabin lead")
	await create_timer(maxf(0.1, level.PORT_FIRE + 0.2 - level.fire_elapsed)).timeout
	_check(level.get_node("Ships/Fire/DeckShortcut/FireLight").visible and level.get_node("Ships/Fire/PortAisle/FireLight").visible, "Both alternative stern passages visibly catch fire")
	for destination in [Vector3(17.25, -1.2, -23.15), Vector3(17.35, -1.2, -24.35), level._point("StarboardLanding"), level._point("Seal")]:
		_check(await _walk(destination), "The starboard stair remains a walkable route to the purser")
	_check(level.player.position.y > 0.85, "The stern cabin stands above the hold")
	await _tap(KEY_E)
	await create_timer(0.5).timeout
	_check(level.ship_step == level.ShipStep.TAKE_SEAL and level.seal.visible and not level.seal.collected and level.get_node("Ships/OutboundMerchant/PurserCabin/Strongbox/Lid").rotation.x < -1.6, "The dispatch key opens the strongbox before the seal can be taken")
	await _tap(KEY_E)
	_check(level.phase == level.Phase.ENDING and level.seal.collected, "Taking the Night Seal starts the comic")
	for index in 3:
		await _tap(KEY_SPACE)
	_check(level.comic.panel == 3 and level.comic.bubble.text == "YOU" and level.comic.bubble.modulate.a == 1.0, "The final panel reveals the exact speech bubble")


func _check_early_lock() -> void:
	change_scene_to_file("res://Levels/TheLastBarrel.tscn")
	await scene_changed
	await _attach()
	level.guard.active = false
	var lock_at: Vector3 = level._point("OfficeLock")
	_check(await _walk(Vector3(-2.55, 0, 13.35)) and await _walk(Vector3(-2.52, 0, 5.85)) and await _walk(lock_at), "Rook can reach the closed lock straight from arrival")
	# Start with a full gap between glances. Leave the pick in place after the
	# first pin so we also exercise the shipmaster interrupting the attempt.
	for glance in [true, false]:
		for frame in 720:
			if level._master_visible == glance:
				break
			await physics_frame
	await _tap(KEY_E)
	_check(level.phase == level.Phase.SCOUT and level.modal == level.Modal.LOCK, "The arrival phase allows lockpicking when the shipmaster looks away")
	if failures:
		return
	_check(await _seat_pin(0), "The first pin can be seated during the smoke break")
	for frame in 720:
		if level.modal == level.Modal.NONE:
			break
		await physics_frame
	_check(level.modal == level.Modal.NONE and level.pins.seated == 1, "The shipmaster interrupts visible picking without losing the seated pin")
	for frame in 720:
		if not level._seen():
			break
		await physics_frame
	await _tap(KEY_E)
	for index in range(1, 4):
		_check(await _seat_pin(index), "Early picking seats remaining pin %d" % (index + 1))
	await create_timer(0.6).timeout
	_check(level.door_unlocked and level.phase == level.Phase.SCOUT and absf(level.door.rotation.y) > 1.0, "Picking all pins early opens the door and keeps the scouting objective")
	if failures:
		return
	_check(await _walk(Vector3(-2.52, 0, 5.85)) and await _walk(level._point("Scout")), "Rook can return to the overlook after picking")
	_check(await _walk(Vector3(0.55, 0, -2.66)) and await _walk(Vector3(3.15, 0, -2.66)) and await _walk(Vector3(3.15, 0, -4.12)), "The bell is still accessible after opening the office early")
	await _check_argument(level.Phase.ENTER_OFFICE)
	_check(level.door_unlocked, "Quelling the watch keeps the already-picked office available")


func _check_checkpoints() -> void:
	var variant: int = level.signature.variant_index
	level._retry = {"checkpoint": level.Checkpoint.OFFICE, "variant": variant}
	reload_current_scene()
	await scene_changed
	await _attach()
	var post: Vector3 = level.sentinel.position
	level._place_player(post + Vector3(0, 0.49, 0.15))
	await scene_changed
	await _attach()
	_check(level.phase == level.Phase.OFFICE_LOCK and level.player.position.distance_to(level._point("OfficeApproach")) < 0.3, "A real sentinel sighting restores the office checkpoint")
	level._retry = {"checkpoint": level.Checkpoint.BARREL, "variant": variant}
	reload_current_scene()
	await scene_changed
	await _attach()
	_check(level.phase == level.Phase.BARREL_RUN and level.manifest_swapped and not level.barrel.player_inside, "Barrel checkpoint keeps the swap and restores the empty barrel")
	level._place_player(level._point("LoadingMark") + Vector3.UP * 0.49)
	level.delivery_left = 7.9
	await scene_changed
	await _attach()
	_check(level.phase == level.Phase.BARREL_RUN and level.signature.variant_index == variant, "An unoccupied barrel fails the handoff and keeps the run’s signature")
	level._retry = {"checkpoint": level.Checkpoint.BOARDING, "variant": variant}
	reload_current_scene()
	await scene_changed
	await _attach()
	await create_timer(level.DECK_FIRE + 0.1).timeout
	level._place_player(level.get_node("Ships/Fire/DeckShortcut").global_position + Vector3.UP * 0.49)
	await scene_changed
	await _attach()
	_check(level.phase == level.Phase.SHIP and level.fire_elapsed < 0.2 and level.player.position.distance_to(level._point("Boarding")) < 0.4, "Fire contact restores the boarding checkpoint")
	level._place_player(level._point("Seal"))
	await _tap(KEY_E)
	_check(level.ship_step == level.ShipStep.SLATE and not level.seal.visible and not level.seal.collected, "The strongbox stays locked if the cabin is reached early")
	level._place_player(level._point("CrescentCrate"))
	await _tap(KEY_E)
	_check(level.ship_step == level.ShipStep.SLATE and is_zero_approx(level._crate_lid().rotation.x), "The marked crate stays sealed until its cargo is identified")
	level._place_player(level._point("CargoSlate"))
	await _tap(KEY_E)
	level._place_player(Vector3(0, -3.5, -50))
	await scene_changed
	await _attach()
	_check(level.ship_step == level.ShipStep.MARKS and level.player.position.distance_to(level._point("CargoSlate")) < 0.4, "Falling overboard after reading the tally keeps the cargo clue")
	level._place_player(level._point("CrescentCrate"))
	await _tap(KEY_E)
	await create_timer(0.5).timeout
	await _tap(KEY_E)
	await create_timer(level.DECK_FIRE + 0.1).timeout
	level._place_player(level.get_node("Ships/Fire/DeckShortcut").global_position + Vector3.UP * 0.49)
	await scene_changed
	await _attach()
	_check(level.ship_step == level.ShipStep.STRONGBOX and level.player.position.distance_to(level._point("CrescentCrate")) < 0.4 and not level._crate_lid().get_node("DispatchKey").visible, "A fire retry preserves the transfer slip, open crate and key")
	_check(level.get_node("Ships/Fire/PortAisle/FireLight").visible, "The starboard passage remains the clear route on a late retry")


func _walk(destination: Vector3, speed := 4.2) -> bool:
	var player: CharacterBody3D = level.player
	for frame in 700:
		await physics_frame
		if not is_instance_valid(player):
			return false
		if player.interaction_locked:
			print("Movement interrupted at ", player.position, " toward ", destination, " / ", level._story.text)
			return false
		var offset := destination - player.position
		offset.y = 0
		if offset.length() < 0.12:
			player.velocity = Vector3.ZERO
			return true
		player.velocity = offset.normalized() * minf(speed, offset.length() * 60.0)
		player.velocity.y = -2.0
		player.move_and_slide()
	print("Blocked at ", player.position, " toward ", destination)
	return false


func _wait_phase(phase: int, seconds: float) -> bool:
	for frame in ceili(seconds * 60.0):
		await physics_frame
		if not is_instance_valid(level):
			return false
		if level.phase == phase:
			return true
	return false


func _tap(key: Key) -> void:
	_input(key, true)
	await process_frame
	_input(key, false)
	await process_frame


func _input(key: Key, pressed: bool) -> void:
	if using_pad:
		var joy := InputEventJoypadButton.new()
		joy.button_index = {KEY_E: JOY_BUTTON_B, KEY_Q: JOY_BUTTON_Y, KEY_SPACE: JOY_BUTTON_A, KEY_RIGHT: JOY_BUTTON_DPAD_RIGHT, KEY_D: JOY_BUTTON_DPAD_RIGHT, KEY_A: JOY_BUTTON_DPAD_LEFT, KEY_W: JOY_BUTTON_DPAD_UP}[key]
		joy.pressed = pressed
		Input.parse_input_event(joy)
	else:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func _check(ok: bool, line: String) -> void:
	if ok:
		print("PASS ", line)
	else:
		failures += 1
		push_error(line)
