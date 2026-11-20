extends Control
## Displays the source signature at the desk and the editable draft in cover.

signal tuck_away_requested
signal signature_forged

enum View { CLOSED, MANUSCRIPT, DRAFT }

const Signatures := preload("res://Modules/Gameplay/SignatureForgery/signatures.gd")
const CREAM := Color("f3e2bd")
const MUTED := Color("b0bfc2")
const CYAN := Color("8de1d5")
const CHARCOAL := Color("111a23")
const EDGE := Color("405762")
const PAPER := Color("ecd5a6")
const INK := Color("302420")
const MANUSCRIPT_SIZE := Vector2(492, 544)
const DRAFT_SIZE := Vector2(632, 370)
const MANUSCRIPT_PAPER := Rect2(18, 83, 456, 400)
const SOURCE_INK_RECT := Rect2(214, 386, 240, 62)

var view := View.CLOSED
var using_controller := false:
	set(value):
		if using_controller != value:
			using_controller = value
			queue_redraw()
var target: PackedInt32Array
var variant_index := -1
var manifest_title := "LAMPLIGHT EXCHANGE"
var manifest_subtitle := "West wing · Night shift"
var signer := "Sorting clerk"
var entries := [["6 sacks of oats", "North Quay"], ["3 crates of candles", "East Pier"], ["2 barrels of salt", "Canal Gate"]]
var amendment := ""
var source_ink: ImageTexture
var draft := PackedInt32Array()
var selection := 0
var rejected := false
var _stick_direction := 0
var _draft_ink: ImageTexture
var _stroke_icons: Array[ImageTexture] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	if variant_index < 0:
		variant_index = randi_range(0, Signatures.VARIANTS.size() - 1)
	target = PackedInt32Array(Signatures.VARIANTS[variant_index])
	source_ink = Signatures.make_ink(target, target.size())
	for index in Signatures.STROKES.size():
		_stroke_icons.append(Signatures.make_ink(PackedInt32Array([index]), 1))
	hide()


func present(next_view: View) -> void:
	view = next_view
	_stick_direction = 0
	for device in Input.get_connected_joypads():
		_stick_direction = _read_stick(Input.get_joy_axis(device, JOY_AXIS_LEFT_X))
		if _stick_direction != 0:
			break
	show()
	queue_redraw()


func dismiss() -> void:
	view = View.CLOSED
	hide()


func handle_input(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		if view == View.DRAFT and event.axis == JOY_AXIS_LEFT_X:
			var direction := _read_stick(event.axis_value)
			if direction != 0 and direction != _stick_direction:
				_select(direction)
			_stick_direction = direction
			return true
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action_pressed("secondary_action") or (view == View.MANUSCRIPT and event.is_action_pressed("interact")):
		tuck_away_requested.emit()
		return true
	if view != View.DRAFT:
		return false
	if event.is_action_pressed("move_left"):
		_select(-1)
	elif event.is_action_pressed("move_right"):
		_select(1)
	elif event.is_action_pressed("jump"):
		if not draft.is_empty():
			draft.resize(draft.size() - 1)
			_update_draft()
	elif event.is_action_pressed("interact"):
		if draft.size() < target.size():
			draft.append(selection)
			_update_draft()
		elif draft == target:
			signature_forged.emit()
		else:
			rejected = true
			queue_redraw()
	else:
		return false
	return true


func _read_stick(axis: float) -> int:
	if absf(axis) >= 0.55:
		return 1 if axis > 0.0 else -1
	return _stick_direction if absf(axis) > 0.25 else 0


func _select(direction: int) -> void:
	selection = posmod(selection + direction, _stroke_icons.size())
	queue_redraw()


func _update_draft() -> void:
	rejected = false
	_draft_ink = Signatures.make_ink(draft, target.size())
	queue_redraw()


func _draw() -> void:
	if view == View.CLOSED:
		return
	var panel_size := MANUSCRIPT_SIZE if view == View.MANUSCRIPT else DRAFT_SIZE
	var fit := minf(1.0, minf((size.x - 56.0) / panel_size.x, (size.y - 144.0) / panel_size.y))
	if fit <= 0.0:
		return
	draw_set_transform(size - Vector2(28, 78) - panel_size * fit, 0.0, Vector2.ONE * fit)
	draw_rect(Rect2(Vector2(0, 5), panel_size), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2.ZERO, panel_size), CHARCOAL)
	draw_rect(Rect2(Vector2.ZERO, panel_size), EDGE, false, 1.0)
	if view == View.MANUSCRIPT:
		_draw_manuscript()
	else:
		_draw_draft()


func _draw_manuscript() -> void:
	_write("Study the signature", Vector2(24, 33), 24, CREAM)
	_write("Memorize the strokes, then find cover.", Vector2(24, 59), 18, MUTED)
	draw_rect(MANUSCRIPT_PAPER, PAPER)
	draw_rect(MANUSCRIPT_PAPER.grow(-10), Color("c1a878"), false, 1.0)
	_write(manifest_title, Vector2(44, 127), 22, INK)
	_write(manifest_subtitle, Vector2(44, 154), 17, INK)
	draw_line(Vector2(44, 171), Vector2(448, 171), Color("947449"))
	_write("Cargo", Vector2(44, 195), 16, INK)
	_write("Destination", Vector2(286, 195), 16, INK)
	for row in entries.size():
		var baseline := 231 + row * 39
		_write(entries[row][0], Vector2(44, baseline), 18, INK)
		_write(entries[row][1], Vector2(286, baseline), 18, INK)
		draw_line(Vector2(44, baseline + 11), Vector2(448, baseline + 11), Color("c1a878"))
	_write(signer, Vector2(292, 386), 16, INK)
	draw_line(Vector2(220, 427), Vector2(448, 427), Color("b39a6d"))
	draw_texture_rect(source_ink, SOURCE_INK_RECT, false)
	var controls := "Circle or Triangle   Tuck away" if using_controller else "E or Q   Tuck away"
	_write(controls, Vector2(24, 517), 18, CREAM)


func _draw_draft() -> void:
	_write("Forge the signature", Vector2(24, 34), 24, CREAM)
	var instruction := "Rebuild the clerk’s signature from memory."
	if not amendment.is_empty():
		instruction = amendment
	if rejected:
		instruction = "Signature doesn’t match. Undo a stroke or study it again."
	_write(instruction, Vector2(24, 62), 18, Color("f3b09d") if rejected else MUTED)
	draw_rect(Rect2(24, 83, 584, 123), PAPER)
	var signature_rect := Rect2(100, 87, 432, 112)
	var stroke_width := signature_rect.size.x / float(Signatures.STROKE_ADVANCE * target.size() + 20)
	for slot in target.size():
		var start := signature_rect.position.x + stroke_width * (10 + Signatures.STROKE_ADVANCE * slot)
		var end := start + stroke_width * Signatures.STROKE_ADVANCE
		var color := Color("8a572f") if slot == draft.size() else Color("b39a6d")
		draw_line(Vector2(start + 3, 181), Vector2(end - 3, 181), color, 2.0, true)
	if _draft_ink != null:
		draw_texture_rect(_draft_ink, signature_rect, false)
	for index in _stroke_icons.size():
		var box := Rect2(24 + index * 99, 225, 89, 78)
		var selected := index == selection and draft.size() < target.size()
		draw_rect(box, Color("fbedd0") if selected else PAPER)
		if selected:
			draw_rect(box.grow(2), CYAN, false, 2.0)
		draw_texture_rect(_stroke_icons[index], box.grow(-6), false)
	var action := "Submit" if draft.size() == target.size() else "Ink stroke"
	var controls := "Stick / D-pad   Pick     Circle   %s     Cross   Undo     Triangle   Tuck away" if using_controller else "← →   Pick      E   %s      Space   Undo      Q   Tuck away"
	_write(controls % action, Vector2(24, 341), 16, CREAM)


func _write(value: String, baseline: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, baseline, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
