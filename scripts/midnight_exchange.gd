extends Node3D
## Medium encounter: time a mouse, draw away the Hound, then work the vault.

signal ready_for_play
enum DisplayMode { HUD_ONLY, HUD_AND_VISION, VISION_ONLY, HIDDEN, STYLED_HUD }

@export var readable_lamp_ground := true
@export var play_opening_dialogue := true
@export var play_establishing_shot := true
@export_range(1.0, 20.0) var establishing_shot_duration := 7.0
var _establishing_shot: Node

const OPENING_DIALOGUE: Array[Dictionary] = [
	{"speaker": "Pot Goblin", "text": "Rook, winter solstice is this weekend! I need you to pick up a couple things."},
	{"speaker": "Rook", "text": "Some coin?"},
	{"speaker": "Pot Goblin", "text": "Exactly, I am boiling some goose"},
	{"speaker": "Rook", "text": "That isn't a goose"},
]
var _dialogue: Node2D
var _dialogue_layer: CanvasLayer


var display_mode: DisplayMode = DisplayMode.HUD_ONLY
var _hud_layer: CanvasLayer
var _styled_hud: CanvasLayer
var _standard_hud_controls: Array[Control] = []
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
var _alert_eye: AlertEye
@onready var exposure_sensor: StealthExposureSensor = $Player/ExposureSensor
var _result: PanelContainer
var _result_title: Label
var _result_detail: Label
var _bell_audio: AudioStreamPlayer
var _interaction_panel: PanelContainer
var _interaction_label: Label
var _interaction_art: TextureRect
var _using_controller := false


func _ready() -> void:
	_configure_harbor_backdrop()
	_configure_ground_lighting()
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
	_build_interaction_prompt()
	for target in $Stations.get_children() + $Bells.get_children():
		var shimmer := preload("res://scripts/exchange_shimmer.gd").new()
		target.add_child(shimmer)
		shimmer.setup(target)
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var map := region.get_navigation_map()
	while NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_closest_point_owner(map, player.global_position) != region.get_rid():
		await get_tree().physics_frame
	for guard in guards:
		guard.navigation_ready = true
	if play_opening_dialogue:
		if play_establishing_shot:
			_start_establishing_shot()
		else:
			_start_opening_dialogue()
	ready_for_play.emit()


func _configure_harbor_backdrop() -> void:
	if not has_node("HarborBackdrop"):
		add_child(preload("res://scenes/backdrops/HarborBackdrop.tscn").instantiate())
	var world: WorldEnvironment = $WorldEnvironment
	world.environment = world.environment.duplicate()
	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	var material := ShaderMaterial.new()
	material.shader = preload("res://Materials/harbor_sky.gdshader")
	sky.sky_material = material
	world.environment.sky = sky
	world.environment.background_mode = Environment.BG_SKY
	# Moving clouds are visual only; retain the encounter's authored lighting.
	world.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Ambient lighting stays explicitly sourced from the existing encounter.
	$HarborWater.hide()


func _start_establishing_shot() -> void:
	elapsed = 0.0
	_hud_layer.hide()
	_styled_hud.hide()
	for label in _world_labels:
		label.hide()
	for marker in _hud_markers:
		marker.layers = 0
	_establishing_shot = preload("res://scripts/exchange_establishing_shot.gd").new()
	_establishing_shot.name = "EstablishingShot"
	_establishing_shot.duration = establishing_shot_duration
	add_child(_establishing_shot)
	_establishing_shot.completed.connect(func():
		_establishing_shot = null
		_start_opening_dialogue())
	_establishing_shot.start(self)


func _configure_ground_lighting() -> void:
	if not readable_lamp_ground:
		return
	# Surface overrides belong to these instances, preserving the shared art and
	# other levels. Rebuilt encounters inherit the same treatment on startup.
	var stone := preload("res://Materials/NewToon-Stone.tres")
	var readable_stone := stone.duplicate() as ShaderMaterial
	readable_stone.set_shader_parameter("toon_local_lighting", true)
	for mesh: MeshInstance3D in $NavigationRegion3D/StoneFloor.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			if mesh.get_active_material(surface) == stone:
				mesh.set_surface_override_material(surface, readable_stone)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.25):
		_using_controller = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_using_controller = false
	# Handle Tab before GUI focus navigation, including while the result is shown.
	if event.is_action_pressed("toggle_vision"):
		display_mode = ((display_mode + 1) % DisplayMode.size()) as DisplayMode
		_apply_display_mode()
		get_viewport().set_input_as_handled()


func _apply_display_mode() -> void:
	var hud_visible := display_mode in [DisplayMode.HUD_ONLY, DisplayMode.HUD_AND_VISION]
	var styled_visible := display_mode == DisplayMode.STYLED_HUD
	var vision_visible := display_mode in [DisplayMode.HUD_AND_VISION, DisplayMode.VISION_ONLY]
	# The shared result panel remains available in either HUD option.
	_hud_layer.visible = hud_visible or styled_visible
	_styled_hud.visible = styled_visible
	for control in _standard_hud_controls:
		control.visible = hud_visible
	for label in _world_labels:
		label.visible = hud_visible
	for marker in _hud_markers:
		# Keep pulse visibility/animation state running while its rendering is hidden.
		marker.layers = 1 if hud_visible else 0
	for guard in guards:
		guard.set_vision_visible(vision_visible)
		guard.set_suspicion_visible(hud_visible or styled_visible)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("secondary_action"):
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
	var descriptions := ["01 / COPY THE SORTING MANIFEST", "02 / RELEASE THE VAULT CRANK", "03 / RECOVER THE NIGHT SEAL", "04 / RETURN TO THE BLUE EXIT"]
	var destination: Vector3 = $Extraction.position if stage == 3 else $Stations.get_child(stage).position
	var offset := destination - player.position
	var camera: Camera3D = $LevelCamera
	var direction := Vector2(offset.dot(camera.global_basis.x), offset.dot(camera.global_basis.z))
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var arrow: String = arrows[posmod(roundi(direction.angle() / (PI / 4)), 8)]
	_objective.text = descriptions[stage] + "   /   %dm %s" % [roundi(Vector2(offset.x, offset.z).length()), arrow]
	_update_interaction(delta)
	_update_interaction_prompt()
	for bell in $Bells.get_children():
		var nearby: bool = _can_reach(bell, 2.3)
		bell.get_node("Caption").text = "Q / RING BELL" if nearby and bell_cooldown <= 0 else ("BELL / %.0fs" % ceilf(bell_cooldown) if bell_cooldown > 0 else "NOISE BELL")
		var pulse: MeshInstance3D = bell.get_node("Pulse")
		if pulse.visible:
			pulse.scale += Vector3.ONE * delta * 4
			if pulse.scale.x > 9:
				pulse.hide()
	if player.position.y < -5:
		_end_run(false)
	try_extract()


func _update_interaction(delta: float, holding := Input.is_action_pressed("interact")) -> void:
	for i in $Stations.get_child_count():
		var station = $Stations.get_child(i)
		if station.completed:
			continue
		var nearby: bool = _can_reach(station, 1.8)
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
		if _can_reach(bell, 2.3) and (nearest == null or bell.position.distance_to(player.position) < nearest.position.distance_to(player.position)):
			nearest = bell
	if nearest == null:
		return false
	bell_cooldown = 9.0
	_bell_audio.play()
	nearest.get_node("Visual").ring()
	for guard in guards:
		if guard.investigate_noise(nearest.global_position):
			_notify_heard("BELL")
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
	_interaction_panel.hide()
	_alert_eye.freeze()
	_styled_hud.get_node("Control/EyeAnchor/AlertEye").freeze()
	player.set_interaction_locked(true)
	for guard in guards:
		guard.active = false
	_result_title.text = "The midnight exchange is complete." if won else "Caught on the night shift."
	_result_detail.text = ("Manifest copied. Vault released. Night seal recovered.\nTime / %d:%02d" % [int(elapsed) / 60, int(elapsed) % 60] if won else "Use the bell to move the Hound. Stone screens break sight.\nMice turn quickly, but their patrol pauses give you an opening.") + "\n\nR / restart"
	_result.show()


func _build_hud() -> void:
	_styled_hud = preload("res://UI/StyledHUD.tscn").instantiate()
	add_child(_styled_hud)
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
	_standard_hud_controls.append(panel)
	_objective = _label("PREPARING THE EXCHANGE", 14, Color("e4bc77"))
	panel.add_child(_objective)
	var threat := Control.new()
	screen.add_child(threat)
	_standard_hud_controls.append(threat)
	threat.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	threat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_eye = preload("res://UI/alert_eye.tscn").instantiate()
	_alert_eye.position = Vector2(-60.5, 20)
	_alert_eye.scale = Vector2(0.5, 0.5)
	threat.add_child(_alert_eye)
	_guard_label = _label("PATROLS PREPARING", 12)
	_guard_label.position = Vector2(-150, 138)
	_guard_label.custom_minimum_size.x = 300
	_guard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	threat.add_child(_guard_label)
	var footer: PanelContainer = _panel(16, 10)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 28
	footer.offset_right = -28
	footer.offset_top = -62
	footer.offset_bottom = -24
	screen.add_child(footer)
	_standard_hud_controls.append(footer)
	footer.add_child(_label("WASD / ARROWS  move     SHIFT  slow walk     SPACE  jump     E  hold to work     Q  nearby bell     TAB  HUD / vision / styled HUD     R  restart", 12, Color("91a9b7")))
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
		if guard.hear_sound(at, audible_radius, kind):
			_notify_heard(kind)


func _start_opening_dialogue() -> void:
	elapsed = 0.0
	# A separate HUD layer keeps story text readable in every Tab display mode.
	_dialogue_layer = CanvasLayer.new()
	_dialogue_layer.layer = 20
	_dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialogue_layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_layer.add_child(screen)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.055, 0.20)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	_dialogue = preload("res://UI/DialogueBox.tscn").instantiate()
	screen.add_child(_dialogue)
	screen.resized.connect(_layout_dialogue.bind(screen))
	_layout_dialogue(screen)
	_hud_layer.hide()
	_styled_hud.hide()
	for label in _world_labels:
		label.hide()
	player.set_interaction_locked(true)
	get_tree().paused = true
	_dialogue.dialogue_finished.connect(func():
		get_tree().paused = false
		player.set_interaction_locked(false)
		_apply_display_mode()
		_dialogue_layer.queue_free())
	_dialogue.start_dialogue(OPENING_DIALOGUE)


func _layout_dialogue(screen: Control) -> void:
	var fit := minf((screen.size.x - 48.0) / 1667.0, 0.77)
	_dialogue.scale = Vector2.ONE * fit
	_dialogue.position = Vector2(screen.size.x * 0.5, screen.size.y - 300.0 * fit)


func _notify_heard(kind: String) -> void:
	_alert_eye.notify_heard(kind)
	_styled_hud.get_node("Control/EyeAnchor/AlertEye").notify_heard(kind)


func _can_reach(target: Node3D, radius: float) -> bool:
	if target.global_position.distance_to(player.global_position) >= radius:
		return false
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.6, target.global_position + Vector3.UP * 0.6, guards[0].sight_blocker_mask)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _build_interaction_prompt() -> void:
	_interaction_panel = _panel(20, 12)
	_hud_layer.get_child(0).add_child(_interaction_panel)
	_interaction_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_panel.offset_left = -240
	_interaction_panel.offset_right = 240
	_interaction_panel.offset_top = -196
	_interaction_panel.offset_bottom = -82
	_interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_interaction_panel.add_child(content)
	_interaction_art = TextureRect.new()
	_interaction_art.name = "PlayStationInteract"
	_interaction_art.texture = preload("res://textures/ps-interact.png")
	_interaction_art.custom_minimum_size = Vector2(292, 53)
	_interaction_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_interaction_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_interaction_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_interaction_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_interaction_art)
	_interaction_art.hide()
	_interaction_label = _label("", 20, Color("e9e3d7"))
	_interaction_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_interaction_label.add_theme_constant_override("shadow_offset_x", 2)
	_interaction_label.add_theme_constant_override("shadow_offset_y", 2)
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_interaction_label)
	_interaction_panel.hide()


func _update_interaction_prompt() -> void:
	_interaction_panel.hide()
	_interaction_art.hide()
	if finished:
		return
	var lines: PackedStringArray = []
	var use_key := "Circle" if _using_controller else "E"
	var bell_key := "Triangle" if _using_controller else "Q"
	for i in $Stations.get_child_count():
		var station = $Stations.get_child(i)
		if not _can_reach(station, 1.8):
			continue
		if station.completed:
			lines.append(station.title + " — complete")
		elif i != stage:
			lines.append("Copy the manifest first" if stage == 0 else "Release the vault crank first")
		elif under_pursuit():
			lines.append("Break line of sight and lose pursuit first")
		elif not station.guard_is_clear():
			lines.append("Lure the Hound away from the crank")
		else:
			var progress_text := "  %d%%" % mini(100, roundi(station.progress / station.hold_seconds * 100)) if station.progress > 0 else ""
			_interaction_art.visible = _using_controller
			if _using_controller:
				lines.append("HOLD — %s%s" % [station.title, progress_text])
			else:
				lines.append("Hold [%s]  %s%s" % [use_key, station.title, progress_text])
		break
	for bell in $Bells.get_children():
		if _can_reach(bell, 2.3):
			lines.append("Bell ready in %ds" % ceili(bell_cooldown) if bell_cooldown > 0 else "[%s]  Ring bell — draw guards here" % bell_key)
			break
	_interaction_label.text = "\n".join(lines)
	_interaction_panel.visible = not lines.is_empty()
