extends Node3D

signal ready_for_play

enum Phase { SCOUT, DISTRACTION, ALTERCATION, OFFICE_LOCK, ENTER_OFFICE, STUDY, REPLACE,
	LEAVE_OFFICE, SORTING, BARREL_RUN, LOADING, SHIP, ENDING }
enum Checkpoint { ARRIVAL, OFFICE, BARREL, BOARDING, HATCH, TRANSFER }
enum Modal { NONE, LOCK, SIGNATURE }
enum ShipStep { SLATE, MARKS, TRANSFER_SLIP, STRONGBOX, TAKE_SEAL }

const Forgery := preload("res://Modules/Gameplay/SignatureForgery/signature_forgery.gd")
const Pins := preload("res://Modules/Gameplay/Lockpicking/listening_pins.gd")
const Comic := preload("res://Modules/Gameplay/LastBarrel/ending_comic.gd")
const ShipEvidence := preload("res://Modules/Gameplay/LastBarrel/ship_evidence.gd")
const DockCutaway := preload("res://Modules/Gameplay/LastBarrel/dock_cutaway.gd")
const BLOCK_PRINT_LIGHTING := preload("res://scenes/BlockPrintLighting.tscn")
const DELIVERY_WINDOW := 65.0
const DECK_FIRE := 12.0
const PORT_FIRE := 26.0
const STAIR_FOOT := Vector3(-6.03, 0, 3.82)
const STAIR_TOP := Vector3(-6.03, 2.8, -3.18)
const OFFICE_ENTRY := Vector3(-8.2, 2.8, -3.18)
const OFFICE_ROUTE := [
	OFFICE_ENTRY, Vector3(-7.56, 2.8, -1.3), Vector3(-7.56, 2.8, 0.55),
	Vector3(-7.56, 2.8, 2.78), Vector3(-10.55, 2.8, 2.78), Vector3(-7.56, 2.8, 2.78),
]
const SONNET := [
	"Shall I compare thee to a harbor light?",
	"No. A harbor light is useful.",
	"Thy beams are bright against the restless tide…",
	"Tide. Wide. Pride. Something less obvious.",
	"O moon, forgive the meter of the sea.",
	"That will do. For now.",
]
const DIRECTIONS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
const SHIP_PROPS := {
	&"CargoSlate": ^"FreightDeck/CargoSlate",
	&"SailclothCrate": ^"LowerHold/SailclothCrate",
	&"SilverCrate": ^"LowerHold/SilverCrate",
	&"CrescentCrate": ^"LowerHold/MarkedCrate",
	&"Seal": ^"PurserCabin/Strongbox",
}

static var _retry: Dictionary = {}

@export var start_aboard := false
@export var block_print_lighting := true

@onready var player = $Player
@onready var guard = $Guards/DockWatch
@onready var sentinel = $Guards/Sentinel
@onready var master = $People/Shipmaster
@onready var pipe = $People/Shipmaster/SmokingPipe
@onready var clerk = $People/Clerk
@onready var porter: Node3D = $People/Porter
@onready var barrel = $Cargo/SpareBarrel
@onready var door: Node3D = $Quay/Office/Door/Hinge
@onready var desk = $Quay/Office/Manifest
@onready var seal: Area3D = $Ships/OutboundMerchant/NightSeal
@onready var camera: Camera3D = $LevelCamera

var phase := Phase.SCOUT
var checkpoint := Checkpoint.ARRIVAL
var modal := Modal.NONE
var pins := Pins.new()
var signature: Forgery
var comic: Comic
var studied := false
var door_unlocked := false
var manifest_swapped := false
var controller := false
var delivery_left := DELIVERY_WINDOW
var fire_elapsed := 0.0
var ship_step := ShipStep.SLATE
var _evidence: ShipEvidence
var _dock_cutaway: DockCutaway
var _objective: Label
var _prompt: Label
var _dialogue: Node2D
var _caption: Node2D
var _styled_hud: CanvasLayer
var _alert_eye: AlertEye
var _story_alerts := {}
var _confirmed_alert_time := 0.0
var _patrol: Label
var _pin_readout: Label
var _pin_panel: PanelContainer
var _tick: AudioStreamPlayer3D
var _bell_sound: AudioStreamPlayer3D
var _fire_sound: AudioStreamPlayer
var _pin_glint := 0.0
var _story_left := 0.0
var _restart_queued := false
var _door_busy := false
var _reopen_door := false
var _break_clock := 0.0
var _tea_distraction := 0.0

var _kit_briefed := false
var _kit_farewell := false
var _smoking := false
var _smoke_clock := 0.0
var _checkpoint_pins := 0
var _checkpoint_barrel := Vector3.ZERO
var _checkpoint_table_taken := false
var _master_index := 0
var _master_pause := 0.0
var _office_returning := false
var _office_patrolling := false
var _master_awareness := 0.0
var _master_visible := false
var _delivery_started := false
var _delivery_arrived := false


func _ready() -> void:
	if block_print_lighting:
		add_child(BLOCK_PRINT_LIGHTING.instantiate())
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_build_ui(int(_retry.get("variant", -1)))
	_build_audio()
	for title in ["Shipmaster", "TeaWatch", "LandingWatch"]:
		var alert := preload("res://Modules/Gameplay/LastBarrel/story_alert.gd").new()
		$People.get_node(title).add_child(alert)
		_story_alerts[title] = alert
	desk.set_manifest_signature(signature.source_ink)
	guard.player_caught.connect(_capture)
	sentinel.player_caught.connect(_capture)
	player.noise_emitted.connect(_on_noise)
	seal.monitoring = false
	seal.hide()
	seal.get_node("Ring").hide()
	seal.recovered.connect(func(_item): _finish())
	_checkpoint_barrel = barrel.position
	if not _retry.is_empty():
		player.quay_intro = 0.0
		_checkpoint_pins = int(_retry.get("seated", 0))
		_checkpoint_barrel = _retry.get("barrel_position", barrel.position)
		_checkpoint_table_taken = _retry.get("table_taken", false)
		checkpoint = _retry.get("checkpoint", Checkpoint.ARRIVAL) as Checkpoint
		_retry.clear()
		_restore_checkpoint()
	elif start_aboard:
		checkpoint = Checkpoint.BOARDING
		_restore_checkpoint()
	else:
		_begin_smoke_break()
	if not start_aboard:
		var deckhand := create_tween().set_loops()
		deckhand.tween_property($People/LighterHand, "position:x", -5.5, 3.7)
		deckhand.tween_interval(2.4)
		deckhand.tween_property($People/LighterHand, "position:x", -8.2, 3.7)
		deckhand.tween_interval(1.8)
	$Quay.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	guard.navigation_ready = true
	sentinel.navigation_ready = true
	ready_for_play.emit()


func _begin_smoke_break() -> void:
	_smoking = true
	master.position = _point("SmokingPost")
	master.rotation.y = PI
	pipe.set_lit(true)
	_say("ROOK  /  The fish stalls are shut. If the tip is right, the Night Seal sails from the quay below.", 8.0)


func _restore_checkpoint() -> void:
	if checkpoint != Checkpoint.ARRIVAL:
		_rest_pipe()
	if checkpoint in [Checkpoint.OFFICE, Checkpoint.BARREL]:
		barrel.position = _checkpoint_barrel
		barrel.barrel_base_y = _checkpoint_barrel.y
		$Cargo/SpareBarrel/Tabletop.visible = not _checkpoint_table_taken
	match checkpoint:
		Checkpoint.ARRIVAL:
			_begin_smoke_break()
		Checkpoint.OFFICE:
			pins.seated = _checkpoint_pins
			door_unlocked = pins.seated == Pins.CONTACTS.size()
			phase = Phase.ENTER_OFFICE if door_unlocked else Phase.OFFICE_LOCK
			door.rotation.y = deg_to_rad(101.0) if door_unlocked else 0.0
			master.position = _point("WatchArgument")
			master.look_at(sentinel.position)
			_place_player(_point("OfficeApproach"))
			_say("ROOK  /  The shipmaster is sorting out the watch. The office is clear.")
		Checkpoint.BARREL:
			manifest_swapped = true
			door_unlocked = true
			master.position = OFFICE_ROUTE[0]
			_stow_original_stock()
			_place_player(_point("SortingOverlook"))
			_start_barrel_run()
		Checkpoint.BOARDING, Checkpoint.HATCH, Checkpoint.TRANSFER:
			manifest_swapped = true
			_stow_original_stock()
			_start_fire()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		controller = true
	elif event is InputEventKey or event is InputEventMouseButton:
		controller = false
	signature.using_controller = controller


func _unhandled_input(event: InputEvent) -> void:
	if modal == Modal.SIGNATURE and signature.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or event.is_echo():
		return
	if _dialogue.active and event.is_action_pressed("dialogue_advance"):
		_dialogue.advance()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart"):
		_retry.clear()
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
		return
	if phase == Phase.ENDING:
		if event.is_action_pressed("dialogue_advance"):
			comic.controller = controller
			comic.advance()
			get_viewport().set_input_as_handled()
		return
	if _restart_queued or phase == Phase.LOADING:
		return
	if event.is_action_pressed("secondary_action"):
		if modal == Modal.LOCK:
			_close_modal()
		elif phase == Phase.DISTRACTION and not barrel.player_inside and not barrel.transition_in_progress and _near($Quay/DistractionBell, 1.85):
			_start_altercation()
		else:
			return
	elif event.is_action_pressed("interact"):
		if not _interact():
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _interact() -> bool:
	if _dialogue.active:
		_dialogue.advance()
		return true
	if phase == Phase.SCOUT and not _kit_briefed and _near($People/Kit, 2.1):
		_start_kit_briefing()
		return true
	if modal == Modal.LOCK:
		pins.listening = pins.contact
		if not pins.contact:
			_contact_tick(0.70)
		return true
	if modal != Modal.NONE:
		return false
	if phase == Phase.ENTER_OFFICE and _tea_distraction <= 0.0 and _near($Quay/Office/TeaKettle, 1.25):
		_tea_distraction = 4.0
		_tick.play()
		_say("ROOK  /  That rattle should keep the watch busy for a moment.", 3.0)
		return true
	if phase < Phase.LOADING:
		if barrel.transition_in_progress:
			return false
		if barrel.player_inside:
			barrel.exit_barrel()
			return true
	if _can_try_lock():
		if _seen():
			_say("ROOK  /  Wait till he turns his back." if _master_visible else "ROOK  /  Wait until the watch passes.")
			return true
		modal = Modal.LOCK
		player.set_interaction_locked(true)
		_pin_panel.show()
		return true
	if phase in [Phase.STUDY, Phase.REPLACE] and _near($Points/Desk, 1.15):
		if _seen():
			_say("ROOK  /  Wait for the shipmaster to turn away.")
		elif phase == Phase.STUDY:
			studied = true
			_open_forgery(Forgery.View.MANUSCRIPT)
		else:
			_swap_manifest()
		return true
	if phase == Phase.STUDY and studied and _in_office() and not _seen() and _office_cover():
		_open_forgery(Forgery.View.DRAFT)
		return true
	if door_unlocked and phase < Phase.SORTING and _near($Quay/Office/Door, 1.48):
		if _door_busy:
			_reopen_door = true
		else:
			_swing(true)
		return true
	if phase < Phase.LOADING and _near(barrel, 1.35):
		var tabletop := $Cargo/SpareBarrel/Tabletop
		if tabletop.visible and not _card_guards_away():
			_say("ROOK  /  That’s their card table. Wait until they go for tea.")
			return true
		tabletop.hide()
		barrel.enter_barrel(player)
		return true
	var exhibit := _nearby_exhibit()
	if exhibit:
		_say(str(exhibit.get_meta("inscription")), 8.0)
		return true
	if phase == Phase.SHIP:
		return _inspect_ship(_ship_target())
	return false


func _start_kit_briefing() -> void:
	var lines: Array[Dictionary] = [
		{"speaker": "Kit", "text": "The Night Seal is meant to sail tonight. My contact saw the merchant at the far berth."},
		{"speaker": "Rook", "text": "Do we know where they stowed it?"},
		{"speaker": "Kit", "text": "No. The shipmaster keeps the cargo list in his quarters. The hound at the crank guards the gangway."},
		{"speaker": "Kit", "text": "Take this note. The fish steps and the cart ramp both lead down to the quay."},
		{"speaker": "Rook", "text": "I’ll take a look. Keep a way home open for me."},
		{"speaker": "Kit", "text": "Always. I’ll watch from here. Good luck, Rook."},
	]
	_caption.hide()
	_prompt.get_parent().hide()
	player.set_interaction_locked(true)
	_dialogue.start_dialogue(lines)
	_dialogue.set_advance_hint("Cross / Circle" if controller else "Space / E")


func _physics_process(delta: float) -> void:
	if _restart_queued or phase == Phase.ENDING:
		return
	_confirmed_alert_time = maxf(0.0, _confirmed_alert_time - delta)
	_story_left = maxf(0.0, _story_left - delta)
	_caption.visible = _story_left > 0 and not _dialogue.active and modal == Modal.NONE
	if player.position.y < -2.65:
		if phase == Phase.SHIP:
			_fail("Rook fell overboard.")
		else:
			_capture()
		return
	match phase:
		Phase.SCOUT:
			if _near($Points/Scout, 2.0):
				_kit_briefed = true
				phase = Phase.DISTRACTION
				_say("ROOK  /  The valuables are already aboard. I’ll have to find a way onto that ship.", 7.0)
		Phase.ENTER_OFFICE:
			if _near($Points/Desk, 2.35) and _in_office():
				phase = Phase.STUDY
				_return_to_office()
		Phase.LEAVE_OFFICE:
			if not _in_office() and _near($Points/OfficeExit, 2.1):
				phase = Phase.SORTING
				_say("ROOK  /  There should be one potato barrel left in sorting.")
		Phase.SORTING:
			if _near($Points/SortingOverlook, 1.8):
				_show_other_ship()
		Phase.BARREL_RUN:
			_tick_delivery(delta)
		Phase.SHIP:
			_tick_fire(delta)
	if phase < Phase.LOADING:
		_tick_break_guards(delta)
	if _kit_briefed and not _kit_farewell and phase == Phase.SCOUT and player.position.z < 25.5:
		_kit_farewell = true
		_say("KIT  /  I’ll be watching. Come back in one piece.", 4.0)
	if _smoking:
		_tick_smoke_break(delta)
	if _office_patrolling:
		_tick_office_patrol(delta)
	if phase in [Phase.STUDY, Phase.REPLACE, Phase.LEAVE_OFFICE]:
		_tick_master_sight(delta)
	if modal == Modal.LOCK:
		if _seen():
			_close_modal()
			_say("ROOK  /  He’s looking at the lock. Keep the pick out of sight." if _smoking and _master_visible else "ROOK  /  The watch is back. Wait for another opening.")
		else:
			_tick_lock(delta)
	elif modal == Modal.SIGNATURE and (_seen() or not _in_office()):
		_close_modal()
		_say("ROOK  /  Tuck the paper away. Keep out of sight.")
	_update_ui()


func _card_guards_away() -> bool:
	return _break_clock >= 5.0 and _break_clock < 10.0


func _tick_break_guards(delta: float) -> void:
	_break_clock = fmod(_break_clock + delta, 13.0)
	var tea_break := smoothstep(3.3, 5.0, _break_clock) * (1.0 - smoothstep(10.0, 12.0, _break_clock))
	$People/CardWatch.position = Vector3(-11.55, 0, 12.8).lerp(Vector3(-13.2, 0, 15.8), tea_break)
	$People/CardPartner.position = Vector3(-10.4, 0, 11.55).lerp(Vector3(-11.3, 0, 15.6), tea_break)
	_tea_distraction = maxf(0.0, _tea_distraction - delta)
	var tea := smoothstep(0.5, 3.0, _break_clock) * (1.0 - smoothstep(7.0, 9.0, _break_clock))
	$People/TeaWatch.position = Vector3(-9.5, 0, 2).lerp(Vector3(-7.55, 0, 3.75), tea)
	var on_stairs: bool = player.position.x > -7.0 and player.position.x < -5.1
	var crosses_tea_watch: bool = on_stairs and player.position.y < 0.85 and player.position.distance_to($People/TeaWatch.position) < 1.85
	if crosses_tea_watch and _tea_distraction <= 0.0 and player.velocity.length() > 2.2:
		_confirm_story_alert("TeaWatch")
		_say("TEA WATCH  /  Who’s there?", 2.0)
		_capture()
	var on_bare_boards: bool = player.position.y > 3 and player.position.x < -11.45
	if on_bare_boards and player.position.distance_to($People/LandingWatch.position) < 1.6 and player.velocity.length() > 2.2:
		_confirm_story_alert("LandingWatch")
		_say("LANDING WATCH  /  What was that?", 2.0)
		_capture()


func _can_try_lock() -> bool:
	return phase <= Phase.OFFICE_LOCK and not door_unlocked and not _door_busy and _near($Points/OfficeLock, 1.2)


func _tick_smoke_break(delta: float) -> void:
	# He turns from the water to check his doorway, then goes back to his pipe.
	_smoke_clock = fmod(_smoke_clock + delta, 9.0)
	var glance := smoothstep(5.5, 6.4, _smoke_clock) * (1.0 - smoothstep(7.8, 8.8, _smoke_clock))
	master.rotation.y = PI + lerpf(-0.18, 1.42, glance)
	var offset: Vector3 = player.position - master.position
	offset.y = 0.0
	var facing: Vector3 = -master.global_basis.z
	var in_view := offset.length() < 4.1 and facing.dot(offset.normalized()) > 0.75
	_master_visible = in_view and not barrel.conceals(player, master) and _ray_clear(master.position + Vector3.UP * 1.06, player.position + Vector3.UP * 0.36)


func _rest_pipe() -> void:
	pipe.top_level = true
	pipe.global_rotation = Vector3(0, -PI / 2.0, 0)
	pipe.global_position = _point("Ashtray")
	pipe.set_lit(false)


func _put_out_pipe() -> void:
	_smoking = false
	_master_visible = false
	master.look_at(Vector3(_point("Ashtray").x, master.position.y, _point("Ashtray").z))
	pipe.top_level = true
	var motion := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(pipe, "global_position", _point("Ashtray"), 0.55)
	motion.parallel().tween_property(pipe, "global_rotation", Vector3(0, -PI / 2.0, 0), 0.55)
	await motion.finished
	_rest_pipe()


func _start_altercation() -> void:
	phase = Phase.ALTERCATION
	$Quay/DistractionBell.ring()
	_bell_sound.play()
	guard.active = false
	guard.player_visible = false
	guard.guard_state = StealthGuard.GuardState.PATROL
	_say("DOCK WATCH  /  Who rang that? You were meant to check the quay.", 4.3)
	var approach: Array[Vector3] = []
	if guard.position.x < -3.15:
		approach.append(Vector3(-2.65, 0, 5.75))
	approach.append_array([Vector3(2.9, 0, -2.5), Vector3(4.72, 0, -8.95)])
	await _move_watch(approach, 3.2)
	guard._face_position(sentinel.position, 1.0)
	sentinel._face_position(guard.position, 1.0)
	await _move_watch([Vector3(5.15, 0, -9.08), Vector3(4.38, 0, -8.75)], 2.4)
	_dock_cutaway.follow(sentinel, "At the gangway", 3.8, sentinel)
	_say("SENTINEL  /  Strict orders. I stay at this entrance until the ship is gone.", 6.0)
	await get_tree().create_timer(2.35, false).timeout
	_dock_cutaway.follow(master, "Outside the office", 3.3)
	master.says("What in blazes…")
	_say("SHIPMASTER  /  What in blazes…", 2.4)
	await get_tree().create_timer(0.60, false).timeout
	await _put_out_pipe()
	await get_tree().create_timer(0.30, false).timeout
	master.says("")
	if not await _walk_master([Vector3(-2.65, 0, 5.55), Vector3(4.65, 0, -2.40), _point("WatchArgument")], 3.45):
		return
	master.look_at(sentinel.position)
	guard._face_position(master.position, 1.0)
	master.says("Enough. You keep the gate. Back to your rounds.")
	_say("SHIPMASTER  /  Enough. You keep the gate. Back to your rounds.", 3.0)
	_dock_cutaway.follow(master, "At the gangway", 2.7, sentinel)
	await get_tree().create_timer(2.7, false).timeout
	if _restart_queued:
		return
	master.says("")
	sentinel._face_position(sentinel.position + Vector3.BACK, 1.0)
	checkpoint = Checkpoint.OFFICE
	_checkpoint_pins = pins.seated
	_remember_barrel()
	phase = Phase.ENTER_OFFICE if door_unlocked else Phase.OFFICE_LOCK
	_say("ROOK  /  I already have the door. Time to find his manifest." if door_unlocked else "ROOK  /  His office is empty. I can change what goes aboard.", 6.0)
	await _move_watch([Vector3(2.9, 0, -2.5), Vector3(0.9, 0, 3.1)], 2.4)
	if phase < Phase.LOADING:
		guard.active = true


func _move_watch(points: Array[Vector3], speed: float) -> void:
	for at in points:
		var distance: float = guard.position.distance_to(at)
		guard._face_position(at, 1.0)
		var motion := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		motion.tween_property(guard, "position", at, maxf(distance / speed, 0.1))
		await motion.finished


func _swing(open: bool, duration := 0.48) -> void:
	if _door_busy:
		return
	_door_busy = true
	var movement := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	movement.tween_property(door, "rotation:y", deg_to_rad(101.0) if open else 0.0, duration)
	await movement.finished
	_door_busy = false
	var reopen := _reopen_door and not open
	_reopen_door = false
	if reopen:
		await _swing(true)


func _return_to_office() -> void:
	_office_returning = true
	_say("ROOK  /  He’s coming back. Study the page, then finish the signature in cover.", 6.0)
	if not await _walk_master([Vector3(4.65, 0, -2.40), Vector3(-2.65, 0, 5.55), Vector3(-6.1, 0, 5.8)], 2.95):
		return
	if not await _wait_for_door():
		return
	await _swing(true)
	if not await _walk_master([STAIR_FOOT, STAIR_TOP, OFFICE_ENTRY], 1.8):
		return
	await _swing(false)
	_office_returning = false
	if phase >= Phase.BARREL_RUN:
		return
	_office_patrolling = true
	_master_pause = 1.1
	master.says(SONNET[0])


func _walk_master(points: Array[Vector3], speed: float) -> bool:
	for at in points:
		while is_inside_tree() and not _restart_queued:
			if master.walk_to(at, get_physics_process_delta_time(), speed):
				break
			await get_tree().physics_frame
		if not is_inside_tree() or _restart_queued:
			return false
	return true


func _wait_for_door() -> bool:
	while _door_busy and is_inside_tree() and not _restart_queued:
		await get_tree().physics_frame
	return is_inside_tree() and not _restart_queued


func _tick_office_patrol(delta: float) -> void:
	if _master_pause > 0:
		_master_pause -= delta
		return
	if master.walk_to(OFFICE_ROUTE[_master_index], delta, 1.18):
		master.says(SONNET[_master_index])
		_master_index = (_master_index + 1) % OFFICE_ROUTE.size()
		_master_pause = 1.55


func _tick_master_sight(delta: float) -> void:
	_master_visible = false
	if not (_office_patrolling or _office_returning) or not _in_office() or player.position.x > -7.13 or _behind_chart_rack() or barrel.conceals(player, master):
		_master_awareness = 0.0
		return
	var offset: Vector3 = player.global_position - master.global_position
	offset.y = 0.0
	var facing: Vector3 = -master.global_basis.z
	var in_view := offset.length() < 0.94 or (offset.length() < 5.3 and facing.dot(offset.normalized()) > 0.68)
	if in_view and _ray_clear(master.global_position + Vector3.UP * 1.06, player.global_position + Vector3.UP * 0.36):
		_master_visible = offset.length() < 0.94 or player.get_node("ExposureSensor").exposure > 0.12
	_master_awareness = clampf(_master_awareness + delta * (0.80 if _master_visible else -1.45), 0.0, 1.0)
	_story_alerts["Shipmaster"].update_awareness(_master_awareness)
	if _master_awareness >= 1.0:
		_confirm_story_alert("Shipmaster")
		_capture()


func _tick_lock(delta: float) -> void:
	_pin_glint = maxf(0, _pin_glint - delta)
	if pins.sweep(Input.get_axis("move_left", "move_right"), delta):
		_pin_glint = 0.32
		_contact_tick(1.24)
	if pins.listen(Input.is_action_pressed("interact"), delta):
		_contact_tick(1.73)
		if pins.seated == Pins.CONTACTS.size():
			_close_modal()
			door_unlocked = true
			if phase == Phase.OFFICE_LOCK:
				phase = Phase.ENTER_OFFICE
			_swing(true)
			_say("Latch released", 2.5)
	var segments := ""
	for index in Pins.CONTACTS.size():
		segments += "●  " if index < pins.seated else "○  "
	var feedback := "CONTACT   ·   Hold to seat" if pins.contact else "Sweep slowly to feel for contact"
	if _pin_glint > 0:
		feedback = "CONTACT"
	_pin_readout.text = segments + "\n" + feedback + "\n" + ("Stick ↔  Sweep   Hold Circle  Listen   Triangle  Back" if controller else "← →  Sweep   Hold E  Listen   Q  Back")


func _open_forgery(view: Forgery.View) -> void:
	modal = Modal.SIGNATURE
	signature.present(view)
	if view == Forgery.View.MANUSCRIPT:
		desk.set_manifest_open(true)
	player.set_interaction_locked(true)


func _close_modal() -> void:
	if signature.view == Forgery.View.MANUSCRIPT:
		desk.set_manifest_open(false)
	signature.dismiss()
	pins.release()
	_pin_panel.hide()
	modal = Modal.NONE
	player.set_interaction_locked(false)


func _draft_complete() -> void:
	_close_modal()
	if not _seen():
		phase = Phase.REPLACE
		_say("REPLACEMENT READY  /  One extra barrel of potatoes. Swap the pages at the desk.", 6.0)


func _swap_manifest() -> void:
	manifest_swapped = true
	phase = Phase.LEAVE_OFFICE
	$Quay/Office/ReplacedPage.show()
	_say("ROOK  /  Now to get back to sorting.", 4.0)


func _show_other_ship() -> void:
	# The reveal runs alongside the first seconds of the deadline.
	checkpoint = Checkpoint.BARREL
	_remember_barrel()
	_start_barrel_run()
	_say("ROOK  /  The last barrels went onto the lighter! The guard courtyard had a barrel for a card table.", 6.0)
	var overview := create_tween()
	player.follow_size = 18.3
	overview.tween_interval(4.0)
	overview.tween_property(player, "follow_size", 11.1, 0.8)
	var stock := $Cargo/PotatoStock.get_children()
	for index in stock.size():
		var prop: Node3D = stock[index]
		var movement := create_tween().set_trans(Tween.TRANS_SINE)
		movement.parallel().tween_property(porter, "position", Vector3(-8.15, 0, -10.5), 0.75)
		movement.tween_property(prop, "position", Vector3(-8.3, 1.0, -13.25), 0.7)
		movement.tween_property(prop, "position", _stock_destination(index), 0.8)
		await movement.finished


func _remember_barrel() -> void:
	_checkpoint_table_taken = not $Cargo/SpareBarrel/Tabletop.visible
	_checkpoint_barrel = Vector3(barrel.position.x, barrel.barrel_base_y, barrel.position.z)


func _start_barrel_run() -> void:
	phase = Phase.BARREL_RUN
	delivery_left = DELIVERY_WINDOW
	_office_patrolling = false
	master.says("")
	_prepare_courier()


func _prepare_courier() -> void:
	# Keep the actor inside the office until it is time to deliver the page.
	while _office_returning and is_inside_tree() and not _restart_queued:
		await get_tree().physics_frame
	if not is_inside_tree() or _restart_queued:
		return
	var route: Array[Vector3] = [Vector3(master.position.x, 2.8, -3.18), OFFICE_ENTRY, STAIR_TOP, STAIR_FOOT]
	await _walk_master(route, 2.8)


func _tick_delivery(delta: float) -> void:
	delivery_left = maxf(0.0, delivery_left - delta)
	if delivery_left <= 8.0 and not _delivery_started:
		_delivery_started = true
		_deliver_manifest()
	if delivery_left > 0:
		return
	if not _delivery_arrived:
		return
	if not barrel.player_inside or barrel.inside_player != player or barrel.transition_in_progress or not _near($Points/LoadingMark, 0.85):
		_fail("The manifest reached sorting before the potato barrel.")
		return
	_load_barrel()


func _deliver_manifest() -> void:
	master.get_node("DeliveryPaper").show()
	if not await _wait_for_door():
		return
	await _swing(true, 0.30)
	var route: Array[Vector3] = [Vector3(-6.1, 0, 5.35), Vector3(-2.72, 0, 5.35),
		Vector3(0.87, 0, -6.72), Vector3(0.87, 0, -7.85), Vector3(-3.0, 0, -7.85)]
	if not await _walk_master(route, 3.65):
		return
	master.says("The outbound manifest.")
	master.get_node("DeliveryPaper").hide()
	$Quay/ClerkDelivery.show()
	_delivery_arrived = true


func _load_barrel() -> void:
	phase = Phase.LOADING
	guard.active = false
	sentinel.active = false
	player.set_interaction_locked(true)
	clerk.says("One barrel of potatoes still ashore. Put it aboard.")
	_say("CLERK  /  One barrel of potatoes still ashore. Put it aboard.", 4.0)
	porter.look_at(Vector3(0.4, 0.0, -9.1))
	var approach := create_tween()
	approach.tween_property(porter, "position", Vector3(-0.18, 0, -9.16), 1.6)
	await approach.finished
	var hoist_path: Array[Vector3] = [Vector3(0.4, 2.5, -9.1), Vector3(-0.65, 2.5, -21), Vector3(-0.65, 0, -21)]
	await barrel.carry_to(hoist_path, $Quay/HoistLine)
	_start_fire()


func _start_fire() -> void:
	phase = Phase.SHIP
	# The quay jib has emptied its sling and swung back over the dock.
	var boom: MeshInstance3D = $Quay/HoistBoom
	boom.position = Vector3(-4.8, 3.63, -11.6)
	boom.rotation.y = 1.2
	$Quay/HoistLine.hide()
	barrel.position = _point("Boarding") + Vector3(-0.93, -0.07, -0.45)
	barrel.rotation.x = PI * 0.5
	player.begin_ship_search()
	guard.active = false
	sentinel.active = false
	for actor in [guard, sentinel]:
		actor.player_visible = false
	_ignite($Ships/Fire/Smoke)
	_fire_sound.play()
	_objective.get_parent().hide()
	_prompt.get_parent().add_theme_stylebox_override("panel", ShipEvidence.caption_style())
	seal.get_node("Caption").hide()
	match checkpoint:
		Checkpoint.TRANSFER:
			_place_player(_point("CrescentCrate"))
			_crate_lid().rotation.x = -1.69
			_crate_lid().get_node("DispatchKey").hide()
			fire_elapsed = PORT_FIRE
			_ignite($Ships/Fire/DeckShortcut)
			_ignite($Ships/Fire/PortAisle)
			_set_ship_step(ShipStep.STRONGBOX)
			_say("ROOK  /  Still have the purser’s key. The starboard stair leads aft.")
		Checkpoint.HATCH:
			_place_player(_point("CargoSlate"))
			_set_ship_step(ShipStep.MARKS)
			_say("ROOK  /  A crescent and two dots. The marked crate is below deck.")
		_:
			checkpoint = Checkpoint.BOARDING
			_place_player(_point("Boarding"))
			_set_ship_step(ShipStep.SLATE)
			_say("ROOK  /  Smoke already. The hatch tally should tell me where they stowed that seal.", 6.0)


func _crate_lid() -> Node3D:
	return $Ships/OutboundMerchant/LowerHold/MarkedCrate/Lid


func _set_ship_step(step: ShipStep) -> void:
	ship_step = step
	match step:
		ShipStep.SLATE:
			_evidence.display("FREIGHT HATCH", "Read the cargo slate", false)
		ShipStep.MARKS:
			_evidence.display("CARGO SLATE   /   LOWER HOLD", "Find the crate with this mark", true)
		ShipStep.TRANSFER_SLIP:
			_evidence.display("LOWER HOLD   /   EMPTY CRATE", "Read the slip inside the lid", true)
		ShipStep.STRONGBOX:
			_evidence.display("TRANSFER SLIP   /   PURSER", "Find the strongbox in the stern cabin", true)
		ShipStep.TAKE_SEAL:
			_evidence.display("PURSER’S CABIN", "Take the Night Seal", false)


func _ship_target() -> StringName:
	for id: StringName in SHIP_PROPS:
		if _near($Points.get_node(NodePath(id)), 1.25):
			return id
	return &""


func _ship_action(id: StringName) -> String:
	match id:
		&"CargoSlate":
			return "Read the cargo slate"
		&"SailclothCrate", &"SilverCrate":
			return "Inspect the freight tag"
		&"CrescentCrate":
			if ship_step == ShipStep.TRANSFER_SLIP and _crate_lid().rotation.x > -1.45:
				return ""
			return "Read the transfer slip" if ship_step >= ShipStep.TRANSFER_SLIP else "Inspect the crate"
		&"Seal":
			if ship_step == ShipStep.STRONGBOX:
				return "Unlock the strongbox"
			if ship_step == ShipStep.TAKE_SEAL and $Ships/OutboundMerchant/PurserCabin/Strongbox/Lid.rotation.x > -1.45:
				return ""
			return "Take the Night Seal" if ship_step == ShipStep.TAKE_SEAL else "Examine the strongbox"
	return ""


func _inspect_ship(id: StringName) -> bool:
	if _ship_action(id).is_empty():
		return false
	var prop: Node3D = $Ships/OutboundMerchant.get_node(SHIP_PROPS[id])
	player._update_facing(player.global_position.direction_to(prop.global_position))
	match id:
		&"CargoSlate":
			_say("CARGO SLATE  /  Night Seal. One case. Stowed below under the crescent and two dots.", 6.0)
			if ship_step == ShipStep.SLATE:
				checkpoint = Checkpoint.HATCH
				_set_ship_step(ShipStep.MARKS)
		&"SailclothCrate":
			_say("ROOK  /  A triangle. Spare sailcloth, still rolled around its spar.")
		&"SilverCrate":
			_say("ROOK  /  A diamond. Silver plate for the officers’ mess.")
		&"CrescentCrate":
			match ship_step:
				ShipStep.SLATE:
					_say("ROOK  /  A crescent and two dots. Better check the hatch tally before I break a seal.")
				ShipStep.MARKS:
					_open_ship_lid(_crate_lid())
					_set_ship_step(ShipStep.TRANSFER_SLIP)
					_say("ROOK  /  A velvet lining and a dent where the box sat. There’s a slip in the lid.")
				ShipStep.TRANSFER_SLIP:
					_crate_lid().get_node("DispatchKey").hide()
					checkpoint = Checkpoint.TRANSFER
					_set_ship_step(ShipStep.STRONGBOX)
					_say("ROOK  /  “Purser.” A little brass key pinned underneath. His cabin’s up the starboard stair.", 7.0)
				_:
					_say("TRANSFER SLIP  /  PURSER. The brass key is in Rook’s pocket.")
		&"Seal":
			match ship_step:
				ShipStep.STRONGBOX:
					_open_ship_lid($Ships/OutboundMerchant/PurserCabin/Strongbox/Lid)
					seal.show()
					_set_ship_step(ShipStep.TAKE_SEAL)
					_say("ROOK  /  There you are.")
				ShipStep.TAKE_SEAL:
					seal.recover(player)
				_:
					_say("ROOK  /  Locked. The tag on the latch matches a consignment below.")
		_:
			return false
	return true


func _open_ship_lid(lid: Node3D) -> void:
	var movement := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	movement.tween_property(lid, "rotation:x", -1.69, 0.45)
	var latch := AudioStreamPlayer3D.new()
	latch.stream = preload("res://Music/FX/knock1.mp3")
	latch.pitch_scale = 0.75
	latch.volume_db = -10.0
	lid.add_child(latch)
	latch.finished.connect(latch.queue_free)
	latch.play()


func _tick_fire(delta: float) -> void:
	var before := fire_elapsed
	fire_elapsed += delta
	var deck := $Ships/Fire/DeckShortcut
	var port := $Ships/Fire/PortAisle
	if before < DECK_FIRE - 3.0 and fire_elapsed >= DECK_FIRE - 3.0:
		_warn_fire(deck, "Smoke is pouring through the middle bulkhead.")
	if before < PORT_FIRE - 3.0 and fire_elapsed >= PORT_FIRE - 3.0:
		_warn_fire(port, "The port passage is catching. The starboard stair is clear.")
	if fire_elapsed >= DECK_FIRE:
		_ignite(deck)
	if fire_elapsed >= PORT_FIRE:
		_ignite(port)
	for patch in [deck, port, $Ships/Fire/Smoke]:
		if patch.get_node("FireLight").visible:
			for index in 5:
				var flame: MeshInstance3D = patch.get_node("Flame%d" % index)
				flame.scale.y = 0.78 + 0.28 * sin(fire_elapsed * 9.0 + index * 1.9)
	if (fire_elapsed >= DECK_FIRE and _in_flames(deck)) or (fire_elapsed >= PORT_FIRE and _in_flames(port)):
		_fail("Flames cut off Rook. Try another passage.")


func _warn_fire(patch: Node3D, line: String) -> void:
	patch.show()
	for child in patch.get_children():
		if child is MeshInstance3D:
			child.hide()
	patch.get_node("Haze").emitting = true
	if _near(patch, 6.0) and _story_left < 1.0:
		_say(line, 4.0)


func _ignite(patch: Node3D) -> void:
	if patch.get_node("FireLight").visible:
		return
	patch.show()
	for child in patch.get_children():
		if child is Node3D:
			child.show()
	patch.get_node("Embers").emitting = true
	patch.get_node("Haze").emitting = true


func _in_flames(patch: Node3D) -> bool:
	var offset := player.global_position - patch.global_position as Vector3
	return absf(offset.x) <= float(patch.get_meta("half_width")) and absf(offset.z) <= float(patch.get_meta("half_span"))


func _finish() -> void:
	phase = Phase.ENDING
	_evidence.hide()
	_styled_hud.hide()
	_caption.hide()
	player.set_interaction_locked(true)
	_fire_sound.stop()
	comic.begin(controller)


func _on_noise(at: Vector3, radius: float, kind: String) -> void:
	if phase < Phase.LOADING and guard.active:
		if guard.hear_sound(at, minf(radius, 2.3) if barrel.player_inside else radius, kind):
			_alert_eye.notify_heard(kind)


func _confirm_story_alert(title: String) -> void:
	_story_alerts[title].confirm()
	_confirmed_alert_time = 2.0
	_alert_eye.extra_awareness = 1.0
	_alert_eye.extra_pursuit = true
	_alert_eye.refresh()


func _capture() -> void:
	if phase != Phase.ENDING and phase != Phase.LOADING:
		_fail("Rook was spotted.")


func _fail(reason: String) -> void:
	if _restart_queued:
		return
	_restart_queued = true
	if modal != Modal.NONE:
		_close_modal()
	player.set_interaction_locked(true)
	_say(reason + "  Retrying from the checkpoint…", 3.0)
	await get_tree().create_timer(1.15, false).timeout
	if not is_inside_tree():
		return
	_retry = {"checkpoint": checkpoint, "variant": signature.variant_index,
		"seated": _checkpoint_pins, "barrel_position": _checkpoint_barrel, "table_taken": _checkpoint_table_taken}
	if get_tree().reload_current_scene() != OK:
		_retry.clear()
		_restart_queued = false
		player.set_interaction_locked(false)


func _seen() -> bool:
	return _master_visible or guard.player_visible or guard.guard_state == StealthGuard.GuardState.CHASE or sentinel.player_visible


func _office_cover() -> bool:
	if _near($Points/Desk, 1.55):
		return false
	var sensor: StealthExposureSensor = $Player/ExposureSensor
	return _behind_chart_rack() or sensor.exposure < 0.12 or not _ray_clear(master.position + Vector3.UP, player.position + Vector3.UP * 0.42)


func _behind_chart_rack() -> bool:
	return player.position.x > -8.82 and player.position.x < -7.60 and absf(player.position.z - 0.16) < 0.68


func _ray_clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _in_office() -> bool:
	return player.position.y > 2.9 and player.position.x > -12.6 and player.position.x < -3.55 and player.position.z < 4.43 and player.position.z > -4.4


func _near(target: Node3D, distance: float) -> bool:
	return target.global_position.distance_to(player.global_position) <= distance


func _point(id: String) -> Vector3:
	return $Points.get_node(id).global_position


func _place_player(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player._focus = at
	player._update_phase_camera()


func _stock_destination(index: int) -> Vector3:
	return Vector3(-9.2 + index * 0.75, -0.04, -17.63)


func _stow_original_stock() -> void:
	var stock := $Cargo/PotatoStock.get_children()
	for index in stock.size():
		stock[index].position = _stock_destination(index)
	porter.position = Vector3(-3.6, 0, -8.75)


func _say(message: String, seconds := 4.2) -> void:
	var parts := message.split("  /  ", false, 1)
	var speaker := parts[0].capitalize() if parts.size() > 1 else ""
	_caption.display_caption(speaker, parts[-1])
	_caption.visible = not _dialogue.active and modal == Modal.NONE
	_story_left = seconds


func _contact_tick(pitch: float) -> void:
	_tick.pitch_scale = pitch
	_tick.play()
	if controller and pitch > 1.0:
		for device in Input.get_connected_joypads():
			Input.start_joy_vibration(device, 0.13, 0.0, 0.06)


func _nearby_exhibit() -> Node3D:
	if phase >= Phase.LOADING or barrel.player_inside or barrel.transition_in_progress:
		return null
	for prop in $Quay/PlacesToExplore.get_children():
		if _near(prop, 1.55):
			return prop
	return null


func _update_ui() -> void:
	var key := "Circle" if controller else "E"
	var bell_key := "Triangle" if controller else "Q"
	var objective := ""
	var prompt := ""
	var destination: Node3D
	match phase:
		Phase.SCOUT:
			objective = "Check the outbound berth" if _kit_briefed else "Meet Kit or check the outbound berth"
			destination = $Points/Scout
		Phase.DISTRACTION:
			objective = "Draw the watch away from the gangway"
			destination = $Quay/DistractionBell
			if _near(destination, 1.85):
				prompt = bell_key + "   Ring the bell"
		Phase.ALTERCATION:
			objective = "Listen to the watch"
		Phase.OFFICE_LOCK:
			objective = "Pick the shipmaster’s office lock"
			destination = $Points/OfficeLock
		Phase.ENTER_OFFICE:
			objective = "Reach the upstairs manifest"
			if _tea_distraction <= 0.0 and _near($Quay/Office/TeaKettle, 1.25):
				prompt = key + "   Rattle the kettle"
			destination = $Points/Desk
		Phase.STUDY:
			objective = "Forge the signature from cover" if studied else "Study the shipmaster’s signature"
			if _near($Points/Desk, 1.15):
				prompt = key + "   Study the signature"
			elif studied and _in_office() and not _seen() and _office_cover():
				prompt = key + "   Open your draft"
		Phase.REPLACE:
			objective = "Replace the manifest"
			destination = $Points/Desk
			if _near(destination, 1.15):
				prompt = key + "   Swap the pages"
		Phase.LEAVE_OFFICE:
			objective = "Slip out of the office"
			destination = $Points/OfficeExit
		Phase.SORTING:
			objective = "Find the potato barrel at sorting"
			destination = $Points/SortingOverlook
		Phase.BARREL_RUN:
			objective = "%02ds   /   %s" % [ceili(delivery_left), "Reach the hoist in the barrel" if barrel.player_inside else "Find the courtyard barrel"]
			destination = $Points/LoadingMark if barrel.player_inside else barrel
		Phase.LOADING:
			objective = "Stay inside the barrel"
		Phase.SHIP:
			var action := _ship_action(_ship_target())
			if not action.is_empty():
				prompt = key + "   " + action
	if phase < Phase.LOADING and not barrel.transition_in_progress:
		if barrel.player_inside:
			prompt = "Stay inside. Wait to be loaded." if phase == Phase.BARREL_RUN and _near($Points/LoadingMark, 0.85) else key + "   Exit barrel"
		elif _can_try_lock():
			prompt = key + "   Pick the lock" if not _seen() else "Wait for the next opening"
		elif prompt.is_empty() and _near(barrel, 1.35):
			prompt = "Wait for the guards to go for tea" if $Cargo/SpareBarrel/Tabletop.visible and not _card_guards_away() else key + "   Climb inside the barrel"
	if not barrel.player_inside and door_unlocked and phase < Phase.SORTING and _near($Quay/Office/Door, 1.48) and absf(door.rotation.y) < 0.3:
		prompt = key + "   Open the office door"
	if _dialogue.active:
		_dialogue.set_advance_hint("Cross / Circle" if controller else "Space / E")
	elif not _kit_briefed and phase == Phase.SCOUT and _near($People/Kit, 2.1):
		prompt = key + "   Talk to Kit"
	if prompt.is_empty():
		var exhibit := _nearby_exhibit()
		if exhibit:
			prompt = key + "   Inspect " + str(exhibit.name).to_lower()
	if destination != null:
		var offset := destination.global_position - player.global_position as Vector3
		var flat := Vector2(offset.dot(camera.global_basis.x), offset.dot(camera.global_basis.z))
		var arrow: String = DIRECTIONS[posmod(roundi(flat.angle() / (PI / 4.0)), 8)]
		objective += "   %dm %s" % [roundi(Vector2(offset.x, offset.z).length()), arrow]
	_objective.text = objective
	if _prompt.text != prompt:
		_prompt.text = prompt
		_prompt.get_parent().reset_size()
	_prompt.get_parent().visible = not _dialogue.active and modal == Modal.NONE and not prompt.is_empty()
	_patrol.text = "SHIPMASTER  /  %s" % ("WATCHING" if _master_visible else "PACING") if _office_patrolling and _in_office() else "DOCK WATCH  /  " + guard.state_name()
	if _smoking and _near($Points/OfficeLock, 3.5):
		_patrol.text = "SHIPMASTER  /  " + ("WATCHING THE DOOR" if _master_visible else "SMOKING OUTSIDE")
	_patrol.get_parent().visible = phase < Phase.LOADING and (_office_patrolling and _in_office() or _smoking and _near($Points/OfficeLock, 3.5))
	_styled_hud.visible = phase < Phase.LOADING and modal != Modal.SIGNATURE and not _dialogue.active
	_alert_eye.extra_awareness = maxf(_master_awareness, 1.0 if _confirmed_alert_time > 0 else 0.0)
	_alert_eye.extra_pursuit = _confirmed_alert_time > 0


func _build_audio() -> void:
	_tick = AudioStreamPlayer3D.new()
	_tick.stream = preload("res://Music/FX/knock1.mp3")
	_tick.volume_db = -19.0
	$Quay/Office/Door.add_child(_tick)
	_bell_sound = AudioStreamPlayer3D.new()
	_bell_sound.stream = _make_bell_sound()
	_bell_sound.volume_db = -10.0
	$Quay/DistractionBell.add_child(_bell_sound)
	_fire_sound = AudioStreamPlayer.new()
	_fire_sound.stream = _make_fire_sound()
	_fire_sound.volume_db = -24.0
	add_child(_fire_sound)


func _make_bell_sound() -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 16000
	var samples := PackedByteArray()
	samples.resize(44800)
	for index in 22400:
		var t := float(index) / sound.mix_rate
		var note := sin(TAU * 438.0 * t) + 0.32 * sin(TAU * 1073.0 * t)
		samples.encode_s16(index * 2, int(note * exp(-4.7 * t) * 10500))
	sound.data = samples
	return sound


func _make_fire_sound() -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 16000
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = 48000
	var samples := PackedByteArray()
	samples.resize(96000)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var current := 0.0
	for index in 48000:
		current = lerpf(current, rng.randf_range(-1.0, 1.0), 0.12)
		var crackle := rng.randf_range(-0.55, 0.55) if index % 1273 < 22 else 0.0
		samples.encode_s16(index * 2, int((current * 0.6 + crackle) * 19000.0))
	sound.data = samples
	return sound


func _build_ui(variant: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	_objective = _build_objective(screen)
	_patrol = _hud_label(screen, Vector2(26, 72), "", 14)
	_prompt = _hud_label(screen, Vector2(26, 804), "", 18)
	_prompt.get_parent().set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	_prompt.get_parent().position = Vector2(26, screen.size.y - 65.0)
	_pin_readout = _hud_label(screen, Vector2(26, 645), "", 20)
	_pin_panel = _pin_readout.get_parent()
	_pin_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	_pin_panel.position = Vector2(26, screen.size.y - 252.0)
	_pin_panel.hide()
	_evidence = ShipEvidence.new()
	screen.add_child(_evidence)
	signature = Forgery.new()
	signature.variant_index = variant
	signature.manifest_title = "OUTBOUND MERCHANT"
	signature.manifest_subtitle = "Final manifest  ·  Night sailing"
	signature.signer = "Shipmaster"
	signature.entries = [["1 purser’s strongbox", "Aft hold"], ["4 crates of silver", "Aft hold"], ["3 rolls of sailcloth", "Foredeck"]]
	signature.amendment = "Amendment   +1 barrel of potatoes"
	layer.add_child(signature)
	signature.tuck_away_requested.connect(_close_modal)
	signature.signature_forged.connect(_draft_complete)
	comic = Comic.new()
	layer.add_child(comic)
	_dock_cutaway = preload("res://Modules/Gameplay/LastBarrel/dock_cutaway.tscn").instantiate()
	screen.add_child(_dock_cutaway)
	if block_print_lighting:
		_dock_cutaway.view.add_child(BLOCK_PRINT_LIGHTING.instantiate())
	_styled_hud = preload("res://UI/StyledHUD.tscn").instantiate()
	_styled_hud.layer = layer.layer
	_styled_hud.show_coin_counter = false
	add_child(_styled_hud)
	_alert_eye = _styled_hud.get_node("Control/EyeAnchor/AlertEye")
	_alert_eye.texture_progress_bar.tint_under.a = 0.38
	var dialogue_scene := preload("res://UI/DialogueBox.tscn")
	_caption = dialogue_scene.instantiate()
	_dialogue = dialogue_scene.instantiate()
	screen.add_child(_caption)
	screen.add_child(_dialogue)
	_caption.set_process_input(false)
	_dialogue.set_process_input(false)
	_dialogue.dialogue_finished.connect(func():
		_kit_briefed = true
		player.set_interaction_locked(false)
		_layout_dialogue(screen)
		_say("ROOK  /  Time to see what’s already been loaded.", 5.0))
	screen.resized.connect(_layout_dialogue.bind(screen))
	_layout_dialogue(screen)


func _build_objective(screen: Control) -> Label:
	var label := _hud_label(screen, Vector2(26, 22), "", 21)
	var panel := label.get_parent() as PanelContainer
	var padding := StyleBoxEmpty.new()
	padding.content_margin_left = 19
	padding.content_margin_right = 20
	padding.content_margin_top = 11
	padding.content_margin_bottom = 11
	panel.add_theme_stylebox_override("panel", padding)
	var paper := ColorRect.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.show_behind_parent = true
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://Modules/Gameplay/LastBarrel/objective_paper.gdshader")
	paper.material = finish
	label.add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.offset_left = -19
	paper.offset_right = 20
	paper.offset_top = -11
	paper.offset_bottom = 11
	label.add_theme_color_override("font_color", Color("272329"))
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "DejaVu Serif", "Liberation Serif"])
	font.font_weight = 700
	label.add_theme_font_override("font", font)
	return label


func _layout_dialogue(screen: Control) -> void:
	var fit := minf((screen.size.x - 48.0) / 1667.0, 0.65)
	if not _dialogue.active:
		_dialogue.scale = Vector2.ONE * fit
		_dialogue.position = Vector2(screen.size.x * 0.5, screen.size.y - 302.0 * fit)
	_caption.scale = Vector2.ONE * minf(fit, 0.47)
	_caption.position = Vector2(screen.size.x * 0.5, screen.size.y - 175.0)


func _hud_label(parent: Control, at: Vector2, line: String, font_size: int) -> Label:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.115, 0.94)
	style.border_color = Color("52616f")
	style.set_border_width_all(1)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.position = at
	parent.add_child(panel)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f4d9ab"))
	label.text = line
	panel.add_child(label)
	return label
