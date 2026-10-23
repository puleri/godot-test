extends Node3D
## Three objectives and a loop through two patrols, using the proven stealth rules.

signal ready_for_play
@onready var player: CharacterBody3D = $Player
@onready var region: NavigationRegion3D = $NavigationRegion3D
var guards: Array[StealthGuard] = []
var recovered_seals: Array[Area3D] = []
var finished := false
var _at_exit := false
var _objective: Label
var _guard_label: Label
var _awareness: ProgressBar
var _help: Label
var _result: PanelContainer
var _result_title: Label
var _result_detail: Label


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for guard in $Guards.get_children():
		guards.append(guard as StealthGuard)
		guard.player_caught.connect(_on_player_caught)
	for seal in $CargoSeals.get_children():
		seal.recovered.connect(_on_seal_recovered)
	$Extraction.body_entered.connect(_on_exit_entered)
	$Extraction.body_exited.connect(_on_exit_exited)
	_build_hud()
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Baking the mesh and registering it with the server complete separately.
	# Wait for our region's surface, rather than a fixed number of empty frames.
	var map := region.get_navigation_map()
	while NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_closest_point_owner(map, player.global_position) != region.get_rid():
		await get_tree().physics_frame
	for guard in guards:
		guard.navigation_ready = true
	ready_for_play.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode == KEY_TAB:
		for guard in guards:
			guard.show_vision = not guard.show_vision
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_M:
		player.toggle_map()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if finished:
		return
	var threat := guards[0]
	for guard in guards:
		if guard.awareness > threat.awareness or (is_equal_approx(guard.awareness, threat.awareness) and guard.global_position.distance_to(player.global_position) < threat.global_position.distance_to(player.global_position)):
			threat = guard
	_guard_label.text = ("CUSTOMS HOUND" if threat == guards[0] else "ARCHIVE HOUND") + " / " + threat.state_name()
	_guard_label.modulate = threat.state_color()
	_awareness.value = threat.awareness * 100.0
	if _under_pursuit():
		_help.text = "Break sight around a wall. The Hound searches where it last saw you."
	elif recovered_seals.size() == $CargoSeals.get_child_count():
		_help.text = "All seals recovered. Return to the blue extraction circle unseen."
	elif threat.guard_state == StealthGuard.GuardState.SEARCH:
		_help.text = "A Hound is searching. Keep cover between you and its beam."
	else:
		_help.text = "Watch the beams. Use the screens and barrels; the tide bridge connects both stores."
	if player.global_position.y < -5:
		_end_run("Overboard.", "Stay inside the stone railings and cross at the bridge.")
	_try_extract()


func _on_seal_recovered(seal: Area3D) -> void:
	if finished or recovered_seals.has(seal):
		return
	recovered_seals.append(seal)
	_update_objective()


func _update_objective() -> void:
	_objective.text = "CARGO SEALS  %d / %d" % [recovered_seals.size(), $CargoSeals.get_child_count()]
	if recovered_seals.size() == $CargoSeals.get_child_count():
		_objective.text += "   /   RETURN TO EXTRACTION"
		_objective.modulate = Color("87d1c5")


func _under_pursuit() -> bool:
	for guard in guards:
		if guard.player_visible or guard.guard_state == StealthGuard.GuardState.CHASE:
			return true
	return false


func _on_exit_entered(body: Node3D) -> void:
	if body == player:
		_at_exit = true
		_try_extract()


func _on_exit_exited(body: Node3D) -> void:
	if body == player:
		_at_exit = false


func _try_extract() -> void:
	if not finished and _at_exit and recovered_seals.size() == $CargoSeals.get_child_count() and not _under_pursuit():
		_end_run("A clean getaway.", "Three cargo seals recovered. The harbor is none the wiser.")


func _on_player_caught() -> void:
	_end_run("Spotted. Cornered. Caught.", "Turn a corner to break sight, then move away from your last seen position.")


func _end_run(title: String, detail: String) -> void:
	if finished:
		return
	finished = true
	for guard in guards:
		guard.active = false
	player.set_interaction_locked(true)
	for seal in $CargoSeals.get_children():
		seal.set_deferred("monitoring", false)
	_result_title.text = title
	_result_detail.text = detail + "\n\nR  restart the night shift"
	_result.show()


func _label(text: String, size: int, tint := Color("e9ede9")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	return label


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.05, 0.075, 0.94)
	style.border_color = Color("324652")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MissionHUD"
	add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	var title := _panel()
	title.position = Vector2(28, 24)
	screen.add_child(title)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 5)
	title.add_child(titles)
	titles.add_child(_label("ROOK / THE HARBOR JOB", 12, Color("e4bc77")))
	titles.add_child(_label("Night shift", 30))
	_objective = _label("", 14, Color("e4bc77"))
	titles.add_child(_objective)
	_update_objective()
	var awareness_panel := _panel()
	awareness_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	awareness_panel.position = Vector2(-390, 24)
	awareness_panel.custom_minimum_size.x = 362
	screen.add_child(awareness_panel)
	var awareness_box := VBoxContainer.new()
	awareness_box.add_theme_constant_override("separation", 10)
	awareness_panel.add_child(awareness_box)
	_guard_label = _label("PATROLS PREPARING", 13, Color("84c9d0"))
	awareness_box.add_child(_guard_label)
	_awareness = ProgressBar.new()
	_awareness.custom_minimum_size = Vector2(320, 6)
	_awareness.show_percentage = false
	awareness_box.add_child(_awareness)
	var footer := _panel()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 28
	footer.offset_right = -28
	footer.offset_top = -100
	footer.offset_bottom = -24
	screen.add_child(footer)
	var instructions := VBoxContainer.new()
	instructions.add_theme_constant_override("separation", 8)
	footer.add_child(instructions)
	_help = _label("Recover the three gold cargo seals. Return to the blue circle unseen.", 16)
	instructions.add_child(_help)
	instructions.add_child(_label("WASD / ARROWS  move     SHIFT  slow walk     SPACE  jump     M  overview     TAB  sight overlay     R  restart", 12, Color("91a9b7")))
	_result = _panel()
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result.position = Vector2(-310, -85)
	_result.custom_minimum_size.x = 620
	screen.add_child(_result)
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 14)
	_result.add_child(result_box)
	_result_title = _label("", 30, Color("e4bc77"))
	_result_detail = _label("", 16)
	result_box.add_child(_result_title)
	result_box.add_child(_result_detail)
	_result.hide()
