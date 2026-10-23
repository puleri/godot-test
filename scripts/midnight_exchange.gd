extends Node3D
## Medium encounter: time a mouse, draw away the Hound, then work the vault.

signal ready_for_play
enum DisplayMode { HUD_ONLY, HUD_AND_VISION, VISION_ONLY, HIDDEN }

var display_mode: DisplayMode = DisplayMode.HUD_ONLY
var _hud_layer: CanvasLayer
var _world_labels: Array[Node] = []
var _hud_markers: Array[Node] = []
@onready var player: CharacterBody3D = $Player
@onready var region: NavigationRegion3D = $NavigationRegion3D
var guards: Array[StealthGuard] = []
var stage := 0
var finished := false
var bell_cooldown := 0.0
var elapsed := 0.0
var _objective: Label
var _guard_label: Label
var _awareness: ProgressBar
@onready var exposure_sensor: StealthExposureSensor = $Player/ExposureSensor
var _result: PanelContainer
var _result_title: Label
var _result_detail: Label
var _bell_audio: AudioStreamPlayer


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for guard in $Guards.get_children():
		guards.append(guard)
		guard.player_caught.connect(func(): _end_run(false))
	player.noise_emitted.connect(_on_noise_emitted)
	_build_hud()
	_world_labels = find_children("*", "Label3D", true, false)
	_hud_markers = find_children("Ring", "MeshInstance3D", true, false)
	_hud_markers.append_array(find_children("Pulse", "MeshInstance3D", true, false))
	_hud_markers.append($Player/PlayerMarker)
	_apply_display_mode()
	_build_bell_audio()
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var map := region.get_navigation_map()
	while NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_closest_point_owner(map, player.global_position) != region.get_rid():
		await get_tree().physics_frame
	for guard in guards:
		guard.navigation_ready = true
	ready_for_play.emit()


func _input(event: InputEvent) -> void:
	# Handle Tab before GUI focus navigation, including while the result is shown.
	if event is InputEventKey and event.physical_keycode == KEY_TAB and event.pressed and not event.echo:
		display_mode = ((display_mode + 1) % DisplayMode.size()) as DisplayMode
		_apply_display_mode()
		get_viewport().set_input_as_handled()


func _apply_display_mode() -> void:
	var hud_visible := display_mode in [DisplayMode.HUD_ONLY, DisplayMode.HUD_AND_VISION]
	var vision_visible := display_mode in [DisplayMode.HUD_AND_VISION, DisplayMode.VISION_ONLY]
	_hud_layer.visible = hud_visible
	for label in _world_labels:
		label.visible = hud_visible
	for marker in _hud_markers:
		# Keep pulse visibility/animation state running while its rendering is hidden.
		marker.layers = 1 if hud_visible else 0
	for guard in guards:
		guard.set_vision_visible(vision_visible)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_Q:
			ring_nearest_bell()


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	bell_cooldown = maxf(0, bell_cooldown - delta)
	var threat := guards[0]
	for guard in guards:
		if guard.awareness > threat.awareness or (is_equal_approx(guard.awareness, threat.awareness) and guard.position.distance_to(player.position) < threat.position.distance_to(player.position)):
			threat = guard
	_guard_label.text = threat.guard_title + " / " + threat.state_name()
	_guard_label.modulate = threat.state_color()
	_awareness.value = threat.awareness * 100
	var descriptions := ["01 / COPY THE SORTING MANIFEST", "02 / RELEASE THE VAULT CRANK", "03 / RECOVER THE NIGHT SEAL", "04 / RETURN TO THE BLUE EXIT"]
	var destination: Vector3 = $Extraction.position if stage == 3 else $Stations.get_child(stage).position
	var offset := destination - player.position
	var camera: Camera3D = $LevelCamera
	var direction := Vector2(offset.dot(camera.global_basis.x), offset.dot(camera.global_basis.z))
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var arrow: String = arrows[posmod(roundi(direction.angle() / (PI / 4)), 8)]
	_objective.text = descriptions[stage] + "   /   %dm %s" % [roundi(Vector2(offset.x, offset.z).length()), arrow]
	_update_interaction(delta)
	for bell in $Bells.get_children():
		var nearby: bool = bell.position.distance_to(player.position) < 2.3
		bell.get_node("Caption").text = "Q / RING BELL" if nearby and bell_cooldown <= 0 else ("BELL / %.0fs" % ceilf(bell_cooldown) if bell_cooldown > 0 else "NOISE BELL")
		var pulse: MeshInstance3D = bell.get_node("Pulse")
		if pulse.visible:
			pulse.scale += Vector3.ONE * delta * 4
			if pulse.scale.x > 9:
				pulse.hide()
	if player.position.y < -5:
		_end_run(false)
	try_extract()


func _update_interaction(delta: float, holding := Input.is_physical_key_pressed(KEY_E)) -> void:
	for i in $Stations.get_child_count():
		var station = $Stations.get_child(i)
		if station.completed:
			continue
		var nearby: bool = station.position.distance_to(player.position) < 1.8
		var clear: bool = station.guard_is_clear() and not under_pursuit()
		if i == stage and nearby and clear and holding:
			if station.advance(delta):
				stage += 1
		else:
			station.reset_progress()


func ring_nearest_bell() -> bool:
	if finished or bell_cooldown > 0:
		return false
	var nearest: Node3D
	for bell in $Bells.get_children():
		if bell.position.distance_to(player.position) < 2.3 and (nearest == null or bell.position.distance_to(player.position) < nearest.position.distance_to(player.position)):
			nearest = bell
	if nearest == null:
		return false
	bell_cooldown = 9.0
	_bell_audio.play()
	nearest.get_node("Visual").ring()
	for guard in guards:
		guard.investigate_noise(nearest.global_position)
	var pulse: MeshInstance3D = nearest.get_node("Pulse")
	pulse.scale = Vector3.ONE
	pulse.show()
	return true


func under_pursuit() -> bool:
	for guard in guards:
		if guard.player_visible or guard.guard_state == StealthGuard.GuardState.CHASE:
			return true
	return false


func try_extract() -> void:
	if not finished and stage == 3 and player.position.distance_to($Extraction.position) < 1.5 and not under_pursuit():
		_end_run(true)


func _end_run(won: bool) -> void:
	if finished:
		return
	finished = true
	player.set_interaction_locked(true)
	for guard in guards:
		guard.active = false
	_result_title.text = "The midnight exchange is complete." if won else "Caught on the night shift."
	_result_detail.text = ("Manifest copied. Vault released. Night seal recovered.\nTime / %d:%02d" % [int(elapsed) / 60, int(elapsed) % 60] if won else "Use the bell to move the Hound. Stone screens break sight.\nMice turn quickly, but their patrol pauses give you an opening.") + "\n\nR / restart"
	_result.show()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	_hud_layer = layer
	add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	var panel: PanelContainer = _panel(16, 12)
	panel.position = Vector2(28, 24)
	screen.add_child(panel)
	_objective = _label("PREPARING THE EXCHANGE", 14, Color("e4bc77"))
	panel.add_child(_objective)
	var threat: PanelContainer = _panel(14, 10)
	threat.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	threat.position = Vector2(-288, 24)
	threat.custom_minimum_size.x = 260
	screen.add_child(threat)
	var threat_box := VBoxContainer.new()
	threat_box.add_theme_constant_override("separation", 4)
	threat.add_child(threat_box)
	_guard_label = _label("PATROLS PREPARING", 12)
	threat_box.add_child(_guard_label)
	_awareness = ProgressBar.new()
	_awareness.custom_minimum_size = Vector2(232, 4)
	_awareness.show_percentage = false
	threat_box.add_child(_awareness)
	var footer: PanelContainer = _panel(16, 10)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 28
	footer.offset_right = -28
	footer.offset_top = -62
	footer.offset_bottom = -24
	screen.add_child(footer)
	footer.add_child(_label("WASD / ARROWS  move     SHIFT  slow walk     SPACE  jump     E  hold to work     Q  nearby bell     TAB  HUD / vision     R  restart", 12, Color("91a9b7")))
	_result = _panel()
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result.position = Vector2(-330, -100)
	_result.custom_minimum_size.x = 660
	screen.add_child(_result)
	var result_box := VBoxContainer.new()
	_result.add_child(result_box)
	_result_title = _label("", 27, Color("e4bc77"))
	_result_detail = _label("", 16)
	result_box.add_child(_result_title)
	result_box.add_child(_result_detail)
	_result.hide()


func _label(text: String, size: int, tint := Color("e9ede9")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	return label


func _panel(horizontal_padding := 20, vertical_padding := 15) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.075, 0.94)
	style.border_color = Color("324652")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = vertical_padding
	style.content_margin_bottom = vertical_padding
	panel.add_theme_stylebox_override("panel", style)
	return panel




func _build_bell_audio() -> void:
	# A soft brass strike, generated once; no external sound dependency.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2)
	for sample in 22050:
		var t := float(sample) / 22050.0
		var wave := sin(TAU * 660 * t) * exp(-4 * t) + sin(TAU * 1327 * t) * 0.35 * exp(-7 * t)
		data.encode_s16(sample * 2, int(wave * minf(t * 250, 1) * 16000))
	stream.data = data
	_bell_audio = AudioStreamPlayer.new()
	_bell_audio.stream = stream
	_bell_audio.volume_db = -14
	add_child(_bell_audio)


func _on_noise_emitted(at: Vector3, audible_radius: float, kind: String) -> void:
	if finished:
		return
	for guard in guards:
		guard.hear_sound(at, audible_radius, kind)
