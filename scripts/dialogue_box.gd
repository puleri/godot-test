extends Node2D
## Shared illustrated HUD dialogue. Coordinates use the source art's 1667px canvas.
signal dialogue_finished

const INK := Color("eee5cf")
var active := false
var line_index := 0
var lines: Array[Dictionary] = []
var _revealing := false
var _clock := 0.0
var _delay := 0.0
var _closing := false
var _motion: Tween
var _speaker: Label
var _body: Label
var _hint: Label
var _count: Label
var _rest_position := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_speaker = _make_label(Vector2(-665, -130), Vector2(1200, 55), 37)
	_body = _make_label(Vector2(-665, -62), Vector2(1240, 190), 42)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_hint = _make_label(Vector2(270, 123), Vector2(350, 45), 23)
	_count = _make_label(Vector2(-665, 123), Vector2(220, 45), 23)
	_count.modulate.a = 0.55
	$ContinueButton.position = Vector2(563, 146)
	$ContinueButton.scale = Vector2(0.55, 0.55)
	hide()


func _make_label(at: Vector2, extent: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	add_child(label)
	return label


func start_dialogue(dialogue_lines: Array[Dictionary]) -> void:
	if active or dialogue_lines.is_empty():
		return
	lines = dialogue_lines.duplicate(true)
	line_index = 0
	active = true
	_closing = false
	_rest_position = position
	show()
	modulate.a = 0.0
	scale *= 0.94
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(self, "modulate:a", 1.0, 0.18)
	_motion.tween_property(self, "scale", scale / 0.94, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_line()


func _show_line() -> void:
	var line := lines[line_index]
	_speaker.text = line.speaker
	_speaker.modulate = Color("d6c48d") if line.speaker == "Pot Goblin" else Color("9ed8e3")
	_body.text = line.text
	_body.visible_characters = 0
	_revealing = true
	_clock = 0.0
	_delay = 0.028
	_count.text = "%02d / %02d" % [line_index + 1, lines.size()]
	_hint.text = "REVEAL"
	$Splatter.modulate = _speaker.modulate


func _process(delta: float) -> void:
	if not active or _closing:
		return
	_clock += delta
	if _revealing and _clock >= _delay:
		_clock = 0.0
		_body.visible_characters += 1
		var character := _body.text.substr(_body.visible_characters - 1, 1)
		_delay = 0.19 if character in [".", "!", "?"] else (0.10 if character == "," else 0.028)
		if _body.visible_characters >= _body.text.length():
			_reveal_all()
	$ContinueButton.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.004) if not _revealing else 0.5


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		advance()


func _reveal_all() -> void:
	_body.visible_characters = -1
	_revealing = false
	_hint.text = "END" if line_index == lines.size() - 1 else "CONTINUE"


func advance() -> void:
	if not active or _closing:
		return
	if _revealing:
		_reveal_all()
	elif line_index + 1 < lines.size():
		line_index += 1
		_show_line()
	else:
		_closing = true
		if _motion:
			_motion.kill()
		_motion = create_tween().set_parallel(true)
		_motion.tween_property(self, "modulate:a", 0.0, 0.16)
		_motion.tween_property(self, "position:y", _rest_position.y + 14.0, 0.16)
		_motion.chain().tween_callback(func():
			hide()
			position = _rest_position
			active = false
			_closing = false
			dialogue_finished.emit())
