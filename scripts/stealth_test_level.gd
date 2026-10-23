extends Node3D

signal ready_for_play

const INK := Color("111c2b")
const TEXT := Color("eef2ec")
const MUTED := Color("a2b4bf")
const GOLD := Color("efc67b")

@onready var player: CharacterBody3D = $Player
@onready var guard: StealthGuard = $Guard
@onready var region: NavigationRegion3D = $NavigationRegion3D
var has_loot := false
var finished := false
var _at_exit := false
var _status: Label
var _guard_status: Label
var _awareness_bar: ProgressBar
var _bar_fill: StyleBoxFlat
var _objective_text: Label
var _help: Label
var _result_panel: PanelContainer
var _result_title: Label
var _result_detail: Label


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_build_hud()
	guard.player_caught.connect(_on_player_caught)
	$Objective.body_entered.connect(_on_objective_entered)
	$Exit.body_entered.connect(_on_exit_entered)
	$Exit.body_exited.connect(_on_exit_exited)
	# Bake only the study's static colliders, including its full-height cover.
	# Wait for the navigation server to synchronize before the guard asks for paths.
	region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	guard.navigation_ready = true
	ready_for_play.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode == KEY_TAB:
		guard.show_vision = not guard.show_vision
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	$Objective/Treasure.rotation.y += delta * 0.8
	$Objective/Treasure.position.y = 0.8 + sin(Time.get_ticks_msec() * 0.002) * 0.08
	_guard_status.text = guard.state_name()
	_guard_status.modulate = guard.state_color()
	_awareness_bar.value = guard.awareness * 100.0
	_bar_fill.bg_color = guard.state_color()
	_status.text = "IN SIGHT" if guard.player_visible else "OUT OF SIGHT"
	_status.modulate = Color("ffca76") if guard.player_visible else Color("94d7bb")
	if not guard.navigation_ready:
		_status.text = "PREPARING PATROL"
	if not finished:
		if guard.guard_state == StealthGuard.GuardState.CHASE:
			_help.text = "Break line of sight. Get around a wall, then keep moving."
		elif guard.guard_state == StealthGuard.GuardState.SEARCH:
			_help.text = "The Hound is checking your last known position. Stay out of sight."
		elif guard.player_visible:
			_help.text = "You're being noticed. Move behind full-height cover."
		else:
			_help.text = "Watch the patrol. Use the walls to cross the courtyard unseen."
		_try_escape()


func _on_objective_entered(body: Node3D) -> void:
	if body != player or has_loot or finished:
		return
	has_loot = true
	$Objective/Treasure.hide()
	$Objective/Beacon.hide()
	$Objective/Caption.text = "RELIC COLLECTED"
	_objective_text.text = "02  Return to the blue extraction circle, unseen."
	_objective_text.modulate = Color("94d7bb")


func _on_exit_entered(body: Node3D) -> void:
	if body == player:
		_at_exit = true


func _on_exit_exited(body: Node3D) -> void:
	if body == player:
		_at_exit = false


func _try_escape() -> void:
	if not _at_exit or not has_loot or guard.player_visible or guard.guard_state == StealthGuard.GuardState.CHASE:
		return
	_end_run("Clean getaway.", "Relic recovered. You made it back unseen.", Color("94d7bb"))


func _on_player_caught() -> void:
	_end_run("Caught in the open.", "Use the walls to break sight before the Hound reaches you.", Color("ff9385"))


func _end_run(title: String, detail: String, color: Color) -> void:
	if finished:
		return
	finished = true
	guard.active = false
	player.set_interaction_locked(true)
	_result_title.text = title
	_result_title.modulate = color
	_result_detail.text = detail + "\n\nPress R to try another route."
	_result_panel.show()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "StudyHUD"
	add_child(layer)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	var title := VBoxContainer.new()
	title.position = Vector2(36, 28)
	title.add_theme_constant_override("separation", 7)
	screen.add_child(title)
	title.add_child(_label("ROOK  /  FIELD STUDY 01", 13, GOLD))
	title.add_child(_label("The quiet courtyard", 30, TEXT))
	title.add_child(_label("A small exercise in staying unseen.", 15, MUTED))

	var awareness_panel := _panel()
	awareness_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	awareness_panel.position = Vector2(-342, 28)
	awareness_panel.custom_minimum_size = Vector2(306, 150)
	screen.add_child(awareness_panel)
	var awareness_box := _padded_box(awareness_panel)
	_guard_status = _label("PATROLLING", 13, Color("7cc9d2"))
	awareness_box.add_child(_guard_status)
	_status = _label("OUT OF SIGHT", 23, TEXT)
	awareness_box.add_child(_status)
	_awareness_bar = ProgressBar.new()
	_awareness_bar.custom_minimum_size = Vector2(260, 7)
	_awareness_bar.show_percentage = false
	_awareness_bar.add_theme_stylebox_override("background", _style(Color("283549"), 4))
	_bar_fill = _style(Color("7cc9d2"), 4)
	_awareness_bar.add_theme_stylebox_override("fill", _bar_fill)
	awareness_box.add_child(_awareness_bar)
	awareness_box.add_child(_label("GUARD AWARENESS", 11, MUTED))

	var footer := _panel()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 36
	footer.offset_right = -36
	footer.offset_top = -132
	footer.offset_bottom = -28
	screen.add_child(footer)
	var footer_box := _padded_box(footer)
	_objective_text = _label("01  Take the gold relic. Return to the blue extraction circle.", 19, GOLD)
	footer_box.add_child(_objective_text)
	_help = _label("Watch the patrol. Use the walls to cross the courtyard unseen.", 14, MUTED)
	footer_box.add_child(_help)
	footer_box.add_child(_label("WASD / ARROWS  move     SHIFT  slow walk     SPACE  jump     TAB  vision overlay     R  restart", 12, TEXT))

	_result_panel = _panel()
	_result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result_panel.position = Vector2(-280, -100)
	_result_panel.custom_minimum_size = Vector2(560, 200)
	screen.add_child(_result_panel)
	var result_box := _padded_box(_result_panel)
	_result_title = _label("", 32, TEXT)
	result_box.add_child(_result_title)
	_result_detail = _label("", 17, MUTED)
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_detail.custom_minimum_size.x = 500
	result_box.add_child(_result_detail)
	_result_panel.hide()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(Color(INK, 0.96), 10)
	style.border_color = Color("304252")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _padded_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	margin.add_child(box)
	return box
