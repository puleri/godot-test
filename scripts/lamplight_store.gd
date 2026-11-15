extends Node3D
signal ready_for_play
@onready var player = $Player
var guards: Array[Node3D] = []
var ready_to_play := false
var lights_on := true
var caught := false
var ledger_taken := false
var escaped := false
var guards_paused := false
var _cutaway_bodies: Array[RID] = []
var _cutaway_feedback_active := false
var _caption: Label
var _hint: Label
var _status: Label
var _message := "Enter the store through the archway. The camera changes automatically."


func _ready() -> void:
	# Imported mesh descendants retain their source scene layers on packing.
	# Apply the camera-only shell layer to the instantiated render geometry.
	for shell in [$WeatherRoof, $NavigationRegion3D/CutawayFacade]:
		for geometry in shell.find_children("*", "GeometryInstance3D", true, false):
			geometry.layers = 1 << 18
		for body in shell.find_children("*", "StaticBody3D", true, false):
			_cutaway_bodies.append(body.get_rid())
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for guard in $Guards.get_children():
		guards.append(guard)
		guard.player_caught.connect(_on_caught)
	player.noise_emitted.connect(_on_noise)
	_build_hud()
	$NavigationRegion3D.bake_navigation_mesh(false)
	await get_tree().physics_frame
	var map: RID = $NavigationRegion3D.get_navigation_map()
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await get_tree().physics_frame
	for guard in guards:
		guard.navigation_ready = true
	ready_to_play = true
	ready_for_play.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not ready_to_play:
		return
	if event.is_action("secondary_action"):
		if not caught:
			player.set_peeking(event.is_pressed())
		return
	if not event.is_pressed():
		return
	if event.is_action_pressed("interact"): interact()
	elif event.is_action_pressed("restart"): get_tree().reload_current_scene()
	elif event is InputEventKey and event.physical_keycode == KEY_P:
		if not caught and not escaped:
			guards_paused = not guards_paused
			for guard in guards:
				guard.set_physics_process(not guards_paused)
			_message = "GUARDS PAUSED. Explore the camera and interactions; P resumes." if guards_paused else "GUARDS ACTIVE. Watch their lamps and keep quiet."
	elif event.is_action_pressed("toggle_vision"):
		for guard in guards:
			guard.set_vision_visible(not guard.show_vision)


func interact() -> bool:
	if caught or escaped:
		return false
	if player.concealed:
		player.leave_hide()
		_message = "LEFT COVER. Stay quiet and watch the lamps."
		return true
	if player.position.distance_to($LightSwitch.position) < 2.0:
		set_store_lights(not lights_on)
		_on_noise($LightSwitch.position, 4.0, "SWITCH")
		return true
	if player.position.distance_to($HideSpot.position) < 2.0:
		for guard in guards:
			if guard.active and guard.player_visible:
				_message = "SEEN ENTERING. Break line of sight before hiding."
				return false
		player.enter_hide($HideSpot.position)
		_message = "CONCEALED. Hold Q to peek; peeking exposes Rook. E leaves. Trackers can sense you nearby."
		return true
	if not ledger_taken and player.position.distance_to($Ledger.position) < 1.8:
		ledger_taken = true
		$Ledger.hide()
		_message = "LEDGER RECOVERED. Return to the blue courtyard marker."
		return true
	return false


func set_store_lights(enabled: bool) -> void:
	lights_on = enabled
	$HarborLights/StoreLights.visible = enabled
	player.get_node("ExposureSensor").refresh()
	_message = "STORE LIGHTS %s. The roof still shelters Rook from lightning." % ("ON" if enabled else "OFF")


func _on_noise(at: Vector3, radius: float, kind: String) -> void:
	if not ready_to_play or caught:
		return
	for guard in guards:
		guard.hear_sound(at, radius, kind)


func _process(_delta: float) -> void:
	if not ready_to_play:
		return
	_sync_cutaway_feedback()
	if not caught and not escaped and ledger_taken and player.position.distance_to($ExitMarker.position) < 1.8:
		escaped = true
		_message = "DELIVERY COMPLETE. R restarts the encounter."
		for guard in guards:
			guard.active = false
	if player.position.y < -5:
		get_tree().reload_current_scene()
	_caption.text = "ROOK / LAMPLIGHT STORE\n" + ("INTERIOR / CLOSE SHOT" if player.indoors else "COURTYARD / WIDE SHOT")
	_status.text = "LIGHTS %s   |   %s   |   %s\n%s" % ["ON" if lights_on else "OFF", player.get_node("ExposureSensor").exposure_name(), "PEEKING / EXPOSED TO VISION" if player.peeking else ("CONCEALED" if player.concealed else "MOVING FREELY"), _message]
	var prompt := "Walk through the archway to enter or leave the store."
	if player.concealed:
		prompt = "Hold Q: peek   /   E: leave hiding"
	elif player.position.distance_to($LightSwitch.position) < 2:
		prompt = "E: switch store lighting"
	elif player.position.distance_to($HideSpot.position) < 2:
		prompt = "E: hide in the barrel alcove"
	elif not ledger_taken and player.position.distance_to($Ledger.position) < 1.8:
		prompt = "E: collect the ledger"
	_hint.text = prompt


func _sync_cutaway_feedback() -> void:
	if _cutaway_feedback_active == player.indoors:
		return
	_cutaway_feedback_active = player.indoors
	for guard in guards:
		guard._suspicion_bubble.occlusion_exclusions.assign(_cutaway_bodies if player.indoors else [])


func _on_caught() -> void:
	caught = true
	player.set_interaction_locked(true)
	_message = "CAUGHT. R restarts. Hiding and darkness do not defeat a nearby tracker."
	for guard in guards:
		guard.active = false


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = _label(layer, Vector2(30, 24), 27)
	_status = _label(layer, Vector2(30, 100), 17)
	_hint = _label(layer, Vector2(30, 790), 21)
	var controls := _label(layer, Vector2(30, 854), 15)
	controls.text = "WASD move   SHIFT quiet   SPACE jump   E interact   Hold Q peek   TAB vision   P pause guards   R restart"
	var profiles := _label(layer, Vector2(30, 748), 14)
	profiles.text = "WATCHMAN: light-dependent recognition   /   TRACKER: senses through darkness and concealment within 2.6m; walls block both"


func _label(parent: Node, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e8e1cf"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label
