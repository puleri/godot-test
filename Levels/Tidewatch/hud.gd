extends CanvasLayer

const INK := Color("111d2a")
const CREAM := Color("f9e7ca")
const MUTED := Color("a9bdc8")
const TEAL := Color("83e3dd")
const GOLD := Color("f6bb75")

var _objective: Label
var _hint: Label
var _visibility: Label
var _danger: Label
var _target: Label
var _result: PanelContainer
var _result_title: Label
var _result_detail: Label


func _ready() -> void:
	layer = 5
	var panel := _panel(8.0)
	panel.position = Vector2(34, 30)
	add_child(panel)
	var lines := VBoxContainer.new()
	panel.add_child(lines)
	lines.add_child(_label("T I D E W A T C H", 17, TEAL))
	_objective = _label("", 29, CREAM)
	lines.add_child(_objective)

	var status := _panel(8.0)
	add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -246
	status.offset_right = -34
	status.offset_top = 30
	var status_lines := VBoxContainer.new()
	status.add_child(status_lines)
	_visibility = _label("", 21, TEAL)
	_danger = _label("", 15, GOLD)
	status_lines.add_child(_visibility)
	status_lines.add_child(_danger)

	var help := _panel(7.0)
	add_child(help)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -116
	help.offset_bottom = -24
	help.offset_left = 34
	help.offset_right = -34
	var help_lines := VBoxContainer.new()
	help.add_child(help_lines)
	_hint = _label("", 23, CREAM)
	help_lines.add_child(_hint)
	help_lines.add_child(_label("A / D   Move & lean     Space   Jump     Shift   Quiet walk     Click / F   Slingshot     E   Winch     R   Restart", 17, MUTED))

	_target = _label("◇", 42, TEAL)
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target.size = Vector2(56, 56)
	_target.add_theme_constant_override("outline_size", 7)
	add_child(_target)
	_target.hide()

	_result = _panel(16.0)
	add_child(_result)
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result.offset_left = -275
	_result.offset_right = 275
	_result.offset_top = -98
	_result.offset_bottom = 98
	var result_lines := VBoxContainer.new()
	result_lines.alignment = BoxContainer.ALIGNMENT_CENTER
	result_lines.add_theme_constant_override("separation", 10)
	_result.add_child(result_lines)
	_result_title = _label("", 35, CREAM)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lines.add_child(_result_title)
	_result_detail = _label("", 20, MUTED)
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lines.add_child(_result_detail)
	var restart := _label("R   TRY AGAIN", 16, TEAL)
	restart.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lines.add_child(restart)
	_result.hide()


func update_display(objective: String, hint: String, exposure: float, danger: String) -> void:
	_objective.text = objective
	_hint.text = hint
	_visibility.text = "IN SHADOW" if exposure <= 0.12 else ("IN DIM LIGHT" if exposure < 0.30 else "IN LIGHT")
	_visibility.add_theme_color_override("font_color", TEAL.lerp(GOLD, minf(exposure * 2.5, 1.0)))
	_danger.text = danger


func set_target(at: Vector2) -> void:
	_target.visible = at.is_finite()
	if _target.visible:
		_target.position = at - _target.size * 0.5


func show_result(title: String, detail: String) -> void:
	_result_title.text = title
	_result_detail.text = detail
	_result.show()


func _label(content: String, pixels: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", pixels)
	return label


func _panel(radius: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK, 0.94)
	style.border_color = Color("355766")
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(radius))
	style.content_margin_left = 19
	style.content_margin_right = 19
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel
