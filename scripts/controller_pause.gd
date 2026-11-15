extends CanvasLayer
## Options pauses gameplay; the opening cinematic retains its own skip input.
var active := false
var _closing := false
var _overlay: Control
var _panel: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.07, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var panel := VBoxContainer.new()
	_overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position -= Vector2(280, 230)
	panel.size = Vector2(560, 460)
	panel.add_theme_constant_override("separation", 16)
	for line in ["PAUSED", "Left stick / D-pad  •  Move in any direction", "Cross  •  Jump / dialogue     Circle  •  Interact", "R1  •  Run     L1  •  Quiet walk", "Triangle  •  Bell / peek     L3  •  Vision / HUD", "Share  •  Map"]:
		var label := Label.new()
		label.text = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 28 if line == "PAUSED" else 18)
		panel.add_child(label)
	var resume := Button.new()
	resume.text = "Resume  —  Cross / Circle / Options"
	resume.pressed.connect(_resume)
	panel.add_child(resume)
	var restart := Button.new()
	restart.text = "Restart level  —  Triangle / R"
	restart.pressed.connect(_restart)
	panel.add_child(restart)
	_overlay.hide()
	_panel = panel
	get_viewport().size_changed.connect(_update_layout)
	_update_layout.call_deferred()

func _update_layout() -> void:
	var extent := get_viewport().get_visible_rect().size
	var ui_scale := minf(extent.x / 1440.0, extent.y / 900.0)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * ui_scale
	_panel.position = (extent - _panel.size) * 0.5

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		active = true
		_overlay.show()
		get_tree().paused = true

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("pause_game") or event.is_action_pressed("dialogue_advance") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_resume()
	elif event.is_action_pressed("secondary_action") or event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		_restart()

func _resume() -> void:
	if _closing:
		return
	_closing = true
	# Consume the resume press before physics can interpret Cross as a jump.
	await get_tree().create_timer(0.12, true).timeout
	_overlay.hide()
	active = false
	_closing = false
	get_tree().paused = false

func _restart() -> void:
	if _closing:
		return
	_overlay.hide()
	active = false
	get_tree().paused = false
	get_tree().reload_current_scene()
